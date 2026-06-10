import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api.dart';
import '../device_id.dart';
import '../lan/lan_discovery.dart';
import '../logger.dart';
import 'auth_provider.dart';
import 'auth_session_provider.dart';

/// Virtual device ID for the S3 cloud relay entry in the device list.
const s3VirtualDeviceId = '__s3_cloud__';

enum SendMode { nearby, lan, webrtc, s3 }

class DeviceInfo {
  final String id;
  final String name;
  const DeviceInfo({required this.id, required this.name});
}

final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  final id = await getOrCreateDeviceId();
  final name = await getDeviceName();
  return DeviceInfo(id: id, name: name);
});

final lanDiscoveryProvider = Provider<LanDiscoveryService>((ref) {
  final deviceInfo = ref.watch(deviceInfoProvider).valueOrNull;
  if (deviceInfo == null) {
    return LanDiscoveryService(
      deviceId: 'pending',
      deviceName: 'pending',
      platform: Platform.operatingSystem,
    );
  }
  final service = LanDiscoveryService.ensureInstance(
    deviceId: deviceInfo.id,
    deviceName: deviceInfo.name,
    platform: Platform.operatingSystem,
  );
  return service;
});

final lanDevicesProvider =
    StreamNotifierProvider<LanDevicesNotifier, List<DeviceDto>>(
      LanDevicesNotifier.new,
    );

class LanDevicesNotifier extends StreamNotifier<List<DeviceDto>> {
  @override
  Stream<List<DeviceDto>> build() {
    final discovery = ref.watch(lanDiscoveryProvider);
    if (discovery.deviceId == 'pending') return const Stream.empty();
    // 不在此处调用 startDiscovery()：发现由 ChatScreen._init() 在 LAN HTTP 服务就绪后
    // 统一启动。若在此处与 _init 的 stopDiscovery/startDiscovery 并发，Windows 上
    // Bonsoir 原生层曾出现访问冲突 (0xC0000005) 导致进程闪退。
    ref.onDispose(() {
      logChat.info('LanDevicesNotifier disposed');
    });
    return discovery.discoveredDevices;
  }
}

