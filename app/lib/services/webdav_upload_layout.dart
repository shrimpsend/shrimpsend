import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_file_entry.dart';

const webDavUploadLayoutPrefKey = 'webdav_upload_layout_last';

enum WebDavUploadLayout {
  flat,
  preserveStructure,
}

Future<WebDavUploadLayout> loadWebDavUploadLayoutPref() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(webDavUploadLayoutPrefKey);
  if (raw == 'preserveStructure') {
    return WebDavUploadLayout.preserveStructure;
  }
  return WebDavUploadLayout.flat;
}

Future<void> saveWebDavUploadLayoutPref(WebDavUploadLayout layout) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    webDavUploadLayoutPrefKey,
    layout == WebDavUploadLayout.preserveStructure
        ? 'preserveStructure'
        : 'flat',
  );
}

/// Parent directory of a WebDAV app-relative path (`''` for root).
String webDavRemoteParentPath(String remotePath) {
  if (remotePath.isEmpty) return '';
  final idx = remotePath.lastIndexOf('/');
  if (idx < 0) return '';
  return remotePath.substring(0, idx);
}

/// Collects unique parent directories for [remoteFilePaths], shallow-first.
List<String> collectSortedParentDirs(Iterable<String> remoteFilePaths) {
  final dirs = <String>{};
  for (final remote in remoteFilePaths) {
    var parent = webDavRemoteParentPath(remote);
    while (parent.isNotEmpty) {
      dirs.add(parent);
      parent = webDavRemoteParentPath(parent);
    }
  }
  final sorted = dirs.toList()
    ..sort(
      (a, b) => a.split('/').length.compareTo(b.split('/').length),
    );
  return sorted;
}

String joinWebDavRelativePath(String base, String leaf) {
  final normalizedLeaf = leaf.replaceAll('\\', '/');
  if (base.isEmpty) return normalizedLeaf;
  if (normalizedLeaf.isEmpty) return base;
  return '$base/$normalizedLeaf';
}

String buildWebDavUploadRemotePath({
  required String relativeDir,
  required PendingFileEntry entry,
  required WebDavUploadLayout layout,
  required String remoteLeafName,
}) {
  final leaf = layout == WebDavUploadLayout.preserveStructure &&
          entry.relativeSubPath != null &&
          entry.relativeSubPath!.isNotEmpty
      ? entry.relativeSubPath!.replaceAll('\\', '/')
      : remoteLeafName;
  return joinWebDavRelativePath(relativeDir, leaf);
}

/// Assigns remote paths for a batch; flat mode dedupes basenames with `(n)`.
List<({
  String remotePath,
  String localPath,
  int size,
  String fileName,
  PendingFileEntry entry,
})> buildWebDavUploadJobs({
  required String relativeDir,
  required List<PendingFileEntry> entries,
  required WebDavUploadLayout layout,
}) {
  final usedFlatNames = <String>{};
  final jobs = <
      ({
        String remotePath,
        String localPath,
        int size,
        String fileName,
        PendingFileEntry entry,
      })>[];

  for (final entry in entries) {
    final path = entry.file.path;
    if (path == null || path.isEmpty) continue;
    final remoteLeaf = layout == WebDavUploadLayout.flat
        ? _uniqueFlatLeafName(entry.file.name, usedFlatNames)
        : (entry.relativeSubPath != null && entry.relativeSubPath!.isNotEmpty
            ? entry.relativeSubPath!.replaceAll('\\', '/')
            : entry.file.name);
    final remotePath = buildWebDavUploadRemotePath(
      relativeDir: relativeDir,
      entry: entry,
      layout: layout,
      remoteLeafName: remoteLeaf,
    );
    jobs.add((
      remotePath: remotePath,
      localPath: path,
      size: entry.file.size,
      fileName: p.basename(remotePath),
      entry: entry,
    ));
  }
  return jobs;
}

String _uniqueFlatLeafName(String originalName, Set<String> used) {
  if (!used.contains(originalName)) {
    used.add(originalName);
    return originalName;
  }
  final ext = p.extension(originalName);
  final stem = ext.isEmpty
      ? originalName
      : originalName.substring(0, originalName.length - ext.length);
  var n = 1;
  while (true) {
    final candidate = ext.isEmpty ? '$stem ($n)' : '$stem ($n)$ext';
    if (!used.contains(candidate)) {
      used.add(candidate);
      return candidate;
    }
    n++;
  }
}
