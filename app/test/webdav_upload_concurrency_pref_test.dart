import 'package:app/services/webdav_upload_concurrency_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('webdav upload concurrency pref', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to 3', () async {
      expect(await loadWebDavUploadConcurrencyPref(), 3);
    });

    test('clamps saved values to 1-12', () async {
      await saveWebDavUploadConcurrencyPref(99);
      expect(await loadWebDavUploadConcurrencyPref(), 12);

      await saveWebDavUploadConcurrencyPref(0);
      expect(await loadWebDavUploadConcurrencyPref(), 1);
    });

    test('round-trips valid values', () async {
      await saveWebDavUploadConcurrencyPref(6);
      expect(await loadWebDavUploadConcurrencyPref(), 6);
    });

    test('clampWebDavUploadConcurrency', () {
      expect(clampWebDavUploadConcurrency(-1), 1);
      expect(clampWebDavUploadConcurrency(8), 8);
      expect(clampWebDavUploadConcurrency(20), 12);
    });
  });
}
