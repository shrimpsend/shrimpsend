import 'dart:async';
import 'dart:io';

import 'package:saver_gallery/saver_gallery.dart';

import '../file_save_preferences.dart';
import '../logger.dart';
import '../utils/helpers.dart';
import '../utils/runtime_platform.dart';
import 'file_export_service.dart';
import 'file_store.dart';
import 'received_file_dao.dart';
import 'saf_storage_service.dart';
import 'visible_export_target.dart';

final _log = logChat;

enum _ExportRunMode { inline, background }

/// Copies cache files to user-visible storage.
///
/// Normal receives call [exportNow] inline. [enqueue] is only for manual retry.
class FileExportPipeline {
  FileExportPipeline._();
  static final instance = FileExportPipeline._();

  final List<String> _queue = [];
  bool _processing = false;
  static const _maxRetries = 8;
  static const _maxNullRecordAttempts = 12;

  /// Runs export immediately as part of the receive finalize path (no queue).
  Future<bool> exportNow(String messageId) async {
    if (messageId.isEmpty) return false;
    await _exportWithRetries(messageId, mode: _ExportRunMode.inline);
    final record = await ReceivedFileDao.instance.getByMessageId(messageId);
    if (record == null) return false;
    if (record.protocol == 'share') return true;
    return record.exportStatus == ExportStatus.done;
  }

  void enqueue(String messageId) {
    if (messageId.isEmpty) return;
    if (!_queue.contains(messageId)) {
      _queue.add(messageId);
    }
    unawaited(_drain());
  }

  Future<void> retry(String messageId) async {
    await ReceivedFileDao.instance.updateExportState(
      messageId: messageId,
      exportStatus: ExportStatus.pending,
      exportError: '',
    );
    enqueue(messageId);
  }

