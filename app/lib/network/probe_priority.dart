import '../api/api.dart';

/// Probe tier for reachability scans.
enum ProbePriority {
  /// LAN-discovered or has a direct HTTP URL.
  lanDiscovered,

  /// Same-account device with server presence online.
  presenceOnline,

  /// Lazy: skip auto-probe; show offline until user selects or manual refresh.
  lazy,
}

class ProbePartition {
  const ProbePartition({
    required this.lanDiscovered,
    required this.presenceOnline,
    required this.lazy,
  });

  final List<DeviceDto> lanDiscovered;
  final List<DeviceDto> presenceOnline;
  final List<DeviceDto> lazy;

  List<DeviceDto> get autoProbe => [...lanDiscovered, ...presenceOnline];
}

ProbePriority classifyDevice(
  DeviceDto device, {
  required Set<String> nearbyIds,
  required Set<String> myDeviceIds,
}) {
  final hasLanUrl =
      device.lanHttpUrl != null && device.lanHttpUrl!.trim().isNotEmpty;
  if (hasLanUrl || nearbyIds.contains(device.deviceId)) {
    return ProbePriority.lanDiscovered;
  }
  if (myDeviceIds.contains(device.deviceId) &&
      device.presenceStatus == 'online') {
    return ProbePriority.presenceOnline;
  }
  return ProbePriority.lazy;
}

ProbePartition partitionForProbe(
  List<DeviceDto> devices, {
  required Set<String> nearbyIds,
  required Set<String> myDeviceIds,
}) {
  final p0 = <DeviceDto>[];
  final p1 = <DeviceDto>[];
  final p2 = <DeviceDto>[];
  for (final d in devices) {
    switch (classifyDevice(
      d,
      nearbyIds: nearbyIds,
      myDeviceIds: myDeviceIds,
    )) {
      case ProbePriority.lanDiscovered:
        p0.add(d);
      case ProbePriority.presenceOnline:
        p1.add(d);
      case ProbePriority.lazy:
        p2.add(d);
    }
  }
  return ProbePartition(
    lanDiscovered: p0,
    presenceOnline: p1,
    lazy: p2,
  );
}

/// Returns true when an auto-probe can be skipped (offline with no LAN URL).
bool shouldSkipAutoProbe(
  DeviceDto device, {
  required Set<String> nearbyIds,
}) {
  final hasLanUrl =
      device.lanHttpUrl != null && device.lanHttpUrl!.trim().isNotEmpty;
  if (hasLanUrl || nearbyIds.contains(device.deviceId)) return false;
  return device.presenceStatus == 'offline';
}
