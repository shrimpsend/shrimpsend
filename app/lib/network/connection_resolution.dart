import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/devices.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import 'link_models.dart';
import 'link_strategy.dart';

class ConnectionCandidate {
  const ConnectionCandidate({
    required this.mode,
    required this.kind,
    required this.available,
    required this.attemptable,
    required this.reason,
  });

  final SendMode mode;
  final SmartLinkKind kind;

  /// Probe-confirmed transfer path (includes reverse pull).
  final bool available;

  /// User may manually select and attempt (even when [available] is false).
  final bool attemptable;
  final String reason;
}

class SelectedConnectionContext {
  const SelectedConnectionContext({
    required this.selectedDeviceId,
    required this.localOs,
    required this.peer,
    required this.chain,
    required this.reach,
    required this.s3Configured,
    required this.s3Online,
    required this.isLoggedIn,
    required this.isRegisteredPeer,
  });

  final String selectedDeviceId;
  final String localOs;
  final DeviceDto? peer;
  final List<SmartLinkKind> chain;
  final DeviceReachDetail reach;
  final bool s3Configured;
  /// CUSTOM: presigned HEAD from client; HOSTED: configured only.
  final bool s3Online;
  final bool isLoggedIn;
  /// Peer is registered under the current account (not LAN-only external).
  final bool isRegisteredPeer;
}

/// Account-backed channels (HTTP signaling / WebRTC / S3) require login and a
/// registered peer. External LAN-discovered devices only support nearby/HTTP direct.
bool allowsAccountTransferModes(SelectedConnectionContext context) {
  return context.isLoggedIn && context.isRegisteredPeer;
}

SelectedConnectionContext? watchSelectedConnectionContext(Ref ref) {
  final selected = ref.watch(selectedDeviceIdProvider);
  if (selected == null || selected == s3VirtualDeviceId) {
    return null;
  }

  final peer = findDeviceById(ref, selected);
  final localOs = Platform.operatingSystem;
  final isLoggedIn = ref.watch(authProvider).isLoggedIn;
  final isRegisteredPeer = ref
      .watch(myDevicesProvider)
      .any((d) => d.deviceId == selected);
  // Only rebuild when the selected peer's reach detail actually changes,
  // not when any other device's probe progress mutates the whole Map.
  final reach = ref.watch(
    deviceReachabilityProvider.select(
      (m) => m[selected] ?? DeviceReachDetail.offlineDetail,
    ),
  );
  return SelectedConnectionContext(
    selectedDeviceId: selected,
    localOs: localOs,
    peer: peer,
    chain: resolveStrategyChain(localOs: localOs, peerPlatform: peer?.platform),
    reach: reach,
    s3Configured: ref.watch(s3ConfiguredProvider),
    s3Online: ref.watch(s3OnlineProvider),
    isLoggedIn: isLoggedIn,
    isRegisteredPeer: isRegisteredPeer,
  );
}

DeviceDto? findDeviceById(Ref ref, String deviceId) {
  for (final d in ref.watch(myDevicesProvider)) {
    if (d.deviceId == deviceId) return d;
  }
  for (final d in ref.watch(nearbyDevicesProvider)) {
    if (d.deviceId == deviceId) return d;
  }
  return null;
}

bool httpDirectAvailable(DeviceReachDetail detail) {
  return detail.directHttp || detail.peerHttpHealthy;
}

/// HTTP transfer path verified by probe (direct push, peer healthy, or reverse pull).
bool httpTransferAvailable(DeviceReachDetail detail) {
  return detail.directHttp || detail.pullReachable || detail.peerHttpHealthy;
}

bool httpPullOnlyAvailable(DeviceReachDetail detail) {
  return detail.pullReachable && !detail.directHttp;
}

String connectionPeerLabel(String deviceId, {DeviceDto? device}) {
  final name = device?.name.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  return deviceId.length > 12 ? '${deviceId.substring(0, 12)}…' : deviceId;
}

String connectionModeLabel(SendMode mode, {String? localOs, AppLocalizations? l10n}) {
  switch (mode) {
    case SendMode.nearby:
      return l10n?.sendModeNearby ?? 'Nearby';
    case SendMode.lan:
      return 'HTTP';
    case SendMode.webrtc:
      return 'WebRTC';
    case SendMode.s3:
      return 'S3';
  }
}

String transferModeBarLabel(SendMode mode, {AppLocalizations? l10n}) {
  switch (mode) {
    case SendMode.nearby:
      return l10n?.sendModeNearby ?? 'Nearby';
    case SendMode.lan:
      return l10n?.transportModeHttpLan ?? 'HTTP LAN direct';
    case SendMode.webrtc:
      return l10n?.transportModeWebrtcLan ?? 'WebRTC LAN direct';
    case SendMode.s3:
      return l10n?.chatS3RelayTitle ?? 'S3 cloud relay';
  }
}

/// Keeps the user's preferred [preferred] mode when it is still available.
/// Falls back to the first available mode only when preferred is unavailable
/// or not applicable to the current peer context.
SendMode resolveSendModeWithMemory({
  required SendMode preferred,
  required List<ConnectionCandidate> candidates,
  required bool isLoggedIn,
  required bool isRegisteredPeer,
}) {
  final visible = visibleConnectionCandidatesForUi(
    candidates: candidates,
    isLoggedIn: isLoggedIn,
    isRegisteredPeer: isRegisteredPeer,
  );
  if (visible.isEmpty) return preferred;

  final visibleModes = visible.map((c) => c.mode).toSet();
  if (!visibleModes.contains(preferred)) {
    for (final c in visible) {
      if (c.available) return c.mode;
    }
    return visible.first.mode;
  }

  for (final c in visible) {
    if (c.mode == preferred && c.available) {
      return preferred;
    }
  }

  for (final c in visible) {
    if (c.available) return c.mode;
  }

  return preferred;
}

