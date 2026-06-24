import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'webdav_session.dart';

const _table = 'webdav_recent';
const _maxPerConnection = 100;

class WebDavRecentRecord {
  final int id;
  final String connectionId;
  final String remotePath;
  final String name;
  final bool isDirectory;
  final DateTime accessedAt;

  const WebDavRecentRecord({
    required this.id,
    required this.connectionId,
    required this.remotePath,
    required this.name,
    required this.isDirectory,
    required this.accessedAt,
  });

  WebDavEntry toEntry() => WebDavEntry(
        name: name,
        path: remotePath,
        isDirectory: isDirectory,
      );

  factory WebDavRecentRecord.fromRow(Map<String, dynamic> row) {
    return WebDavRecentRecord(
      id: row['id'] as int,
      connectionId: row['connection_id'] as String,
      remotePath: row['remote_path'] as String,
      name: row['name'] as String,
      isDirectory: (row['is_directory'] as int? ?? 0) == 1,
      accessedAt: DateTime.parse(row['accessed_at'] as String),
    );
  }
}

class WebDavRecentDao {
  WebDavRecentDao._();
  static final instance = WebDavRecentDao._();

  Database get _db => AppDatabase.instance.db;

  Future<void> recordAccess({
    required String connectionId,
    required WebDavEntry entry,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      final existing = await txn.query(
        _table,
        where: 'connection_id = ? AND remote_path = ?',
        whereArgs: [connectionId, entry.path],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.update(
          _table,
          {
            'name': entry.name,
            'is_directory': entry.isDirectory ? 1 : 0,
            'accessed_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert(_table, {
          'connection_id': connectionId,
          'remote_path': entry.path,
          'name': entry.name,
          'is_directory': entry.isDirectory ? 1 : 0,
          'accessed_at': now,
        });
      }
      await txn.rawDelete(
        '''
DELETE FROM $_table
WHERE connection_id = ?
  AND id NOT IN (
    SELECT id FROM $_table
    WHERE connection_id = ?
    ORDER BY accessed_at DESC
    LIMIT ?
  )
''',
        [connectionId, connectionId, _maxPerConnection],
      );
    });
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
    await _db.update(
      _table,
      {
        'remote_path': entry.path,
        'name': entry.name,
        'is_directory': entry.isDirectory ? 1 : 0,
      },
      where: 'connection_id = ? AND remote_path = ?',
      whereArgs: [connectionId, oldPath],
    );
  }

  Future<List<WebDavRecentRecord>> listForConnection(
    String connectionId,
  ) async {
    final rows = await _db.query(
      _table,
      where: 'connection_id = ?',
      whereArgs: [connectionId],
      orderBy: 'accessed_at DESC',
      limit: _maxPerConnection,
    );
    return rows.map(WebDavRecentRecord.fromRow).toList();
  }
}
