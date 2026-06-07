import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart';
import '../color_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/app_ui.dart';
import '../network/probe_priority.dart';
import '../ui/platform_icon.dart';

const _lanProbeTimeoutSheet = Duration(seconds: 3);
const _sheetLanProbeConcurrency = 6;
const _sheetSignalingProbeConcurrency = 3;
const _keySendTabIndex = 'ultrasend_send_tab_index';

/// Sort rank from resolved reach status; checking is probe UI, not device state.
int _reachSortRank(String status) {
  switch (status) {
    case 'online':
      return 0;
    case 'connectable':
    case 'pull_online':
      return 1;
    default:
      return 2;
  }
}

String _resolvedSortStatus(String? current, String? stable) {
  if (current != null && current != 'checking') return current;
  return stable ?? 'offline';
}

_SheetColors _sheetColors(BuildContext context) {
  final theme = Theme.of(context);
  final colors = context.appColors;
  return _SheetColors(
    onSurface: colors.textPrimary,
    muted: colors.textSecondary,
    divider: colors.border,
    success: colors.success,
    info: AppColorTheme.s3Color,
    danger: colors.danger,
    accent: theme.colorScheme.primary,
  );
}

class _SheetColors {
  final Color onSurface;
  final Color muted;
  final Color divider;
  final Color success;
  final Color info;
  final Color danger;
  final Color accent;
  _SheetColors({
    required this.onSurface,
    required this.muted,
    required this.divider,
    required this.success,
    required this.info,
    required this.danger,
    required this.accent,
  });
}

class FileSendChoice {
  final String mode; // 's3', 'lan', 'webrtc'
  final List<String>? targetDeviceIds;
  FileSendChoice._({required this.mode, this.targetDeviceIds});
  factory FileSendChoice.s3() => FileSendChoice._(mode: 's3');
  factory FileSendChoice.lan(List<DeviceDto> devices) => FileSendChoice._(
    mode: 'lan',
    targetDeviceIds: devices.map((d) => d.deviceId).toList(),
  );
  factory FileSendChoice.webrtc(List<DeviceDto> devices) => FileSendChoice._(
    mode: 'webrtc',
    targetDeviceIds: devices.map((d) => d.deviceId).toList(),
  );

  bool get useLan => mode == 'lan';
  bool get useWebRTC => mode == 'webrtc';
  List<String>? get lanDeviceIds => targetDeviceIds;
}

class FileSendSheet extends StatefulWidget {
  const FileSendSheet({
    super.key,
    required this.fileNames,
    required this.myDevices,
    required this.discoveredDevices,
    required this.onCancel,
    this.onS3,
    required this.onLan,
    this.onWebRTC,
    this.lanReceiverUrl,
    this.onProbePull,
    this.onLanHttpProbe,
    this.onWebRTCProbe,
    this.offlineMode = false,
    this.manualHttpAttempt = false,
    this.s3Configured = true,
    this.onOpenS3Settings,
  });
  final List<String> fileNames;
  final List<DeviceDto> myDevices;
  final List<DeviceDto> discoveredDevices;
  final VoidCallback onCancel;
  final VoidCallback? onS3;
  final void Function(List<DeviceDto> selected) onLan;
  final void Function(List<DeviceDto> selected)? onWebRTC;
  final String? lanReceiverUrl;
  final Future<bool> Function(String targetDeviceId)? onProbePull;
  final Future<({bool success, String? lanHttpUrl, bool senderReachable})>
  Function(String targetDeviceId)?
  onLanHttpProbe;
  final Future<String> Function(String targetDeviceId)? onWebRTCProbe;
  final bool offlineMode;
  final bool manualHttpAttempt;
  final bool s3Configured;
  final VoidCallback? onOpenS3Settings;

  List<DeviceDto> get allDevices => [...myDevices, ...discoveredDevices];

  @override
  State<FileSendSheet> createState() => _FileSendSheetState();
}