/// Session auto mode: pick the first available mode by direct-first priority.
SendMode resolveSendModeAutoPreferHttp({
  required List<ConnectionCandidate> candidates,
  required bool isLoggedIn,
  required bool isRegisteredPeer,
  SendMode fallback = SendMode.lan,
}) {
  final visible = visibleConnectionCandidatesForUi(
    candidates: candidates,
    isLoggedIn: isLoggedIn,
    isRegisteredPeer: isRegisteredPeer,
  );
  if (visible.isEmpty) return fallback;

  const priority = [
    SendMode.lan,
    SendMode.webrtc,
    SendMode.nearby,
    SendMode.s3,
  ];
  for (final mode in priority) {
    for (final c in visible) {
      if (c.mode == mode && c.available) return mode;
    }
  }

  for (final c in visible) {
    if (c.available) return c.mode;
  }
  return visible.first.mode;
}

List<ConnectionCandidate> buildConnectionCandidates({
  required SelectedConnectionContext context,
}) {
  final expanded = <({SendMode mode, SmartLinkKind kind})>[];
  for (final kind in context.chain) {
    expanded.addAll(_expandKind(kind));
  }

  final out = <ConnectionCandidate>[];
  final seen = <SendMode>{};
  for (final item in expanded) {
    if (!seen.add(item.mode)) continue;
    final availability = _checkAvailability(mode: item.mode, context: context);
    out.add(
      ConnectionCandidate(
        mode: item.mode,
        kind: item.kind,
        available: availability.available,
        attemptable: availability.attemptable,
        reason: availability.reason,
      ),
    );
  }
  return out;
}

/// 未登录或外部设备时 UI 不展示需账号的渠道（WebRTC/S3）；未登录时仅保留「附近」，
/// 已登录外部设备保留「附近」与 HTTP 直连。
List<ConnectionCandidate> visibleConnectionCandidatesForUi({
  required List<ConnectionCandidate> candidates,
  required bool isLoggedIn,
  required bool isRegisteredPeer,
}) {
  if (isLoggedIn && isRegisteredPeer) {
    return List<ConnectionCandidate>.from(candidates);
  }
  if (isLoggedIn) {
    return candidates
        .where((c) => c.mode == SendMode.nearby || c.mode == SendMode.lan)
        .toList();
  }
  return candidates.where((c) => c.mode == SendMode.nearby).toList();
}

List<({SendMode mode, SmartLinkKind kind})> _expandKind(SmartLinkKind kind) {
  switch (kind) {
    case SmartLinkKind.sameLan:
      return [
        (mode: SendMode.lan, kind: kind),
        (mode: SendMode.webrtc, kind: kind),
        (mode: SendMode.nearby, kind: kind),
      ];
    case SmartLinkKind.pcHotspot:
      return [
        (mode: SendMode.lan, kind: kind),
        (mode: SendMode.webrtc, kind: kind),
      ];
    case SmartLinkKind.internetRelay:
      return [(mode: SendMode.s3, kind: kind)];
  }
}

({bool available, bool attemptable, String reason}) _checkAvailability({
  required SendMode mode,
  required SelectedConnectionContext context,
}) {
  switch (mode) {
    case SendMode.nearby:
      final ok = httpTransferAvailable(context.reach);
      return (
        available: ok,
        attemptable: context.peer != null,
        reason: ok ? '附近链路可用' : '未发现可用局域网设备',
      );
    case SendMode.lan:
      if (!context.isLoggedIn) {
        return (
          available: false,
          attemptable: false,
          reason: '登录后可使用',
        );
      }
      if (!context.isRegisteredPeer) {
        final directOk = context.reach.directHttp;
        return (
          available: directOk,
          attemptable: context.peer != null,
          reason: directOk ? 'HTTP 直连可用' : 'HTTP 直连不可达',
        );
      }
      final lanOk = httpTransferAvailable(context.reach);
      final pullOnly = httpPullOnlyAvailable(context.reach);
      return (
        available: lanOk,
        attemptable: true,
        reason: lanOk
            ? (pullOnly ? 'HTTP 反向拉取可用' : 'HTTP 直连可用')
            : 'HTTP 直连不可达',
      );
    case SendMode.webrtc:
      if (!allowsAccountTransferModes(context)) {
        return (
          available: false,
          attemptable: false,
          reason: '仅支持账号下已注册设备',
        );
      }
      final rtc = context.reach.webrtc;
      if (rtc == true) {
        return (available: true, attemptable: true, reason: 'WebRTC 可用');
      }
      if (rtc == false) {
        return (
          available: false,
          attemptable: true,
          reason: 'WebRTC 信令/ICE 不可达',
        );
      }
      return (available: true, attemptable: true, reason: 'WebRTC 未检测');
    case SendMode.s3:
      if (!allowsAccountTransferModes(context)) {
        return (
          available: false,
          attemptable: false,
          reason: '仅支持账号下已注册设备',
        );
      }
      if (!context.s3Configured) {
        return (
          available: false,
          attemptable: false,
          reason: 'S3 未配置',
        );
      }
      if (!context.s3Online) {
        return (
          available: false,
          attemptable: false,
          reason: 'S3 不可用',
        );
      }
      return (available: true, attemptable: true, reason: 'S3 可用');
  }
}
