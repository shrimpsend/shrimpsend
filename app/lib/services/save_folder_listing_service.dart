import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/file_utils.dart';
import 'file_store.dart';
import 'file_export_service.dart';
import 'receive_dir_resolver.dart';
import 'saf_storage_service.dart';
import 'visible_export_target.dart';

/// Prefix for synthetic [ReceivedFileInfo.messageId] rows from save-folder tab.
const saveFolderMessageIdPrefix = 'savefolder:';

enum SaveFolderAccessErrorKind {
  notConfigured,
  notAccessible,
  permissionDenied,
  ioError,
}

class SaveFolderAccessError {
  final SaveFolderAccessErrorKind kind;
  final String? detail;

  const SaveFolderAccessError({required this.kind, this.detail});
}

class SaveFolderFileEntry {
  final String name;
  final String pathOrUri;
  final int size;
  final DateTime modified;
  final bool isContentUri;

  const SaveFolderFileEntry({
    required this.name,
    required this.pathOrUri,
    required this.size,
    required this.modified,
    this.isContentUri = false,
  });
}

class SaveFolderListingResult {
  final List<SaveFolderFileEntry> files;
  final String displayLabel;
  final String? displayPath;
  final SaveFolderAccessError? error;

  const SaveFolderListingResult({
    required this.files,
    required this.displayLabel,
    this.displayPath,
    this.error,
  });

  bool get isSuccess => error == null;
}

class SaveFolderListingService {
  SaveFolderListingService._();

  static Future<SaveFolderListingResult> list() async {
    final target = await ReceiveDirResolver.resolveVisibleExportTarget();
    final displayLabel = target.displayName;

    switch (target.kind) {
      case VisibleExportKind.safTree:
        return _listSafTree(target, displayLabel);
      case VisibleExportKind.downloads:
        if (defaultTargetPlatform == TargetPlatform.android &&
            (target.posixPath == null || target.posixPath!.isEmpty)) {
          return _listAndroidDownloads(displayLabel);
        }
        return _listPosixTarget(target, displayLabel);
      case VisibleExportKind.documents:
      case VisibleExportKind.customDir:
        return _listPosixTarget(target, displayLabel);
    }
  }

  static Future<SaveFolderListingResult> _listAndroidDownloads(
    String displayLabel,
  ) async {
    if (!Platform.isAndroid) {
      final base = await ReceiveDirResolver.getPublicDownloadsBase();
      if (base == null || base.isEmpty) {
        return SaveFolderListingResult(
          files: const [],
          displayLabel: displayLabel,
          error: const SaveFolderAccessError(
            kind: SaveFolderAccessErrorKind.notAccessible,
            detail: 'Downloads directory unavailable',
          ),
        );
      }
      return _listPosixDirectory(
        directoryPath: base,
        displayLabel: displayLabel,
        displayPath: base,
      );
    }

    final displayPath =
        await ReceiveDirResolver.getPublicDownloadsBase() ?? displayLabel;
    try {
      final rawFiles = await FileExportService.listDownloads();
      final entries = rawFiles
          .where((f) => !_shouldSkipFileName(f.name))
          .map(
            (f) => SaveFolderFileEntry(
              name: f.name,
              pathOrUri: f.pathOrUri,
              size: f.size,
              modified: f.lastModified,
              isContentUri: f.isContentUri,
            ),
          )
          .toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));

