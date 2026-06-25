import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/webdav.dart';
import '../logger.dart';
import '../providers/auth_provider.dart';
import 'async_semaphore.dart';
import 'file_store.dart';
import 'received_file_dao.dart';
import 'pending_dispatch_bridge.dart';
import 'received_file_index_pipeline.dart';
import 'speed_tracker.dart';
import 'transfer_record.dart';
import 'transfer_state_manager.dart';
import 'transfer_status.dart';
import 'webdav_cstcloud.dart';
import 'webdav_path_preparer.dart';
import 'webdav_session.dart';
import 'webdav_transfer_progress_summary.dart';
import 'webdav_upload_local_resolver.dart';
import 'visible_export_target.dart';

export 'webdav_upload_layout.dart' show webDavRemoteParentPath, collectSortedParentDirs;

/// Stable received_files key for a WebDAV remote file.
String webDavMessageId(int connectionId, String remotePath) {
  final key = connectionId.toString();
  final hash = Object.hash(key, remotePath);
  return 'webdav_${key}_${hash.abs()}';
}

String webDavConnectionKey(int connectionId) => connectionId.toString();

typedef WebDavUploadCompleted = void Function({
  required int connectionId,
  required String remotePath,
});

typedef WebDavDownloadCompleted = void Function({
  required int connectionId,
  required String remotePath,
  required String localPath,
});

class WebDavTransferSnapshot {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int transferredBytes;
  final String direction;
  final String status;
  final double bytesPerSecond;
  final String? webdavRemotePath;

  const WebDavTransferSnapshot({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.transferredBytes,
    required this.direction,
    required this.status,
    required this.bytesPerSecond,
    this.webdavRemotePath,
  });

  int get progressPercent =>
      fileSize > 0 ? (transferredBytes * 100 ~/ fileSize).clamp(0, 100) : 0;

  bool get isActive =>
      status == TransferStatus.inProgress || status == TransferStatus.paused;
}

class WebDavTransferService extends ChangeNotifier {
  WebDavTransferService._();
  static final instance = WebDavTransferService._();

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, SpeedTracker> _speedTrackers = {};
  final Map<String, WebDavTransferSnapshot> _snapshots = {};
  final Map<String, int> _pendingProgressBytes = {};
  final Map<String, int> _lastPersistedBytes = {};
  final Map<String, DateTime> _lastProgressPersist = {};
  static const _progressPersistInterval = Duration(milliseconds: 500);
  static const _uploadConcurrency = 6;
  final _uploadSemaphore = AsyncSemaphore(_uploadConcurrency);
  final Set<WebDavUploadCompleted> _uploadCompletedListeners = {};
  final Set<WebDavDownloadCompleted> _downloadCompletedListeners = {};
  final Map<int, int> _uploadBatchTotal = {};
  final Map<int, int> _uploadBatchSucceeded = {};
  final Map<int, int> _uploadBatchFailed = {};

  List<WebDavTransferSnapshot> snapshotsFor(String connectionId) {
    return _snapshots.values
        .where((s) => s.transferId.contains(connectionId))
        .toList();
  }

  List<WebDavTransferSnapshot> get allSnapshots =>
      List.unmodifiable(_snapshots.values);

  int activeCountFor(int connectionId) {
    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    return _snapshots.values
        .where((s) => s.isActive && s.transferId.startsWith(prefix))
        .length;
  }

