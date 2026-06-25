import 'dart:io';

import 'package:app/services/webdav_upload_local_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveUploadLocalFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('webdav_upload_resolver_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns null for empty path', () async {
      expect(
        await resolveUploadLocalFile(
          localPath: null,
          fileName: 'a.txt',
          cachedSize: 1,
        ),
        isNull,
      );
    });

    test('returns file with refreshed size for existing local path', () async {
      final file = File('${tempDir.path}/hello.txt')..writeAsStringSync('abcd');
      final resolved = await resolveUploadLocalFile(
        localPath: file.path,
        fileName: 'hello.txt',
        cachedSize: 0,
      );
      expect(resolved, isNotNull);
      expect(resolved!.path, file.path);
      expect(resolved.fileName, 'hello.txt');
      expect(resolved.size, 4);
    });

    test('returns null when file missing', () async {
      final resolved = await resolveUploadLocalFile(
        localPath: '${tempDir.path}/missing.txt',
        fileName: 'missing.txt',
        cachedSize: 1,
      );
      expect(resolved, isNull);
    });

    test('returns null for zero-byte file', () async {
      final file = File('${tempDir.path}/empty.txt')..createSync();
      final resolved = await resolveUploadLocalFile(
        localPath: file.path,
        fileName: 'empty.txt',
        cachedSize: 0,
      );
      expect(resolved, isNull);
    });
  });
}
