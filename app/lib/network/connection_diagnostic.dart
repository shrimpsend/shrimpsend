import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'probe_priority.dart';

enum ConnectionDiagnosticStepId {
  s3,
  httpDirect,
  httpSignaling,
  httpPull,
  webrtc,
}

enum ConnectionDiagnosticStepStatus {
  pending,
  running,
  success,
  failure,
  skipped,
}

class ConnectionDiagnosticStep {
  const ConnectionDiagnosticStep({
    required this.id,
    required this.title,
    this.status = ConnectionDiagnosticStepStatus.pending,
    this.elapsed,
    this.reason,
    this.startedAt,
  });

  final ConnectionDiagnosticStepId id;
  final String title;
  final ConnectionDiagnosticStepStatus status;
  final Duration? elapsed;
  final String? reason;
  final DateTime? startedAt;

  ConnectionDiagnosticStep copyWith({
    String? title,
    ConnectionDiagnosticStepStatus? status,
    Duration? elapsed,
    String? reason,
    DateTime? startedAt,
    bool clearElapsed = false,
    bool clearReason = false,
    bool clearStartedAt = false,
  }) {
    return ConnectionDiagnosticStep(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      elapsed: clearElapsed ? null : (elapsed ?? this.elapsed),
      reason: clearReason ? null : (reason ?? this.reason),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }
}

class ConnectionDiagnosticState {
  const ConnectionDiagnosticState({
    required this.peerId,
    required this.peerLabel,
    required this.steps,
    this.running = false,
    this.summary,
    this.finishedAt,
  });

  final String peerId;
  final String peerLabel;
  final List<ConnectionDiagnosticStep> steps;
  final bool running;
  final String? summary;
  final DateTime? finishedAt;

  static const empty = ConnectionDiagnosticState(
    peerId: '',
    peerLabel: '',
    steps: [],
  );

  bool get isEmpty => peerId.isEmpty;

