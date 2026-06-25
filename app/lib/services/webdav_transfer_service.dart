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
import 'transfer_error_message.dart';
import 'transfer_record.dart';
import 'transfer_state_manager.dart';
import 'transfer_status.dart';
import 'webdav_cstcloud.dart';
import 'webdav_path_preparer.dart';
import 'webdav_session.dart';
import 'webdav_transfer_progress_summary.dart';
import 'webdav_upload_concurrency_pref.dart';
import 'webdav_upload_job.dart';
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
  final String? errorMessage;

  const WebDavTransferSnapshot({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.transferredBytes,
    required this.direction,
    required this.status,
    required this.bytesPerSecond,
    this.webdavRemotePath,
    this.errorMessage,
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
  final _uploadSemaphore =
      AsyncSemaphore(webDavUploadConcurrencyDefault);
  final Set<WebDavUploadCompleted> _uploadCompletedListeners = {};
  final Set<WebDavDownloadCompleted> _downloadCompletedListeners = {};
  final Map<int, int> _uploadBatchTotal = {};
  final Map<int, int> _uploadBatchSucceeded = {};
  final Map<int, int> _uploadBatchFailed = {};
  final Map<int, Set<WebDavUploadJobHandle>> _uploadJobsByConnection = {};

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

    final maxConcurrency = await loadWebDavUploadConcurrencyPref();
    _uploadSemaphore.updateMaxConcurrent(maxConcurrency);

    _uploadBatchTotal[connection.id] =
        (_uploadBatchTotal[connection.id] ?? 0) + files.length;
    notifyListeners();

    for (final file in files) {
      final handle = _registerUploadJob(
        connectionId: connection.id,
        localPath: file.localPath,
        remotePath: file.remotePath,
        fileName: file.name,
        fileSize: file.size,
        ensureParent: false,
      );
      unawaited(
        _uploadSemaphore.run(
          () => _runUpload(
            client: client,
            connection: connection,
            handle: handle,
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
        await _markTransferFailed(
          transferId: transferId,
          fileName: entry.name,
          fileSize: fileSize,
          transferredBytes: record.transferredBytes,
          direction: 'download',
          remotePath: entry.path,
          error: e,
          tracker: tracker,
        );
      }
      return false;
    } catch (e) {
      await _flushProgressPersist(transferId);
      await _markTransferFailed(
        transferId: transferId,
        fileName: entry.name,
        fileSize: fileSize,
        transferredBytes: record.transferredBytes,
        direction: 'download',
        remotePath: entry.path,
        error: e,
        tracker: tracker,
      );
      return false;
    } finally {
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
    }
  }

  Future<void> _runUpload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required WebDavUploadJobHandle handle,
  }) async {
    final heldPath = handle.localPath;
    final remotePath = handle.remotePath;
    final fileName = handle.fileName;
    final fileSize = handle.fileSize;
    final ensureParent = handle.ensureParent;

    try {
      if (_shouldStopUploadJob(handle)) {
        await _handleUploadJobStopped(
          connectionId: connection.id,
          handle: handle,
          transferId: handle.transferId,
        );
        return;
      }

      final resolved = await resolveUploadLocalFile(
        localPath: handle.localPath,
        fileName: fileName,
        cachedSize: fileSize,
      );
      if (resolved == null) {
        PendingDispatchBridge.notifySettled(heldPath, success: false);
        _recordUploadBatchFailure(connection.id);
        return;
      }

      if (_shouldStopUploadJob(handle)) {
        await _handleUploadJobStopped(
          connectionId: connection.id,
          handle: handle,
          transferId: handle.transferId,
          filePath: resolved.path,
          fileName: resolved.fileName,
          fileSize: resolved.size,
        );
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

      if (_shouldStopUploadJob(handle)) {
        await _handleUploadJobStopped(
          connectionId: connection.id,
          handle: handle,
          transferId: handle.transferId,
          filePath: resolved.path,
          fileName: resolved.fileName,
          fileSize: resolved.size,
        );
        return;
      }

      final uploadPath = resolved.path;
      final uploadName = resolved.fileName;
      final uploadSize = resolved.size;

      final connKey = webDavConnectionKey(connection.id);
      final transferId =
          'webdav_${connKey}_ul_${remotePath.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
      handle.transferId = transferId;
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

      if (_shouldStopUploadJob(handle)) {
        cancelToken.cancel();
        await _handleUploadJobStopped(
          connectionId: connection.id,
          handle: handle,
          transferId: transferId,
          filePath: uploadPath,
          fileName: uploadName,
          fileSize: uploadSize,
          transferredBytes: record.transferredBytes,
          tracker: tracker,
        );
        return;
      }

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
      final transferId = handle.transferId;
      if (transferId != null) {
        await _flushProgressPersist(transferId);
      }
      if (transferId != null && CancelToken.isCancel(e)) {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.paused,
        );
        final tracker = _speedTrackers[transferId];
        final record = await TransferStateManager.instance.getRecord(transferId);
        _updateSnapshot(
          transferId: transferId,
          fileName: handle.fileName,
          fileSize: handle.fileSize,
          transferredBytes: record?.transferredBytes ?? 0,
          direction: 'upload',
          status: TransferStatus.paused,
          tracker: tracker ?? SpeedTracker(),
          remotePath: remotePath,
        );
      } else if (transferId != null) {
        await _markTransferFailed(
          transferId: transferId,
          fileName: handle.fileName,
          fileSize: handle.fileSize,
          transferredBytes:
              (await TransferStateManager.instance.getRecord(transferId))
                      ?.transferredBytes ??
                  0,
          direction: 'upload',
          remotePath: remotePath,
          error: e,
          tracker: _speedTrackers[transferId],
        );
        PendingDispatchBridge.notifySettled(heldPath, success: false);
        _recordUploadBatchFailure(connection.id);
      } else {
        PendingDispatchBridge.notifySettled(heldPath, success: false);
        _recordUploadBatchFailure(connection.id);
      }
    } catch (e) {
      final transferId = handle.transferId;
      if (transferId != null && _snapshots.containsKey(transferId)) {
        await _markTransferFailed(
          transferId: transferId,
          fileName: handle.fileName,
          fileSize: handle.fileSize,
          transferredBytes:
              (await TransferStateManager.instance.getRecord(transferId))
                      ?.transferredBytes ??
                  0,
          direction: 'upload',
          remotePath: remotePath,
          error: e,
          tracker: _speedTrackers[transferId],
        );
      }
      PendingDispatchBridge.notifySettled(heldPath, success: false);
      _recordUploadBatchFailure(connection.id);
    } finally {
      final transferId = handle.transferId;
      if (transferId != null) {
        _cancelTokens.remove(transferId);
        _speedTrackers.remove(transferId);
        _clearProgressPersist(transferId);
      }
      _unregisterUploadJob(handle);
    }
  }

  WebDavUploadJobHandle _registerUploadJob({
    required int connectionId,
    required String localPath,
    required String remotePath,
    required String fileName,
    required int fileSize,
    bool ensureParent = true,
  }) {
    final handle = WebDavUploadJobHandle(
      connectionId: connectionId,
      localPath: localPath,
      remotePath: remotePath,
      fileName: fileName,
      fileSize: fileSize,
      ensureParent: ensureParent,
    );
    _uploadJobsByConnection
        .putIfAbsent(connectionId, () => <WebDavUploadJobHandle>{})
        .add(handle);
    return handle;
  }

  void _unregisterUploadJob(WebDavUploadJobHandle handle) {
    final jobs = _uploadJobsByConnection[handle.connectionId];
    jobs?.remove(handle);
    if (jobs != null && jobs.isEmpty) {
      _uploadJobsByConnection.remove(handle.connectionId);
    }
  }

  Set<WebDavUploadJobHandle> _uploadJobsFor(int connectionId) {
    return Set<WebDavUploadJobHandle>.from(
      _uploadJobsByConnection[connectionId] ?? const {},
    );
  }

  bool _shouldStopUploadJob(WebDavUploadJobHandle handle) => handle.isStopped;

  Future<void> _handleUploadJobStopped({
    required int connectionId,
    required WebDavUploadJobHandle handle,
    String? transferId,
    String? filePath,
    String? fileName,
    int? fileSize,
    int transferredBytes = 0,
    SpeedTracker? tracker,
  }) async {
    if (handle.isTerminated) {
      if (transferId != null) {
        await TransferStateManager.instance.removeRecord(transferId);
        _snapshots.remove(transferId);
        _cancelTokens.remove(transferId);
        _speedTrackers.remove(transferId);
        _clearProgressPersist(transferId);
      }
      PendingDispatchBridge.notifySettled(handle.localPath, success: false);
      _recordUploadBatchFailure(connectionId);
      notifyListeners();
      return;
    }

    final resolvedName = fileName ?? handle.fileName;
    final resolvedSize = fileSize ?? handle.fileSize;
    final resolvedPath = filePath ?? handle.localPath;
    final resolvedTransferId = transferId ??
        handle.transferId ??
        await _ensurePausedUploadRecord(
          connectionId: connectionId,
          fileName: resolvedName,
          fileSize: resolvedSize,
          filePath: resolvedPath,
          remotePath: handle.remotePath,
          transferredBytes: transferredBytes,
        );
    handle.transferId = resolvedTransferId;

    await TransferStateManager.instance.markStatus(
      resolvedTransferId,
      TransferStatus.paused,
    );
    _updateSnapshot(
      transferId: resolvedTransferId,
      fileName: resolvedName,
      fileSize: resolvedSize,
      transferredBytes: transferredBytes,
      direction: 'upload',
      status: TransferStatus.paused,
      tracker: tracker ?? SpeedTracker(),
      remotePath: handle.remotePath,
    );
  }

  Future<String> _ensurePausedUploadRecord({
    required int connectionId,
    required String fileName,
    required int fileSize,
    required String filePath,
    required String remotePath,
    int transferredBytes = 0,
  }) async {
    final connKey = webDavConnectionKey(connectionId);
    final transferId =
        'webdav_${connKey}_ul_${remotePath.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    final record = TransferRecord(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      channel: 'webdav',
      direction: 'upload',
      status: TransferStatus.paused,
      transferredBytes: transferredBytes,
      webdavConnectionId: connKey,
      webdavRemotePath: remotePath,
    );
    await TransferStateManager.instance.saveRecord(record);
    return transferId;
  }

  Future<void> pause(String transferId) async {
    _cancelTokens[transferId]?.cancel();
    for (final jobs in _uploadJobsByConnection.values) {
      for (final handle in jobs) {
        if (handle.transferId == transferId) {
          handle.stopReason = WebDavUploadJobStopReason.paused;
          return;
        }
      }
    }
  }

  Future<void> pauseAll(int connectionId) async {
    for (final handle in _uploadJobsFor(connectionId)) {
      handle.stopReason = WebDavUploadJobStopReason.paused;
      if (handle.transferId == null) {
        await _handleUploadJobStopped(
          connectionId: connectionId,
          handle: handle,
        );
      }
    }

    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    for (final id in _cancelTokens.keys.toList()) {
      if (id.startsWith(prefix)) {
        await pause(id);
      }
    }
    notifyListeners();
  }

  Future<void> terminateAllUploads(int connectionId) async {
    final connKey = webDavConnectionKey(connectionId);
    final prefix = 'webdav_${connKey}_';

    for (final handle in _uploadJobsFor(connectionId)) {
      handle.stopReason = WebDavUploadJobStopReason.terminated;
    }

    for (final id in _cancelTokens.keys.toList()) {
      if (id.startsWith(prefix)) {
        _cancelTokens[id]?.cancel();
      }
    }

    final rows = await TransferStateManager.instance.listWebDavTransfers(
      connectionId: connKey,
      activeOnly: true,
    );

    final restoredPaths = <String>{};
    for (final record in rows) {
      if (record.direction == 'upload') {
        final path = record.filePath;
        if (path != null && path.isNotEmpty && restoredPaths.add(path)) {
          PendingDispatchBridge.notifySettled(path, success: false);
          _recordUploadBatchFailure(connectionId);
        }
      }
      await TransferStateManager.instance.removeRecord(record.transferId);
      _snapshots.remove(record.transferId);
      _cancelTokens.remove(record.transferId);
      _speedTrackers.remove(record.transferId);
      _clearProgressPersist(record.transferId);
    }

    for (final handle in _uploadJobsFor(connectionId)) {
      if (handle.localPath.isNotEmpty && restoredPaths.add(handle.localPath)) {
        PendingDispatchBridge.notifySettled(handle.localPath, success: false);
        _recordUploadBatchFailure(connectionId);
      }
    }
    _uploadJobsByConnection.remove(connectionId);

    clearUploadBatchProgress(connectionId);
    notifyListeners();
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

    final handle = _registerUploadJob(
      connectionId: connection.id,
      localPath: record.filePath!,
      remotePath: record.webdavRemotePath!,
      fileName: record.fileName,
      fileSize: record.fileSize,
    );
    unawaited(
      _uploadSemaphore.run(
        () => _runUpload(
          client: client,
          connection: connection,
          handle: handle,
        ),
      ),
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
        errorMessage: r.errorMessage,
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

  Future<void> _markTransferFailed({
    required String transferId,
    required String fileName,
    required int fileSize,
    required int transferredBytes,
    required String direction,
    required String remotePath,
    required Object error,
    SpeedTracker? tracker,
  }) async {
    final message = formatTransferErrorMessage(error);
    await TransferStateManager.instance.markFailed(transferId, message);
    _updateSnapshot(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      transferredBytes: transferredBytes,
      direction: direction,
      status: TransferStatus.failed,
      tracker: tracker ?? SpeedTracker(),
      remotePath: remotePath,
      errorMessage: message,
    );
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
    String? errorMessage,
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
      errorMessage: errorMessage,
    );
    notifyListeners();
  }
}
