import 'package:test/test.dart';
import 'package:webdav_client/src/utils.dart';

void main() {
  group('contentTypeForFileName', () {
    test('pdf', () {
      expect(
        contentTypeForFileName('B1101_被动离职员工补贴申领协议.pdf'),
        'application/pdf',
      );
    });

    test('windows path', () {
      expect(
        contentTypeForFileName(r'C:\Users\me\photo.png'),
        'image/png',
      );
    });

    test('unknown extension', () {
      expect(contentTypeForFileName('file.unknown'), 'application/octet-stream');
    });
  });
}