  WebDavTransferProgressSummary progressSummaryFor(int connectionId) {
    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    final connSnapshots = _snapshots.values
        .where((s) => s.transferId.startsWith(prefix))
        .toList();

    final uploadSnapshots =
        connSnapshots.where((s) => s.direction == 'upload').toList();
    final downloadSnapshots =
        connSnapshots.where((s) => s.direction == 'download').toList();

    final uploadActive = uploadSnapshots
        .where((s) => s.status == TransferStatus.inProgress)
        .length;
    final downloadActive = downloadSnapshots
        .where((s) => s.status == TransferStatus.inProgress)
        .length;

    final uploadSpeed = uploadSnapshots.fold<double>(
      0,
      (sum, s) => sum + s.bytesPerSecond,
    );
    final downloadSpeed = downloadSnapshots.fold<double>(
      0,
      (sum, s) => sum + s.bytesPerSecond,
    );

    final batchTotal = _uploadBatchTotal[connectionId] ?? 0;
    final succeeded = _uploadBatchSucceeded[connectionId] ?? 0;
    final failed = _uploadBatchFailed[connectionId] ?? 0;
    final settled = succeeded + failed;
    final queued = (batchTotal - settled - uploadActive).clamp(0, batchTotal);

    final transferredBytes = uploadSnapshots.fold<int>(
      0,
      (sum, s) => sum + s.transferredBytes,
    );
    final totalBytes = uploadSnapshots.fold<int>(
      0,
      (sum, s) => sum + s.fileSize,
    );

    return WebDavTransferProgressSummary(
      uploadBatchTotal: batchTotal,
      uploadSucceeded: succeeded,
      uploadFailed: failed,
      uploadActive: uploadActive,
      uploadQueued: queued,
      uploadSpeedBps: uploadSpeed,
      uploadTransferredBytes: transferredBytes,
      uploadTotalBytes: totalBytes,
      downloadActive: downloadActive,
      downloadSpeedBps: downloadSpeed,
    );
  }

  void clearUploadBatchProgress(int connectionId) {
    _uploadBatchTotal.remove(connectionId);
    _uploadBatchSucceeded.remove(connectionId);
    _uploadBatchFailed.remove(connectionId);
    notifyListeners();
  }

  void _recordUploadBatchSuccess(int connectionId) {
    _uploadBatchSucceeded[connectionId] =
        (_uploadBatchSucceeded[connectionId] ?? 0) + 1;
    _maybeFinishUploadBatch(connectionId);
    notifyListeners();
  }

  void _recordUploadBatchFailure(int connectionId) {
    _uploadBatchFailed[connectionId] =
        (_uploadBatchFailed[connectionId] ?? 0) + 1;
    _maybeFinishUploadBatch(connectionId);
    notifyListeners();
  }

  void _maybeFinishUploadBatch(int connectionId) {
    final total = _uploadBatchTotal[connectionId] ?? 0;
    if (total <= 0) return;
    final settled = (_uploadBatchSucceeded[connectionId] ?? 0) +
        (_uploadBatchFailed[connectionId] ?? 0);
    if (settled < total) return;
    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    final uploadActive = _snapshots.values.where(
      (s) =>
          s.transferId.startsWith(prefix) &&
          s.direction == 'upload' &&
          s.status == TransferStatus.inProgress,
    );
    if (uploadActive.isNotEmpty) return;
  }

  void addUploadCompletedListener(WebDavUploadCompleted listener) {
    _uploadCompletedListeners.add(listener);
  }

  void removeUploadCompletedListener(WebDavUploadCompleted listener) {
    _uploadCompletedListeners.remove(listener);
  }

  void _notifyUploadCompleted({
    required int connectionId,
    required String remotePath,
  }) {
    for (final listener in _uploadCompletedListeners) {
      listener(connectionId: connectionId, remotePath: remotePath);
    }
  }

  void addDownloadCompletedListener(WebDavDownloadCompleted listener) {
    _downloadCompletedListeners.add(listener);
  }

  void removeDownloadCompletedListener(WebDavDownloadCompleted listener) {
    _downloadCompletedListeners.remove(listener);
  }

  void _notifyDownloadCompleted({
    required int connectionId,
    required String remotePath,
    required String localPath,
  }) {
    for (final listener in _downloadCompletedListeners) {
      listener(
        connectionId: connectionId,
        remotePath: remotePath,
        localPath: localPath,
      );
    }
  }

  Future<String?> _resolveUserId() async {
    final uid = await getStoredUserId();
    if (uid != null && uid.isNotEmpty) return uid;
    return getOrCreateOfflineUserId();
  }

