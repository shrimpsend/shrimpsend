import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../color_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../network/connection_orchestrator.dart';
import '../network/connection_resolution.dart';
import '../network/probe_priority.dart';
import '../providers/app_mode_provider.dart';
import '../providers/device_provider.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';
import '../ui/platform_icon.dart';

const _lanProbeTimeout = Duration(seconds: 3);
const _panelLanProbeConcurrency = 6;
const _panelSignalingProbeConcurrency = 3;

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

List<SendMode> _panelModes(bool isOffline) {
  if (isOffline) return [SendMode.nearby];
  if (kIsWeb) return [SendMode.nearby, SendMode.lan, SendMode.s3];
  return [SendMode.nearby, SendMode.lan, SendMode.webrtc, SendMode.s3];
}

String _modeTabLabel(BuildContext context, SendMode mode) {
  return connectionModeLabel(mode, l10n: AppLocalizations.of(context));
}

class DevicePanel extends ConsumerStatefulWidget {
  final bool vertical;
  final String? lanReceiverUrl;
  final Future<bool> Function(String targetDeviceId)? onProbePull;
  final Future<String> Function(String targetDeviceId)? onWebRTCProbe;
  final Future<({bool success, String? lanHttpUrl, bool senderReachable})>
  Function(String targetDeviceId)?
  onLanHttpProbe;

  const DevicePanel({
    super.key,
    this.vertical = false,
    this.lanReceiverUrl,
    this.onProbePull,
    this.onWebRTCProbe,
    this.onLanHttpProbe,
  });

  @override
  ConsumerState<DevicePanel> createState() => _DevicePanelState();
}

