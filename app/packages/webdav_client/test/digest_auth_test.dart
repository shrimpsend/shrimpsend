import 'package:test/test.dart';
import 'package:webdav_client/src/auth.dart';

void main() {
  group('DigestParts', () {
    test('parses Railway-style WWW-Authenticate header', () {
      const header =
          'Digest realm="Default realm", qop="auth", nonce="abc123", opaque="opaque456"';
      final parts = DigestParts(header);

      expect(parts.parts['realm'], 'Default realm');
      expect(parts.parts['qop'], 'auth');
      expect(parts.parts['nonce'], 'abc123');
      expect(parts.parts['opaque'], 'opaque456');
    });
  });

  group('DigestAuth', () {
    test('authorize produces Digest header with qop and opaque', () {
      const header =
          'Digest realm="Default realm", qop="auth", nonce="abc123", opaque="opaque456"';
      final auth = DigestAuth(
        user: 'root',
        pwd: 'secret',
        dParts: DigestParts(header),
      );

      final value = auth.authorize('PROPFIND', '/');
      expect(value, startsWith('Digest username="root"'));
      expect(value, contains('realm="Default realm"'));
      expect(value, contains('nonce="abc123"'));
      expect(value, contains('uri="/"'));
      expect(value, contains('qop=auth'));
      expect(value, contains('opaque=opaque456'));
      expect(value, contains('response="'));
    });
  });
}
