import 'dart:io';

import 'package:app/services/local_received_file_resolver.dart';
import 'package:app/services/received_file_dao.dart';
import 'package:app/services/save_folder_listing_service.dart';
import 'package:app/services/webdav_session.dart';
import 'package:app/services/webdav_transfer_service.dart';
import 'package:app/utils/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

ReceivedFileRecord _record({
  required String messageId,
  required String fileName,
  String? cachePath,
  String? visiblePath,
  String? absPath,
  int size = 10,
}) {
  final path = absPath ?? cachePath ?? visiblePath ?? '/missing/$fileName';
  return ReceivedFileRecord(
    messageId: messageId,
    dirName: 'dir',
    fileName: fileName,
    absPath: path,
    size: size,
    mtime: DateTime.fromMillisecondsSinceEpoch(1),
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
    category: FileCategory.other,
    cachePath: cachePath,
    visiblePath: visiblePath,
  );
}

void main() {
  group('LocalReceivedFileResolver', () {
    late Directory cacheRoot;

    setUp(() async {
      cacheRoot = await Directory.systemTemp.createTemp('local_resolver_');
    });

    tearDown(() {
      if (cacheRoot.existsSync()) {
        cacheRoot.deleteSync(recursive: true);
      }
    });

    test('returns existing cachePath from DAO record', () async {
      final cacheFile = File(p.join(cacheRoot.path, 'cached.bin'));
      cacheFile.writeAsStringSync('data');

      final resolver = LocalReceivedFileResolver(
        getRecord: (messageId) async => _record(
          messageId: messageId,
          fileName: 'cached.bin',
          cachePath: cacheFile.path,
          absPath: cacheFile.path,
        ),
        getCacheDir: () async => cacheRoot.path,
      );

      final path = await resolver.resolveLocalPath(
        messageId: 'msg_cache',
        fileName: 'cached.bin',
      );

      expect(path, cacheFile.path);
    });

    test('falls back to visiblePath when cache is missing', () async {
      final visible = File(p.join(cacheRoot.path, 'visible.bin'));
      visible.writeAsStringSync('data');

      final resolver = LocalReceivedFileResolver(
        getRecord: (messageId) async => _record(
          messageId: messageId,
          fileName: 'visible.bin',
          cachePath: p.join(cacheRoot.path, 'missing.bin'),
          visiblePath: visible.path,
          absPath: visible.path,
        ),
        getCacheDir: () async => cacheRoot.path,
      );

      final path = await resolver.resolveLocalPath(
        messageId: 'msg_visible',
        fileName: 'visible.bin',
      );

      expect(path, visible.path);
    });

    test('scans cache directory when DAO record is absent', () async {
      final messageId = 'msg_scan';
      final dir = Directory(
        p.join(cacheRoot.path, messageId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')),
      );
      dir.createSync(recursive: true);
      final file = File(p.join(dir.path, 'remote.pdf'));
      file.writeAsStringSync('pdf');

      final resolver = LocalReceivedFileResolver(
        getRecord: (_) async => null,
        getCacheDir: () async => cacheRoot.path,
        findByNameAndSize: ({required String fileName, int? size}) async => [],
      );

      final path = await resolver.resolveLocalPath(
        messageId: messageId,
        fileName: 'remote.pdf',
      );

      expect(path, file.path);
    });

    test('falls back to save folder listing by name and size', () async {
      final exported = File(p.join(cacheRoot.path, 'exported.bin'));
      exported.writeAsStringSync('data');

      final resolver = LocalReceivedFileResolver(
        getRecord: (_) async => null,
        getCacheDir: () async => cacheRoot.path,
        findByNameAndSize: ({required String fileName, int? size}) async => [],
        listSaveFolder: () async => SaveFolderListingResult(
          files: [
            SaveFolderFileEntry(
              name: 'exported.bin',
              pathOrUri: exported.path,
              size: 4,
              modified: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
          displayLabel: 'Downloads',
        ),
      );

      final path = await resolver.resolveLocalPath(
        messageId: 'msg_save',
        fileName: 'exported.bin',
        size: 4,
      );

      expect(path, exported.path);
    });

    test('returns null when no local copy exists', () async {
      final resolver = LocalReceivedFileResolver(
        getRecord: (_) async => null,
        getCacheDir: () async => cacheRoot.path,
        findByNameAndSize: ({required String fileName, int? size}) async => [],
        listSaveFolder: () async => const SaveFolderListingResult(
          files: [],
          displayLabel: 'Downloads',
        ),
      );

      final path = await resolver.resolveLocalPath(
        messageId: 'msg_missing',
        fileName: 'missing.bin',
        size: 99,
      );

      expect(path, isNull);
    });

    test('resolveForWebDavEntries maps remote paths for files only', () async {
      final cacheFile = File(p.join(cacheRoot.path, 'a.txt'));
      cacheFile.writeAsStringSync('a');
      final messageId = webDavMessageId(7, 'a.txt');

      final resolver = LocalReceivedFileResolver(
        getRecord: (id) async {
          if (id == messageId) {
            return _record(
              messageId: id,
              fileName: 'a.txt',
              cachePath: cacheFile.path,
              absPath: cacheFile.path,
            );
          }
          return null;
        },
        getCacheDir: () async => cacheRoot.path,
        findByNameAndSize: ({required String fileName, int? size}) async => [],
        listSaveFolder: () async => const SaveFolderListingResult(
          files: [],
          displayLabel: 'Downloads',
        ),
      );

      final map = await resolver.resolveForWebDavEntries(
        connectionId: 7,
        entries: const [
          WebDavEntry(name: 'docs', path: 'docs', isDirectory: true),
          WebDavEntry(name: 'a.txt', path: 'a.txt', isDirectory: false, size: 1),
          WebDavEntry(name: 'b.txt', path: 'b.txt', isDirectory: false, size: 1),
        ],
      );

      expect(map.containsKey('docs'), isFalse);
      expect(map['a.txt'], cacheFile.path);
      expect(map['b.txt'], isNull);
    });
  });
}
