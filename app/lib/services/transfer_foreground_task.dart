import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Minimal foreground-task handler: keeps the OS process alive while a file
/// transfer is in progress. No periodic work is required.
@pragma('vm:entry-point')
void transferForegroundTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(_TransferForegroundTaskHandler());
}

class _TransferForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}
