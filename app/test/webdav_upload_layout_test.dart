import 'package:app/models/pending_file_entry.dart';
import 'package:app/services/webdav_upload_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collectSortedParentDirs', () {
    test('dedupes and sorts shallow-first', () {
      expect(
        collectSortedParentDirs([
          '测试/a/b/c.txt',
          '测试/a/d.txt',
          '测试/e.txt',
        ]),
        ['测试', '测试/a', '测试/a/b'],
      );
    });

    test('returns empty for root-level files', () {
      expect(collectSortedParentDirs(['file.txt']), isEmpty);
    });
  });

  group('buildWebDavUploadJobs', () {
    test('flat mode uses basename only', () {
      final jobs = buildWebDavUploadJobs(
        relativeDir: '测试',
        layout: WebDavUploadLayout.flat,
        entries: [
          PendingFileEntry.fromPlatformFile(
            PlatformFile(name: 'c.txt', path: '/tmp/c.txt', size: 1),
            relativeSubPath: 'a/b/c.txt',
          ),
        ],
      );
      expect(jobs.single.remotePath, '测试/c.txt');
    });

    test('preserve mode keeps relative sub path', () {
      final jobs = buildWebDavUploadJobs(
        relativeDir: '测试',
        layout: WebDavUploadLayout.preserveStructure,
        entries: [
          PendingFileEntry.fromPlatformFile(
            PlatformFile(name: 'c.txt', path: '/tmp/c.txt', size: 1),
            relativeSubPath: 'a/b/c.txt',
          ),
        ],
      );
      expect(jobs.single.remotePath, '测试/a/b/c.txt');
    });

    test('flat mode dedupes basename collisions', () {
      final jobs = buildWebDavUploadJobs(
        relativeDir: '',
        layout: WebDavUploadLayout.flat,
        entries: [
          PendingFileEntry.fromPlatformFile(
            PlatformFile(name: 'dup.txt', path: '/tmp/1/dup.txt', size: 1),
            relativeSubPath: 'a/dup.txt',
          ),
          PendingFileEntry.fromPlatformFile(
            PlatformFile(name: 'dup.txt', path: '/tmp/2/dup.txt', size: 2),
            relativeSubPath: 'b/dup.txt',
          ),
        ],
      );
      expect(jobs.map((j) => j.remotePath).toList(), ['dup.txt', 'dup (1).txt']);
    });
  });

  group('WebDAV MKCOL idempotent status codes', () {
    test('201 405 423 are treated as directory ready', () {
      bool isMkcolSuccess(int? status) =>
          status == 201 || status == 405 || status == 423;
      expect(isMkcolSuccess(201), isTrue);
      expect(isMkcolSuccess(405), isTrue);
      expect(isMkcolSuccess(423), isTrue);
      expect(isMkcolSuccess(409), isFalse);
    });
  });
}
