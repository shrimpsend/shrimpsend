import 'dart:io';

import 'package:app/services/received_file_dao.dart';
import 'package:app/services/visible_export_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReceivedFileDao.reconcileWithRoot', () {
    late Database db;
    late Directory cacheRoot;
    late Directory visibleRoot;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute(_createReceivedFiles);
        },
      );
      ReceivedFileDao.testDatabase = db;

      cacheRoot = await Directory.systemTemp.createTemp('reconcile_cache_');
      visibleRoot = await Directory.systemTemp.createTemp('reconcile_visible_');
    });

    tearDown(() async {
      ReceivedFileDao.testDatabase = null;
      await db.close();
      if (await cacheRoot.exists()) {
        await cacheRoot.delete(recursive: true);
      }
      if (await visibleRoot.exists()) {
        await visibleRoot.delete(recursive: true);
      }
    });

    test('preserves done export_status when cache file path differs from abs_path',
        () async {
      const messageId = 'lan_recv_reconcile_test';
      final cacheDir = Directory(p.join(cacheRoot.path, messageId));
      await cacheDir.create(recursive: true);
      final cacheFile = File(p.join(cacheDir.path, 'photo.jpg'));
      await cacheFile.writeAsBytes([1, 2, 3, 4]);

      final visibleFile = File(p.join(visibleRoot.path, 'photo.jpg'));
      await visibleFile.writeAsBytes([1, 2, 3, 4]);

      await ReceivedFileDao.instance.upsert(
        messageId: messageId,
        absPath: cacheFile.path,
        cachePath: cacheFile.path,
        protocol: 'lan',
        exportStatus: ExportStatus.pending,
      );
      await ReceivedFileDao.instance.updateExportState(
        messageId: messageId,
        exportStatus: ExportStatus.done,
        visiblePath: visibleFile.path,
        absPath: visibleFile.path,
        clearCachePath: true,
      );

      await ReceivedFileDao.instance.reconcileWithRoot(cacheRoot.path);

      final record =
          await ReceivedFileDao.instance.getByMessageId(messageId);
      expect(record, isNotNull);
      expect(record!.exportStatus, ExportStatus.done);
      expect(record.visiblePath, visibleFile.path);
      expect(record.cachePath, cacheFile.path);
      expect(record.absPath, cacheFile.path);
    });

    test('resets pending export_status when cache path changes for unexported row',
        () async {
      const messageId = 's3_recv_reconcile_pending';
      final cacheDir = Directory(p.join(cacheRoot.path, messageId));
      await cacheDir.create(recursive: true);
      final cacheFile = File(p.join(cacheDir.path, 'doc.pdf'));
      await cacheFile.writeAsBytes([5, 6, 7]);

      await ReceivedFileDao.instance.upsert(
        messageId: messageId,
        absPath: p.join(cacheRoot.path, 'stale', 'doc.pdf'),
        cachePath: p.join(cacheRoot.path, 'stale', 'doc.pdf'),
        protocol: 's3',
        exportStatus: ExportStatus.pending,
      );

      await ReceivedFileDao.instance.reconcileWithRoot(cacheRoot.path);

      final record =
          await ReceivedFileDao.instance.getByMessageId(messageId);
      expect(record, isNotNull);
      expect(record!.exportStatus, ExportStatus.pending);
      expect(record.cachePath, cacheFile.path);
      expect(record.absPath, cacheFile.path);
    });
  });

  group('ReceivedFileDao.rekeyMessageId', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute(_createReceivedFiles);
        },
      );
      ReceivedFileDao.testDatabase = db;
    });

    tearDown(() async {
      ReceivedFileDao.testDatabase = null;
      await db.close();
    });

    test('preserves export fields when re-keying to server message id', () async {
      const oldId = 'lan_recv_local';
      const newId = '1781146674038_android_abc';
      const visiblePath = '/storage/Downloads/photo.jpg';

      await ReceivedFileDao.instance.upsert(
        messageId: oldId,
        absPath: '/cache/photo.jpg',
        cachePath: '/cache/photo.jpg',
        protocol: 'lan',
        exportStatus: ExportStatus.done,
      );
      await ReceivedFileDao.instance.updateExportState(
        messageId: oldId,
        exportStatus: ExportStatus.done,
        visiblePath: visiblePath,
        exportTarget: ExportTargetKind.downloads,
        gallerySaved: false,
        absPath: visiblePath,
        clearCachePath: true,
      );

      final ok = await ReceivedFileDao.instance.rekeyMessageId(
        oldMessageId: oldId,
        newMessageId: newId,
        userId: '1',
        threadKey: 'u:1',
        fromDeviceId: 'android_device',
      );
      expect(ok, isTrue);

      expect(await ReceivedFileDao.instance.getByMessageId(oldId), isNull);
      final record = await ReceivedFileDao.instance.getByMessageId(newId);
      expect(record, isNotNull);
      expect(record!.exportStatus, ExportStatus.done);
      expect(record.visiblePath, visiblePath);
      expect(record.exportTarget, ExportTargetKind.downloads);
      expect(record.userId, '1');
      expect(record.threadKey, 'u:1');
      expect(record.fromDeviceId, 'android_device');
    });
  });
}
