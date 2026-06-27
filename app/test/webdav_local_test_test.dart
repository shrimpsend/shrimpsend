import 'package:app/api/webdav.dart';
import 'package:app/services/webdav_cstcloud.dart';
import 'package:app/services/webdav_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildWebDavTestCredentials', () {
    test('trims fields and defaults empty root to slash', () {
      final creds = buildWebDavTestCredentials(
        baseUrl: ' https://dav.example.com/ ',
        username: ' root ',
        password: 'secret',
        rootPath: '',
      );

      expect(creds.baseUrl, 'https://dav.example.com/');
      expect(creds.username, 'root');
      expect(creds.password, 'secret');
      expect(creds.rootPath, '/');
      expect(creds.clientApp, isNull);
    });

    test('preserves clientApp for data capsule hosts', () {
      final creds = buildWebDavTestCredentials(
        baseUrl: 'https://data.cstcloud.cn/dav',
        username: 'u',
        password: 'p',
        rootPath: '/',
        clientApp: 'zotero',
      );

      expect(creds.clientApp, 'zotero');
      expect(resolveWebDavUserAgent(creds), kCstCloudWebDavUserAgent);
    });

    test('builds root URI matching browse path', () {
      final creds = buildWebDavTestCredentials(
        baseUrl: 'https://webdav-production-444b.up.railway.app/',
        username: 'root',
        password: 'p',
        rootPath: '/',
      );

      expect(
        buildWebDavRootUri(creds.baseUrl, creds.rootPath),
        'https://webdav-production-444b.up.railway.app/',
      );
      expect(resolveWebDavUserAgent(creds), isNull);
    });
  });
}
