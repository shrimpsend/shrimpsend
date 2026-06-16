import 'dart:typed_data';

/// Infers a file extension (without dot) from image [bytes] magic numbers.
///
/// Falls back to `png` when the format is unrecognized, since clipboard
/// screenshots on most platforms are exposed as PNG.
String extensionForImageBytes(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpg';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61) {
    return 'gif';
  }
  if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return 'bmp';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp';
  }
  return 'png';
}

/// Builds a screenshot-style file name like `Screenshot-20250616-143052.png`.
String clipboardImageFileName({required String ext, DateTime? now}) {
  final t = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  return 'Screenshot-$stamp.$ext';
}
