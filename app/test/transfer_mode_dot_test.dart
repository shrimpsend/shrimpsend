import 'package:flutter_test/flutter_test.dart';
import 'package:app/network/connection_bar_view_model.dart';
import 'package:app/network/transfer_mode_dot.dart';
import 'package:app/providers/device_provider.dart';

void main() {
  group('resolveTransferModeDotState', () {
    test('webrtc null is unchecked', () {
      expect(
        resolveTransferModeDotState(
          mode: SendMode.webrtc,
          reachKnownOnline: null,
          reachPullOnly: false,
          attemptable: true,
        ),
        TransferModeDotState.unchecked,
      );
    });

    test('http verified when online and not pull-only', () {
      expect(
        resolveTransferModeDotState(
          mode: SendMode.lan,
          reachKnownOnline: true,
          reachPullOnly: false,
          attemptable: true,
        ),
        TransferModeDotState.verified,
      );
    });

    test('http pull-only when online with reverse pull only', () {
      expect(
        resolveTransferModeDotState(
          mode: SendMode.lan,
          reachKnownOnline: true,
          reachPullOnly: true,
          attemptable: true,
        ),
        TransferModeDotState.pullOnly,
      );
    });

    test('http attemptable when offline but attemptable', () {
      expect(
        resolveTransferModeDotState(
          mode: SendMode.lan,
          reachKnownOnline: false,
          reachPullOnly: false,
          attemptable: true,
        ),
        TransferModeDotState.attemptable,
      );
    });

    test('s3 unavailable when offline', () {
      expect(
        resolveTransferModeDotState(
          mode: SendMode.s3,
          reachKnownOnline: false,
          reachPullOnly: false,
          attemptable: false,
        ),
        TransferModeDotState.unavailable,
      );
    });
  });

  test('resolveTransferModeDotStateFromItem mirrors item fields', () {
    const item = ConnectionBarModeItem(
      mode: SendMode.webrtc,
      label: 'WebRTC',
      available: true,
      attemptable: true,
      isSelected: false,
      reachKnownOnline: true,
    );
    expect(
      resolveTransferModeDotStateFromItem(item),
      TransferModeDotState.verified,
    );
  });
}
