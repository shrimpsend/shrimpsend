import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'file_store.dart';
import 'saf_storage_service.dart';

enum FileExportTarget { downloads, filesApp }

class FileExportResult {
  final FileExportTarget target;
  final String? displayName;
  final String? location;

  const FileExportResult({
    required this.target,
    this.displayName,
    this.location,
  });
}

class FileSaveAsResult {
  final String displayName;
  final String? location;

  /// iOS only: [saveFileAs] fell back to the system share sheet.
  final bool usedShareFallback;

  const FileSaveAsResult({
    required this.displayName,
    this.location,
    this.usedShareFallback = false,
  });
}

class FileExportService {
  static const _channel = MethodChannel('dev.ultrasend/file_export');
  static const _saveAsInMemoryMaxBytes = 32 * 1024 * 1024;
  static const _saveFileTimeout = Duration(seconds: 10);

  static bool get isSupported {
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;
  }

  /// Resolves [sourcePath] to a readable local file path for export/copy.
  static Future<String> resolveExportSourcePath({
    required String sourcePath,
    required String fileName,
  }) async {
    if (sourcePath.startsWith('content://')) {
      final local = await SafStorageService.copyFileToCache(
        sourcePath,
        fileName,
      );
      if (local == null || local.isEmpty) {
        throw FileSystemException('Could not resolve source file', sourcePath);
      }
      return local;
    }
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }
    return sourcePath;
  }

  /// Opens a platform save dialog so the user picks where to store [fileName].
  /// Returns `null` when the user cancels. Throws on hard failures.
  static Future<FileSaveAsResult?> saveFileAs({
    required String sourcePath,
    required String fileName,
    String? dialogTitle,
  }) async {
    final resolved = await resolveExportSourcePath(
      sourcePath: sourcePath,
      fileName: fileName,
    );
    final sanitizedName = _sanitizeFileName(fileName);

    if (Platform.isIOS) {
      return _saveFileAsIOS(
        resolvedPath: resolved,
        fileName: sanitizedName,
        dialogTitle: dialogTitle,
      );
    }

    if (Platform.isAndroid) {
      return _saveFileAsAndroid(
        resolvedPath: resolved,
        fileName: sanitizedName,
        dialogTitle: dialogTitle,
      );
    }

    final file = File(resolved);
    final bytes = await file.readAsBytes();
    final dest = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: sanitizedName,
      bytes: bytes,
    );
    if (dest == null || dest.isEmpty) return null;

    return FileSaveAsResult(
      displayName: p.basename(dest),
      location: dest,
    );
  }

  static Future<FileSaveAsResult?> _saveFileAsAndroid({
    required String resolvedPath,
    required String fileName,
    String? dialogTitle,
  }) async {
    final file = File(resolvedPath);
    final size = await file.length();

    // Large files: native ACTION_CREATE_DOCUMENT + stream copy (no OOM).
    if (size > _saveAsInMemoryMaxBytes) {
      final destUri = await _channel.invokeMethod<String>('saveFileAsStream', {
        'sourcePath': resolvedPath,
        'fileName': fileName,
      });
      if (destUri == null || destUri.isEmpty) return null;
      return FileSaveAsResult(displayName: fileName, location: destUri);
    }

    // file_picker on Android requires [bytes]; it writes to the SAF URI itself.
    final bytes = await file.readAsBytes();
    final dest = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
    );
    if (dest == null || dest.isEmpty) return null;
    return FileSaveAsResult(displayName: fileName, location: dest);
  }

  static Future<FileSaveAsResult?> _saveFileAsIOS({
    required String resolvedPath,
    required String fileName,
    String? dialogTitle,
  }) async {
    try {
      final file = File(resolvedPath);
      final size = await file.length();
      if (size > _saveAsInMemoryMaxBytes) {
        await Share.shareXFiles([XFile(resolvedPath)]);
        return FileSaveAsResult(
          displayName: fileName,
          usedShareFallback: true,
        );
      }

      final bytes = await file.readAsBytes();
      final dest = await FilePicker
          .saveFile(
            dialogTitle: dialogTitle,
            fileName: fileName,
            bytes: bytes,
          )
          .timeout(_saveFileTimeout);
      if (dest == null || dest.isEmpty) return null;
      return FileSaveAsResult(
        displayName: p.basename(dest),
        location: dest,
      );
    } on TimeoutException {
      await Share.shareXFiles([XFile(resolvedPath)]);
      return FileSaveAsResult(
        displayName: fileName,
        usedShareFallback: true,
      );
    } catch (_) {
      await Share.shareXFiles([XFile(resolvedPath)]);
      return FileSaveAsResult(
        displayName: fileName,
        usedShareFallback: true,
      );
    }
  }

  static Future<String> _copyToDestination({
    required String sourcePath,
    required String destination,
    required String fileName,
  }) async {
    if (destination.startsWith('content://')) {
      if (!Platform.isAndroid) {
        throw FileSystemException(
          'content URI destination is only supported on Android',
          destination,
        );
      }
      await _channel.invokeMethod<void>('copyToContentUri', {
        'sourcePath': sourcePath,
        'destUri': destination,
      });
      return destination;
    }

    final destPath = _normalizeDestinationPath(destination, fileName);
    return FileStore.exportCopyVerified(
      sourcePath: sourcePath,
      directoryPath: p.dirname(destPath),
      fileName: p.basename(destPath),
    );
  }

  static String _normalizeDestinationPath(String destination, String fileName) {
    final destExt = p.extension(destination);
    final nameExt = p.extension(fileName);
    if (destExt.isEmpty && nameExt.isNotEmpty) {
      return '$destination$nameExt';
    }
    if (destExt.isEmpty) {
      return destination;
    }
    return destination;
  }

  static String _sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'received' : cleaned;
  }

  static Future<FileExportResult> exportFile({
    required String path,
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      final result = await _channel.invokeMapMethod<String, String?>(
        'saveToDownloads',
        {'path': path, 'fileName': fileName},
      );
      return FileExportResult(
        target: FileExportTarget.downloads,
        displayName: result?['displayName'] ?? fileName,
        location: result?['path'] ?? result?['uri'],
      );
    }

    if (Platform.isIOS) {
      await Share.shareXFiles([XFile(path)]);
      return const FileExportResult(target: FileExportTarget.filesApp);
    }

    final downloads = await FileStore.getDesktopDownloadsDir();
    if (downloads == null || downloads.trim().isEmpty) {
      throw const FileSystemException('Downloads directory is unavailable');
    }
    final exportedPath = await FileStore.exportCopyToPath(
      sourcePath: path,
      directoryPath: downloads,
      fileName: fileName,
    );
    return FileExportResult(
      target: FileExportTarget.downloads,
      displayName: File(exportedPath).uri.pathSegments.last,
      location: exportedPath,
    );
  }

  /// Deletes a public Downloads entry (Android only). [uriOrPath] may be a
  /// MediaStore `content://` URI or a legacy file path. MediaStore items are
  /// removed via ContentResolver natively. Returns true on success.
  static Future<bool> deleteDownload(String uriOrPath) async {
    if (!Platform.isAndroid || uriOrPath.isEmpty) return false;
    final isUri =
        uriOrPath.startsWith('content://') || uriOrPath.startsWith('file://');
    final ok = await _channel.invokeMethod<bool>('deleteDownload', {
      'uri': isUri ? uriOrPath : null,
      'path': isUri ? null : uriOrPath,
    });
    return ok ?? false;
  }

  /// List top-level files in the public Downloads folder (Android only).
  static Future<List<DownloadsFileEntry>> listDownloads() async {
    if (!Platform.isAndroid) return const [];
    final result = await _channel.invokeMethod<List<dynamic>>('listDownloads');
    if (result == null) {
      throw PlatformException(code: 'LIST_FAILED', message: 'No Downloads data');
    }
    return result.map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final uri = map['uri'] as String? ?? '';
      final path = map['path'] as String?;
      return DownloadsFileEntry(
        name: map['name'] as String? ?? '',
        uri: uri,
        path: path,
        size: (map['size'] as num?)?.toInt() ?? 0,
        lastModified: DateTime.fromMillisecondsSinceEpoch(
          (map['lastModified'] as num?)?.toInt() ?? 0,
        ),
      );
    }).where((e) => e.name.isNotEmpty && (e.path?.isNotEmpty == true || e.uri.isNotEmpty)).toList();
  }
}

class DownloadsFileEntry {
  final String name;
  final String uri;
  final String? path;
  final int size;
  final DateTime lastModified;

  const DownloadsFileEntry({
    required this.name,
    required this.uri,
    this.path,
    required this.size,
    required this.lastModified,
  });

  String get pathOrUri => (path != null && path!.isNotEmpty) ? path! : uri;

  bool get isContentUri => uri.startsWith('content://');
}
