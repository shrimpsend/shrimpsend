import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'webdav_session.dart';

const _table = 'webdav_favorites';

class WebDavFavoriteRecord {
  final String connectionId;
  final String remotePath;
  final String name;
  final bool isDirectory;
  final int? size;
  final DateTime? lastModified;
  final DateTime createdAt;

  const WebDavFavoriteRecord({
    required this.connectionId,
    required this.remotePath,
    required this.name,
    required this.isDirectory,
    this.size,
    this.lastModified,
    required this.createdAt,
  });

  WebDavEntry toEntry() => WebDavEntry(
        name: name,
        path: remotePath,
        isDirectory: isDirectory,
        size: size,
        lastModified: lastModified,
      );

  factory WebDavFavoriteRecord.fromRow(Map<String, dynamic> row) {
    final lm = row['last_modified'] as String?;
    return WebDavFavoriteRecord(
      connectionId: row['connection_id'] as String,
      remotePath: row['remote_path'] as String,
      name: row['name'] as String,
      isDirectory: (row['is_directory'] as int? ?? 0) == 1,
      size: row['size'] as int?,
      lastModified: lm != null && lm.isNotEmpty ? DateTime.tryParse(lm) : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class WebDavFavoriteDao {
  WebDavFavoriteDao._();
  static final instance = WebDavFavoriteDao._();

  Database get _db => AppDatabase.instance.db;

  Future<void> upsert({
    required String connectionId,
    required WebDavEntry entry,
  }) async {
    await _db.insert(
      _table,
      {
        'connection_id': connectionId,
        'remote_path': entry.path,
        'name': entry.name,
        'is_directory': entry.isDirectory ? 1 : 0,
        'size': entry.size,
        'last_modified': entry.lastModified?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove({
    required String connectionId,
    required String remotePath,
  }) async {
    await removeByPath(connectionId: connectionId, remotePath: remotePath);
  }

  Future<void> removeByPath({
    required String connectionId,
    required String remotePath,
  }) async {
    await _db.delete(
      _table,
      where: 'connection_id = ? AND remote_path = ?',
      whereArgs: [connectionId, remotePath],
    );
  }

  Future<void> updatePath({
    required String connectionId,
    required String oldPath,
    required WebDavEntry entry,
  }) async {
    final rows = await _db.query(
      _table,
      where: 'connection_id = ? AND remote_path = ?',
      whereArgs: [connectionId, oldPath],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await _db.update(
      _table,
      {
        'remote_path': entry.path,
        'name': entry.name,
        'is_directory': entry.isDirectory ? 1 : 0,
        'size': entry.size,
        'last_modified': entry.lastModified?.toIso8601String(),
      },
      where: 'connection_id = ? AND remote_path = ?',
      whereArgs: [connectionId, oldPath],
    );
  }

  Future<bool> isFavorite({
    required String connectionId,
    required String remotePath,
  }) async {
    final rows = await _db.query(
      _table,
      columns: ['remote_path'],
      where: 'connection_id = ? AND remote_path = ?',
      whereArgs: [connectionId, remotePath],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<WebDavFavoriteRecord>> listForConnection(
    String connectionId,
  ) async {
    final rows = await _db.query(
      _table,
      where: 'connection_id = ?',
      whereArgs: [connectionId],
      orderBy: 'created_at DESC',
    );
    return rows.map(WebDavFavoriteRecord.fromRow).toList();
  }
}
