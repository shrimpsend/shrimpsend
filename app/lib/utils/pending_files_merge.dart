import '../models/pending_file_entry.dart';
import '../config/env.dart';
import '../utils/file_utils.dart';

/// Merges [incoming] into [existing], deduplicating by path or name+size.
/// Filters APK installers on Play distribution builds.
List<PendingFileEntry> mergePendingFileEntries(
  List<PendingFileEntry> existing,
  List<PendingFileEntry> incoming,
) {
  var toAdd = incoming;
  if (Env.androidPlayDistribution) {
    toAdd = incoming
        .where((e) => !looksLikeApkInstallerFileName(e.file.name))
        .toList();
  }
  if (toAdd.isEmpty) return existing;

  final existingPaths = existing
      .where((e) => e.file.path != null)
      .map((e) => e.file.path!)
      .toSet();
  final existingFiles = existing
      .where((e) => e.file.path == null)
      .map((e) => '${e.file.name}_${e.file.size}')
      .toSet();

  final newFiles = toAdd.where((entry) {
    final file = entry.file;
    if (file.path != null) {
      return !existingPaths.contains(file.path);
    }
    return !existingFiles.contains('${file.name}_${file.size}');
  }).toList();

  if (newFiles.isEmpty) return existing;
  return [...newFiles, ...existing];
}

@Deprecated('Use mergePendingFileEntries')
List<PendingFileEntry> mergePendingFiles(
  List<PendingFileEntry> existing,
  List<PendingFileEntry> incoming,
) =>
    mergePendingFileEntries(existing, incoming);
