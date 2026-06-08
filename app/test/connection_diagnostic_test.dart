import 'package:app/network/connection_diagnostic.dart';
import 'package:app/network/probe_priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionDiagnosticNotifier', () {
    late ConnectionDiagnosticNotifier notifier;

    setUp(() {
      notifier = ConnectionDiagnosticNotifier();
      notifier.startSession(
        peerId: 'peer-1',
        peerLabel: 'Test Device',
        steps: const [
          ConnectionDiagnosticStep(
            id: ConnectionDiagnosticStepId.httpDirect,
            title: 'HTTP direct',
          ),
          ConnectionDiagnosticStep(
            id: ConnectionDiagnosticStepId.webrtc,
            title: 'WebRTC',
          ),
        ],
      );
    });

    test('beginStep moves step to running', () {
      notifier.beginStep(ConnectionDiagnosticStepId.httpDirect);
      final step = notifier.state.steps.first;
      expect(step.status, ConnectionDiagnosticStepStatus.running);
      expect(step.startedAt, isNotNull);
    });

    test('finishStep records elapsed and reason', () {
      final started = DateTime.now().subtract(const Duration(milliseconds: 500));
      notifier.state = notifier.state.copyWith(
        steps: [
          ConnectionDiagnosticStep(
            id: ConnectionDiagnosticStepId.httpDirect,
            title: 'HTTP direct',
            status: ConnectionDiagnosticStepStatus.running,
            startedAt: started,
          ),
          notifier.state.steps[1],
        ],
      );

      notifier.finishStep(
        ConnectionDiagnosticStepId.httpDirect,
        status: ConnectionDiagnosticStepStatus.success,
        reason: 'ok',
        finishedAt: started.add(const Duration(milliseconds: 1200)),
      );

      final step = notifier.state.steps.first;
      expect(step.status, ConnectionDiagnosticStepStatus.success);
      expect(step.reason, 'ok');
      expect(step.elapsed, const Duration(milliseconds: 1200));
    });

    test('setSummary stops running and stores text', () {
      notifier.setSummary('Recommended: HTTP');
      expect(notifier.state.running, isFalse);
      expect(notifier.state.summary, 'Recommended: HTTP');
      expect(notifier.state.finishedAt, isNotNull);
    });
  });

  group('ConnectionDiagnosticReporter', () {
    test('ignores steps not in session', () {
      final notifier = ConnectionDiagnosticNotifier();
      notifier.startSession(
        peerId: 'peer-1',
        peerLabel: 'Test Device',
        steps: const [
          ConnectionDiagnosticStep(
            id: ConnectionDiagnosticStepId.httpDirect,
            title: 'HTTP direct',
          ),
        ],
      );
      final reporter = ConnectionDiagnosticReporter(notifier);

      reporter.beginStep(ConnectionDiagnosticStepId.webrtc);
      reporter.finishSuccess(
        ConnectionDiagnosticStepId.webrtc,
        reason: 'should not apply',
      );

      expect(notifier.state.steps.length, 1);
      expect(
        notifier.state.steps.first.status,
        ConnectionDiagnosticStepStatus.pending,
      );
    });
  });

  group('diagnosticStepOrder', () {
    test('lanDiscovered puts httpDirect before httpSignaling', () {
      final ids = diagnosticStepOrder(
        devicePriority: ProbePriority.lanDiscovered,
      );
      expect(ids.length, 5);
      expect(
        ids.indexOf(ConnectionDiagnosticStepId.httpDirect),
        lessThan(ids.indexOf(ConnectionDiagnosticStepId.httpSignaling)),
      );
      expect(ids.last, ConnectionDiagnosticStepId.s3);
    });

    test('presenceOnline puts httpSignaling before httpDirect', () {
      final ids = diagnosticStepOrder(
        devicePriority: ProbePriority.presenceOnline,
      );
      expect(ids.length, 5);
      expect(
        ids.indexOf(ConnectionDiagnosticStepId.httpSignaling),
        lessThan(ids.indexOf(ConnectionDiagnosticStepId.httpDirect)),
      );
      expect(ids.last, ConnectionDiagnosticStepId.s3);
    });

    test('lazy uses cloud-first ordering like presenceOnline', () {
      final ids = diagnosticStepOrder(devicePriority: ProbePriority.lazy);
      expect(ids.length, 5);
      expect(
        ids.indexOf(ConnectionDiagnosticStepId.httpSignaling),
        lessThan(ids.indexOf(ConnectionDiagnosticStepId.httpDirect)),
      );
      expect(ids.last, ConnectionDiagnosticStepId.s3);
    });
  });

  group('formatDiagnosticElapsed', () {
    test('formats sub-second as ms', () {
      expect(
        formatDiagnosticElapsed(const Duration(milliseconds: 842)),
        '842ms',
      );
    });

    test('formats seconds with one decimal', () {
      expect(formatDiagnosticElapsed(const Duration(milliseconds: 1530)), '1.5s');
    });
  });
}
