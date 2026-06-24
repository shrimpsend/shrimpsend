import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_store.dart';
import 'received_file_dao.dart';
import 'save_folder_listing_service.dart';
import 'webdav_session.dart';
import 'webdav_transfer_service.dart';

/// Resolves whether a received file exists locally using the same fallback
/// chain as chat / file transfer: cache, visible export, cache dir scan, save
/// folder.
class LocalReceivedFileResolver {
  const LocalReceivedFileResolver({
    this.getRecord,
    this.getCacheDir,
    this.findByNameAndSize,
    this.listSaveFolder,
  });

  final Future<ReceivedFileRecord?> Function(String messageId)? getRecord;
  final Future<String> Function()? getCacheDir;
  final Future<List<ReceivedFileRecord>> Function({
    required String fileName,
    int? size,
  })?
  findByNameAndSize;
  final Future<SaveFolderListingResult> Function()? listSaveFolder;

  static const instance = LocalReceivedFileResolver();

  Future<bool> isLocallyAvailable({
    required String messageId,
    required String fileName,
    int? size,
    String? candidate,
  }) async {
    final path = await resolveLocalPath(
      messageId: messageId,
      fileName: fileName,
      size: size,
      candidate: candidate,
    );
    return path != null;
  }

  Future<String?> resolveLocalPath({
    required String messageId,
    required String fileName,
    int? size,
    String? candidate,
  }) async {
    if (candidate != null &&
        candidate.isNotEmpty &&
        File(candidate).existsSync()) {
      return candidate;
    }

    try {
      final record = await _getRecord(messageId);
      if (record != null) {
        final fromRecord = await _pathFromRecord(record);
        if (fromRecord != null) return fromRecord;
      }

      if (fileName.isNotEmpty) {
        final hits = await _findByNameAndSize(fileName: fileName, size: size);
        for (final hit in hits) {
          final path = await _pathFromRecord(hit);
          if (path != null) return path;
        }
      }

      final cacheRoot = await _getCacheDir();
      final dirPath = FileStore.reserveCacheDirSync(cacheRoot, messageId);
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        for (final entry in dir.listSync(followLinks: false)) {
          if (entry is File && !p.basename(entry.path).startsWith('.')) {
            return entry.path;
          }
        }
      }

      return _resolveFromSaveFolder(fileName: fileName, size: size);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String?>> resolveForWebDavEntries({
    required int connectionId,
    required List<WebDavEntry> entries,
  }) async {
    final result = <String, String?>{};
    for (final entry in entries) {
      if (entry.isDirectory) continue;
      final messageId = webDavMessageId(connectionId, entry.path);
      result[entry.path] = await resolveLocalPath(
        messageId: messageId,
        fileName: entry.name,
        size: entry.size,
      );
    }
    return result;
  }

  Future<ReceivedFileRecord?> _getRecord(String messageId) {
    return (getRecord ?? ReceivedFileDao.instance.getByMessageId)(messageId);
  }

  Future<String> _getCacheDir() {
    return (getCacheDir ?? FileStore.getCacheDir)();
  }

  Future<List<ReceivedFileRecord>> _findByNameAndSize({
    required String fileName,
    int? size,
  }) {
    final finder =
        findByNameAndSize ?? ReceivedFileDao.instance.findByNameAndSize;
    return finder(fileName: fileName, size: size);
  }

  Future<String?> _pathFromRecord(ReceivedFileRecord record) async {
    final cachePath = record.cachePath;
    if (cachePath != null &&
        cachePath.isNotEmpty &&
        File(cachePath).existsSync()) {
      return cachePath;
    }

    final visiblePath = record.visiblePath;
    if (visiblePath != null && visiblePath.isNotEmpty) {
      if (visiblePath.startsWith('content://')) {
        final local = await SaveFolderListingService.resolveLocalPath(
          record.toInfo(),
        );
        if (local != null && local.isNotEmpty && File(local).existsSync()) {
          return local;
        }
      } else if (File(visiblePath).existsSync()) {
        return visiblePath;
      }
    }

    final readable = record.readablePath;
    if (readable.isNotEmpty && File(readable).existsSync()) {
      return readable;
    }

    return null;
  }

  Future<String?> _resolveFromSaveFolder({
    required String fileName,
    int? size,
  }) async {
    if (fileName.isEmpty) return null;
    final entry = await _findSaveFolderEntry(fileName: fileName, size: size);
    if (entry == null) return null;
    final info = SaveFolderListingService.toReceivedFileInfo(entry);
    final local = await SaveFolderListingService.resolveLocalPath(info);
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return local;
    }
    return null;
  }

  Future<SaveFolderFileEntry?> _findSaveFolderEntry({
    required String fileName,
    required int? size,
  }) async {
    final listing = await (listSaveFolder ?? SaveFolderListingService.list)();
    if (!listing.isSuccess) return null;

    SaveFolderFileEntry? match;
    final wantSize = size;
    for (final entry in listing.files) {
      if (entry.name != fileName) continue;
      if (wantSize != null && wantSize > 0) {
        if (entry.size == wantSize) {
          return entry;
        }
        match ??= entry;
      } else {
        return entry;
      }
    }
    return match;
  }
}
