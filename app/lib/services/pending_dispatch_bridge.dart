typedef PendingDispatchSettledHandler = void Function(
  String localPath, {
  required bool success,
});

/// Routes channel delivery results back to [PendingFilesNotifier].
final class PendingDispatchBridge {
  PendingDispatchBridge._();

  static PendingDispatchSettledHandler? _handler;

  static void register(PendingDispatchSettledHandler handler) {
    _handler = handler;
  }

  static void unregister() {
    _handler = null;
  }

  static void notifySettled(
    String localPath, {
    required bool success,
  }) {
    if (localPath.isEmpty) return;
    _handler?.call(localPath, success: success);
  }
}
