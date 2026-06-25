import 'package:app/models/pending_file_entry.dart';
import 'package:app/services/pending_files_store.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/tmp/shrimpsend_test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingFilesStore relativeSubPath', () {
    setUp(() {
      PathProviderPlatform.instance = _FakePathProviderPlatform();
    });

    test('round-trips relativeSubPath in memory model', () {
      final entry = PendingFileEntry.fromPlatformFile(
        PlatformFile(name: 'c.txt', path: '/tmp/c.txt', size: 3),
        relativeSubPath: 'a/b/c.txt',
      );
      expect(entry.relativeSubPath, 'a/b/c.txt');
      expect(entry.file.name, 'c.txt');
    });
  });
}
