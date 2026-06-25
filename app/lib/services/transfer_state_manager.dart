import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../logger.dart';
import 'database.dart';
import 'transfer_record.dart';
import 'transfer_status.dart';

const _maxAge = Duration(hours: 24);
const _table = 'transfer_records';

/// Persists [TransferRecord] instances so that interrupted transfers can be
/// resumed after an app restart. Uses SQLite for efficient single-row CRUD.
class TransferStateManager {
  TransferStateManager._();
  static final instance = TransferStateManager._();

  Database get _db => AppDatabase.instance.db;

  Future<void> saveRecord(TransferRecord record) async {
    record.updatedAt = DateTime.now();
    await _db.insert(
      _table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    logChat.info(
      'TransferStateManager saveRecord id=${record.transferId} channel=${record.channel} direction=${record.direction} file=${record.fileName} status=${record.status}',
    );
  }

  Future<void> updateProgress(
    String transferId,
    int transferredBytes, {
    List<CompletedPart>? completedParts,
    int? lanResumeOffset,
    int? webrtcOffset,
  }) async {
    final updates = <String, dynamic>{
      'transferred_bytes': transferredBytes,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (completedParts != null) {
      updates['s3_completed_parts'] = jsonEncode(
        completedParts.map((p) => p.toJson()).toList(),
      );
    }
    if (lanResumeOffset != null) {
      updates['lan_resume_offset'] = lanResumeOffset;
    }
    if (webrtcOffset != null) {
      updates['webrtc_offset'] = webrtcOffset;
    }
    await _db.update(
      _table,
      updates,
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
  }

  /// Persist the LAN sender's known offset alongside [transferredBytes].
  Future<void> updateLanOffset(String transferId, int offset) async {
    await updateProgress(
      transferId,
      offset,
      lanResumeOffset: offset,
    );
  }

  /// Persist the WebRTC sender's confirmed offset alongside [transferredBytes].
  Future<void> updateWebrtcOffset(String transferId, int offset) async {
    await updateProgress(
      transferId,
      offset,
      webrtcOffset: offset,
    );
  }

  Future<void> markStatus(String transferId, String status) async {
    if (status == TransferStatus.completed) {
      await _db.delete(
        _table,
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
      return;
    }
    await _db.update(
      _table,
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
  }

  Future<void> markFailed(String transferId, String errorMessage) async {
    await _db.update(
      _table,
      {
        'status': TransferStatus.failed,
        'error_message': errorMessage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
  }

  /// Persist filePath (used when the writer switches from one partial file to
  /// a different on-disk location, e.g. S3 download writing to `*.partial`).
  Future<void> updateFilePath(String transferId, String filePath) async {
    await _db.update(
      _table,
      {
        'file_path': filePath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
  }

  Future<TransferRecord?> getRecord(String transferId) async {
    final rows = await _db.query(
      _table,
      where: 'transfer_id = ?',
      whereArgs: [transferId],
    );
    if (rows.isEmpty) return null;
    return TransferRecord.fromMap(rows.first);
  }

  /// Returns transfers that can be resumed. Includes user-paused (`paused`)
  /// and legacy `cancelled` rows so a previously cancelled transfer can still
  /// be continued from the UI / on cold start.
  Future<List<TransferRecord>> getResumableTransfers() async {
    final rows = await _db.query(
      _table,
      where: "status IN ('in_progress', 'paused', 'failed', 'cancelled')",
    );
    final list = rows.map((r) => TransferRecord.fromMap(r)).toList();
    logChat.info(
      'TransferStateManager getResumableTransfers total=${list.length}',
    );
    return list;
  }

  /// Returns transfers that the user explicitly paused/cancelled. Useful when
  /// the UI needs to distinguish "Continue" vs "Retry" affordances.
  Future<List<TransferRecord>> getPausedTransfers() async {
    final rows = await _db.query(
      _table,
      where: "status IN ('paused', 'cancelled')",
    );
    return rows.map((r) => TransferRecord.fromMap(r)).toList();
  }

  Future<TransferRecord?> findResumable({
    required String channel,
    required String direction,
    String? s3Key,
    String? fileName,
    int? fileSize,
  }) async {
    final resumable = await getResumableTransfers();
    for (final r in resumable) {
      if (r.channel != channel || r.direction != direction) continue;
      if (s3Key != null && r.s3Key == s3Key) return r;
      if (fileName != null &&
          fileSize != null &&
          r.fileName == fileName &&
          r.fileSize == fileSize) {
        return r;
      }
    }
    return null;
  }

  /// Remove records older than [_maxAge] (non in_progress only).
  Future<void> cleanExpired() async {
    final cutoff = DateTime.now().subtract(_maxAge).toIso8601String();
    final count = await _db.delete(
      _table,
      where: "status != '${TransferStatus.inProgress}' AND updated_at < ?",
      whereArgs: [cutoff],
    );
    logChat.info('TransferStateManager cleanExpired removed $count records');
  }

  Future<void> removeRecord(String transferId) async {
    await _db.delete(_table, where: 'transfer_id = ?', whereArgs: [transferId]);
  }

  Future<List<TransferRecord>> listWebDavTransfers({
    required String connectionId,
    String? direction,
    bool activeOnly = false,
  }) async {
    final where = <String>['channel = ?', 'webdav_connection_id = ?'];
    final args = <Object>['webdav', connectionId];
    if (direction != null) {
      where.add('direction = ?');
      args.add(direction);
    }
    if (activeOnly) {
      where.add("status IN ('in_progress', 'paused', 'failed', 'cancelled')");
    }
    final rows = await _db.query(
      _table,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => TransferRecord.fromMap(r)).toList();
  }

  Future<int> countActiveWebDavTransfers(String connectionId) async {
    final rows = await _db.rawQuery(
      '''
SELECT COUNT(*) AS c FROM $_table
WHERE channel = 'webdav'
  AND webdav_connection_id = ?
  AND status IN ('in_progress', 'paused')
''',
      [connectionId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> clear() async {
    await _db.delete(_table);
  }
}