  ConnectionDiagnosticState copyWith({
    String? peerId,
    String? peerLabel,
    List<ConnectionDiagnosticStep>? steps,
    bool? running,
    String? summary,
    DateTime? finishedAt,
    bool clearSummary = false,
    bool clearFinishedAt = false,
  }) {
    return ConnectionDiagnosticState(
      peerId: peerId ?? this.peerId,
      peerLabel: peerLabel ?? this.peerLabel,
      steps: steps ?? this.steps,
      running: running ?? this.running,
      summary: clearSummary ? null : (summary ?? this.summary),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    );
  }
}

/// Full diagnostic step list ordered by [ProbePriority] (UI order = execution order).
List<ConnectionDiagnosticStepId> diagnosticStepOrder({
  required ProbePriority devicePriority,
}) {
  const lan = [ConnectionDiagnosticStepId.httpDirect];
  const cloud = [
    ConnectionDiagnosticStepId.httpSignaling,
    ConnectionDiagnosticStepId.httpPull,
    ConnectionDiagnosticStepId.webrtc,
  ];
  const fallback = [ConnectionDiagnosticStepId.s3];

  final core = switch (devicePriority) {
    ProbePriority.lanDiscovered => [...lan, ...cloud],
    ProbePriority.presenceOnline => [...cloud, ...lan],
    ProbePriority.lazy => [...cloud, ...lan],
  };
  return [...core, ...fallback];
}

class ConnectionDiagnosticNotifier
    extends StateNotifier<ConnectionDiagnosticState> {
  ConnectionDiagnosticNotifier() : super(ConnectionDiagnosticState.empty);

  void startSession({
    required String peerId,
    required String peerLabel,
    required List<ConnectionDiagnosticStep> steps,
  }) {
    state = ConnectionDiagnosticState(
      peerId: peerId,
      peerLabel: peerLabel,
      steps: steps,
      running: true,
    );
  }

  void clear() {
    state = ConnectionDiagnosticState.empty;
  }

  void beginStep(ConnectionDiagnosticStepId id) {
    final now = DateTime.now();
    state = state.copyWith(
      steps: _mapStep(
        id,
        (step) => step.copyWith(
          status: ConnectionDiagnosticStepStatus.running,
          startedAt: now,
          clearElapsed: true,
          clearReason: true,
        ),
      ),
    );
  }

  void finishStep(
    ConnectionDiagnosticStepId id, {
    required ConnectionDiagnosticStepStatus status,
    String? reason,
    DateTime? finishedAt,
  }) {
    final end = finishedAt ?? DateTime.now();
    state = state.copyWith(
      steps: _mapStep(id, (step) {
        final started = step.startedAt;
        final elapsed = started != null ? end.difference(started) : null;
        return step.copyWith(
          status: status,
          elapsed: elapsed,
          reason: reason,
        );
      }),
    );
  }

  void skipStep(ConnectionDiagnosticStepId id, {required String reason}) {
    finishStep(
      id,
      status: ConnectionDiagnosticStepStatus.skipped,
      reason: reason,
    );
  }

  void setSummary(String summary) {
    state = state.copyWith(
      running: false,
      summary: summary,
      finishedAt: DateTime.now(),
    );
  }

  void skipPendingSteps({required String reason}) {
    state = state.copyWith(
      steps: state.steps
          .map(
            (step) =>
                step.status == ConnectionDiagnosticStepStatus.pending ||
                    step.status == ConnectionDiagnosticStepStatus.running
                ? step.copyWith(
                    status: ConnectionDiagnosticStepStatus.skipped,
                    reason: reason,
                    clearStartedAt: true,
                  )
                : step,
          )
          .toList(growable: false),
    );
  }

  bool hasStep(ConnectionDiagnosticStepId id) {
    return state.steps.any((step) => step.id == id);
  }

  List<ConnectionDiagnosticStep> _mapStep(
    ConnectionDiagnosticStepId id,
    ConnectionDiagnosticStep Function(ConnectionDiagnosticStep step) transform,
  ) {
    return state.steps
        .map((step) => step.id == id ? transform(step) : step)
        .toList(growable: false);
  }
}

final connectionDiagnosticProvider =
    StateNotifierProvider<ConnectionDiagnosticNotifier, ConnectionDiagnosticState>(
  (_) => ConnectionDiagnosticNotifier(),
);

/// Thin wrapper passed into probe methods to emit diagnostic events.
class ConnectionDiagnosticReporter {
  ConnectionDiagnosticReporter(this._notifier);

  final ConnectionDiagnosticNotifier _notifier;

  void beginStep(ConnectionDiagnosticStepId id) {
    if (!_notifier.hasStep(id)) return;
    _notifier.beginStep(id);
  }

  void finishSuccess(ConnectionDiagnosticStepId id, {required String reason}) {
    if (!_notifier.hasStep(id)) return;
    _notifier.finishStep(
      id,
      status: ConnectionDiagnosticStepStatus.success,
      reason: reason,
    );
  }

  void finishFailure(ConnectionDiagnosticStepId id, {required String reason}) {
    if (!_notifier.hasStep(id)) return;
    _notifier.finishStep(
      id,
      status: ConnectionDiagnosticStepStatus.failure,
      reason: reason,
    );
  }

  void skipStep(ConnectionDiagnosticStepId id, {required String reason}) {
    if (!_notifier.hasStep(id)) return;
    _notifier.skipStep(id, reason: reason);
  }

  void skipPendingSteps({required String reason}) {
    _notifier.skipPendingSteps(reason: reason);
  }

  void setSummary(String summary) => _notifier.setSummary(summary);
}

String formatDiagnosticElapsed(Duration elapsed) {
  if (elapsed.inMilliseconds < 1000) {
    return '${elapsed.inMilliseconds}ms';
  }
  final seconds = elapsed.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1)}s';
}
