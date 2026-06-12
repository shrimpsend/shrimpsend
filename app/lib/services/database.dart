import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

import 'transfer_record.dart';
import '../chat/thread_key.dart';

const _dbVersion = 7;

const _createTransferRecords = '''
CREATE TABLE transfer_records (
  transfer_id   TEXT PRIMARY KEY,
  file_name     TEXT NOT NULL,
  file_size     INTEGER NOT NULL,
  file_path     TEXT,
  channel       TEXT NOT NULL,
  direction     TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'in_progress',
  transferred_bytes INTEGER NOT NULL DEFAULT 0,
  file_hash     TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  s3_upload_id  TEXT,
  s3_key        TEXT,
  s3_completed_parts TEXT,
  lan_target_url TEXT,
  lan_resume_offset INTEGER,
  lan_target_device_ids TEXT,
  webrtc_file_id TEXT,
  webrtc_offset  INTEGER,
  webrtc_target_device_id TEXT
);

CREATE INDEX idx_transfer_status ON transfer_records(status);
CREATE INDEX idx_transfer_channel ON transfer_records(channel);
''';

const _createChatMessages = '''
CREATE TABLE chat_messages (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  type          TEXT NOT NULL,
  payload       TEXT NOT NULL,
  from_device_id TEXT NOT NULL,
  ts            INTEGER NOT NULL,
  synced        INTEGER NOT NULL DEFAULT 1,
  status        TEXT,
  thread_key    TEXT
);

CREATE INDEX idx_msg_ts ON chat_messages(ts);
CREATE INDEX idx_msg_device ON chat_messages(from_device_id);
CREATE INDEX idx_msg_user_ts ON chat_messages(user_id, ts);
CREATE INDEX idx_msg_user_thread_ts ON chat_messages(user_id, thread_key, ts);
''';

/// Persistent index of files saved into the receive directory. Replaces the
/// previous "scan disk on demand" approach so that the file manager and chat
/// bubbles can resolve files in O(1) regardless of total file count.
const _createReceivedFiles = '''
CREATE TABLE received_files (
  message_id     TEXT PRIMARY KEY,
  user_id        TEXT,
  thread_key     TEXT,
  dir_name       TEXT NOT NULL,
  file_name      TEXT NOT NULL,
  abs_path       TEXT NOT NULL,
  protocol       TEXT,
  category       TEXT,
  size           INTEGER NOT NULL DEFAULT 0,
  mtime          INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL DEFAULT 0,
  s3_key         TEXT,
  from_device_id TEXT,
  deleted        INTEGER NOT NULL DEFAULT 0,
  cache_path     TEXT,
  visible_path   TEXT,
  export_status  TEXT,
  export_target  TEXT,
  gallery_saved  INTEGER NOT NULL DEFAULT 0,
  export_error   TEXT,
  exported_at    INTEGER
);

CREATE INDEX idx_recv_user_mtime ON received_files(user_id, mtime DESC);
CREATE INDEX idx_recv_thread_mtime ON received_files(thread_key, mtime DESC);
CREATE INDEX idx_recv_category_mtime ON received_files(category, mtime DESC);
CREATE INDEX idx_recv_mtime ON received_files(mtime DESC);
''';

