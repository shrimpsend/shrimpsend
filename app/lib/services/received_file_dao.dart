import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/file_utils.dart';
import '../lan/transfer_worker.dart' show makeFileId;
import 'database.dart';
import 'file_store.dart';
import 'visible_export_target.dart';

const _table = 'received_files';

enum ReceivedFileSortBy {
  createdAt,
  modified,
}

class ReceivedFileRecord {
  final String messageId;
  final String? userId;
  final String? threadKey;
  final String dirName;
  final String fileName;
  final String absPath;
  final String? protocol;
  final FileCategory category;
  final int size;
  final DateTime mtime;
  final DateTime createdAt;
  final String? s3Key;
  final String? fromDeviceId;
  final bool deleted;
  final String? cachePath;
  final String? visiblePath;
  final ExportStatus exportStatus;
  final ExportTargetKind? exportTarget;
  final bool gallerySaved;
  final String? exportError;
  final DateTime? exportedAt;

  ReceivedFileRecord({
    required this.messageId,
    required this.dirName,
    required this.fileName,
    required this.absPath,
    required this.size,
    required this.mtime,
    required this.createdAt,
    required this.category,
    this.userId,
    this.threadKey,
    this.protocol,
    this.s3Key,
    this.fromDeviceId,
    this.deleted = false,
    this.cachePath,
    this.visiblePath,
    this.exportStatus = ExportStatus.pending,
    this.exportTarget,
    this.gallerySaved = false,
    this.exportError,
    this.exportedAt,
  });

  String get readablePath => FileStore.resolveReadablePath(
        cachePath: cachePath,
        visiblePath: visiblePath,
        absPath: absPath,
      );

  ReceivedFileInfo toInfo() => ReceivedFileInfo(
        messageId: messageId,
        path: readablePath,
        displayName: fileName,
        protocol: protocol ?? 'unknown',
        size: size,
        modified: mtime,
        createdAt: createdAt,
        category: category,
        threadKey: threadKey,
        s3Key: s3Key,
        fromDeviceId: fromDeviceId,
        cachePath: cachePath,
        visiblePath: visiblePath,
        exportStatus: exportStatus,
        gallerySaved: gallerySaved,
      );

  static ExportStatus _parseExportStatus(String? raw) {
    if (raw == null || raw.isEmpty) return ExportStatus.pending;
    return ExportStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ExportStatus.pending,
    );
  }

  static ExportTargetKind? _parseExportTarget(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final e in ExportTargetKind.values) {
      if (e.name == raw) return e;
    }
    return null;
  }

  static ReceivedFileRecord fromRow(Map<String, dynamic> row) {
    final cat = (row['category'] as String?) ?? '';
    final category = FileCategory.values.firstWhere(
      (c) => c.name == cat,
      orElse: () => getFileCategory(row['file_name'] as String?),
    );
    final exportedAtMs = row['exported_at'] as int?;
    return ReceivedFileRecord(
      messageId: row['message_id'] as String,
      userId: row['user_id'] as String?,
      threadKey: row['thread_key'] as String?,
      dirName: row['dir_name'] as String,
      fileName: row['file_name'] as String,
      absPath: row['abs_path'] as String,
      size: (row['size'] as int?) ?? 0,
      mtime: DateTime.fromMillisecondsSinceEpoch((row['mtime'] as int?) ?? 0),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((row['created_at'] as int?) ?? 0),
      category: category,
      protocol: row['protocol'] as String?,
      s3Key: row['s3_key'] as String?,
      fromDeviceId: row['from_device_id'] as String?,
      deleted: ((row['deleted'] as int?) ?? 0) == 1,
      cachePath: row['cache_path'] as String?,
      visiblePath: row['visible_path'] as String?,
      exportStatus: _parseExportStatus(row['export_status'] as String?),
      exportTarget: _parseExportTarget(row['export_target'] as String?),
      gallerySaved: ((row['gallery_saved'] as int?) ?? 0) == 1,
      exportError: row['export_error'] as String?,
      exportedAt: exportedAtMs != null && exportedAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(exportedAtMs)
          : null,
    );
  }
}

class ReceivedFileDao {
  ReceivedFileDao._();
  static final instance = ReceivedFileDao._();

  /// In-memory DB for unit tests; when null, uses [AppDatabase.instance].
  @visibleForTesting
  static Database? testDatabase;

  Database get _db => testDatabase ?? AppDatabase.instance.db;

