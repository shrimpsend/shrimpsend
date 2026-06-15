import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../chat/thread_key.dart';
import 'database.dart';

const _table = 'chat_messages';

/// One row from chat_messages table. [payload] is decoded from JSON.
class LocalChatMessage {
  final String id;
  final String type;
  final dynamic payload;
  final String fromDeviceId;
  final int ts;
  final bool synced;
  final String? status;
  final String? threadKey;

  LocalChatMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.fromDeviceId,
    required this.ts,
    this.synced = true,
    this.status,
    this.threadKey,
  });

  static LocalChatMessage fromRow(Map<String, dynamic> row) {
    dynamic payload = row['payload'];
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {}
    }
    return LocalChatMessage(
      id: row['id'] as String,
      type: row['type'] as String,
      payload: payload,
      fromDeviceId: row['from_device_id'] as String,
      ts: row['ts'] as int,
      synced: (row['synced'] as int?) == 1,
      status: row['status'] as String?,
      threadKey: row['thread_key'] as String?,
    );
  }
}

/// Data access for chat_messages table (local cache of message history).
class ChatMessageDao {
  ChatMessageDao._();
  static final instance = ChatMessageDao._();

  Database get _db => AppDatabase.instance.db;

  Future<void> insertMessage({
    required String userId,
    required String id,
    required String type,
    required dynamic payload,
    required String fromDeviceId,
    required int ts,
    required String threadKey,
    bool synced = true,
    String? status,
  }) async {
    final payloadJson = payload is String ? payload : jsonEncode(payload);
    await _db.insert(_table, {
      'id': id,
      'user_id': userId,
      'type': type,
      'payload': payloadJson,
      'from_device_id': fromDeviceId,
      'ts': ts,
      'synced': synced ? 1 : 0,
      'status': status,
      'thread_key': threadKey,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(String id, String status) async {
    await _db.update(
      _table,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Rewrite an existing row's `type`/`payload`/`status` while keeping its
  /// `user_id`, `thread_key`, `ts`, `from_device_id`, etc. untouched. Used by
  /// rollback flows (e.g. peer-cancelled reverse-pull) where the sender wants
  /// to demote a previously "completed" file row back to a cancelled text
  /// bubble without losing the conversation linkage.
  Future<void> rewriteMessagePayload({
    required String id,
    required String type,
    required dynamic payload,
    String? status,
  }) async {
    final payloadJson = payload is String ? payload : jsonEncode(payload);
    final values = <String, Object?>{
      'type': type,
      'payload': payloadJson,
      if (status != null) 'status': status,
    };
    await _db.update(
      _table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Messages for [userIds] and [threadKey], with ts < [beforeTs], ordered newest first.
  Future<List<LocalChatMessage>> getMessages({
    required List<String> userIds,
    required String threadKey,
    int limit = 50,
    int? beforeTs,
  }) async {
    if (userIds.isEmpty) return [];
    final orderBy = 'ts DESC, rowid DESC';
    final whereParts = <String>[];
    final whereArgs = <Object>[];
    if (userIds.length == 1) {
      whereParts.add('user_id = ?');
      whereArgs.add(userIds.first);
    } else {
      final placeholders = List.filled(userIds.length, '?').join(', ');
      whereParts.add('user_id IN ($placeholders)');
      whereArgs.addAll(userIds);
    }
    whereParts.add('thread_key = ?');
    whereArgs.add(threadKey);
    if (beforeTs != null) {
      whereParts.add('ts < ?');
      whereArgs.add(beforeTs);
    }
    final rows = await _db.query(
      _table,
      orderBy: orderBy,
      limit: limit,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
    );
    return rows.map((r) => LocalChatMessage.fromRow(r)).toList();
  }

  /// Local-only message search. Cloud search is intentionally avoided so the
  /// server never receives plaintext search keywords.
  Future<List<LocalChatMessage>> searchMessages({
    required List<String> userIds,
    required String query,
    int limit = 50,
    int? beforeTs,
    String? threadKey,
  }) async {
    final q = query.trim();
    if (userIds.isEmpty || q.isEmpty) return [];
    final whereParts = <String>[];
    final whereArgs = <Object>[];
    if (userIds.length == 1) {
      whereParts.add('user_id = ?');
      whereArgs.add(userIds.first);
    } else {
      final placeholders = List.filled(userIds.length, '?').join(', ');
      whereParts.add('user_id IN ($placeholders)');
      whereArgs.addAll(userIds);
    }
    whereParts.add("(type = 'text' OR type = 'file')");
    whereParts.add("payload LIKE ? ESCAPE '\\'");
    whereArgs.add('%${_escapeLike(q)}%');
    if (threadKey != null && threadKey.isNotEmpty) {
      whereParts.add('thread_key = ?');
      whereArgs.add(threadKey);
    }
    if (beforeTs != null) {
      whereParts.add('ts < ?');
      whereArgs.add(beforeTs);
    }
    final rows = await _db.query(
      _table,
      orderBy: 'ts DESC, rowid DESC',
      limit: limit,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
    );
    return rows.map((r) => LocalChatMessage.fromRow(r)).toList();
  }

  /// Most recent incoming text message (type `text`, from a device other than
  /// [selfDeviceId]) for [userIds], across all threads. Used to auto-copy the
  /// latest received text after the app is reopened, including messages that
  /// arrived while the app was exited (e.g. via the back button) and were only
  /// fetched later through history sync.
  Future<LocalChatMessage?> getLatestIncomingText({
    required List<String> userIds,
    required String selfDeviceId,
  }) async {
    if (userIds.isEmpty) return null;
    final whereParts = <String>[];
    final whereArgs = <Object>[];
    if (userIds.length == 1) {
      whereParts.add('user_id = ?');
      whereArgs.add(userIds.first);
    } else {
      final placeholders = List.filled(userIds.length, '?').join(', ');
      whereParts.add('user_id IN ($placeholders)');
      whereArgs.addAll(userIds);
    }
    whereParts.add("type = 'text'");
    whereParts.add('from_device_id != ?');
    whereArgs.add(selfDeviceId);
    final rows = await _db.query(
      _table,
      orderBy: 'ts DESC, rowid DESC',
      limit: 1,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
    );
    if (rows.isEmpty) return null;
    return LocalChatMessage.fromRow(rows.first);
  }

  Future<int?> getLatestTs(String userId, String threadKey) async {
    final rows = await _db.query(
      _table,
      columns: ['ts'],
      orderBy: 'ts DESC',
      limit: 1,
      where: 'user_id = ? AND thread_key = ?',
      whereArgs: [userId, threadKey],
    );
    if (rows.isEmpty) return null;
    return rows.first['ts'] as int?;
  }

  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Future<void> markSynced(String id) async {
    await _db.update(_table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteById(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all local messages for [userIds] and [threadKey].
  Future<int> deleteAllForThread({
    required List<String> userIds,
    required String threadKey,
  }) async {
    if (userIds.isEmpty || threadKey.isEmpty) return 0;
    final whereParts = <String>[];
    final whereArgs = <Object>[];
    if (userIds.length == 1) {
      whereParts.add('user_id = ?');
      whereArgs.add(userIds.first);
    } else {
      final placeholders = List.filled(userIds.length, '?').join(', ');
      whereParts.add('user_id IN ($placeholders)');
      whereArgs.addAll(userIds);
    }
    whereParts.add('thread_key = ?');
    whereArgs.add(threadKey);
    return _db.delete(
      _table,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
    );
  }

  /// Look up a single row by its primary [id]. Returns null if no row exists.
  Future<LocalChatMessage?> getById(String id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalChatMessage.fromRow(rows.first);
  }

  /// Delete messages for [userId] and [threadKey] with ts < [ts] to cap storage.
  Future<int> deleteOlderThan(String userId, String threadKey, int ts) async {
    return _db.delete(
      _table,
      where: 'user_id = ? AND thread_key = ? AND ts < ?',
      whereArgs: [userId, threadKey, ts],
    );
  }

  /// Migrate all messages from [oldUserId] to [newUserId] (offline -> online).
  Future<int> migrateUserId(String oldUserId, String newUserId) async {
    final n = await _db.update(
      _table,
      {'user_id': newUserId},
      where: 'user_id = ?',
      whereArgs: [oldUserId],
    );
    final fromPrefix = accountPartOffline(oldUserId);
    final toPrefix = accountPartLoggedIn(newUserId);
    final rows = await _db.query(
      _table,
      columns: ['id', 'thread_key'],
      where: 'user_id = ?',
      whereArgs: [newUserId],
    );
    for (final row in rows) {
      final tk = row['thread_key'] as String?;
      if (tk == null || !tk.startsWith(fromPrefix)) continue;
      final newTk = toPrefix + tk.substring(fromPrefix.length);
      await _db.update(
        _table,
        {'thread_key': newTk},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return n;
  }
}