class _DevicePanelState extends ConsumerState<DevicePanel>
    with TickerProviderStateMixin {
  Map<String, String> _lanReachability = {};
  Map<String, String> _webrtcReachability = {};
  Map<String, String> _lanSortReach = {};
  Map<String, String> _webrtcSortReach = {};
  List<DeviceDto>? _lastDevices;
  TabController? _tabController;
  bool? _lastIsOffline;
  bool _offlineCleanupScheduled = false;

  TabController _ensureTabController(bool isOffline, SendMode savedMode) {
    final modes = _availableModes(isOffline);
    final tabCount = modes.length;
    if (_tabController != null && _lastIsOffline == isOffline) {
      return _tabController!;
    }
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    final savedIdx = modes.indexOf(savedMode);
    final initialIndex = (savedIdx >= 0 ? savedIdx : 0).clamp(0, tabCount - 1);
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_onTabChanged);
    _lastIsOffline = isOffline;
    return _tabController!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cloudDeviceRosterProvider.notifier).refreshSnapshot();
    });
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    final isOffline = ref.read(effectiveOfflineModeProvider);
    final modes = _availableModes(isOffline);
    final idx = _tabController!.index;
    if (idx >= modes.length) return;
    final mode = modes[idx];
    ref.read(selectedSendModeProvider.notifier).select(mode);
    Analytics.track(AnalyticsEvents.sendModeChanged, {
      'send_mode': mode.name,
      'is_offline': isOffline,
    });
    if (mode != SendMode.s3 && _lastDevices != null) {
      _startProbes(_lastDevices!, isOffline, mode);
    }
  }

  List<SendMode> _availableModes(bool isOffline) {
    return _panelModes(isOffline);
  }

  // ---------------------------------------------------------------------------
  // Probing logic (carried over from previous implementation)
  // ---------------------------------------------------------------------------

  void _setLanReach(String deviceId, String status) {
    _lanReachability = {..._lanReachability, deviceId: status};
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

  Future<void> _runPanelProbeWave(
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

  void _probeOneDevice(DeviceDto d, bool isOffline, SendMode sendMode) {
    final hasLan = d.lanHttpUrl != null && d.lanHttpUrl!.isNotEmpty;
    final useDirectProbe = sendMode == SendMode.nearby && hasLan;
    if (!useDirectProbe && !isOffline && widget.onLanHttpProbe != null) {
      unawaited(_probeLanViaCentrifugo(d.deviceId));
    } else {
      if (hasLan) {
        unawaited(_probeDirectPush(d.deviceId, d.lanHttpUrl!));
      } else if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
        unawaited(_probeReversePull(d.deviceId));
      } else if (mounted) {
        setState(() => _setLanReach(d.deviceId, 'offline'));
      }
    }
    if (!isOffline && widget.onWebRTCProbe != null) {
      unawaited(_probeWebRTC(d.deviceId));
    } else if (mounted) {
      setState(() => _setWebrtcReach(d.deviceId, 'offline'));
    }
  }

  void _startProbes(
    List<DeviceDto> devices,
    bool isOffline,
    SendMode sendMode, {
    bool forceAll = false,
  }) {
    final nearbyIds = ref
        .read(nearbyDevicesProvider)
        .map((d) => d.deviceId)
        .toSet();
    final myIds = ref.read(myDevicesProvider).map((d) => d.deviceId).toSet();
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

    final nextLan = <String, String>{};
    final nextWebrtc = <String, String>{};
    for (final d in devices) {
      final prevLan = _lanReachability[d.deviceId];
      if (prevLan != null && prevLan != 'checking') {
        _lanSortReach[d.deviceId] = prevLan;
      }
      final prevWebrtc = _webrtcReachability[d.deviceId];
      if (prevWebrtc != null && prevWebrtc != 'checking') {
        _webrtcSortReach[d.deviceId] = prevWebrtc;
      }
      if (lazyIds.contains(d.deviceId)) {
        nextLan[d.deviceId] = 'offline';
        nextWebrtc[d.deviceId] = 'offline';
      } else if (probeIds.contains(d.deviceId)) {
        nextLan[d.deviceId] = 'checking';
        nextWebrtc[d.deviceId] = 'checking';
      } else {
        nextLan[d.deviceId] = _lanReachability[d.deviceId] ?? 'offline';
        nextWebrtc[d.deviceId] = _webrtcReachability[d.deviceId] ?? 'offline';
      }
    }
    setState(() {
      _lanReachability = nextLan;
      _webrtcReachability = nextWebrtc;
    });

    if (toProbe.isEmpty) return;

    unawaited(() async {
      if (forceAll) {
        await _runPanelProbeWave(
          toProbe,
          _panelSignalingProbeConcurrency,
          (d) async => _probeOneDevice(d, isOffline, sendMode),
        );
        return;
      }
      await _runPanelProbeWave(
        partition.lanDiscovered,
        _panelLanProbeConcurrency,
        (d) async => _probeOneDevice(d, isOffline, sendMode),
      );
      if (!mounted) return;
      await _runPanelProbeWave(
        partition.presenceOnline,
        _panelSignalingProbeConcurrency,
        (d) async => _probeOneDevice(d, isOffline, sendMode),
      );
    }());
  }

  Future<void> _probeDirectPush(String deviceId, String lanHttpUrl) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = _lanProbeTimeout;
      final uri = Uri.parse('$lanHttpUrl/probe');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(_lanProbeTimeout);
      await response.drain<void>();
      if (response.statusCode == HttpStatus.ok) {
        if (!mounted) return;
        setState(() {
          if (_lanReachability[deviceId] == 'checking') {
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
        if (_lanReachability[deviceId] == 'checking') {
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
        _setLanReach(deviceId, success ? 'pull_online' : 'offline');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _setLanReach(deviceId, 'offline'));
    }
  }

  Future<void> _probeWebRTC(String deviceId) async {
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

  Future<void> _probeLanViaCentrifugo(String deviceId) async {
    try {
      final result = await widget.onLanHttpProbe!(deviceId).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            (success: false, lanHttpUrl: null, senderReachable: false),
      );
      if (!mounted) return;
      final String status;
      if (result.senderReachable) {
        status = 'pull_online';
      } else if (result.success && result.lanHttpUrl != null) {
        status = 'online';
        final allDevices = [
          ...ref.read(myDevicesProvider),
          ...ref.read(nearbyDevicesProvider),
        ];
        final device = allDevices
            .where((d) => d.deviceId == deviceId)
            .firstOrNull;
        ref
            .read(lanDiscoveryProvider)
            .addManualDevice(
              DeviceDto(
                deviceId: deviceId,
                name: device?.name ?? deviceId,
                platform: device?.platform,
                lanHttpUrl: result.lanHttpUrl,
                lastSeen: DateTime.now().millisecondsSinceEpoch,
                presenceStatus: device?.presenceStatus,
                presenceUpdatedAt: device?.presenceUpdatedAt,
                displayCode: device?.displayCode,
              ),
            );
      } else if (result.success) {
        status = 'unreachable';
      } else {
        if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
          await _probeReversePull(deviceId);
          return;
        }
        status = 'offline';
      }
      setState(() => _setLanReach(deviceId, status));
    } catch (_) {
      if (!mounted) return;
      if (widget.lanReceiverUrl != null && widget.onProbePull != null) {
        await _probeReversePull(deviceId);
        return;
      }
      setState(() => _setLanReach(deviceId, 'offline'));
    }
  }

  int _reachabilityRank(String deviceId, SendMode mode) {
    final isLan = mode == SendMode.nearby || mode == SendMode.lan;
    final current = isLan
        ? _lanReachability[deviceId]
        : _webrtcReachability[deviceId];
    final stable = isLan
        ? _lanSortReach[deviceId]
        : _webrtcSortReach[deviceId];
    return _reachSortRank(_resolvedSortStatus(current, stable));
  }

  bool _isDeviceReachable(String deviceId, SendMode mode) {
    final status = (mode == SendMode.nearby || mode == SendMode.lan)
        ? (_lanReachability[deviceId] ?? 'checking')
        : (_webrtcReachability[deviceId] ?? 'checking');
    return status == 'online' ||
        status == 'pull_online' ||
        status == 'connectable';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(effectiveOfflineModeProvider);
    final lanDevices = ref.watch(lanDevicesProvider).valueOrNull ?? [];
    final myDevices = ref.watch(myDevicesProvider);
    final nearby = ref.watch(nearbyDevicesProvider);
    final cloudDevices = ref.watch(cloudDevicesProvider).valueOrNull ?? [];
    final cloudDeviceIds = cloudDevices.map((d) => d.deviceId).toSet();
    final deviceInfo = ref.watch(deviceInfoProvider).valueOrNull;
    final currentDeviceId = deviceInfo?.id ?? '';
    final selectedTargets = ref.watch(selectedLanTargetsProvider);
    final sendMode = ref.watch(selectedSendModeProvider);
    final manualHttpLocked =
        ref.watch(connectionManualOverrideProvider) &&
        ref.watch(connectionManualModeProvider) == SendMode.lan;
    final tabController = _ensureTabController(isOffline, sendMode);

    final allDevices = isOffline
        ? lanDevices.where((d) => d.deviceId != currentDeviceId).toList()
        : <DeviceDto>[
            ...myDevices.where((d) => d.deviceId != currentDeviceId),
            ...nearby,
          ];

    if (_lastDevices == null || !_listEquals(_lastDevices!, allDevices)) {
      _lastDevices = allDevices;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startProbes(allDevices, isOffline, sendMode);
      });
    }

    final nearbyLanDevices = lanDevices
        .where(
          (d) =>
              d.deviceId != currentDeviceId &&
              d.lanHttpUrl != null &&
              d.lanHttpUrl!.isNotEmpty,
        )
        .toList();
    final filteredDevices = _filterDevices(
      allDevices,
      sendMode,
      cloudDeviceIds,
      nearbyLanDevices,
    );
    final sortedDevices = List<DeviceDto>.from(filteredDevices)
      ..sort((a, b) {
        final aMine = cloudDeviceIds.contains(a.deviceId);
        final bMine = cloudDeviceIds.contains(b.deviceId);
        if (aMine != bMine) return aMine ? -1 : 1;
        final ra = _reachabilityRank(a.deviceId, sendMode);
        final rb = _reachabilityRank(b.deviceId, sendMode);
        if (ra != rb) return ra.compareTo(rb);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final reachableIds = <String>{};
    for (final d in sortedDevices) {
      if (_isDeviceReachable(d.deviceId, sendMode) ||
          (manualHttpLocked &&
              (sendMode == SendMode.lan || sendMode == SendMode.nearby))) {
        reachableIds.add(d.deviceId);
      }
    }

    // Auto-deselect devices confirmed offline by probes (schedule at most once).
    if (!_offlineCleanupScheduled && !manualHttpLocked) {
      final offlineSelected = <String>{};
      for (final d in sortedDevices) {
        if (!selectedTargets.contains(d.deviceId)) continue;
        final status = _deviceStatus(
          d,
          sendMode,
          _lanReachability,
          _webrtcReachability,
        );
        if (status == 'offline') offlineSelected.add(d.deviceId);
      }
      if (offlineSelected.isNotEmpty) {
        _offlineCleanupScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _offlineCleanupScheduled = false;
          if (!mounted) return;
          final current = ref.read(selectedLanTargetsProvider);
          final cleaned = current.difference(offlineSelected);
          if (cleaned.length != current.length) {
            ref.read(selectedLanTargetsProvider.notifier).setAll(cleaned);
          }
        });
      }
    }

    final theme = Theme.of(context);
    final colors = context.appColors;

    final props = _PanelProps(
      devices: sortedDevices,
      selectedTargets: selectedTargets,
      reachableIds: reachableIds,
      sendMode: sendMode,
      isOffline: isOffline,
      cloudDeviceIds: cloudDeviceIds,
      lanReachability: _lanReachability,
      webrtcReachability: _webrtcReachability,
      theme: theme,
      colors: colors,
      tabController: tabController,
      onToggleDevice: (id) {
        if (reachableIds.contains(id)) {
          ref.read(selectedLanTargetsProvider.notifier).toggle(id);
        }
      },
    );

    return widget.vertical
        ? _VerticalLayout(props: props)
        : _HorizontalLayout(props: props);
  }

  static List<DeviceDto> _filterDevices(
    List<DeviceDto> all,
    SendMode mode,
    Set<String> cloudDeviceIds,
    List<DeviceDto> nearbyLanDevices,
  ) {
    switch (mode) {
      case SendMode.nearby:
        return nearbyLanDevices;
      case SendMode.lan:
        return all.where((d) => cloudDeviceIds.contains(d.deviceId)).toList();
      case SendMode.webrtc:
        return all.where((d) => cloudDeviceIds.contains(d.deviceId)).toList();
      case SendMode.s3:
        return [];
    }
  }

  static bool _listEquals(List<DeviceDto> a, List<DeviceDto> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].deviceId != b[i].deviceId ||
          a[i].lanHttpUrl != b[i].lanHttpUrl) {
        return false;
      }
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Shared props
// ---------------------------------------------------------------------------

