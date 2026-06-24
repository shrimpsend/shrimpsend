import 'package:app/services/webdav_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildWebDavRootUri', () {
    test('base only', () {
      expect(
        buildWebDavRootUri('https://dav.example.com', '/'),
        'https://dav.example.com/',
      );
    });

    test('base with root path', () {
      expect(
        buildWebDavRootUri('https://dav.example.com/', '/remote/files/user'),
        'https://dav.example.com/remote/files/user/',
      );
    });

    test('trims redundant slashes', () {
      expect(
        buildWebDavRootUri('https://dav.example.com///', 'files/'),
        'https://dav.example.com/files/',
      );
    });
  });

  group('appRelativeToWebDavListPath', () {
    test('root', () {
      expect(appRelativeToWebDavListPath(''), '/');
    });

    test('nested folder', () {
      expect(appRelativeToWebDavListPath('Documents/Work'), '/Documents/Work/');
    });
  });

  group('appRelativeToWebDavResourcePath', () {
    test('file path', () {
      expect(appRelativeToWebDavResourcePath('a.txt'), '/a.txt');
    });

    test('directory path', () {
      expect(
        appRelativeToWebDavResourcePath('Documents', isDirectory: true),
        '/Documents/',
      );
    });
  });

  group('webDavPathToAppRelative', () {
    test('root', () {
      expect(webDavPathToAppRelative('/'), '');
    });

    test('file', () {
      expect(webDavPathToAppRelative('/readme.txt'), 'readme.txt');
    });

    test('folder', () {
      expect(webDavPathToAppRelative('/Documents/'), 'Documents');
    });

    test('nested', () {
      expect(webDavPathToAppRelative('/Documents/Work/'), 'Documents/Work');
    });
  });
}
