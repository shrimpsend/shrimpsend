import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logger.dart';
import '../utils/helpers.dart';
import '../utils/runtime_platform.dart';
import 'speed_tracker.dart';
import 'transfer_completion_notifier.dart';
import 'transfer_foreground_task.dart';

class _TransferEntry {
  _TransferEntry({
    required this.totalBytes,
    this.fileName,
  });

  int totalBytes;
  int transferredBytes = 0;
  String? fileName;
}

/// Keeps the app awake while at least one file transfer is active.
///
/// Reference-counted by transfer id: pair [retain] with [release]. When the
/// count drops to zero, a completion notification may be shown, then wakelock
/// and the foreground service are torn down.
class TransferKeepAlive {
  TransferKeepAlive._();

  static final instance = TransferKeepAlive._();

  static const _serviceId = 256;
  static const _notificationChannelId = 'transfer_keep_alive';

  final Map<String, _TransferEntry> _entries = {};
  int _refCount = 0;
  bool _initialized = false;
  bool _wakelockEnabled = false;
  bool _foregroundServiceRunning = false;

  DateTime? _sessionStartedAt;
  int _completedFileCount = 0;
  int _completedBytes = 0;

  final SpeedTracker _aggregateSpeed = SpeedTracker();
  Timer? _notificationTimer;
  DateTime? _lastNotificationUpdateAt;

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
  void retain(
    String id, {
    int totalBytes = 0,
    String? fileName,
  }) {
    final isNew = !_entries.containsKey(id);
    if (isNew) {
      _entries[id] = _TransferEntry(
        totalBytes: totalBytes,
        fileName: fileName,
      );
      final prev = _refCount;
      _refCount++;
      _sessionStartedAt ??= DateTime.now();
      if (prev == 0) {
        unawaited(_enable());
      }
    } else {
      final entry = _entries[id]!;
      if (totalBytes > 0) entry.totalBytes = totalBytes;
      if (fileName != null && fileName.isNotEmpty) entry.fileName = fileName;
    }
    logChat.fine('TransferKeepAlive retain id=$id refCount=$_refCount');
    _scheduleNotificationUpdate(immediate: isNew);
  }

  void updateProgress(
    String id,
    int transferred, {
    int? totalBytes,
  }) {
    final entry = _entries[id];
    if (entry == null) return;
    if (totalBytes != null && totalBytes > 0) {
      entry.totalBytes = totalBytes;
    }
    entry.transferredBytes = transferred;
    _aggregateSpeed.update(_aggregateTransferred);
    _scheduleNotificationUpdate();
  }

  /// Release a keep-alive slot. Must match a prior [retain].
  void release(String id, {bool completed = false}) {
    final entry = _entries.remove(id);
    if (entry == null) {
      logChat.warning('TransferKeepAlive release unknown id=$id');
      return;
    }
    if (completed && entry.transferredBytes > 0) {
      _completedFileCount++;
      _completedBytes += entry.transferredBytes;
    }
    if (_refCount <= 0) {
      logChat.warning('TransferKeepAlive release called with refCount=0');
      return;
    }
    _refCount--;
    logChat.fine(
      'TransferKeepAlive release id=$id completed=$completed refCount=$_refCount',
    );
    if (_refCount == 0) {
      unawaited(_finalizeSession());
    } else {
      _scheduleNotificationUpdate(immediate: true);
    }
  }

  /// Force-reset all keep-alive state (e.g. on screen dispose).
  void releaseAll() {
    if (_refCount == 0 && _entries.isEmpty) return;
    logChat.fine('TransferKeepAlive releaseAll prevRefCount=$_refCount');
    _entries.clear();
    _refCount = 0;
    _resetSessionStats();
    unawaited(_disable(resetSession: true));
  }

  int get _aggregateTransferred =>
      _entries.values.fold<int>(0, (sum, e) => sum + e.transferredBytes);

  int get _aggregateTotal => _entries.values.fold<int>(
        0,
        (sum, e) => sum + (e.totalBytes > 0 ? e.totalBytes : 0),
      );

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
      _scheduleNotificationUpdate(immediate: true);
    }
  }

  Future<void> _finalizeSession() async {
    _notificationTimer?.cancel();
    _notificationTimer = null;

    final startedAt = _sessionStartedAt;
    final completedFiles = _completedFileCount;
    final completedBytes = _completedBytes;
    final shouldNotify = completedFiles > 0 && completedBytes > 0;

    await _disable(resetSession: false);

    if (shouldNotify && startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final avgSpeed = elapsed.inMilliseconds > 0
          ? completedBytes / (elapsed.inMilliseconds / 1000.0)
          : 0.0;
      await TransferCompletionNotifier.instance.showBatchComplete(
        fileCount: completedFiles,
        totalBytes: completedBytes,
        elapsed: elapsed,
        avgBytesPerSecond: avgSpeed,
      );
    }

    _resetSessionStats();
  }

  void _resetSessionStats() {
    _sessionStartedAt = null;
    _completedFileCount = 0;
    _completedBytes = 0;
    _aggregateSpeed.reset();
    _lastNotificationUpdateAt = null;
  }

  Future<void> _disable({bool resetSession = true}) async {
    _notificationTimer?.cancel();
    _notificationTimer = null;

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

    if (resetSession) {
      _resetSessionStats();
    }
  }

  void _scheduleNotificationUpdate({bool immediate = false}) {
    if (!RuntimePlatform.isAndroid && !RuntimePlatform.isIos) return;
    if (_refCount <= 0) return;

    final now = DateTime.now();
    if (!immediate &&
        _lastNotificationUpdateAt != null &&
        now.difference(_lastNotificationUpdateAt!) <
            const Duration(seconds: 1)) {
      _notificationTimer ??= Timer(const Duration(seconds: 1), () {
        _notificationTimer = null;
        unawaited(_pushNotificationUpdate());
      });
      return;
    }

    unawaited(_pushNotificationUpdate());
  }

  Future<void> _pushNotificationUpdate() async {
    if (_refCount <= 0) return;
    if (!await FlutterForegroundTask.isRunningService) return;

    _lastNotificationUpdateAt = DateTime.now();
    final (title, text) = _buildProgressNotificationText();
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e, st) {
      logChat.warning('TransferKeepAlive notification update failed: $e', e, st);
    }
  }

  (String, String) _buildProgressNotificationText() {
    final activeCount = _entries.length;
    final transferred = _aggregateTransferred;
    final total = _aggregateTotal;
    final title = activeCount <= 1 ? '正在传输文件' : '正在传输 $activeCount 个文件';

    if (total <= 0) {
      return (title, '传输进行中…');
    }

    final pct = ((transferred * 100) / total).round().clamp(0, 100);
    final speed = _aggregateSpeed.formatted;
    final parts = <String>[
      '已完成 $pct%',
      '${formatSize(transferred)}/${formatSize(total)}',
      if (speed.isNotEmpty) speed,
    ];
    return (title, parts.join(' · '));
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    if (_foregroundServiceRunning) return;
    try {
      if (RuntimePlatform.isAndroid) {
        final permission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      }

      if (await FlutterForegroundTask.isRunningService) {
        _foregroundServiceRunning = true;
        return;
      }

      final (title, text) = _buildProgressNotificationText();
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: text,
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
