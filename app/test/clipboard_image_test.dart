import 'dart:typed_data';

import 'package:app/utils/clipboard_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extensionForImageBytes', () {
    test('detects PNG', () {
      final bytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00,
      ]);
      expect(extensionForImageBytes(bytes), 'png');
    });

    test('detects JPEG', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
      expect(extensionForImageBytes(bytes), 'jpg');
    });

    test('detects GIF', () {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00,
      ]);
      expect(extensionForImageBytes(bytes), 'gif');
    });

    test('detects BMP', () {
      final bytes = Uint8List.fromList([0x42, 0x4D, 0x00, 0x00]);
      expect(extensionForImageBytes(bytes), 'bmp');
    });

    test('detects WebP', () {
      final bytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      expect(extensionForImageBytes(bytes), 'webp');
    });

    test('falls back to png on unknown bytes', () {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      expect(extensionForImageBytes(bytes), 'png');
    });
  });

  group('clipboardImageFileName', () {
    test('formats timestamped name with extension', () {
      final name = clipboardImageFileName(
        ext: 'png',
        now: DateTime(2025, 6, 16, 14, 30, 52),
      );
      expect(name, 'Screenshot-20250616-143052.png');
    });

    test('uses provided extension', () {
      final name = clipboardImageFileName(
        ext: 'jpg',
        now: DateTime(2025, 1, 2, 3, 4, 5),
      );
      expect(name, 'Screenshot-20250102-030405.jpg');
    });
  });
}
