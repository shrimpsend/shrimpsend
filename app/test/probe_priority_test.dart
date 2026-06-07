import 'package:flutter_test/flutter_test.dart';
import 'package:app/api/api.dart';
import 'package:app/network/probe_priority.dart';

DeviceDto _device({
  required String id,
  String? lanHttpUrl,
  String? presenceStatus,
}) {
  return DeviceDto(
    deviceId: id,
    name: id,
    lanHttpUrl: lanHttpUrl,
    presenceStatus: presenceStatus,
  );
}

void main() {
  final myIds = {'a', 'b'};
  final nearbyIds = {'n1'};

  test('classifies LAN URL as lanDiscovered', () {
    expect(
      classifyDevice(
        _device(id: 'a', lanHttpUrl: 'http://192.168.1.2:8080'),
        nearbyIds: nearbyIds,
        myDeviceIds: myIds,
      ),
      ProbePriority.lanDiscovered,
    );
  });

  test('classifies presence online as presenceOnline', () {
    expect(
      classifyDevice(
        _device(id: 'b', presenceStatus: 'online'),
        nearbyIds: nearbyIds,
        myDeviceIds: myIds,
      ),
      ProbePriority.presenceOnline,
    );
  });

  test('classifies offline as lazy', () {
    expect(
      classifyDevice(
        _device(id: 'b', presenceStatus: 'offline'),
        nearbyIds: nearbyIds,
        myDeviceIds: myIds,
      ),
      ProbePriority.lazy,
    );
  });

  test('partitionForProbe splits tiers', () {
    final partition = partitionForProbe(
      [
        _device(id: 'n1'),
        _device(id: 'a', presenceStatus: 'online'),
        _device(id: 'b', presenceStatus: 'offline'),
      ],
      nearbyIds: nearbyIds,
      myDeviceIds: myIds,
    );
    expect(partition.lanDiscovered.map((d) => d.deviceId), ['n1']);
    expect(partition.presenceOnline.map((d) => d.deviceId), ['a']);
    expect(partition.lazy.map((d) => d.deviceId), ['b']);
  });
}
