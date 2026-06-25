import 'dart:io';

import 'package:app/models/pending_file_entry.dart';
import 'package:app/providers/pending_files_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/tmp/shrimpsend_test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingFilesNotifier dispatch rollback', () {
    late Directory tempDir;
    late ProviderContainer container;
    late PendingFilesNotifier notifier;

    setUp(() async {
      PathProviderPlatform.instance = _FakePathProviderPlatform();
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('pending_dispatch_test_');
      container = ProviderContainer();
      notifier = container.read(pendingFilesProvider.notifier);
    });

    tearDown(() async {
      container.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    PendingFileEntry _entry(String name) {
      final file = File('${tempDir.path}/$name')..writeAsStringSync('data');
      return PendingFileEntry.fromPlatformFile(
        PlatformFile(name: name, path: file.path, size: 4),
      );
    }

    test('prepareDispatch does not clear outbox', () async {
      final entry = _entry('a.txt');
      await notifier.add([entry]);
      expect(container.read(pendingFilesProvider).length, 1);

      final prep = await notifier.prepareDispatch([entry]);
      expect(prep.queued.length, 1);
      expect(container.read(pendingFilesProvider).length, 1);
    });

    test('rollbackHeldDispatch restores committed entries', () async {
      final entry = _entry('b.txt');
      await notifier.add([entry]);

      final prep = await notifier.prepareDispatch([entry]);
      await notifier.commitDispatch(prep.queued);
      expect(container.read(pendingFilesProvider), isEmpty);

      notifier.rollbackHeldDispatch([entry.file.path!]);
      expect(container.read(pendingFilesProvider).length, 1);
      expect(container.read(pendingFilesProvider).single.file.name, 'b.txt');
    });

    test('restoreHeldDispatch restores multiple committed entries', () async {
      final a = _entry('e1.txt');
      final b = _entry('e2.txt');
      await notifier.add([a, b]);

      final prep = await notifier.prepareDispatch([a, b]);
      await notifier.commitDispatch(prep.queued);
      expect(container.read(pendingFilesProvider), isEmpty);

      notifier.restoreHeldDispatch([
        a.file.path!,
        b.file.path!,
      ]);
      expect(container.read(pendingFilesProvider).length, 2);
    });

    test('commitDispatch without prepareDispatch clears outbox', () async {
      final entry = _entry('d.txt');
      await notifier.add([entry]);

      final committed = await notifier.commitDispatch([entry]);
      expect(committed.queued.length, 1);
      expect(container.read(pendingFilesProvider), isEmpty);
    });

    test('beginDispatch still prepares then commits', () async {
      final entry = _entry('c.txt');
      await notifier.add([entry]);

      final dispatch = await notifier.beginDispatch([entry]);
      expect(dispatch.queued.length, 1);
      expect(container.read(pendingFilesProvider), isEmpty);
    });
  });
}