/// Application SQLite database. Singleton; must be initialized in main() before use.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError(
        'AppDatabase not initialized. Call AppDatabase.instance.open() first.',
      );
    }
    return d;
  }

  bool get isOpen => _db != null;

  Future<void> open() async {
    if (_db != null) return;
    // Windows / Linux / macOS 桌面端无 sqflite 原生插件，需通过 FFI 使用 sqlite3。
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await _resolveDatabasePath();
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _migrateTransferRecordsFromPrefs();
  }

  /// iOS and desktop keep SQLite in Application Support so it is not user-visible
  /// (iOS Files app / desktop Documents folder).
  static bool get _usesApplicationSupportDatabase =>
      Platform.isIOS ||
      Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS;

  Future<String> _resolveDatabasePath() async {
    if (_usesApplicationSupportDatabase) {
      final supportDir = await getApplicationSupportDirectory();
      await Directory(supportDir.path).create(recursive: true);
      final dbPath = join(supportDir.path, 'ultrasend.db');
      await _migrateDatabaseFromDocuments(dbPath);
      return dbPath;
    }
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'ultrasend.db');
  }

  Future<void> _migrateDatabaseFromDocuments(String newPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final oldPath = join(docsDir.path, 'ultrasend.db');
    final oldFile = File(oldPath);
    if (!await oldFile.exists() || await File(newPath).exists()) return;

    await oldFile.rename(newPath);
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('$oldPath$suffix');
      if (await sidecar.exists()) {
        await sidecar.rename('$newPath$suffix');
      }
    }
  }

  static const _prefsKeyTransferRecords = 'transfer_records';

  Future<void> _migrateTransferRecordsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKeyTransferRecords);
    if (raw == null || raw.isEmpty) return;
    final db = _db!;
    int migrated = 0;
    for (final s in raw) {
      try {
        final record = TransferRecord.fromJsonString(s);
        await db.insert(
          'transfer_records',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        migrated++;
      } catch (_) {
        // skip malformed entries
      }
    }
    if (migrated > 0) {
      await prefs.remove(_prefsKeyTransferRecords);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createTransferRecords);
    await db.execute(_createChatMessages);
    await db.execute(_createReceivedFiles);
  }

  Future<bool> _tableHasColumn(
    Database db,
    String table,
    String column,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in info) {
      if (row['name'] == column) return true;
    }
    return false;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE transfer_records ADD COLUMN webrtc_target_device_id TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN status TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE chat_messages ADD COLUMN user_id TEXT NOT NULL DEFAULT \'\'',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_msg_user_ts ON chat_messages(user_id, ts)',
      );
    }
    if (oldVersion < 5) {
      if (!await _tableHasColumn(db, 'chat_messages', 'thread_key')) {
        await db.execute(
          'ALTER TABLE chat_messages ADD COLUMN thread_key TEXT',
        );
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_msg_user_thread_ts ON chat_messages(user_id, thread_key, ts)',
      );
      final rows = await db.query(
        'chat_messages',
        columns: ['id', 'user_id'],
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final uid = row['user_id'] as String? ?? '';
        final account = RegExp(r'^\d+$').hasMatch(uid)
            ? accountPartLoggedIn(uid)
            : accountPartOffline(uid);
        final tk = threadKeyLegacyBroadcast(account);
        await db.update(
          'chat_messages',
          {'thread_key': tk},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    if (oldVersion < 6) {
      // received_files index — pure additive table, no data migration.
      await db.execute('''
CREATE TABLE IF NOT EXISTS received_files (
  message_id     TEXT PRIMARY KEY,
  user_id        TEXT,
  thread_key     TEXT,
  dir_name       TEXT NOT NULL,
  file_name      TEXT NOT NULL,
  abs_path       TEXT NOT NULL,
  protocol       TEXT,
  category       TEXT,
  size           INTEGER NOT NULL DEFAULT 0,
  mtime          INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL DEFAULT 0,
  s3_key         TEXT,
  from_device_id TEXT,
  deleted        INTEGER NOT NULL DEFAULT 0
)
''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recv_user_mtime ON received_files(user_id, mtime DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recv_thread_mtime ON received_files(thread_key, mtime DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recv_category_mtime ON received_files(category, mtime DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recv_mtime ON received_files(mtime DESC)',
      );
    }
    if (oldVersion < 7) {
      for (final col in [
        'cache_path TEXT',
        'visible_path TEXT',
        'export_status TEXT',
        'export_target TEXT',
        'gallery_saved INTEGER NOT NULL DEFAULT 0',
        'export_error TEXT',
        'exported_at INTEGER',
      ]) {
        final name = col.split(' ').first;
        if (!await _tableHasColumn(db, 'received_files', name)) {
          await db.execute('ALTER TABLE received_files ADD COLUMN $col');
        }
      }
      await db.execute('''
UPDATE received_files
SET cache_path = abs_path,
    export_status = 'legacy'
WHERE cache_path IS NULL OR cache_path = ''
''');
    }
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    await d?.close();
  }
}