  Future<void> enqueueDownloads({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required List<WebDavEntry> entries,
  }) async {
    for (final entry in entries) {
      if (entry.isDirectory) continue;
      unawaited(
        _runDownload(
          client: client,
          connection: connection,
          entry: entry,
        ),
      );
    }
  }

  Future<int> enqueueUploads({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required String relativeDir,
    required List<({
      String name,
      String localPath,
      int size,
      String remotePath,
    })> files,
  }) async {
    if (cstCloudWebDavBlocksGeneralUpload(connection.baseUrl)) {
      return 0;
    }
    if (files.isEmpty) return 0;

    _uploadBatchTotal[connection.id] =
        (_uploadBatchTotal[connection.id] ?? 0) + files.length;
    notifyListeners();

    for (final file in files) {
      unawaited(
        _uploadSemaphore.run(
          () => _runUpload(
            client: client,
            connection: connection,
            remotePath: file.remotePath,
            localPath: file.localPath,
            fileName: file.name,
            fileSize: file.size,
            ensureParent: false,
          ),
        ),
      );
    }
    return files.length;
  }

  Future<bool> _runDownload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required WebDavEntry entry,
  }) async {
    final connKey = webDavConnectionKey(connection.id);
    final messageId = webDavMessageId(connection.id, entry.path);
    final transferId =
        'webdav_${connKey}_dl_${entry.path.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    final fileSize = entry.size ?? await client.fileSize(entry.path) ?? 0;
    final cancelToken = CancelToken();
    _cancelTokens[transferId] = cancelToken;
    final tracker = SpeedTracker();
    _speedTrackers[transferId] = tracker;

    final record = TransferRecord(
      transferId: transferId,
      fileName: entry.name,
      fileSize: fileSize,
      channel: 'webdav',
      direction: 'download',
      webdavConnectionId: connKey,
      webdavRemotePath: entry.path,
    );
    await TransferStateManager.instance.saveRecord(record);
    _updateSnapshot(
      transferId: transferId,
      fileName: entry.name,
      fileSize: fileSize,
      transferredBytes: 0,
      direction: 'download',
      status: TransferStatus.inProgress,
      tracker: tracker,
      remotePath: entry.path,
    );

    try {
      final savePath = await FileStore.buildReceivePath(messageId, entry.name);
      await client.downloadFile(
        entry.path,
        savePath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final totalBytes = total > 0 ? total : fileSize;
          tracker.update(received);
          _scheduleProgressPersist(transferId, received);
          _updateSnapshot(
            transferId: transferId,
            fileName: entry.name,
            fileSize: totalBytes > 0 ? totalBytes : fileSize,
            transferredBytes: received,
            direction: 'download',
            status: TransferStatus.inProgress,
            tracker: tracker,
            remotePath: entry.path,
          );
        },
      );

      await _flushProgressPersist(transferId);

      final uid = await _resolveUserId();
      final exportOk =
          await ReceivedFileIndexPipeline.instance.upsertAndExportInline(
        messageId: messageId,
        upsert: () => ReceivedFileDao.instance.upsert(
          messageId: messageId,
          absPath: savePath,
          cachePath: savePath,
          exportStatus: ExportStatus.pending,
          userId: uid,
          threadKey: 'webdav:$connKey',
          protocol: 'webdav',
          size: fileSize > 0 ? fileSize : WebDavClient.localFileSize(savePath),
          mtime: entry.lastModified,
        ),
      );

      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.completed,
      );
      _notifyDownloadCompleted(
        connectionId: connection.id,
        remotePath: entry.path,
        localPath: savePath,
      );
      _snapshots.remove(transferId);
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
      notifyListeners();
      return exportOk;
    } on DioException catch (e) {
      await _flushProgressPersist(transferId);
      if (CancelToken.isCancel(e)) {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.paused,
        );
        _updateSnapshot(
          transferId: transferId,
          fileName: entry.name,
          fileSize: fileSize,
          transferredBytes: record.transferredBytes,
          direction: 'download',
          status: TransferStatus.paused,
          tracker: tracker,
          remotePath: entry.path,
        );
      } else {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.failed,
        );
        _snapshots.remove(transferId);
        _cancelTokens.remove(transferId);
        _speedTrackers.remove(transferId);
        _clearProgressPersist(transferId);
        notifyListeners();
      }
      return false;
    } catch (_) {
      await _flushProgressPersist(transferId);
      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.failed,
      );
      _snapshots.remove(transferId);
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
      notifyListeners();
      return false;
    }
  }

  Future<void> _runUpload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required String remotePath,
    required String localPath,
    required String fileName,
    required int fileSize,
    bool ensureParent = true,
  }) async {
    final heldPath = localPath;
    final resolved = await resolveUploadLocalFile(
      localPath: localPath,
      fileName: fileName,
      cachedSize: fileSize,
    );
    if (resolved == null) {
      PendingDispatchBridge.notifySettled(heldPath, success: false);
      _recordUploadBatchFailure(connection.id);
      return;
    }

    final preparer = WebDavPathPreparer(
      connectionId: connection.id,
      client: client,
    );
    try {
      await preparer.ensureParentsForRemoteFile(remotePath);
    } catch (e, st) {
      logSettings.warning(
        'WebDAV ensureParents failed path=$remotePath',
        e,
        st,
      );
      PendingDispatchBridge.notifySettled(heldPath, success: false);
      _recordUploadBatchFailure(connection.id);
      return;
    }

    final uploadPath = resolved.path;
    final uploadName = resolved.fileName;
    final uploadSize = resolved.size;

    final connKey = webDavConnectionKey(connection.id);
    final transferId =
        'webdav_${connKey}_ul_${remotePath.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    final cancelToken = CancelToken();
    _cancelTokens[transferId] = cancelToken;
    final tracker = SpeedTracker();
    _speedTrackers[transferId] = tracker;

    final record = TransferRecord(
      transferId: transferId,
      fileName: uploadName,
      fileSize: uploadSize,
      filePath: uploadPath,
      channel: 'webdav',
      direction: 'upload',
      webdavConnectionId: connKey,
      webdavRemotePath: remotePath,
    );

    try {
      await TransferStateManager.instance.saveRecord(record);
      _updateSnapshot(
        transferId: transferId,
        fileName: uploadName,
        fileSize: uploadSize,
        transferredBytes: 0,
        direction: 'upload',
        status: TransferStatus.inProgress,
        tracker: tracker,
        remotePath: remotePath,
      );

      await client.uploadFileFromPath(
        remotePath,
        uploadPath,
        cancelToken: cancelToken,
        ensureParent: ensureParent,
        onProgress: (sent, total) {
          final totalBytes = total > 0 ? total : uploadSize;
          tracker.update(sent);
          _scheduleProgressPersist(transferId, sent);
          _updateSnapshot(
            transferId: transferId,
            fileName: uploadName,
            fileSize: totalBytes > 0 ? totalBytes : uploadSize,
            transferredBytes: sent,
            direction: 'upload',
            status: TransferStatus.inProgress,
            tracker: tracker,
            remotePath: remotePath,
          );
        },
      );
      await _flushProgressPersist(transferId);
      _notifyUploadCompleted(
        connectionId: connection.id,
        remotePath: remotePath,
      );
      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.completed,
      );
      _snapshots.remove(transferId);
      notifyListeners();
      PendingDispatchBridge.notifySettled(heldPath, success: true);
      _recordUploadBatchSuccess(connection.id);
    } on DioException catch (e) {
      await _flushProgressPersist(transferId);
      if (CancelToken.isCancel(e)) {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.paused,
        );
        _updateSnapshot(
          transferId: transferId,
          fileName: uploadName,
          fileSize: uploadSize,
          transferredBytes: record.transferredBytes,
          direction: 'upload',
          status: TransferStatus.paused,
          tracker: tracker,
          remotePath: remotePath,
        );
        PendingDispatchBridge.notifySettled(heldPath, success: false);
        _recordUploadBatchFailure(connection.id);
      } else {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.failed,
        );
        _snapshots.remove(transferId);
        notifyListeners();
        PendingDispatchBridge.notifySettled(heldPath, success: false);
        _recordUploadBatchFailure(connection.id);
      }
    } catch (_) {
      if (_snapshots.containsKey(transferId)) {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.failed,
        );
        _snapshots.remove(transferId);
        notifyListeners();
      }
      PendingDispatchBridge.notifySettled(heldPath, success: false);
      _recordUploadBatchFailure(connection.id);
    } finally {
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
    }
  }

  Future<void> pause(String transferId) async {
    _cancelTokens[transferId]?.cancel();
  }

  Future<void> pauseAll(int connectionId) async {
    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    for (final id in _cancelTokens.keys.toList()) {
      if (id.startsWith(prefix)) {
        await pause(id);
      }
    }
  }

  Future<void> resumeDownload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required TransferRecord record,
  }) async {
    if (record.webdavRemotePath == null) return;
    final entry = WebDavEntry(
      name: record.fileName,
      path: record.webdavRemotePath!,
      isDirectory: false,
      size: record.fileSize,
    );
    await TransferStateManager.instance.removeRecord(record.transferId);
    _snapshots.remove(record.transferId);
    await _runDownload(
      client: client,
      connection: connection,
      entry: entry,
    );
  }

  Future<void> resumeUpload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required TransferRecord record,
  }) async {
    if (record.webdavRemotePath == null || record.filePath == null) return;
    await TransferStateManager.instance.removeRecord(record.transferId);
    _snapshots.remove(record.transferId);
    await _runUpload(
      client: client,
      connection: connection,
      remotePath: record.webdavRemotePath!,
      localPath: record.filePath!,
      fileName: record.fileName,
      fileSize: record.fileSize,
    );
  }

  /// Restores in-progress rows from SQLite after cold start. Does not notify.
  Future<void> restorePersistedSnapshots(int connectionId) async {
    final rows = await TransferStateManager.instance.listWebDavTransfers(
      connectionId: webDavConnectionKey(connectionId),
      activeOnly: true,
    );
    for (final r in rows) {
      if (_snapshots.containsKey(r.transferId)) continue;
      _snapshots[r.transferId] = WebDavTransferSnapshot(
        transferId: r.transferId,
        fileName: r.fileName,
        fileSize: r.fileSize,
        transferredBytes: r.transferredBytes,
        direction: r.direction,
        status: r.status,
        bytesPerSecond: 0,
        webdavRemotePath: r.webdavRemotePath,
      );
    }
  }

  void _scheduleProgressPersist(String transferId, int bytes) {
    _pendingProgressBytes[transferId] = bytes;
    final last = _lastProgressPersist[transferId];
    final lastBytes = _lastPersistedBytes[transferId] ?? 0;
    final now = DateTime.now();
    if (last != null &&
        now.difference(last) < _progressPersistInterval &&
        (bytes - lastBytes).abs() < 256 * 1024) {
      return;
    }
    unawaited(_flushProgressPersist(transferId));
  }

  Future<void> _flushProgressPersist(String transferId) async {
    final bytes = _pendingProgressBytes[transferId];
    if (bytes == null) return;
    if (_lastPersistedBytes[transferId] == bytes) return;
    _lastPersistedBytes[transferId] = bytes;
    _lastProgressPersist[transferId] = DateTime.now();
    await TransferStateManager.instance.updateProgress(transferId, bytes);
  }

  void _clearProgressPersist(String transferId) {
    _pendingProgressBytes.remove(transferId);
    _lastPersistedBytes.remove(transferId);
    _lastProgressPersist.remove(transferId);
  }

  void _updateSnapshot({
    required String transferId,
    required String fileName,
    required int fileSize,
    required int transferredBytes,
    required String direction,
    required String status,
    required SpeedTracker tracker,
    String? remotePath,
  }) {
    _snapshots[transferId] = WebDavTransferSnapshot(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      transferredBytes: transferredBytes,
      direction: direction,
      status: status,
      bytesPerSecond: tracker.bytesPerSecond,
      webdavRemotePath: remotePath,
    );
    notifyListeners();
  }
}