  Future<void> _drain() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeAt(0);
        await _exportWithRetries(id, mode: _ExportRunMode.background);
        await _interExportDelay(_ExportRunMode.background);
      }
    } finally {
      _processing = false;
      if (_queue.isNotEmpty) {
        unawaited(_drain());
      }
    }
  }

  Future<void> _interExportDelay(_ExportRunMode mode) async {
    if (mode == _ExportRunMode.inline) return;
    if (!RuntimePlatform.isDesktop) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<ReceivedFileRecord?> _resolveRecordForExport(String messageId) async {
    for (var attempt = 0; attempt < _maxNullRecordAttempts; attempt++) {
      final record = await ReceivedFileDao.instance.getByMessageId(messageId);
      if (record != null) return record;

      if (attempt == 0 || attempt == 4 || attempt == 8) {
        try {
          final cacheRoot = await FileStore.getCacheDir();
          final indexed = await ReceivedFileDao.instance.reconcileWithRoot(
            cacheRoot,
          );
          if (indexed > 0) {
            _log.info(
              'FileExportPipeline reconcile indexed $indexed row(s) '
              'before export $messageId',
            );
          }
        } catch (e, st) {
          _log.warning(
            'FileExportPipeline reconcile failed for $messageId: $e',
            e,
            st,
          );
        }
      }

      final retryRecord = await ReceivedFileDao.instance.getByMessageId(
        messageId,
      );
      if (retryRecord != null) return retryRecord;

      _log.warning(
        'FileExportPipeline waiting for index row $messageId '
        'attempt=${attempt + 1}/$_maxNullRecordAttempts',
      );
      await Future<void>.delayed(
        Duration(milliseconds: 400 * (attempt + 1)),
      );
    }
    return null;
  }

  Future<void> _exportWithRetries(
    String messageId, {
    _ExportRunMode mode = _ExportRunMode.background,
  }) async {
    ReceivedFileRecord? record;
    try {
      record = await _resolveRecordForExport(messageId);
    } catch (e, st) {
      _log.warning(
        'FileExportPipeline resolve record failed for $messageId: $e',
        e,
        st,
      );
    }

    if (record == null) {
      final err = 'No received_files index row for export: $messageId';
      _log.warning('FileExportPipeline $err');
      await ReceivedFileDao.instance.updateExportState(
        messageId: messageId,
        exportStatus: ExportStatus.failed,
        exportError: err,
      );
      return;
    }

    var activeRecord = record;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final ok = await _exportOne(messageId, record: activeRecord);
        if (ok) {
          _log.info(
            'FileExportPipeline export done messageId=$messageId '
            'fileName=${activeRecord.fileName}',
          );
          return;
        }
      } catch (e, st) {
        _log.warning(
          'FileExportPipeline export attempt $attempt/$_maxRetries for '
          '$messageId fileName=${activeRecord.fileName}: $e',
          e,
          st,
        );
        if (attempt == _maxRetries) {
          await ReceivedFileDao.instance.updateExportState(
            messageId: messageId,
            exportStatus: ExportStatus.failed,
            exportError: e.toString(),
          );
        } else {
          await Future<void>.delayed(
            Duration(milliseconds: 1500 * attempt),
          );
          activeRecord =
              await ReceivedFileDao.instance.getByMessageId(messageId) ??
              activeRecord;
        }
      }
    }
  }

  /// Waits until the cache file exists and its size stops changing.
  Future<void> _waitForStableSourceFile(String path, int expectedSize) async {
    var lastSize = -1;
    var stableReads = 0;
    for (var i = 0; i < 24; i++) {
      final file = File(path);
      if (!file.existsSync()) {
        stableReads = 0;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        continue;
      }
      final size = file.lengthSync();
      if (expectedSize > 0 && size < expectedSize) {
        stableReads = 0;
        lastSize = size;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        continue;
      }
      if (size == lastSize) {
        stableReads++;
        if (stableReads >= 3) return;
      } else {
        stableReads = 0;
        lastSize = size;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  void _verifyExportedFile(String destPath, int expectedSize) {
    final dest = File(destPath);
    if (!dest.existsSync()) {
      throw FileSystemException('Export destination missing after copy', destPath);
    }
    final destSize = dest.lengthSync();
    if (destSize != expectedSize) {
      throw FileSystemException(
        'Export verification failed: expected $expectedSize bytes, '
        'destination has $destSize',
        destPath,
      );
    }
  }

  Future<bool> _exportOne(
    String messageId, {
    required ReceivedFileRecord record,
  }) async {
    if (record.protocol == 'share') return true;
    if (record.exportStatus == ExportStatus.legacy ||
        record.exportStatus == ExportStatus.done) {
      await _cleanupCacheAfterExportIfNeeded(record);
      return true;
    }

    final sourcePath = record.cachePath ?? record.absPath;
    if (sourcePath.isEmpty || !File(sourcePath).existsSync()) {
      if (record.visiblePath != null && record.visiblePath!.isNotEmpty) {
        await ReceivedFileDao.instance.updateExportState(
          messageId: messageId,
          exportStatus: ExportStatus.done,
        );
        return true;
      }
      throw StateError('Cache file missing: $messageId path=$sourcePath');
    }

    final expectedSize = record.size > 0
        ? record.size
        : File(sourcePath).lengthSync();
    await _waitForStableSourceFile(sourcePath, expectedSize);
    final sourceSize = File(sourcePath).lengthSync();
    if (expectedSize > 0 && sourceSize != expectedSize) {
      throw StateError(
        'Cache file size not ready: $messageId expected=$expectedSize '
        'actual=$sourceSize',
      );
    }

    _log.info(
      'FileExportPipeline export start messageId=$messageId '
      'source=$sourcePath bytes=$sourceSize',
    );

    await ReceivedFileDao.instance.updateExportState(
      messageId: messageId,
      exportStatus: ExportStatus.exporting,
      exportError: '',
    );

    final saveToGallery = await getSaveToGallery();
    final isMedia = isImageOrVideoFileName(record.fileName);
    final galleryOnly = saveToGallery && isMedia;

    final target = await FileStore.getVisibleExportTarget();
    late final _ExportResult exportResult;
    var gallerySaved = record.gallerySaved;

    if (galleryOnly) {
      gallerySaved = await _saveToGallery(sourcePath, record.fileName);
      if (gallerySaved) {
        exportResult = const _ExportResult(
          location: null,
          targetKind: ExportTargetKind.gallery,
        );
      } else {
        exportResult = await _exportToVisible(
          sourcePath: sourcePath,
          fileName: record.fileName,
          target: target,
          expectedSize: sourceSize,
        );
      }
    } else {
      exportResult = await _exportToVisible(
        sourcePath: sourcePath,
        fileName: record.fileName,
        target: target,
        expectedSize: sourceSize,
      );
    }

    if (exportResult.location != null &&
        exportResult.location!.isNotEmpty &&
        !exportResult.location!.startsWith('content://')) {
      _verifyExportedFile(exportResult.location!, sourceSize);
    }

    var cachePath = record.cachePath ?? sourcePath;
    var absPath = FileStore.resolveReadablePath(
      cachePath: cachePath,
      visiblePath: exportResult.location,
      absPath: record.absPath,
    );

    final shouldClearCache = await getDeleteCacheAfterSave();
    if (shouldClearCache) {
      absPath = exportResult.location ?? absPath;
    }

    await ReceivedFileDao.instance.updateExportState(
      messageId: messageId,
      exportStatus: ExportStatus.done,
      visiblePath: exportResult.location,
      exportTarget: exportResult.targetKind,
      gallerySaved: gallerySaved,
      absPath: absPath,
      cachePath: shouldClearCache ? null : cachePath,
      clearCachePath: shouldClearCache,
    );

    if (shouldClearCache) {
      final removed = await FileStore.deleteByMessageId(messageId);
      if (!removed) {
        _log.warning(
          'delete cache after export deferred for $messageId (file may be in use)',
        );
        unawaited(FileStore.deleteCacheEntryWhenReady(messageId));
      }
    }

    if (exportResult.location != null &&
        exportResult.location!.isNotEmpty &&
        !exportResult.location!.startsWith('content://')) {
      _log.info(
        'FileExportPipeline export wrote messageId=$messageId '
        'dest=${exportResult.location} bytes=$sourceSize',
      );
    }

    return true;
  }

  Future<_ExportResult> _exportToVisible({
    required String sourcePath,
    required String fileName,
    required VisibleExportTarget target,
    required int expectedSize,
  }) async {
    switch (target.kind) {
      case VisibleExportKind.safTree:
        final uri = target.safTreeUri;
        if (uri == null || uri.isEmpty) {
          throw StateError('SAF tree URI missing');
        }
        final result = await SafStorageService.copyFileToTree(
          treeUri: uri,
          sourcePath: sourcePath,
          displayName: fileName,
        );
        return _ExportResult(
          location: result.uri ?? uri,
          targetKind: ExportTargetKind.saf,
        );
      case VisibleExportKind.downloads:
        if (Platform.isAndroid) {
          final result = await FileExportService.exportFile(
            path: sourcePath,
            fileName: fileName,
          );
          return _ExportResult(
            location: result.location ?? result.displayName,
            targetKind: ExportTargetKind.downloads,
          );
        }
        final dir = target.posixPath ?? await FileStore.getDesktopDownloadsDir();
        if (dir == null || dir.isEmpty) {
          throw const FileSystemException('Downloads directory unavailable');
        }
        final path = await FileStore.exportCopyVerified(
          sourcePath: sourcePath,
          directoryPath: dir,
          fileName: fileName,
        );
        if (expectedSize > 0) {
          _verifyExportedFile(path, expectedSize);
        }
        return _ExportResult(
          location: path,
          targetKind: ExportTargetKind.downloads,
        );
      case VisibleExportKind.documents:
      case VisibleExportKind.customDir:
        final dir = target.posixPath;
        if (dir == null || dir.isEmpty) {
          throw const FileSystemException('Export directory unavailable');
        }
        final path = await FileStore.exportCopyVerified(
          sourcePath: sourcePath,
          directoryPath: dir,
          fileName: fileName,
        );
        if (expectedSize > 0) {
          _verifyExportedFile(path, expectedSize);
        }
        final kind = target.kind == VisibleExportKind.documents
            ? ExportTargetKind.documents
            : ExportTargetKind.custom;
        return _ExportResult(location: path, targetKind: kind);
    }
  }

  Future<void> _cleanupCacheAfterExportIfNeeded(ReceivedFileRecord record) async {
    if (!await getDeleteCacheAfterSave()) return;
    if (record.exportStatus == ExportStatus.legacy) return;
    if (record.exportStatus != ExportStatus.done) return;

    final hasVisibleCopy = record.gallerySaved ||
        (record.visiblePath != null && record.visiblePath!.isNotEmpty);
    if (!hasVisibleCopy) return;

    final cachePath = record.cachePath;
    if (cachePath == null || cachePath.isEmpty) return;

    final nextAbs = record.visiblePath?.isNotEmpty == true
        ? record.visiblePath!
        : record.absPath;
    await ReceivedFileDao.instance.updateExportState(
      messageId: record.messageId,
      exportStatus: record.exportStatus,
      absPath: nextAbs,
      clearCachePath: true,
    );

    final removed = await FileStore.deleteByMessageId(record.messageId);
    if (!removed) {
      unawaited(FileStore.deleteCacheEntryWhenReady(record.messageId));
    }
  }

  Future<bool> _saveToGallery(String path, String fileName) async {
    try {
      final result = await SaverGallery.saveFile(
        filePath: path,
        fileName: fileName,
        skipIfExists: false,
      );
      return result.isSuccess;
    } catch (e) {
      _log.warning('gallery save failed: $e');
      return false;
    }
  }
}

class _ExportResult {
  final String? location;
  final ExportTargetKind targetKind;

  const _ExportResult({required this.location, required this.targetKind});
}
