import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logger.dart';
import '../utils/runtime_platform.dart';
import 'transfer_foreground_task.dart';

/// Keeps the app awake while at least one file transfer is active.
///
/// Reference-counted: callers must pair [retain] with [release]. When the count
/// drops to zero, wakelock and (on Android) the foreground service are torn
/// down.
class TransferKeepAlive {
  TransferKeepAlive._();

  static final instance = TransferKeepAlive._();

  static const _serviceId = 256;
  static const _notificationChannelId = 'transfer_keep_alive';
  static const _notificationTitle = '正在传输文件';
  static const _notificationText = '传输进行中，请保持应用运行';

  int _refCount = 0;
  bool _initialized = false;
  bool _wakelockEnabled = false;
  bool _foregroundServiceRunning = false;

  /// Whether any transfer currently holds a keep-alive reference.
  bool get isActive => _refCount > 0;

  /// Call once during app startup (after [WidgetsFlutterBinding.ensureInitialized]).
  static Future<void> ensureInitialized() async {
    await instance._ensureInitialized();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    if (!RuntimePlatform.isMobile && !RuntimePlatform.isDesktop) return;

    if (RuntimePlatform.isAndroid || RuntimePlatform.isIos) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: _notificationChannelId,
          channelName: '文件传输',
          channelDescription: '传输进行中时显示，确保锁屏后传输不中断。',
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    }
  }

  /// Acquire a keep-alive slot for one active transfer.
  void retain() {
    final prev = _refCount;
    _refCount++;
    if (prev == 0) {
      unawaited(_enable());
    }
    logChat.fine('TransferKeepAlive retain refCount=$_refCount');
  }

  /// Release a keep-alive slot. Must match a prior [retain].
  void release() {
    if (_refCount <= 0) {
      logChat.warning('TransferKeepAlive release called with refCount=0');
      return;
    }
    _refCount--;
    logChat.fine('TransferKeepAlive release refCount=$_refCount');
    if (_refCount == 0) {
      unawaited(_disable());
    }
  }

  /// Force-reset all keep-alive state (e.g. on screen dispose).
  void releaseAll() {
    if (_refCount == 0) return;
    logChat.fine('TransferKeepAlive releaseAll prevRefCount=$_refCount');
    _refCount = 0;
    unawaited(_disable());
  }

  Future<void> _enable() async {
    try {
      if (!_wakelockEnabled) {
        await WakelockPlus.enable();
        _wakelockEnabled = true;
      }
    } catch (e, st) {
      logChat.warning('TransferKeepAlive wakelock enable failed: $e', e, st);
    }

    if (RuntimePlatform.isAndroid || RuntimePlatform.isIos) {
      await _startForegroundServiceIfNeeded();
    }
  }

  Future<void> _disable() async {
    if (RuntimePlatform.isAndroid || RuntimePlatform.isIos) {
      await _stopForegroundServiceIfNeeded();
    }

    if (_wakelockEnabled) {
      try {
        await WakelockPlus.disable();
      } catch (e, st) {
        logChat.warning('TransferKeepAlive wakelock disable failed: $e', e, st);
      } finally {
        _wakelockEnabled = false;
      }
    }
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    if (_foregroundServiceRunning) return;
    try {
      if (RuntimePlatform.isAndroid) {
        final permission = await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      }

      if (await FlutterForegroundTask.isRunningService) {
        _foregroundServiceRunning = true;
        return;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: _notificationTitle,
        notificationText: _notificationText,
        notificationIcon: null,
        callback: transferForegroundTaskStartCallback,
      );
      if (result is ServiceRequestSuccess) {
        _foregroundServiceRunning = true;
        logChat.info('TransferKeepAlive foreground service started');
      } else if (result is ServiceRequestFailure) {
        logChat.warning(
          'TransferKeepAlive foreground service start failed: ${result.error}',
        );
      }
    } catch (e, st) {
      logChat.warning(
        'TransferKeepAlive foreground service start failed: $e',
        e,
        st,
      );
    }
  }

  Future<void> _stopForegroundServiceIfNeeded() async {
    if (!_foregroundServiceRunning &&
        !await FlutterForegroundTask.isRunningService) {
      return;
    }
    try {
      await FlutterForegroundTask.stopService();
      logChat.info('TransferKeepAlive foreground service stopped');
    } catch (e, st) {
      logChat.warning(
        'TransferKeepAlive foreground service stop failed: $e',
        e,
        st,
      );
    } finally {
      _foregroundServiceRunning = false;
    }
  }
}
