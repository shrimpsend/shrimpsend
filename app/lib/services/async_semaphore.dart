import 'dart:async';

/// Limits how many [run] calls execute concurrently.
final class AsyncSemaphore {
  AsyncSemaphore(this.maxConcurrent) : assert(maxConcurrent > 0);

  int maxConcurrent;
  int _inUse = 0;
  final _waiters = <Completer<void>>[];

  void updateMaxConcurrent(int value) {
    assert(value > 0);
    maxConcurrent = value;
  }

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_inUse < maxConcurrent) {
      _inUse++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    if (_inUse > 0) {
      _inUse--;
    }
  }
}
