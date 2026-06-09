import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api.dart';
import '../logger.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/device_provider.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';

const _qrLoginPrefix = 'ultrasend://qr-login/';
final _qrLoginSessionPattern = RegExp(
  'ultrasend://qr-login/([0-9a-fA-F-]{36})',
);

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  MobileScannerController? _controller;
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  bool _processing = false;
  bool _permissionGranted = false;
  bool _permissionChecked = false;
  bool _permissionNeedsSettings = false;
  DateTime? _lastUnrecognizedHintAt;
  String? _lastHandledSessionId;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  MobileScannerController _createController() {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 0,
      cameraResolution: const Size(1920, 1080),
    );
  }

  void _attachBarcodeListener() {
    final controller = _controller;
    if (controller == null) return;
    _barcodeSubscription?.cancel();
    _barcodeSubscription = controller.barcodes.listen(
      _onBarcodeCapture,
      onError: (Object error, StackTrace stackTrace) {
        logAuth.warning('qr_scanner barcode stream error: $error');
      },
    );
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted &&
        !status.isPermanentlyDenied &&
        !status.isRestricted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;

    await _barcodeSubscription?.cancel();
    _barcodeSubscription = null;
    await _controller?.dispose();

    if (status.isGranted) {
      _controller = _createController();
    } else {
      _controller = null;
    }

    setState(() {
      _permissionChecked = true;
      _permissionGranted = status.isGranted;
      _permissionNeedsSettings =
          status.isPermanentlyDenied || status.isRestricted;
    });

    if (status.isGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller == null) return;
        _attachBarcodeListener();
      });
    }
  }

  Iterable<String> _barcodeTextCandidates(Barcode barcode) sync* {
    final raw = barcode.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) yield raw;
    final display = barcode.displayValue?.trim();
    if (display != null && display.isNotEmpty) yield display;
    final url = barcode.url?.url.trim();
    if (url != null && url.isNotEmpty) yield url;
  }

  String? _parseSessionId(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith(_qrLoginPrefix)) {
      final sessionId = trimmed.substring(_qrLoginPrefix.length).trim();
      if (sessionId.isNotEmpty) return sessionId;
    }
    final match = _qrLoginSessionPattern.firstMatch(trimmed);
    return match?.group(1);
  }

  String? _readQrLoginPayload(Barcode barcode) {
    for (final text in _barcodeTextCandidates(barcode)) {
      final sessionId = _parseSessionId(text);
      if (sessionId != null) return sessionId;
    }
    return null;
  }

  void _onBarcodeCapture(BarcodeCapture capture) {
    if (_processing || capture.barcodes.isEmpty) return;

    String? sessionId;
    var sawOtherQr = false;
    for (final barcode in capture.barcodes) {
      final parsed = _readQrLoginPayload(barcode);
      if (parsed != null) {
        sessionId = parsed;
        break;
      }
      if (_barcodeTextCandidates(barcode).isNotEmpty) {
        sawOtherQr = true;
      }
    }

    if (sessionId != null) {
      if (_lastHandledSessionId == sessionId) return;
      _lastHandledSessionId = sessionId;
      HapticFeedback.mediumImpact();
      setState(() => _processing = true);
      unawaited(_handleScan(sessionId));
      return;
    }

    if (sawOtherQr) {
      _showUnrecognizedQrHint();
    }
  }

  void _showUnrecognizedQrHint() {
    if (!mounted || _processing) return;
    final now = DateTime.now();
    if (_lastUnrecognizedHintAt != null &&
        now.difference(_lastUnrecognizedHintAt!) <
            const Duration(seconds: 2)) {
      return;
    }
    _lastUnrecognizedHintAt = now;
    AppToast.show(
      context,
      message: AppLocalizations.of(context).qrScannerUnrecognized,
    );
  }

  Future<void> _handleScan(String sessionId) async {
    logAuth.info('qr_scanner scanned sessionId=$sessionId');
    try {
      await scanQrSession(sessionId);
      if (!mounted) return;
      await _showConfirmDialog(sessionId);
    } catch (e) {
      logAuth.warning('qr_scanner scan failed: $e');
      if (!mounted) return;
      Analytics.track(AnalyticsEvents.qrLoginOutcome, {
        'side': 'scan',
        'status': 'error',
        'stage': 'scan_session',
      });
      AppToast.show(
        context,
        message: AppLocalizations.of(context).qrScannerFailed(
          e.toString().replaceFirst('Exception: ', ''),
        ),
      );
      if (mounted) {
        setState(() {
          _processing = false;
          _lastHandledSessionId = null;
        });
      }
    }
  }

  Future<void> _showConfirmDialog(String sessionId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.qrConfirmLoginTitle,
      content: l10n.qrConfirmLoginBody,
      confirmLabel: l10n.qrConfirmLoginConfirm,
      barrierDismissible: false,
      icon: LucideIcons.smartphone,
    );
    if (confirmed) {
      try {
        await confirmQrLogin(sessionId);
        logAuth.info('qr_scanner confirmed');
        Analytics.track(AnalyticsEvents.qrLoginOutcome, {
          'side': 'scan',
          'status': 'confirmed',
        });
        if (mounted) {
          ref.read(cloudDeviceRosterProvider.notifier).refreshSnapshot();
          AppToast.show(context, message: l10n.qrConfirmLoginSuccess);
          Navigator.of(context).pop();
        }
      } catch (e) {
        logAuth.warning('qr_scanner confirm failed: $e');
        Analytics.track(AnalyticsEvents.qrLoginOutcome, {
          'side': 'scan',
          'status': 'error',
          'stage': 'confirm',
        });
        if (mounted) {
          AppToast.show(
            context,
            message: l10n.qrConfirmLoginFailed(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          );
          setState(() {
            _processing = false;
            _lastHandledSessionId = null;
          });
        }
      }
    } else {
      Analytics.track(AnalyticsEvents.qrLoginOutcome, {
        'side': 'scan',
        'status': 'cancelled',
      });
      try {
        await cancelQrLogin(sessionId);
        logAuth.info('qr_scanner cancelled');
      } catch (e) {
        logAuth.warning('qr_scanner cancel failed: $e');
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    unawaited(_barcodeSubscription?.cancel());
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.qrLoginTitle)),
      body: !_permissionChecked
          ? const Center(child: CircularProgressIndicator())
          : !_permissionGranted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.camera,
                      size: 64,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.qrScannerNeedCamera,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_permissionNeedsSettings) ...[
                      FilledButton(
                        onPressed: () async {
                          await openAppSettings();
                        },
                        child: Text(l10n.qrScannerOpenSettings),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    TextButton(
                      onPressed: _requestCameraPermission,
                      child: Text(l10n.qrScannerPermissionAgain),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller!,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          error.errorDetails?.message ?? error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                  ),
                ),
                if (_processing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.qrScannerProcessing,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller!,
                    builder: (context, state, _) {
                      if (!state.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      final torchOn = state.torchState == TorchState.on;
                      return Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: torchOn
                              ? l10n.qrScannerTorchOff
                              : l10n.qrScannerTorchOn,
                          onPressed: () => _controller!.toggleTorch(),
                          icon: Icon(
                            torchOn ? LucideIcons.zap : LucideIcons.zapOff,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.66),
                        borderRadius: AppRadius.small,
                      ),
                      child: Text(
                        l10n.qrScannerAlignQr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
