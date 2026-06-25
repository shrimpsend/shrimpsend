import 'package:app/services/webdav_cstcloud.dart';
import 'package:app/utils/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/api/webdav.dart';

void main() {
  group('mimeFromFileName', () {
    test('pdf', () {
      expect(mimeFromFileName('B1101_协议.pdf'), 'application/pdf');
    });

    test('jpeg', () {
      expect(mimeFromFileName('/photos/a.JPG'), 'image/jpeg');
    });

    test('unknown falls back to octet-stream', () {
      expect(mimeFromFileName('archive.xyz'), 'application/octet-stream');
    });
  });

  group('resolveWebDavUserAgent', () {
    test('uses API userAgent when present', () {
      const creds = WebDavCredentials(
        username: 'u',
        password: 'p',
        baseUrl: 'https://data.cstcloud.cn/dav',
        rootPath: '/',
        userAgent: 'CustomAgent/1.0',
      );
      expect(resolveWebDavUserAgent(creds), 'CustomAgent/1.0');
    });

    test('falls back to Zotero UA for cstcloud without userAgent', () {
      const creds = WebDavCredentials(
        username: 'u',
        password: 'p',
        baseUrl: 'https://data.cstcloud.cn/dav',
        rootPath: '/',
      );
      expect(resolveWebDavUserAgent(creds), kCstCloudWebDavUserAgent);
    });

    test('returns null for non-cstcloud without userAgent', () {
      const creds = WebDavCredentials(
        username: 'u',
        password: 'p',
        baseUrl: 'https://dav.example.com',
        rootPath: '/',
      );
      expect(resolveWebDavUserAgent(creds), isNull);
    });
  });

  group('cstCloudNeedsCredentialRefresh', () {
    test('true when cstcloud cache lacks userAgent', () {
      const creds = WebDavCredentials(
        username: 'u',
        password: 'p',
        baseUrl: 'https://data.cstcloud.cn/dav',
        rootPath: '/',
      );
      expect(cstCloudNeedsCredentialRefresh(creds), isTrue);
    });

    test('false when cstcloud cache has userAgent', () {
      const creds = WebDavCredentials(
        username: 'u',
        password: 'p',
        baseUrl: 'https://data.cstcloud.cn/dav',
        rootPath: '/',
        userAgent: kCstCloudWebDavUserAgent,
      );
      expect(cstCloudNeedsCredentialRefresh(creds), isFalse);
    });
  });

  group('cstCloudWebDavBlocksGeneralUpload', () {
    test('true for cstcloud host', () {
      expect(
        cstCloudWebDavBlocksGeneralUpload('https://data.cstcloud.cn/dav'),
        isTrue,
      );
    });

    test('false for other hosts', () {
      expect(
        cstCloudWebDavBlocksGeneralUpload('https://dav.example.com'),
        isFalse,
      );
    });
  });
}