class CloudDeviceRosterNotifier
    extends StateNotifier<AsyncValue<List<DeviceDto>>> {
  CloudDeviceRosterNotifier(this.ref) : super(const AsyncValue.data([]));

  final Ref ref;

  Future<void> refreshSnapshot() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final devices = await listDevices();
      ref.read(authSessionControllerProvider.notifier).markServerReachable();
      state = AsyncValue.data(devices);
    } catch (e, st) {
      logChat.warning('cloudDeviceRoster refresh failed: $e');
      if ((state.valueOrNull ?? const <DeviceDto>[]).isEmpty) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void replaceSnapshot(List<DeviceDto> devices) {
    state = AsyncValue.data(devices);
  }

  void applyUpsert(DeviceDto device) {
    final current = state.valueOrNull ?? const <DeviceDto>[];
    final index = current.indexWhere((d) => d.deviceId == device.deviceId);
    if (index < 0) {
      state = AsyncValue.data([...current, device]);
      return;
    }
    final updated = [...current];
    updated[index] = device;
    state = AsyncValue.data(updated);
  }

  void applyRemove(String deviceId) {
    final current = state.valueOrNull ?? const <DeviceDto>[];
    final updated = current.where((d) => d.deviceId != deviceId).toList();
    state = AsyncValue.data(updated);
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final cloudDeviceRosterProvider =
    StateNotifierProvider<
      CloudDeviceRosterNotifier,
      AsyncValue<List<DeviceDto>>
    >((ref) {
      final notifier = CloudDeviceRosterNotifier(ref);
      ref.listen<AuthState>(authProvider, (previous, next) {
        if (!next.isLoggedIn) {
          notifier.clear();
          return;
        }
        if (previous?.userId != next.userId) {
          notifier.refreshSnapshot();
        }
      });
      if (ref.read(authProvider).isLoggedIn) {
        Future.microtask(notifier.refreshSnapshot);
      }
      return notifier;
    });

/// Server-side device roster. The state is refreshed on first login/reconnect/manual refresh
/// and then kept current through Centrifugo `device_roster_patch` events.
final cloudDevicesProvider = Provider<AsyncValue<List<DeviceDto>>>((ref) {
  return ref.watch(cloudDeviceRosterProvider);
});

/// Cloud-registered devices for the current user, enriched with LAN URL when available.
/// Preserves [cloudDevicesProvider] loading/error so UI does not flash an empty list while fetching.
final myDevicesAsyncProvider = Provider<AsyncValue<List<DeviceDto>>>((ref) {
  final cloudAsync = ref.watch(cloudDevicesProvider);
  final lan = ref.watch(lanDevicesProvider).valueOrNull ?? [];
  final lanById = {for (final d in lan) d.deviceId: d};
  return cloudAsync.whenData((cloud) {
    return cloud.map((d) {
      final lanDevice = lanById[d.deviceId];
      return DeviceDto(
        deviceId: d.deviceId,
        name: d.name,
        platform: d.platform,
        lanHttpUrl: lanDevice?.lanHttpUrl ?? d.lanHttpUrl,
        lastSeen: d.lastSeen,
        presenceStatus: d.presenceStatus,
        presenceUpdatedAt: d.presenceUpdatedAt,
        displayCode: d.displayCode,
      );
    }).toList();
  });
});

/// Resolved list (empty while loading); prefer [myDevicesAsyncProvider] when loading UI matters.
final myDevicesProvider = Provider<List<DeviceDto>>((ref) {
  return ref.watch(myDevicesAsyncProvider).valueOrNull ?? [];
});

/// LAN-discovered devices that are not in the current user's cloud device list (nearby devices).
final nearbyDevicesProvider = Provider<List<DeviceDto>>((ref) {
  final lan = ref.watch(lanDevicesProvider).valueOrNull ?? [];
  final cloud = ref.watch(cloudDevicesProvider).valueOrNull ?? [];
  final cloudIds = cloud.map((d) => d.deviceId).toSet();
  return lan.where((d) => !cloudIds.contains(d.deviceId)).toList();
});

final deviceCountProvider = Provider<int>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.isLoggedIn) {
    return ref.watch(myDevicesAsyncProvider).value?.length ?? 0;
  }
  return ref.watch(lanDevicesProvider).valueOrNull?.length ?? 0;
});

// ---------------------------------------------------------------------------
// Persistent selected targets
// ---------------------------------------------------------------------------

class SelectedTargetsNotifier extends StateNotifier<Set<String>> {
  static const _key = 'ultrasend_selected_targets';

  SelectedTargetsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved.toSet();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  void toggle(String deviceId) {
    final updated = {...state};
    if (updated.contains(deviceId)) {
      updated.remove(deviceId);
    } else {
      updated.add(deviceId);
    }
    state = updated;
    _persist();
  }

  void setAll(Set<String> ids) {
    state = ids;
    _persist();
  }
}

/// User-selected target device IDs (persisted across restarts).
final selectedLanTargetsProvider =
    StateNotifierProvider<SelectedTargetsNotifier, Set<String>>(
      (_) => SelectedTargetsNotifier(),
    );

/// Selected targets filtered to only include devices visible in the current
/// send mode's device list, excluding the current device.
final effectiveSelectedTargetsProvider = Provider<Set<String>>((ref) {
  final selected = ref.watch(selectedLanTargetsProvider);
  if (selected.isEmpty) return {};
  final mode = ref.watch(selectedSendModeProvider);
  if (mode == SendMode.s3) return {};
  final currentDeviceId = ref.watch(deviceInfoProvider).valueOrNull?.id;
  switch (mode) {
    case SendMode.nearby:
      final lanIds = ref
          .watch(lanDevicesProvider)
          .valueOrNull
          ?.where(
            (d) =>
                d.lanHttpUrl != null &&
                d.lanHttpUrl!.isNotEmpty &&
                d.deviceId != currentDeviceId,
          )
          .map((d) => d.deviceId)
          .toSet();
      if (lanIds == null) return {};
      return selected.intersection(lanIds);
    case SendMode.lan:
    case SendMode.webrtc:
      final myIds = ref
          .watch(myDevicesProvider)
          .where((d) => d.deviceId != currentDeviceId)
          .map((d) => d.deviceId)
          .toSet();
      final nearbyIds = ref
          .watch(nearbyDevicesProvider)
          .map((d) => d.deviceId)
          .toSet();
      return selected.intersection(myIds.union(nearbyIds));
    case SendMode.s3:
      return {};
  }
});

