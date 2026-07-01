import 'dart:io';

import 'package:app/services/shared_preferences_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportDir);

  final String supportDir;

  @override
  Future<String?> getApplicationSupportPath() async => supportDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isSharedPreferencesCorruptionError', () {
    test('detects FormatException', () {
      expect(
        isSharedPreferencesCorruptionError(
          const FormatException('Unexpected character'),
        ),
        isTrue,
      );
    });

    test('detects wrapped FormatException message', () {
      expect(
        isSharedPreferencesCorruptionError(
          StateError(
            'FormatException: Unexpected character (at character 1)',
          ),
        ),
        isTrue,
      );
    });

    test('ignores unrelated errors', () {
      expect(
        isSharedPreferencesCorruptionError(StateError('network down')),
        isFalse,
      );
    });
  });

  group('bootFailureRecoveryHint', () {
    test('returns hint for corruption errors', () {
      final hint = bootFailureRecoveryHint(
        const FormatException('Unexpected character'),
      );
      expect(hint, isNotNull);
      expect(hint, contains('shared_preferences.json'));
      expect(hint, contains('重新登录'));
    });

    test('returns null for unrelated errors', () {
      expect(
        bootFailureRecoveryHint(StateError('boom')),
        isNull,
      );
    });
  });

  group('backupCorruptedPrefsFileAt', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('prefs_bootstrap_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('renames corrupt file and leaves original path absent', () async {
      final prefsPath = p.join(tempDir.path, sharedPreferencesFileName);
      await File(prefsPath).writeAsBytes(List<int>.filled(64, 0));

      final backupPath = await backupCorruptedPrefsFileAt(prefsPath);

      expect(backupPath, isNotNull);
      expect(await File(prefsPath).exists(), isFalse);
      expect(await File(backupPath!).exists(), isTrue);
      expect(await File(backupPath).readAsBytes(), hasLength(64));
    });

    test('returns null when file is missing', () async {
      final prefsPath = p.join(tempDir.path, sharedPreferencesFileName);
      expect(await backupCorruptedPrefsFileAt(prefsPath), isNull);
    });
  });

  group('ensureSharedPreferencesReady', () {
    tearDown(() {
      SharedPreferences.resetStatic();
    });

    test('loads mock preferences without recovery', () async {
      SharedPreferences.setMockInitialValues({'demo': 'ok'});
      final prefs = await ensureSharedPreferencesReady();
      expect(prefs.getString('demo'), 'ok');
    });
  });

  group('resolveSharedPreferencesFilePath', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('prefs_path_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('joins support directory with shared_preferences.json', () async {
      final path = await resolveSharedPreferencesFilePath();
      expect(path, p.join(tempDir.path, sharedPreferencesFileName));
    });
  });
}