class _PanelProps {
  final List<DeviceDto> devices;
  final Set<String> selectedTargets;
  final Set<String> reachableIds;
  final SendMode sendMode;
  final bool isOffline;
  final Set<String> cloudDeviceIds;
  final Map<String, String> lanReachability;
  final Map<String, String> webrtcReachability;
  final ThemeData theme;
  final AppThemeColors colors;
  final TabController tabController;
  final ValueChanged<String> onToggleDevice;

  const _PanelProps({
    required this.devices,
    required this.selectedTargets,
    required this.reachableIds,
    required this.sendMode,
    required this.isOffline,
    required this.cloudDeviceIds,
    required this.lanReachability,
    required this.webrtcReachability,
    required this.theme,
    required this.colors,
    required this.tabController,
    required this.onToggleDevice,
  });
}

// ---------------------------------------------------------------------------
// Protocol status dot (per device, for the active tab's protocol)
// ---------------------------------------------------------------------------

Widget _buildStatusLabel({
  required String status,
  required SendMode mode,
  required AppThemeColors colors,
}) {
  final Color dotColor;
  final String label;
  switch (status) {
    case 'online':
      dotColor = (mode == SendMode.nearby || mode == SendMode.lan)
          ? colors.success
          : AppColorTheme.s3Color;
      label = '在线';
    case 'connectable':
      dotColor = colors.success;
      label = '可尝试';
    case 'pull_online':
      dotColor = colors.success;
      label = '可拉取';
    case 'unreachable':
      dotColor = colors.textTertiary;
      label = '不可达';
    case 'checking':
      dotColor = colors.textTertiary;
      label = '检测中…';
    default:
      dotColor = colors.textTertiary;
      label = '离线';
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
      ),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: dotColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

String _deviceStatus(
  DeviceDto device,
  SendMode mode,
  Map<String, String> lanReach,
  Map<String, String> webrtcReach,
) {
  if (mode == SendMode.nearby || mode == SendMode.lan) {
    return lanReach[device.deviceId] ?? 'checking';
  }
  return webrtcReach[device.deviceId] ?? 'checking';
}

// ---------------------------------------------------------------------------
// S3 tab content
// ---------------------------------------------------------------------------

class _S3TabContent extends StatelessWidget {
  final ThemeData theme;
  final AppThemeColors colors;
  final bool vertical;

  const _S3TabContent({
    required this.theme,
    required this.colors,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.cloud,
              size: vertical ? 32 : 24,
              color: AppColorTheme.s3Color,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '上传到云端',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '所有设备均可接收',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal layout (mobile)
// ---------------------------------------------------------------------------

class _HorizontalLayout extends StatelessWidget {
  final _PanelProps props;
  const _HorizontalLayout({required this.props});

  @override
  Widget build(BuildContext context) {
    final p = props;
    final modes = _panelModes(p.isOffline);
    return Container(
      color: p.colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 0.5, thickness: 0.5, color: p.colors.border),
          TabBar(
            controller: p.tabController,
            indicatorColor: p.theme.colorScheme.primary,
            labelColor: p.theme.colorScheme.primary,
            unselectedLabelColor: p.colors.textSecondary,
            dividerColor: p.colors.border,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: modes
                .map((m) => Tab(text: _modeTabLabel(context, m), height: 32))
                .toList(),
          ),
          SizedBox(
            height: 130,
            child: p.sendMode == SendMode.s3
                ? _S3TabContent(theme: p.theme, colors: p.colors)
                : p.devices.isEmpty
                ? Center(
                    child: Text(
                      '暂无可用设备',
                      style: p.theme.textTheme.bodySmall?.copyWith(
                        color: p.colors.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: p.devices.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (_, i) {
                      final device = p.devices[i];
                      final reachable = p.reachableIds.contains(
                        device.deviceId,
                      );
                      return _DeviceChip(
                        device: device,
                        selected: p.selectedTargets.contains(device.deviceId),
                        reachable: reachable,
                        status: _deviceStatus(
                          device,
                          p.sendMode,
                          p.lanReachability,
                          p.webrtcReachability,
                        ),
                        sendMode: p.sendMode,
                        theme: p.theme,
                        colors: p.colors,
                        onTap: () => p.onToggleDevice(device.deviceId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vertical layout (desktop sidebar)
// ---------------------------------------------------------------------------

class _VerticalLayout extends StatelessWidget {
  final _PanelProps props;
  const _VerticalLayout({required this.props});

  @override
  Widget build(BuildContext context) {
    final p = props;
    final modes = _panelModes(p.isOffline);
    return Container(
      color: p.colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Text(
              '发送目标',
              style: p.theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TabBar(
            controller: p.tabController,
            indicatorColor: p.theme.colorScheme.primary,
            labelColor: p.theme.colorScheme.primary,
            unselectedLabelColor: p.colors.textSecondary,
            dividerColor: p.colors.border,
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            indicatorSize: TabBarIndicatorSize.label,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: modes
                .map((m) => Tab(text: _modeTabLabel(context, m), height: 30))
                .toList(),
          ),
          Expanded(
            child: p.sendMode == SendMode.s3
                ? _S3TabContent(
                    theme: p.theme,
                    colors: p.colors,
                    vertical: true,
                  )
                : p.devices.isEmpty
                ? Center(
                    child: Text(
                      '暂无可用设备',
                      style: p.theme.textTheme.bodySmall?.copyWith(
                        color: p.colors.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    itemCount: p.devices.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xxs),
                    itemBuilder: (_, i) {
                      final device = p.devices[i];
                      final reachable = p.reachableIds.contains(
                        device.deviceId,
                      );
                      return _DeviceTile(
                        device: device,
                        selected: p.selectedTargets.contains(device.deviceId),
                        reachable: reachable,
                        status: _deviceStatus(
                          device,
                          p.sendMode,
                          p.lanReachability,
                          p.webrtcReachability,
                        ),
                        sendMode: p.sendMode,
                        theme: p.theme,
                        colors: p.colors,
                        onTap: () => p.onToggleDevice(device.deviceId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Device chip (mobile horizontal)
// ---------------------------------------------------------------------------

class _DeviceChip extends StatelessWidget {
  final DeviceDto device;
  final bool selected;
  final bool reachable;
  final String status;
  final SendMode sendMode;
  final ThemeData theme;
  final AppThemeColors colors;
  final VoidCallback onTap;

  const _DeviceChip({
    required this.device,
    required this.selected,
    required this.reachable,
    required this.status,
    required this.sendMode,
    required this.theme,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !reachable;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: selected && !disabled
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : colors.surfaceMuted,
        borderRadius: AppRadius.small,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: AppRadius.small,
          child: Container(
            width: 110,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.small,
              border: Border.all(
                color: selected && !disabled
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : colors.border,
                width: selected && !disabled ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      platformIcon(device.platform),
                      color: platformColor(device.platform, theme.brightness),
                      size: 16,
                    ),
                    if (selected && !disabled) ...[
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.circleCheck,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: selected && !disabled
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: disabled
                        ? colors.textTertiary
                        : selected
                        ? theme.colorScheme.primary
                        : colors.textPrimary,
                  ),
                ),
                if (device.displayCode != null)
                  Text(
                    '#${device.displayCode}',
                    maxLines: 1,
                    style: TextStyle(fontSize: 8, color: colors.textTertiary),
                  ),
                const SizedBox(height: 2),
                _buildStatusLabel(
                  status: status,
                  mode: sendMode,
                  colors: colors,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Device tile (desktop vertical sidebar)
// ---------------------------------------------------------------------------

class _DeviceTile extends StatelessWidget {
  final DeviceDto device;
  final bool selected;
  final bool reachable;
  final String status;
  final SendMode sendMode;
  final ThemeData theme;
  final AppThemeColors colors;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.reachable,
    required this.status,
    required this.sendMode,
    required this.theme,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !reachable;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: selected && !disabled
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: AppRadius.small,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: AppRadius.small,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  platformIcon(device.platform),
                  color: platformColor(device.platform, theme.brightness),
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: selected && !disabled
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: disabled
                              ? colors.textTertiary
                              : selected
                              ? theme.colorScheme.primary
                              : colors.textPrimary,
                        ),
                      ),
                      if (device.displayCode != null)
                        Text(
                          '#${device.displayCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: colors.textTertiary,
                          ),
                        ),
                      _buildStatusLabel(
                        status: status,
                        mode: sendMode,
                        colors: colors,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: selected && !disabled,
                    onChanged: disabled ? null : (_) => onTap(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
