import 'package:flutter_test/flutter_test.dart';
import 'package:app/providers/device_provider.dart';

void main() {
  test('webDav selection id roundtrip', () {
    const id = 42;
    final selection = webDavSelectionId(id);
    expect(isWebDavSelection(selection), isTrue);
    expect(isChatSelection(selection), isFalse);
    expect(isPeerSelection(selection), isFalse);
    expect(parseWebDavConnectionId(selection), id);
  });

  test('s3 is chat selection not peer', () {
    expect(isChatSelection(s3VirtualDeviceId), isTrue);
    expect(isPeerSelection(s3VirtualDeviceId), isFalse);
    expect(isWebDavSelection(s3VirtualDeviceId), isFalse);
  });

  test('peer device id', () {
    const peer = 'device-abc';
    expect(isPeerSelection(peer), isTrue);
    expect(isChatSelection(peer), isTrue);
    expect(isWebDavSelection(peer), isFalse);
  });
}
