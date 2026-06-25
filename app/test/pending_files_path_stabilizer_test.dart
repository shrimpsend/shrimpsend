import 'dart:io';
import 'dart:typed_data';

import 'package:app/services/file_store.dart';
import 'package:app/services/pending_files_path_stabilizer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempRoot);

  final Directory tempRoot;

  @override
  Future<String?> getTemporaryPath() async => tempRoot.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingFilesPathStabilizer', () {
    late Directory tempRoot;
    late Directory externalDir;
    late Directory cacheRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('pending_stabilizer_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempRoot);
      FileStore.invalidateReceiveDirCache();

      externalDir = Directory(p.join(tempRoot.path, 'external'));
      cacheRoot = Directory(p.join(tempRoot.path, 'shrimpsend'));
      await externalDir.create(recursive: true);
      await cacheRoot.create(recursive: true);
    });

    tearDown(() async {
      FileStore.invalidateReceiveDirCache();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('reuses external local path without copying to cache', () async {
      final source = File(p.join(externalDir.path, 'doc.txt'));
      await source.writeAsBytes([1, 2, 3, 4]);

      final pendingDirsBefore = cacheRoot
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('pending_'))
          .length;

      final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
        PlatformFile(name: 'doc.txt', path: source.path, size: 4),
        logSource: 'test',
      );

      expect(stabilized, isNotNull);
      expect(stabilized!.path, source.path);
      expect(stabilized.size, 4);

      final pendingDirsAfter = cacheRoot
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('pending_'))
          .length;
      expect(pendingDirsAfter, pendingDirsBefore);
    });

    test('reuses path already under app cache', () async {
      final pendingDir = Directory(p.join(cacheRoot.path, 'pending_uuid'));
      await pendingDir.create(recursive: true);
      final cached = File(p.join(pendingDir.path, 'cached.bin'));
      await cached.writeAsBytes([9, 8, 7]);

      expect(
        FileStore.isPathUnderDirectory(cached.path, cacheRoot.path),
        isTrue,
      );

      final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
        PlatformFile(name: 'cached.bin', path: cached.path, size: 3),
        logSource: 'test',
      );

      expect(stabilized, isNotNull);
      expect(stabilized!.path, cached.path);
      expect(stabilized.size, 3);
    });

    test('deletePendingCacheFile does not remove external paths', () async {
      final outside = File(p.join(externalDir.path, 'keep.me'));
      await outside.writeAsBytes([5, 6]);

      await PendingFilesPathStabilizer.deletePendingCacheFile(outside.path);

      expect(await outside.exists(), isTrue);
      expect(
        PendingFilesPathStabilizer.isPendingCachePath(outside.path, cacheRoot.path),
        isFalse,
      );
    });

    test('deletePendingCacheFile removes pending cache staging files', () async {
      final pendingDir = Directory(p.join(cacheRoot.path, 'pending_remove'));
      await pendingDir.create(recursive: true);
      final staging = File(p.join(pendingDir.path, 'staging.bin'));
      await staging.writeAsBytes([1]);

      expect(
        PendingFilesPathStabilizer.isPendingCachePath(staging.path, cacheRoot.path),
        isTrue,
      );

      await PendingFilesPathStabilizer.deletePendingCacheFile(staging.path);

      expect(await staging.exists(), isFalse);
    });

    test('writes bytes-only input into cache', () async {
      final bytes = Uint8List.fromList([10, 11, 12]);

      final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
        PlatformFile(name: 'from_bytes.bin', size: bytes.length, bytes: bytes),
        logSource: 'test',
      );

      expect(stabilized, isNotNull);
      expect(stabilized!.path, isNotNull);
      final dest = File(stabilized.path!);
      expect(await dest.exists(), isTrue);
      expect(await dest.readAsBytes(), bytes);
      expect(
        PendingFilesPathStabilizer.isPendingCachePath(
          stabilized.path!,
          cacheRoot.path,
        ),
        isTrue,
      );

      addTearDown(() async {
        await PendingFilesPathStabilizer.deletePendingCacheFile(stabilized.path);
      });
    });

    test('stabilizeAll preserves order and skips missing files', () async {
      final a = File(p.join(externalDir.path, 'a.txt'));
      await a.writeAsBytes([1]);
      final missingPath = p.join(externalDir.path, 'missing.txt');

      final result = await PendingFilesPathStabilizer.stabilizeAll(
        [
          PlatformFile(name: 'a.txt', path: a.path, size: 1),
          PlatformFile(name: 'missing.txt', path: missingPath, size: 0),
        ],
        logSource: 'test',
      );

      expect(result.length, 1);
      expect(result.first.path, a.path);
    });
  });
}
