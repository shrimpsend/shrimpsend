import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:uuid/uuid.dart';

import '../utils/clipboard_image.dart';
import '../utils/runtime_platform.dart';
import 'file_store.dart';

/// Desktop-only file clipboard read/write via [Pasteboard].
final class DesktopFileClipboard {
  DesktopFileClipboard._();

  /// Reads file paths from the system clipboard and returns [PlatformFile]s
  /// suitable for the pending outbox. Empty on non-desktop or when no files.
  ///
  /// When no file paths are present (e.g. a screenshot copied by a capture
  /// tool), falls back to reading raw clipboard image bytes and staging them
  /// into the cache so they can be sent like any other file.
  static Future<List<PlatformFile>> readFilesForPending() async {
    if (!RuntimePlatform.isDesktop) return const [];

    final paths = await Pasteboard.files();
    if (paths.isEmpty) {
      final image = await _readImageForPending();
      return image == null ? const [] : [image];
    }

    final files = <PlatformFile>[];
    for (final p in paths) {
      final f = File(p);
      if (!await f.exists()) continue;
      final stat = await f.stat();
      if (stat.size <= 0) continue;
      files.add(
        PlatformFile(
          name: p.split(Platform.pathSeparator).last,
          path: p,
          size: stat.size,
        ),
      );
    }
    return files;
  }

  /// Stages clipboard image bytes (a screenshot) into the cache as a file.
  static Future<PlatformFile?> _readImageForPending() async {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;

    final ext = extensionForImageBytes(bytes);
    final name = clipboardImageFileName(ext: ext);
    final destPath = await FileStore.buildCachePath(
      'clipboard_${const Uuid().v4()}',
      name,
    );
    final file = File(destPath);
    await file.writeAsBytes(bytes, flush: true);
    final stat = await file.stat();
    if (stat.size <= 0) return null;
    return PlatformFile(name: name, path: destPath, size: stat.size);
  }

  /// Writes local file paths to the system clipboard. Returns false on
  /// non-desktop, if no valid paths, or if the native write fails.
  static Future<bool> writeFilesToClipboard(List<String> paths) async {
    if (!RuntimePlatform.isDesktop) return false;

    final existing = <String>[];
    for (final p in paths) {
      if (p.isEmpty) continue;
      final f = File(p);
      if (await f.exists()) {
        existing.add(p);
      }
    }
    if (existing.isEmpty) return false;
    return Pasteboard.writeFiles(existing);
  }
}