      return SaveFolderListingResult(
        files: entries,
        displayLabel: displayLabel,
        displayPath: displayPath,
      );
    } on PlatformException catch (e) {
      final kind = e.code == 'PERMISSION_DENIED'
          ? SaveFolderAccessErrorKind.permissionDenied
          : SaveFolderAccessErrorKind.notAccessible;
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: displayPath,
        error: SaveFolderAccessError(
          kind: kind,
          detail: e.message ?? e.code,
        ),
      );
    } catch (e) {
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: displayPath,
        error: SaveFolderAccessError(
          kind: SaveFolderAccessErrorKind.ioError,
          detail: _formatError(e),
        ),
      );
    }
  }

  static Future<SaveFolderListingResult> _listPosixTarget(
    VisibleExportTarget target,
    String displayLabel,
  ) async {
    final path = target.posixPath?.trim();
    if (path == null || path.isEmpty) {
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        error: const SaveFolderAccessError(
          kind: SaveFolderAccessErrorKind.notConfigured,
        ),
      );
    }
    return _listPosixDirectory(
      directoryPath: path,
      displayLabel: displayLabel,
      displayPath: path,
    );
  }

  static Future<SaveFolderListingResult> _listPosixDirectory({
    required String directoryPath,
    required String displayLabel,
    required String displayPath,
  }) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        return SaveFolderListingResult(
          files: const [],
          displayLabel: displayLabel,
          displayPath: displayPath,
          error: SaveFolderAccessError(
            kind: SaveFolderAccessErrorKind.notAccessible,
            detail: 'Directory does not exist',
          ),
        );
      }

      final entries = <SaveFolderFileEntry>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path.split('/').last;
        if (_shouldSkipFileName(name)) continue;
        final stat = await entity.stat();
        entries.add(
          SaveFolderFileEntry(
            name: name,
            pathOrUri: entity.path,
            size: stat.size,
            modified: stat.modified,
          ),
        );
      }

      entries.sort((a, b) => b.modified.compareTo(a.modified));
      return SaveFolderListingResult(
        files: entries,
        displayLabel: displayLabel,
        displayPath: displayPath,
      );
    } on FileSystemException catch (e) {
      final kind = _kindFromFileSystemException(e);
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: displayPath,
        error: SaveFolderAccessError(
          kind: kind,
          detail: _formatError(e),
        ),
      );
    } catch (e) {
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: displayPath,
        error: SaveFolderAccessError(
          kind: SaveFolderAccessErrorKind.ioError,
          detail: _formatError(e),
        ),
      );
    }
  }

  static Future<SaveFolderListingResult> _listSafTree(
    VisibleExportTarget target,
    String displayLabel,
  ) async {
    final treeUri = target.safTreeUri?.trim();
    if (treeUri == null || treeUri.isEmpty) {
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        error: const SaveFolderAccessError(
          kind: SaveFolderAccessErrorKind.notConfigured,
        ),
      );
    }

    if (!SafStorageService.isSupported) {
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: treeUri,
        error: const SaveFolderAccessError(
          kind: SaveFolderAccessErrorKind.notAccessible,
        ),
      );
    }

    try {
      final rawFiles = await SafStorageService.listFilesInTree(treeUri);
      final entries = rawFiles
          .where((f) => !_shouldSkipFileName(f.name))
          .map(
            (f) => SaveFolderFileEntry(
              name: f.name,
              pathOrUri: f.uri,
              size: f.size,
              modified: f.lastModified,
              isContentUri: true,
            ),
          )
          .toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));

      return SaveFolderListingResult(
        files: entries,
        displayLabel: displayLabel,
        displayPath: treeUri,
      );
    } on PlatformException catch (e) {
      final kind = e.code == 'PERMISSION_DENIED'
          ? SaveFolderAccessErrorKind.permissionDenied
          : SaveFolderAccessErrorKind.notAccessible;
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: treeUri,
        error: SaveFolderAccessError(
          kind: kind,
          detail: e.message ?? e.code,
        ),
      );
    } catch (e) {
      return SaveFolderListingResult(
        files: const [],
        displayLabel: displayLabel,
        displayPath: treeUri,
        error: SaveFolderAccessError(
          kind: SaveFolderAccessErrorKind.ioError,
          detail: _formatError(e),
        ),
      );
    }
  }

  static bool isSaveFolderEntry(ReceivedFileInfo file) =>
      file.messageId.startsWith(saveFolderMessageIdPrefix);

  static ReceivedFileInfo toReceivedFileInfo(SaveFolderFileEntry entry) {
    return ReceivedFileInfo(
      messageId: '$saveFolderMessageIdPrefix${entry.pathOrUri.hashCode}',
      path: entry.pathOrUri,
      displayName: entry.name,
      protocol: 'local',
      size: entry.size,
      modified: entry.modified,
      createdAt: entry.modified,
      category: getFileCategory(entry.name),
      visiblePath: entry.isContentUri ? null : entry.pathOrUri,
      exportStatus: ExportStatus.done,
    );
  }

  static Future<bool> deleteEntry(
    ReceivedFileInfo file, {
    bool useTrash = false,
  }) {
    return deletePath(file.path, useTrash: useTrash);
  }

  /// Deletes a save-folder file given its path or content URI. Routes
  /// MediaStore Downloads URIs (`content://media/...`) through ContentResolver
  /// — `DocumentFile.delete` silently fails for them — SAF tree document URIs
  /// through SAF, and plain POSIX paths through [FileStore.deleteFile] (which
  /// honours the desktop recycle bin when [useTrash] is set). Returns true on
  /// success.
  static Future<bool> deletePath(
    String pathOrUri, {
    bool useTrash = false,
  }) async {
    if (pathOrUri.isEmpty) return true;
    if (pathOrUri.startsWith('content://')) {
      if (_isMediaStoreUri(pathOrUri)) {
        return FileExportService.deleteDownload(pathOrUri);
      }
      return SafStorageService.deleteFileInTree(pathOrUri);
    }
    return FileStore.deleteFile(pathOrUri, useTrash: useTrash);
  }

  static bool _isMediaStoreUri(String uri) =>
      uri.startsWith('content://media/');

  /// Copy SAF content URI to a temp file for preview / desktop clipboard.
  static Future<String?> resolveLocalPath(ReceivedFileInfo file) async {
    if (!file.path.startsWith('content://')) return file.path;
    return SafStorageService.copyFileToCache(file.path, file.displayName);
  }

  static bool _shouldSkipFileName(String name) {
    if (name.isEmpty) return true;
    if (name.startsWith('.')) return true;
    return name.startsWith('.shrimpsend_');
  }

  static SaveFolderAccessErrorKind _kindFromFileSystemException(
    FileSystemException e,
  ) {
    final message = e.message.toLowerCase();
    if (message.contains('permission') ||
        message.contains('denied') ||
        message.contains('access')) {
      return SaveFolderAccessErrorKind.permissionDenied;
    }
    return SaveFolderAccessErrorKind.ioError;
  }

  static String _formatError(Object e) {
    if (e is FileSystemException) {
      return e.message.isNotEmpty ? e.message : e.toString();
    }
    final text = e.toString();
    return text.length > 240 ? '${text.substring(0, 237)}...' : text;
  }
}
