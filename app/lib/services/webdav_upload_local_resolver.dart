import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'pending_files_path_stabilizer.dart';

/// Resolved local file ready for WebDAV PUT.
final class WebDavUploadLocalFile {
  const WebDavUploadLocalFile({
    required this.path,
    required this.fileName,
    required this.size,
  });

  final String path;
  final String fileName;
  final int size;
}

/// Validates or stabilizes a local file at upload time (per file, async).
Future<WebDavUploadLocalFile?> resolveUploadLocalFile({
  required String? localPath,
  required String fileName,
  required int cachedSize,
}) async {
  if (localPath == null || localPath.isEmpty) {
    return null;
  }

  if (localPath.startsWith('content://')) {
    final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
      PlatformFile(name: fileName, path: localPath, size: cachedSize),
      logSource: 'webdav_upload',
    );
    if (stabilized == null) return null;
    final path = stabilized.path;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size <= 0) return null;
    final name = stabilized.name.isNotEmpty ? stabilized.name : p.basename(path);
    return WebDavUploadLocalFile(path: path, fileName: name, size: size);
  }

  final file = File(localPath);
  if (!await file.exists()) return null;
  final size = await file.length();
  if (size <= 0) return null;
  final name = fileName.isNotEmpty ? fileName : p.basename(localPath);
  return WebDavUploadLocalFile(path: localPath, fileName: name, size: size);
}