  static final List<void Function()> _changedListeners = [];

  static void addChangedListener(void Function() listener) {
    _changedListeners.add(listener);
  }

  static void removeChangedListener(void Function() listener) {
    _changedListeners.remove(listener);
  }

  void _notifyChanged() {
    for (final cb in List.of(_changedListeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }

  Future<void> upsert({
    required String messageId,
    required String absPath,
    String? userId,
    String? threadKey,
    String? protocol,
    String? s3Key,
    String? fromDeviceId,
    int? size,
    DateTime? mtime,
    String? cachePath,
    String? visiblePath,
    ExportStatus? exportStatus,
    ExportTargetKind? exportTarget,
    bool? gallerySaved,
    String? exportError,
    DateTime? exportedAt,
  }) async {
    final fileName = p.basename(absPath);
    final dirName = p.basename(p.dirname(absPath));
    int sz = size ?? 0;
    int mt = mtime?.millisecondsSinceEpoch ?? 0;
    if (sz == 0 || mt == 0) {
      try {
        final stat = File(absPath).statSync();
        if (sz == 0) sz = stat.size;
        if (mt == 0) mt = stat.modified.millisecondsSinceEpoch;
      } catch (_) {}
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final category = getFileCategory(fileName).name;

    final existing = await _db.query(
      _table,
      columns: ['created_at', 'export_status', 'gallery_saved'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? ((existing.first['created_at'] as int?) ?? now)
        : now;

    final effectiveCache = cachePath ?? absPath;
    final status = exportStatus ??
        (existing.isEmpty
            ? ExportStatus.pending
            : ReceivedFileRecord._parseExportStatus(
                existing.first['export_status'] as String?,
              ));
    final effectiveAbs = FileStore.resolveReadablePath(
      cachePath: effectiveCache,
      visiblePath: visiblePath,
      absPath: absPath,
    );

    await _db.insert(
      _table,
      {
        'message_id': messageId,
        'user_id': userId,
        'thread_key': threadKey,
        'dir_name': dirName,
        'file_name': fileName,
        'abs_path': effectiveAbs,
        'protocol': protocol,
        'category': category,
        'size': sz,
        'mtime': mt == 0 ? now : mt,
        'created_at': createdAt,
        's3_key': s3Key,
        'from_device_id': fromDeviceId,
        'deleted': 0,
        'cache_path': effectiveCache,
        'visible_path': visiblePath,
        'export_status': status.name,
        'export_target': exportTarget?.name,
        'gallery_saved': (gallerySaved ??
                (existing.isNotEmpty &&
                    ((existing.first['gallery_saved'] as int?) ?? 0) == 1))
            ? 1
            : 0,
        'export_error': exportError,
        'exported_at': exportedAt?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged();
  }

  Future<void> updateExportState({
    required String messageId,
    required ExportStatus exportStatus,
    String? visiblePath,
    ExportTargetKind? exportTarget,
    bool? gallerySaved,
    String? exportError,
    String? absPath,
    String? cachePath,
    bool clearCachePath = false,
  }) async {
    final data = <String, Object?>{
      'export_status': exportStatus.name,
    };
    if (visiblePath != null) data['visible_path'] = visiblePath;
    if (exportTarget != null) data['export_target'] = exportTarget.name;
    if (gallerySaved != null) data['gallery_saved'] = gallerySaved ? 1 : 0;
    if (exportError != null) data['export_error'] = exportError;
    if (exportStatus == ExportStatus.done || exportStatus == ExportStatus.failed) {
      data['exported_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    if (absPath != null) data['abs_path'] = absPath;
    if (cachePath != null) data['cache_path'] = cachePath;
    if (clearCachePath) data['cache_path'] = null;

    await _db.update(
      _table,
      data,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    _notifyChanged();
  }

  Future<List<ReceivedFileRecord>> listPendingExports({int limit = 2000}) async {
    final rows = await _db.query(
      _table,
      where:
          "deleted = 0 AND export_status IN ('pending', 'failed') "
          "AND (protocol IS NULL OR protocol != 'share')",
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(ReceivedFileRecord.fromRow).toList();
  }

  Future<ReceivedFileRecord?> getByMessageId(String messageId) async {
    final rows = await _db.query(
      _table,
      where: 'message_id = ? AND deleted = 0',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReceivedFileRecord.fromRow(rows.first);
  }

  Future<Map<String, ReceivedFileRecord>> getByMessageIds(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return const {};
    final placeholders = List.filled(messageIds.length, '?').join(', ');
    final rows = await _db.query(
      _table,
      where: 'message_id IN ($placeholders) AND deleted = 0',
      whereArgs: messageIds,
    );
    final map = <String, ReceivedFileRecord>{};
    for (final r in rows) {
      final rec = ReceivedFileRecord.fromRow(r);
      map[rec.messageId] = rec;
    }
    return map;
  }

  /// SQL filter for File Manager cache tab: in-flight exports or rows with cache.
  static const cacheTabWhereClause =
      "deleted = 0 AND (export_status IN ('pending', 'exporting', 'failed') "
      "OR (cache_path IS NOT NULL AND cache_path != ''))";

  Future<List<ReceivedFileRecord>> listPaged({
    int offset = 0,
    int limit = 50,
    String? category,
    String? threadKey,
    String? query,
    ReceivedFileSortBy sortBy = ReceivedFileSortBy.createdAt,
    bool cacheTabOnly = false,
  }) async {
    final whereParts = <String>[
      cacheTabOnly ? cacheTabWhereClause : 'deleted = 0',
    ];
    final args = <Object>[];
    if (category != null && category.isNotEmpty) {
      whereParts.add('category = ?');
      args.add(category);
    }
    if (threadKey != null && threadKey.isNotEmpty) {
      whereParts.add('thread_key = ?');
      args.add(threadKey);
    }
    if (query != null && query.isNotEmpty) {
      whereParts.add('file_name LIKE ?');
      args.add('%${_escapeLike(query)}%');
    }
    final orderColumn = sortBy == ReceivedFileSortBy.modified
        ? 'mtime'
        : 'created_at';
    final rows = await _db.query(
      _table,
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: '$orderColumn DESC, rowid DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ReceivedFileRecord.fromRow).toList();
  }

  Future<List<ReceivedFileRecord>> findByNameAndSize({
    required String fileName,
    int? size,
    int limit = 1,
  }) async {
    final whereParts = <String>['deleted = 0', 'file_name = ?'];
    final args = <Object>[fileName];
    if (size != null && size > 0) {
      whereParts.add('size = ?');
      args.add(size);
    }
    final rows = await _db.query(
      _table,
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'mtime DESC, rowid DESC',
      limit: limit,
    );
    return rows.map(ReceivedFileRecord.fromRow).toList();
  }

  Future<int> countAll({String? category, String? threadKey}) async {
    final whereParts = <String>['deleted = 0'];
    final args = <Object>[];
    if (category != null && category.isNotEmpty) {
      whereParts.add('category = ?');
      args.add(category);
    }
    if (threadKey != null && threadKey.isNotEmpty) {
      whereParts.add('thread_key = ?');
      args.add(threadKey);
    }
    final res = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE ${whereParts.join(' AND ')}',
      args,
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<void> markDeleted(String messageId) async {
    await _db.update(
      _table,
      {'deleted': 1},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    _notifyChanged();
  }

  Future<void> removeByMessageId(String messageId) async {
    await _db.delete(
      _table,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    _notifyChanged();
  }

  /// Re-keys a row to the server-side message id while preserving export state.
  ///
  /// Returns `true` when the old row existed and was updated.
  Future<bool> rekeyMessageId({
    required String oldMessageId,
    required String newMessageId,
    String? userId,
    String? threadKey,
    String? fromDeviceId,
  }) async {
    if (oldMessageId.isEmpty ||
        newMessageId.isEmpty ||
        oldMessageId == newMessageId) {
      return false;
    }

    final oldRows = await _db.query(
      _table,
      where: 'message_id = ?',
      whereArgs: [oldMessageId],
      limit: 1,
    );
    if (oldRows.isEmpty) return false;

    await _db.delete(
      _table,
      where: 'message_id = ?',
      whereArgs: [newMessageId],
    );

    final data = <String, Object?>{
      'message_id': newMessageId,
    };
    if (userId != null) data['user_id'] = userId;
    if (threadKey != null) data['thread_key'] = threadKey;
    if (fromDeviceId != null) data['from_device_id'] = fromDeviceId;

    final updated = await _db.update(
      _table,
      data,
      where: 'message_id = ?',
      whereArgs: [oldMessageId],
    );
    if (updated > 0) {
      _notifyChanged();
    }
    return updated > 0;
  }

  Future<void> reparentRoot(String oldPrefix, String newPrefix) async {
    if (oldPrefix == newPrefix) return;
    await _db.rawUpdate(
      'UPDATE $_table SET abs_path = ? || SUBSTR(abs_path, ?), '
      'cache_path = CASE WHEN cache_path LIKE ? THEN ? || SUBSTR(cache_path, ?) ELSE cache_path END '
      'WHERE abs_path LIKE ?',
      [
        newPrefix,
        oldPrefix.length + 1,
        '${_escapeLike(oldPrefix)}%',
        newPrefix,
        oldPrefix.length + 1,
        '${_escapeLike(oldPrefix)}%',
      ],
    );
  }

  Future<int> reconcileWithRoot(String rootPath) async {
    int changed = 0;
    final root = Directory(rootPath);
    if (!await root.exists()) return changed;

    final allRows = await _db.query(
      _table,
      columns: ['message_id', 'abs_path', 'cache_path', 'deleted'],
    );
    for (final row in allRows) {
      final cachePath = row['cache_path'] as String?;
      final path = (cachePath != null && cachePath.isNotEmpty)
          ? cachePath
          : row['abs_path'] as String;
      if (path.isEmpty) continue;
      final exists = File(path).existsSync();
      final wasDeleted = ((row['deleted'] as int?) ?? 0) == 1;
      if (!exists && !wasDeleted) {
        await _db.update(
          _table,
          {'deleted': 1},
          where: 'message_id = ?',
          whereArgs: [row['message_id']],
        );
        changed++;
      } else if (exists && wasDeleted) {
        await _db.update(
          _table,
          {'deleted': 0},
          where: 'message_id = ?',
          whereArgs: [row['message_id']],
        );
        changed++;
      }
    }

    final knownPaths = <String>{};
    for (final row in allRows) {
      final cp = row['cache_path'] as String?;
      if (cp != null && cp.isNotEmpty) knownPaths.add(cp);
      knownPaths.add(row['abs_path'] as String);
    }
    final entries = root.listSync(followLinks: false);
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final dirName = p.basename(entry.path);
      if (dirName.startsWith('.')) continue;
      File? first;
      try {
        for (final e in entry.listSync(followLinks: false)) {
          if (e is File && !p.basename(e.path).startsWith('.')) {
            first = e;
            break;
          }
        }
      } catch (_) {
        continue;
      }
      if (first == null) continue;
      if (knownPaths.contains(first.path)) continue;
      final existing = await _db.query(
        _table,
        columns: [
          'message_id',
          'abs_path',
          'cache_path',
          'export_status',
          'visible_path',
        ],
        where: 'message_id = ?',
        whereArgs: [dirName],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final row = existing.first;
        final knownPath = row['abs_path'] as String? ?? '';
        final currentCachePath = row['cache_path'] as String?;
        if (knownPath != first.path || currentCachePath != first.path) {
          final exportStatus = ReceivedFileRecord._parseExportStatus(
            row['export_status'] as String?,
          );
          if (exportStatus == ExportStatus.done ||
              exportStatus == ExportStatus.exporting) {
            final visiblePath = row['visible_path'] as String?;
            await updateExportState(
              messageId: dirName,
              exportStatus: exportStatus,
              cachePath: first.path,
              absPath: FileStore.resolveReadablePath(
                cachePath: first.path,
                visiblePath: visiblePath,
                absPath: knownPath.isNotEmpty ? knownPath : first.path,
              ),
            );
          } else {
            await upsert(
              messageId: dirName,
              absPath: first.path,
              cachePath: first.path,
              protocol: _inferProtocolFromMessageId(dirName),
              exportStatus: ExportStatus.pending,
            );
          }
          changed++;
        }
        continue;
      }
      await upsert(
        messageId: dirName,
        absPath: first.path,
        cachePath: first.path,
        protocol: _inferProtocolFromMessageId(dirName),
        exportStatus: ExportStatus.pending,
      );
      changed++;
    }
    if (changed > 0) {
      _notifyChanged();
    }
    return changed;
  }

  Future<int> reconcileAfterCacheClear(String cacheRoot) async {
    final normRoot = p.normalize(cacheRoot);
    final rows = await _db.query(_table, where: 'deleted = 0');
    var changed = 0;
    for (final row in rows) {
      final messageId = row['message_id'] as String;
      final cachePath = row['cache_path'] as String?;
      final absPath = row['abs_path'] as String;
      final visiblePath = row['visible_path'] as String?;
      final exportStatus = ReceivedFileRecord._parseExportStatus(
        row['export_status'] as String?,
      );

      final indexedCachePath =
          cachePath != null && cachePath.isNotEmpty ? cachePath : absPath;
      if (!FileStore.isPathUnderDirectory(indexedCachePath, normRoot)) {
        continue;
      }

      final visiblePosix = visiblePath != null &&
          visiblePath.isNotEmpty &&
          !visiblePath.startsWith('content://') &&
          File(visiblePath).existsSync();
      final exported =
          exportStatus == ExportStatus.done && visiblePath?.isNotEmpty == true;

      if (visiblePosix || exported) {
        final nextAbs = visiblePosix
            ? visiblePath
            : FileStore.resolveReadablePath(
                cachePath: null,
                visiblePath: visiblePath,
                absPath: absPath,
              );
        await _db.update(
          _table,
          {
            'cache_path': null,
            'abs_path': nextAbs,
          },
          where: 'message_id = ?',
          whereArgs: [messageId],
        );
      } else {
        await markDeleted(messageId);
      }
      changed++;
    }
    if (changed > 0) {
      _notifyChanged();
    }
    return changed;
  }

  /// Removes cache staging files for [threadKey] only. Visible export paths are never deleted.
  Future<int> clearCacheForThread(String threadKey) async {
    if (threadKey.isEmpty) return 0;
    final cacheRoot = p.normalize(await FileStore.getCacheDir());
    final receiveDir = await FileStore.getReceiveDir();
    final rows = await _db.query(
      _table,
      where: 'deleted = 0 AND thread_key = ?',
      whereArgs: [threadKey],
    );
    var changed = 0;
    for (final row in rows) {
      final messageId = row['message_id'] as String;
      final cachePath = row['cache_path'] as String?;
      final absPath = row['abs_path'] as String;
      final visiblePath = row['visible_path'] as String?;
      final exportStatus = ReceivedFileRecord._parseExportStatus(
        row['export_status'] as String?,
      );
      final fileName = row['file_name'] as String;
      final size = row['size'] as int?;

      final indexedCachePath =
          cachePath != null && cachePath.isNotEmpty ? cachePath : absPath;
      final hasCacheUnderRoot = FileStore.isPathUnderDirectory(
        indexedCachePath,
        cacheRoot,
      );
      if (hasCacheUnderRoot) {
        await FileStore.deleteByMessageId(messageId);
      }

      if (size != null && size > 0) {
        final localId = _senderLocalIdFromRecvMessageId(messageId);
        if (localId != null) {
          try {
            final fileId = makeFileId(fileName, size, localId: localId);
            final partialFile = File('$receiveDir/.lan_partial_$fileId');
            if (await partialFile.exists()) {
              await partialFile.delete();
            }
          } catch (_) {}
        }
      }

      final visiblePosix = visiblePath != null &&
          visiblePath.isNotEmpty &&
          !visiblePath.startsWith('content://') &&
          File(visiblePath).existsSync();
      final exported =
          exportStatus == ExportStatus.done && visiblePath?.isNotEmpty == true;

      if (visiblePosix || exported) {
        final nextAbs = visiblePosix
            ? visiblePath
            : FileStore.resolveReadablePath(
                cachePath: null,
                visiblePath: visiblePath,
                absPath: absPath,
              );
        await _db.update(
          _table,
          {
            'cache_path': null,
            'abs_path': nextAbs,
          },
          where: 'message_id = ?',
          whereArgs: [messageId],
        );
      } else if (hasCacheUnderRoot) {
        await markDeleted(messageId);
      }
      changed++;
    }
    return changed;
  }

  String? _senderLocalIdFromRecvMessageId(String messageId) {
    const prefixes = ['lan_recv_pull_', 'lan_recv_'];
    for (final prefix in prefixes) {
      if (messageId.startsWith(prefix)) {
        final id = messageId.substring(prefix.length);
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  String _escapeLike(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  String? _inferProtocolFromMessageId(String id) =>
      inferProtocolFromMessageId(id);
}

String inferProtocolFromMessageId(String id) {
  if (id.startsWith('lan_recv_pull_')) return 'lan';
  if (id.startsWith('lan_recv_')) return 'lan';
  if (id.startsWith('webrtc_recv_')) return 'webrtc';
  if (id.startsWith('share_')) return 'share';
  return 's3';
}
