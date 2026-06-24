import 'package:flutter_test/flutter_test.dart';

import 'package:app/services/webdav_transfer_service.dart';

void main() {
  test('webDavMessageId is stable for same connection and path', () {
    final a = webDavMessageId(42, 'Documents/report.pdf');
    final b = webDavMessageId(42, 'Documents/report.pdf');
    expect(a, b);
    expect(a.startsWith('webdav_42_'), isTrue);
  });

  test('webDavMessageId differs for different paths', () {
    final a = webDavMessageId(1, 'a.txt');
    final b = webDavMessageId(1, 'b.txt');
    expect(a, isNot(equals(b)));
  });

  test('webDavConnectionKey stringifies id', () {
    expect(webDavConnectionKey(7), '7');
  });
}