class _FileSendSheetState extends State<FileSendSheet>
    with SingleTickerProviderStateMixin {
  final Set<String> _mySelectedIds = {};
  final Set<String> _discoveredSelectedIds = {};
  final Set<String> _webrtcSelectedIds = {};
  Map<String, String> _reachability = {};
  Map<String, String> _webrtcReachability = {};
  Map<String, String> _lanSortReach = {};
  Map<String, String> _webrtcSortReach = {};
  late TabController _tabController;

  // offline: 1 tab (all LAN); online: 4 tabs
  int get _tabCount => widget.offlineMode ? 1 : 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
    if (!widget.offlineMode) _loadSavedTab();
    _startProbes();
  }

  Future<void> _loadSavedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_keySendTabIndex) ?? 0;
    if (mounted && saved >= 0 && saved < _tabCount) {
      _tabController.index = saved;
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_keySendTabIndex, _tabController.index);
      });
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FileSendSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myDevices != widget.myDevices ||
        oldWidget.discoveredDevices != widget.discoveredDevices) {
      _startProbes();
    }
  }

  void _setLanReach(String deviceId, String status) {
    _reachability = {..._reachability, deviceId: status};
    if (status != 'checking') {
      _lanSortReach = {..._lanSortReach, deviceId: status};
    }
  }

  void _setWebrtcReach(String deviceId, String status) {
    _webrtcReachability = {..._webrtcReachability, deviceId: status};
    if (status != 'checking') {
      _webrtcSortReach = {..._webrtcSortReach, deviceId: status};
    }
  }

  Future<void> _runSheetProbeWave(
    List<DeviceDto> devices,
    int concurrency,
    Future<void> Function(DeviceDto) probe,
  ) async {
    if (devices.isEmpty) return;
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < devices.length) {
        final index = nextIndex++;
        await probe(devices[index]);
      }
    }
    final workers = concurrency < devices.length ? concurrency : devices.length;
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  void _probeOneSheetDevice(DeviceDto d) {
    final hasLan = d.lanHttpUrl != null && d.lanHttpUrl!.isNotEmpty;
    if (!widget.offlineMode && widget.onLanHttpProbe != null) {
      unawaited(_probeLanViaCentrifugo(d.deviceId, fallbackLanUrl: d.lanHttpUrl));
    } else if (hasLan) {
      unawaited(_probeDirectPush(d.deviceId, d.lanHttpUrl!));
    } else if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
      unawaited(_probeReversePull(d.deviceId));
    } else if (mounted) {
      setState(() => _setLanReach(d.deviceId, 'offline'));
    }
    if (!widget.offlineMode) {
      unawaited(_probeWebRTC(d.deviceId));
    } else if (mounted) {
      setState(() => _setWebrtcReach(d.deviceId, 'offline'));
    }
  }

  void _startProbes({bool forceAll = false}) {
    final devices = widget.allDevices;
    final nearbyIds = widget.discoveredDevices.map((d) => d.deviceId).toSet();
    final myIds = widget.myDevices.map((d) => d.deviceId).toSet();
    final partition = partitionForProbe(
      devices,
      nearbyIds: nearbyIds,
      myDeviceIds: myIds,
    );
    final toProbe = forceAll
        ? devices
        : [...partition.lanDiscovered, ...partition.presenceOnline];
    final lazyIds = partition.lazy.map((d) => d.deviceId).toSet();
    final probeIds = toProbe.map((d) => d.deviceId).toSet();

    final next = <String, String>{};
    final nextWebrtc = <String, String>{};
    for (final d in devices) {
      final prevLan = _reachability[d.deviceId];
      if (prevLan != null && prevLan != 'checking') {
        _lanSortReach[d.deviceId] = prevLan;
      }
      final prevWebrtc = _webrtcReachability[d.deviceId];
      if (prevWebrtc != null && prevWebrtc != 'checking') {
        _webrtcSortReach[d.deviceId] = prevWebrtc;
      }
      if (lazyIds.contains(d.deviceId)) {
        next[d.deviceId] = 'offline';
        nextWebrtc[d.deviceId] = 'offline';
      } else if (probeIds.contains(d.deviceId)) {
        next[d.deviceId] = 'checking';
        nextWebrtc[d.deviceId] = 'checking';
      } else {
        next[d.deviceId] = _reachability[d.deviceId] ?? 'offline';
        nextWebrtc[d.deviceId] = _webrtcReachability[d.deviceId] ?? 'offline';
      }
    }
    setState(() {
      _reachability = next;
      _webrtcReachability = nextWebrtc;
    });

    if (toProbe.isEmpty) return;

    unawaited(() async {
      if (forceAll) {
        await _runSheetProbeWave(
          toProbe,
          _sheetSignalingProbeConcurrency,
          (d) async => _probeOneSheetDevice(d),
        );
        return;
      }
      await _runSheetProbeWave(
        partition.lanDiscovered,
        _sheetLanProbeConcurrency,
        (d) async => _probeOneSheetDevice(d),
      );
      if (!mounted) return;
      await _runSheetProbeWave(
        partition.presenceOnline,
        _sheetSignalingProbeConcurrency,
        (d) async => _probeOneSheetDevice(d),
      );
    }());
  }

  Future<void> _probeLanViaCentrifugo(
    String deviceId, {
    String? fallbackLanUrl,
  }) async {
    try {
      final result = await widget.onLanHttpProbe!(deviceId).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            (success: false, lanHttpUrl: null, senderReachable: false),
      );
      if (!mounted) return;
      if (result.senderReachable) {
        setState(() => _setLanReach(deviceId, 'pull_online'));
        return;
      }
      final url = result.lanHttpUrl ?? fallbackLanUrl;
      if (result.success && url != null && url.isNotEmpty) {
        await _probeDirectPush(deviceId, url);
        return;
      }
      if (result.success) {
        setState(() => _setLanReach(deviceId, 'pull_offline'));
        return;
      }
      if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
        await _probeReversePull(deviceId);
        return;
      }
      setState(() => _setLanReach(deviceId, 'offline'));
    } catch (_) {
      if (!mounted) return;
      if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
        await _probeReversePull(deviceId);
        return;
      }
      setState(() => _setLanReach(deviceId, 'offline'));
    }
  }

  Future<void> _probeWebRTC(String deviceId) async {
    if (widget.onWebRTCProbe == null) {
      if (!mounted) return;
      setState(() => _setWebrtcReach(deviceId, 'offline'));
      return;
    }
    try {
      final status = await widget.onWebRTCProbe!(deviceId).timeout(
        const Duration(seconds: 12),
        onTimeout: () => 'offline',
      );
      if (!mounted) return;
      setState(() => _setWebrtcReach(deviceId, status));
    } catch (_) {
      if (!mounted) return;
      setState(() => _setWebrtcReach(deviceId, 'offline'));
    }
  }

  Future<void> _probeDirectPush(String deviceId, String lanHttpUrl) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = _lanProbeTimeoutSheet;
      final uri = Uri.parse('$lanHttpUrl/probe');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(_lanProbeTimeoutSheet);
      await response.drain<void>();
      if (response.statusCode == HttpStatus.ok) {
        if (!mounted) return;
        setState(() {
          if (_reachability[deviceId] == 'checking') {
            _setLanReach(deviceId, 'online');
          }
        });
        return;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    if (!mounted) return;
    if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
      _probeReversePull(deviceId);
    } else {
      setState(() {
        if (_reachability[deviceId] == 'checking') {
          _setLanReach(deviceId, 'offline');
        }
      });
    }
  }

  Future<void> _probeReversePull(String deviceId) async {
    try {
      final success = await widget.onProbePull!(deviceId).timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (!mounted) return;
      setState(() {
        _setLanReach(deviceId, success ? 'pull_online' : 'pull_offline');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _setLanReach(deviceId, 'pull_offline'));
    }
  }

  String _statusLabel(AppLocalizations l10n, String status, bool hasLan) {
    switch (status) {
      case 'checking':
        return l10n.fileSendStatusChecking;
      case 'online':
        return l10n.fileSendLanStatusOnlineDirect;
      case 'pull_online':
        return l10n.fileSendLanStatusPullAvailable;
      case 'pull_offline':
        return l10n.fileSendLanStatusUnreachable;
      case 'offline':
        return hasLan
            ? l10n.fileSendLanStatusOfflineDirect
            : l10n.fileSendLanStatusUnreachable;
      default:
        return '';
    }
  }

  Color _statusColor(_SheetColors colors, String status) {
    switch (status) {
      case 'online':
        return colors.success;
      case 'pull_online':
        return colors.info;
      default:
        return colors.muted;
    }
  }

  String _buildTitle(AppLocalizations l10n) {
    final fileCount = widget.fileNames.length;
    if (fileCount == 1) {
      return l10n.fileSendTitleSingle(widget.fileNames.first);
    }
    return l10n.fileSendTitleMany(widget.fileNames.first, fileCount);
  }

  Widget _buildS3Tab(_SheetColors colors, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final notConfigured = !widget.s3Configured;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fileSendS3Intro,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
          if (notConfigured) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.12),
                borderRadius: AppRadius.small,
                border: Border.all(
                  color: colors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.cloudOff, size: 18, color: colors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.fileSendS3ConfigurePrompt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.onOpenS3Settings != null)
              TextButton.icon(
                onPressed: widget.onOpenS3Settings,
                icon: const Icon(LucideIcons.settings, size: 18),
                label: Text(l10n.connectionBarGoToS3Setup),
              ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(LucideIcons.circleCheck, size: 12, color: colors.success),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  l10n.fileSendResumeSupported,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _webrtcStatusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'checking':
        return l10n.fileSendStatusChecking;
      case 'online':
        return l10n.fileSendWebRtcStatusOnline;
      case 'connectable':
        return l10n.fileSendWebRtcStatusConnectable;
      case 'offline':
        return l10n.fileSendWebRtcStatusOffline;
      default:
        return '';
    }
  }

  Color _webrtcStatusColor(_SheetColors colors, String status) {
    switch (status) {
      case 'online':
      case 'connectable':
        return colors.success;
      default:
        return colors.muted;
    }
  }

  Set<String> get _myDeviceIdSet =>
      widget.myDevices.map((d) => d.deviceId).toSet();

  List<DeviceDto> _sortedByWebRTCStatus(List<DeviceDto> devices) {
    int priority(DeviceDto d) {
      return _reachSortRank(
        _resolvedSortStatus(
          _webrtcReachability[d.deviceId],
          _webrtcSortReach[d.deviceId],
        ),
      );
    }

    int mineRank(DeviceDto d) => _myDeviceIdSet.contains(d.deviceId) ? 0 : 1;

    return List<DeviceDto>.from(devices)..sort((a, b) {
      final byMine = mineRank(a).compareTo(mineRank(b));
      if (byMine != 0) return byMine;
      final byReach = priority(a).compareTo(priority(b));
      if (byReach != 0) return byReach;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  List<DeviceDto> _sortedByLanStatus(List<DeviceDto> devices) {
    int priority(DeviceDto d) {
      return _reachSortRank(
        _resolvedSortStatus(
          _reachability[d.deviceId],
          _lanSortReach[d.deviceId],
        ),
      );
    }

    int mineRank(DeviceDto d) => _myDeviceIdSet.contains(d.deviceId) ? 0 : 1;

    return List<DeviceDto>.from(devices)..sort((a, b) {
      final byMine = mineRank(a).compareTo(mineRank(b));
      if (byMine != 0) return byMine;
      final byReach = priority(a).compareTo(priority(b));
      if (byReach != 0) return byReach;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Widget _buildWebRTCTab(_SheetColors colors, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final allDevices = widget.allDevices;
    if (allDevices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.xs,
        ),
        child: Text(
          l10n.fileSendWebRtcEmptyNoDevices,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            l10n.fileSendWebRtcIntro,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
        ),
        ..._sortedByWebRTCStatus(allDevices).map((d) {
          final idShort = d.deviceId.length > 12
              ? '${d.deviceId.substring(0, 12)}…'
              : d.deviceId;
          final supportsResume = !d.isWeb;
          final status = _webrtcReachability[d.deviceId] ?? 'checking';
          final canSelect = status == 'online' || status == 'connectable';
          return _buildDeviceRow(
            d: d,
            idShort: idShort,
            canSelect: canSelect,
            isSelected: _webrtcSelectedIds.contains(d.deviceId),
            onToggle: () => setState(() {
              if (_webrtcSelectedIds.contains(d.deviceId)) {
                _webrtcSelectedIds.remove(d.deviceId);
              } else {
                _webrtcSelectedIds.add(d.deviceId);
              }
            }),
            statusWidget: Row(
              children: [
                if (status == 'checking') ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Text(
                  _webrtcStatusLabel(l10n, status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _webrtcStatusColor(colors, status),
                  ),
                ),
                if (canSelect) ...[
                  Text(
                    ' · ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                  Text(
                    supportsResume
                        ? l10n.fileSendResumeSupported
                        : l10n.fileSendResumeNotSupported,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: supportsResume ? colors.success : colors.danger,
                    ),
                  ),
                ],
              ],
            ),
            colors: colors,
          );
        }),
      ],
    );
  }

  Widget _buildDeviceListTab(
    AppLocalizations l10n,
    _SheetColors colors,
    List<DeviceDto> devices,
    Set<String> selectedIds,
    VoidCallback Function(DeviceDto d) onToggleFactory,
    String emptyMessage,
  ) {
    final theme = Theme.of(context);
    if (devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.xs,
        ),
        child: Text(
          emptyMessage,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      children: [
        ..._sortedByLanStatus(devices).map((d) {
          final hasLan = d.lanHttpUrl != null && d.lanHttpUrl!.isNotEmpty;
          final status = _reachability[d.deviceId] ?? 'checking';
          final canSelect =
              status == 'online' ||
              status == 'pull_online' ||
              widget.manualHttpAttempt;
          final idShort = d.deviceId.length > 12
              ? '${d.deviceId.substring(0, 12)}…'
              : d.deviceId;
          return _buildDeviceRow(
            d: d,
            idShort: idShort,
            canSelect: canSelect,
            isSelected: selectedIds.contains(d.deviceId),
            onToggle: onToggleFactory(d),
            statusWidget: Row(
              children: [
                if (status == 'checking') ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Text(
                  _statusLabel(l10n, status, hasLan),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _statusColor(colors, status),
                  ),
                ),
                if (canSelect) ...[
                  Text(
                    ' · ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                  Text(
                    d.isWeb
                        ? l10n.fileSendResumeNotSupported
                        : l10n.fileSendResumeSupported,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: d.isWeb ? colors.danger : colors.success,
                    ),
                  ),
                ],
              ],
            ),
            colors: colors,
          );
        }),
      ],
    );
  }

  Widget _buildDeviceRow({
    required DeviceDto d,
    required String idShort,
    required bool canSelect,
    required bool isSelected,
    required VoidCallback onToggle,
    required Widget statusWidget,
    required _SheetColors colors,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: canSelect ? onToggle : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: canSelect
                  ? (v) => onToggle()
                  : null,
            ),
            SizedBox(
              width: 32,
              height: 40,
              child: Center(
                child: Icon(
                  platformIcon(d.platform),
                  size: 20,
                  color: platformColor(d.platform, theme.brightness),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${d.name} ($idShort)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: canSelect ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  statusWidget,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<String> get _allLanSelectedIds => {..._mySelectedIds, ..._discoveredSelectedIds};

  Widget _buildSendButton(AppLocalizations l10n) {
    final accent = Theme.of(context).colorScheme.primary;
    if (widget.offlineMode) {
      return FilledButton(
        onPressed: _allLanSelectedIds.isEmpty
            ? null
            : () {
                final selected = widget.allDevices
                    .where((d) => _allLanSelectedIds.contains(d.deviceId))
                    .toList();
                widget.onLan(selected);
              },
        style: FilledButton.styleFrom(backgroundColor: accent),
        child: Text(l10n.fileSendSendToSelected),
      );
    }
    switch (_tabController.index) {
      case 0:
        return FilledButton(
          onPressed: _mySelectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.myDevices
                      .where((d) => _mySelectedIds.contains(d.deviceId))
                      .toList();
                  widget.onLan(selected);
                },
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(l10n.fileSendSendToSelected),
        );
      case 1:
        return FilledButton(
          onPressed: _discoveredSelectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.discoveredDevices
                      .where((d) => _discoveredSelectedIds.contains(d.deviceId))
                      .toList();
                  widget.onLan(selected);
                },
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(l10n.fileSendSendToSelected),
        );
      case 2:
        return FilledButton(
          onPressed: _webrtcSelectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.allDevices
                      .where((d) => _webrtcSelectedIds.contains(d.deviceId))
                      .toList();
                  widget.onWebRTC!(selected);
                },
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(l10n.fileSendViaWebRtc),
        );
      case 3:
        final s3Disabled = !widget.s3Configured;
        return FilledButton(
          onPressed: s3Disabled ? null : widget.onS3,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(
            s3Disabled
                ? l10n.fileSendConfigureS3First
                : l10n.fileSendToAllDevices,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = _sheetColors(context);
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _buildTitle(l10n),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              TabBar(
                controller: _tabController,
                indicatorColor: colors.accent,
                labelColor: colors.onSurface,
                unselectedLabelColor: colors.muted,
                dividerColor: colors.divider,
                isScrollable: !widget.offlineMode,
                tabAlignment: widget.offlineMode ? null : TabAlignment.start,
                tabs: [
                  if (widget.offlineMode)
                    Tab(text: l10n.sendModeNearby)
                  else ...[
                    Tab(text: l10n.fileSendTabMyDevices),
                    Tab(text: l10n.sendModeNearby),
                    Tab(text: l10n.fileSendTabWebRtc),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('S3'),
                          if (!widget.s3Configured) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              l10n.chatS3StatusNotConfigured,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    if (widget.offlineMode)
                      _buildDeviceListTab(
                        l10n,
                        colors,
                        widget.allDevices,
                        _allLanSelectedIds,
                        (d) => () => setState(() {
                              final id = d.deviceId;
                              if (_mySelectedIds.contains(id)) {
                                _mySelectedIds.remove(id);
                              } else if (_discoveredSelectedIds.contains(id)) {
                                _discoveredSelectedIds.remove(id);
                              } else {
                                _mySelectedIds.add(id);
                              }
                            }),
                        l10n.fileSendEmptyNearbyOffline,
                      )
                    else ...[
                      _buildDeviceListTab(
                        l10n,
                        colors,
                        widget.myDevices,
                        _mySelectedIds,
                        (d) => () => setState(() {
                              if (_mySelectedIds.contains(d.deviceId)) {
                                _mySelectedIds.remove(d.deviceId);
                              } else {
                                _mySelectedIds.add(d.deviceId);
                              }
                            }),
                        l10n.fileSendEmptyMyDevicesOnLan,
                      ),
                      _buildDeviceListTab(
                        l10n,
                        colors,
                        widget.discoveredDevices,
                        _discoveredSelectedIds,
                        (d) => () => setState(() {
                              if (_discoveredSelectedIds.contains(d.deviceId)) {
                                _discoveredSelectedIds.remove(d.deviceId);
                              } else {
                                _discoveredSelectedIds.add(d.deviceId);
                              }
                            }),
                        l10n.fileSendEmptyNearbyOffline,
                      ),
                      _buildWebRTCTab(colors, l10n),
                      _buildS3Tab(colors, l10n),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildSendButton(l10n),
            ],
          ),
        ),
      ),
    );
  }
}