/// Effective selected target count based on available devices.
final effectiveSelectedLanTargetCountProvider = Provider<int>((ref) {
  return ref.watch(effectiveSelectedTargetsProvider).length;
});

// ---------------------------------------------------------------------------
// Persistent send mode (per conversation device)
// ---------------------------------------------------------------------------

class SelectedSendModeNotifier extends StateNotifier<SendMode> {
  static const _mapKey = 'ultrasend_send_mode_by_device';

  String? _activeDeviceId;
  Map<String, SendMode> _byDevice = {};
  bool _loaded = false;

  SelectedSendModeNotifier() : super(SendMode.lan) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mapKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _byDevice = {
            for (final entry in decoded.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: _parseMode(entry.value as String),
          };
        }
      } catch (_) {}
    }
    _loaded = true;
    _applyActiveDeviceMode();
  }

  SendMode _parseMode(String raw) {
    return SendMode.values.firstWhere(
      (x) => x.name == raw,
      orElse: () => SendMode.lan,
    );
  }

  SendMode _modeForDevice(String deviceId) {
    if (deviceId == s3VirtualDeviceId) return SendMode.s3;
    return _byDevice[deviceId] ?? SendMode.lan;
  }

  void _applyActiveDeviceMode() {
    final deviceId = _activeDeviceId;
    if (deviceId == null) return;
    state = _modeForDevice(deviceId);
  }

  /// Loads the remembered send mode when the conversation device changes.
  void activateDevice(String? deviceId) {
    _activeDeviceId = deviceId;
    if (!_loaded) return;
    _applyActiveDeviceMode();
  }

  void select(SendMode mode, {bool persist = true}) {
    state = mode;
    if (!persist) return;
    final deviceId = _activeDeviceId;
    if (deviceId == null || deviceId == s3VirtualDeviceId) return;
    _byDevice[deviceId] = mode;
    SharedPreferences.getInstance().then((prefs) {
      final encoded = jsonEncode(
        _byDevice.map((key, value) => MapEntry(key, value.name)),
      );
      prefs.setString(_mapKey, encoded);
    });
  }

  void resetForLogout() {
    _activeDeviceId = null;
    state = SendMode.nearby;
  }
}

final selectedSendModeProvider =
    StateNotifierProvider<SelectedSendModeNotifier, SendMode>(
      (_) => SelectedSendModeNotifier(),
    );

/// True while the chat session should auto-prefer HTTP when it comes online.
final chatSendModeAutoProvider = StateProvider<bool>((_) => true);

// ---------------------------------------------------------------------------
// Selected device for WeChat-style conversation view
// ---------------------------------------------------------------------------

class SelectedDeviceNotifier extends StateNotifier<String?> {
  SelectedDeviceNotifier() : super(null);
  void select(String? deviceId) => state = deviceId;
}

final selectedDeviceIdProvider =
    StateNotifierProvider<SelectedDeviceNotifier, String?>(
      (_) => SelectedDeviceNotifier(),
    );

// ---------------------------------------------------------------------------
// S3 configuration status
// ---------------------------------------------------------------------------

final s3ConfiguredProvider = StateProvider<bool>((_) => false);

/// True when [hasS3Config] and [checkS3Online] succeed (actual S3 connectivity).
final s3OnlineProvider = StateProvider<bool>((_) => false);
final s3CheckingProvider = StateProvider<bool>((_) => true);

// ---------------------------------------------------------------------------
// Device reachability (per-method: directHttp / peerHttpHealthy / pullReachable / webrtc)
// ---------------------------------------------------------------------------

enum DeviceReachStatus { online, pullOnline, checking, offline }

class DeviceReachDetail {
  final bool directHttp;

  /// Peer HTTP service self-check passed via Centrifugo [lan_http_probe].
  final bool peerHttpHealthy;

  /// Peer can reach this device's HTTP (reverse pull direction).
  final bool pullReachable;

  /// `null` = not probed (e.g. WebRTC skipped when LAN already works).
  final bool? webrtc;
  final bool checking;

