import 'package:app/api/webdav.dart';
import 'package:app/services/webdav_credential_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _testCreds = WebDavCredentials(
  username: 'user',
  password: 'secret',
  baseUrl: 'https://webdav.example.com',
  rootPath: '/',
);

class _FakeSecureStorage implements WebDavSecureStorage {
  _FakeSecureStorage({this.throwOnRead = false, this.throwOnWrite = false});

  bool throwOnRead;
  bool throwOnWrite;
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    if (throwOnRead) {
      throw PlatformException(code: '-34018', message: '没有所需的授权');
    }
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (throwOnWrite) {
      throw PlatformException(code: '-34018', message: '没有所需的授权');
    }
    values[key] = value;
  }
}

void main() {
  group('WebDavCredentialStore secure storage degradation', () {
    test('write keeps credentials in memory when secure storage write fails',
        () async {
      final secure = _FakeSecureStorage(throwOnWrite: true);
      final store = WebDavCredentialStore.forTesting(secure);

      await store.write(1, _testCreds);

      final cached = await store.read(1);
      expect(cached?.username, _testCreds.username);
      expect(cached?.password, _testCreds.password);
      expect(secure.values, isEmpty);
    });

    test('read returns null when secure storage read fails and memory is empty',
        () async {
      final secure = _FakeSecureStorage(throwOnRead: true);
      final store = WebDavCredentialStore.forTesting(secure);

      final cached = await store.read(42);
      expect(cached, isNull);
    });

    test('read prefers memory over secure storage failures', () async {
      final secure = _FakeSecureStorage(throwOnRead: true, throwOnWrite: true);
      final store = WebDavCredentialStore.forTesting(secure);

      await store.write(7, _testCreds);
      final cached = await store.read(7);

      expect(cached?.username, _testCreds.username);
    });

    test('remove clears memory even when secure storage delete would fail',
        () async {
      final secure = _FakeSecureStorage(throwOnWrite: true);
      final store = WebDavCredentialStore.forTesting(secure);

      await store.write(3, _testCreds);
      expect(store.getFromMemory(3), _testCreds);

      secure.throwOnWrite = true;
      await store.remove(3);

      expect(store.getFromMemory(3), isNull);
      final cached = await store.read(3);
      expect(cached, isNull);
    });

    test('wipeAll clears memory even when secure storage deleteAll would fail',
        () async {
      final secure = _FakeSecureStorage(throwOnWrite: true);
      final store = WebDavCredentialStore.forTesting(secure);

      await store.write(1, _testCreds);
      await store.write(2, _testCreds);

      secure.throwOnWrite = true;
      await store.wipeAll();

      expect(store.getFromMemory(1), isNull);
      expect(store.getFromMemory(2), isNull);
    });

    test('persists to secure storage when write succeeds', () async {
      final secure = _FakeSecureStorage();
      final store = WebDavCredentialStore.forTesting(secure);

      await store.write(5, _testCreds);

      expect(secure.values.containsKey('webdav_cred_5'), isTrue);

      final freshStore = WebDavCredentialStore.forTesting(secure);
      final cached = await freshStore.read(5);
      expect(cached?.username, _testCreds.username);
      expect(cached?.password, _testCreds.password);
      expect(cached?.baseUrl, _testCreds.baseUrl);
    });
  });
}
