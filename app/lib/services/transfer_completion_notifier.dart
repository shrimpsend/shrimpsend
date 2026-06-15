import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logger.dart';
import '../utils/helpers.dart';
import '../utils/runtime_platform.dart';
import 'speed_tracker.dart';

/// Shows a one-shot local notification when a transfer batch finishes.
class TransferCompletionNotifier {
  TransferCompletionNotifier._();

  static final instance = TransferCompletionNotifier._();

  static const _channelId = 'transfer_completion';
  static const _notificationId = 257;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static Future<void> ensureInitialized() async {
    await instance._ensureInitialized();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (!RuntimePlatform.isMobile) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              '传输完成',
              description: '文件传输完成后的总结通知',
              importance: Importance.defaultImportance,
            ),
          );
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: false);
    }

    _initialized = true;
  }

  Future<void> showBatchComplete({
    required int fileCount,
    required int totalBytes,
    required Duration elapsed,
    required double avgBytesPerSecond,
  }) async {
    if (!RuntimePlatform.isMobile) return;
    if (!_initialized) await _ensureInitialized();
    if (fileCount <= 0 || totalBytes <= 0) return;

    final elapsedText = _formatDuration(elapsed);
    final speedText = avgBytesPerSecond > 0
        ? SpeedTracker.formatSpeed(avgBytesPerSecond)
        : '';
    final bodyParts = <String>[
      '$fileCount 个文件',
      '共 ${formatSize(totalBytes)}',
      '用时 $elapsedText',
      if (speedText.isNotEmpty) '均速 $speedText',
    ];

    try {
      await _plugin.show(
        id: _notificationId,
        title: '传输完成',
        body: bodyParts.join(' · '),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '传输完成',
            channelDescription: '文件传输完成后的总结通知',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          ),
        ),
      );
      logChat.info(
        'TransferCompletionNotifier shown files=$fileCount bytes=$totalBytes',
      );
    } catch (e, st) {
      logChat.warning('TransferCompletionNotifier show failed: $e', e, st);
    }
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
