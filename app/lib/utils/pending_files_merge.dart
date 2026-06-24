import 'package:file_picker/file_picker.dart';

import '../config/env.dart';
import 'file_utils.dart';

/// Merges [incoming] into [existing], deduplicating by path or name+size.
/// Filters APK installers on Play distribution builds.
List<PlatformFile> mergePendingFiles(
  List<PlatformFile> existing,
  List<PlatformFile> incoming,
) {
  var toAdd = incoming;
  if (Env.androidPlayDistribution) {
    toAdd = incoming
        .where((f) => !looksLikeApkInstallerFileName(f.name))
        .toList();
  }
  if (toAdd.isEmpty) return existing;

  final existingPaths = existing
      .where((f) => f.path != null)
      .map((f) => f.path!)
      .toSet();
  final existingFiles = existing
      .where((f) => f.path == null)
      .map((f) => '${f.name}_${f.size}')
      .toSet();

  final newFiles = toAdd.where((file) {
    if (file.path != null) {
      return !existingPaths.contains(file.path);
    }
    return !existingFiles.contains('${file.name}_${file.size}');
  }).toList();

  if (newFiles.isEmpty) return existing;
  return [...newFiles, ...existing];
}
