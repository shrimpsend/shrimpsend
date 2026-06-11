import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../logger.dart';
import 'file_export_pipeline.dart';
import 'received_file_dao.dart';

final _log = logChat;

/// Brief pause after index write so cache files finish flushing before export.
Duration _settleAfterUpsert() {
  if (kIsWeb) return Duration.zero;
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return const Duration(milliseconds: 50);
  }
  return const Duration(milliseconds: 50);
}

/// Serializes [ReceivedFileDao.upsert] + inline [FileExportPipeline.exportNow]
/// so each received file is exported before the next finalize runs.
class ReceivedFileIndexPipeline {
  ReceivedFileIndexPipeline._();
  static final instance = ReceivedFileIndexPipeline._();

  Future<void>? _tail;

  /// Runs [task] after all prior pipeline work completes.
  Future<T> enqueue<T>(Future<T> Function() task) {
    final prev = _tail ?? Future<void>.value();
    late final Future<T> next;
    next = prev.then((_) => task());
    _tail = next.then((_) {}).catchError((Object e, StackTrace st) {
      _log.warning(
        'ReceivedFileIndexPipeline task failed: $e',
        e,
        st,
      );
    });
    return next;
  }

  /// Runs [upsert] then immediately exports to visible storage.
  /// Returns `true` when export reaches [ExportStatus.done].
  /// Throws if [upsert] fails.
  Future<bool> upsertAndExportInline({
    required String messageId,
    required Future<void> Function() upsert,
  }) {
    return enqueue(() async {
      await upsert();
      final settle = _settleAfterUpsert();
      if (settle > Duration.zero) {
        await Future<void>.delayed(settle);
      }
      return FileExportPipeline.instance.exportNow(messageId);
    });
  }

  /// Re-keys a received_files row after LAN/WebRTC bubble id upgrade.
  /// Must run on the same queue as inline export so export status is preserved.
  Future<bool> rekeyAfterBubbleUpgrade({
    required String oldMessageId,
    required String newMessageId,
    String? userId,
    String? threadKey,
    String? fromDeviceId,
  }) {
    return enqueue(
      () => ReceivedFileDao.instance.rekeyMessageId(
        oldMessageId: oldMessageId,
        newMessageId: newMessageId,
        userId: userId,
        threadKey: threadKey,
        fromDeviceId: fromDeviceId,
      ),
    );
  }
}
