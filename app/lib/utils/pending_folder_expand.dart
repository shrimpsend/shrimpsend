import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/pending_file_entry.dart';

/// Recursively lists files under [dirPath] with POSIX [PendingFileEntry.relativeSubPath].
Future<List<PendingFileEntry>> expandDirectoryToPendingEntries(
  String dirPath,
) async {
  final normalizedRoot = p.normalize(dirPath);
  final dir = Directory(normalizedRoot);
  if (!await dir.exists()) return [];

  final result = <PendingFileEntry>[];
  try {
    await for (final entity in dir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        if (stat.size <= 0) continue;
        final relativeSubPath = p
            .relative(p.normalize(entity.path), from: normalizedRoot)
            .replaceAll('\\', '/');
        result.add(
          PendingFileEntry.fromPlatformFile(
            PlatformFile(
              name: p.basename(entity.path),
              path: entity.path,
              size: stat.size,
            ),
            relativeSubPath: relativeSubPath,
          ),
        );
      } catch (_) {}
    }
  } catch (_) {}
  return result;
}