  /// Legacy optimistic marker. It no longer drives [isOnline]; reachability must
  /// come from an actual probe so startup shows offline before checking.
  final bool provisionalOnline;

  const DeviceReachDetail({
    this.directHttp = false,
    this.peerHttpHealthy = false,
    this.pullReachable = false,
    this.webrtc,
    this.checking = false,
    this.provisionalOnline = false,
  });

  /// Back-compat alias for [peerHttpHealthy].
  bool get lanSignaling => peerHttpHealthy;

  bool get canPushDirect => directHttp;

  bool get canPullOnly => pullReachable && !canPushDirect;

  bool get isOnline =>
      directHttp || pullReachable || peerHttpHealthy || webrtc == true;

  /// At least one path verified by probe (excludes provisional).
  bool get isConfirmedOnline => isOnline;

  String get status {
    if (checking) return 'checking';
    if (canPullOnly) return 'pull_online';
    if (isOnline) return 'online';
    return 'offline';
  }

  DeviceReachStatus get uiReachStatus {
    if (checking) return DeviceReachStatus.checking;
    if (canPullOnly) return DeviceReachStatus.pullOnline;
    if (isOnline) return DeviceReachStatus.online;
    return DeviceReachStatus.offline;
  }

  static const offlineDetail = DeviceReachDetail();
  static const checkingDetail = DeviceReachDetail(checking: true);
}

const kDeviceReachMergeUnset = Object();

class DeviceReachabilityNotifier
    extends StateNotifier<Map<String, DeviceReachDetail>> {
  DeviceReachabilityNotifier() : super({});

  void setDetail(String deviceId, DeviceReachDetail detail) {
    state = {...state, deviceId: detail};
  }

  void mergeDetail(
    String deviceId, {
    bool? directHttp,
    bool? lanSignaling,
    bool? peerHttpHealthy,
    bool? pullReachable,
    Object? webrtc = kDeviceReachMergeUnset,
    bool? checking,
    bool? provisionalOnline,
  }) {
    final existing = state[deviceId] ?? DeviceReachDetail();
    final nextWebrtc = identical(webrtc, kDeviceReachMergeUnset)
        ? existing.webrtc
        : webrtc as bool?;
    final nextPeerHealthy =
        peerHttpHealthy ?? lanSignaling ?? existing.peerHttpHealthy;
    state = {
      ...state,
      deviceId: DeviceReachDetail(
        directHttp: directHttp ?? existing.directHttp,
        peerHttpHealthy: nextPeerHealthy,
        pullReachable: pullReachable ?? existing.pullReachable,
        webrtc: nextWebrtc,
        checking: checking ?? existing.checking,
        provisionalOnline: provisionalOnline ?? existing.provisionalOnline,
      ),
    };
  }

  void setChecking(String deviceId) {
    final existing = state[deviceId] ?? DeviceReachDetail();
    state = {
      ...state,
      deviceId: DeviceReachDetail(
        directHttp: existing.directHttp,
        peerHttpHealthy: existing.peerHttpHealthy,
        pullReachable: existing.pullReachable,
        webrtc: existing.webrtc,
        checking: true,
        provisionalOnline: false,
      ),
    };
  }

  void setAllChecking(List<String> ids) {
    final updates = <String, DeviceReachDetail>{};
    for (final id in ids) {
      final existing = state[id] ?? DeviceReachDetail();
      updates[id] = DeviceReachDetail(
        directHttp: existing.directHttp,
        peerHttpHealthy: existing.peerHttpHealthy,
        pullReachable: existing.pullReachable,
        webrtc: existing.webrtc,
        checking: true,
        provisionalOnline: false,
      );
    }
    applyBatch(updates);
  }

  /// Applies multiple device updates in a single [state] assignment.
  void applyBatch(Map<String, DeviceReachDetail> updates) {
    if (updates.isEmpty) return;
    state = {...state, ...updates};
  }
}

final deviceReachabilityProvider =
    StateNotifierProvider<
      DeviceReachabilityNotifier,
      Map<String, DeviceReachDetail>
    >((_) => DeviceReachabilityNotifier());

final devicesProbingProvider = StateProvider<bool>((_) => false);
