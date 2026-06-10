import 'dart:io';

import 'package:uuid/uuid.dart';

import '../api/api.dart';
import '../api/s3.dart' as s3_api;
import '../logger.dart';
import 'cancel_token.dart';
import 'cloud_transfer.dart';
import 'file_hash.dart';
import 'file_times_apply.dart';
import 'transfer_protocol.dart';
import 'transfer_record.dart';
import 'transfer_state_manager.dart';
import 'transfer_status.dart';

const _multipartThreshold = 5 * 1024 * 1024; // 5 MB
const _partSize = 10 * 1024 * 1024; // 10 MB per part

class S3TransferService extends CloudTransferService {
  /// 上传/下载统一走后端 presign，客户端直连 S3 URL（密钥不落地）。
  @override
  Future<CloudUploadResult> upload({
    required String fileName,
    required int fileSize,
    String? filePath,
    List<int>? bytes,
    String? contentType,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
  }) async {
    if (bytes == null && filePath == null) {
      throw Exception('无法读取文件');
    }

    if (fileSize >= _multipartThreshold && filePath != null) {
      try {
        return await _hostedBackendMultipartUpload(
          fileName: fileName,
          fileSize: fileSize,
          filePath: filePath,
          contentType: contentType,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      } catch (e) {
        logChat.warning(
          'hosted multipart upload failed, falling back to simple: $e',
        );
      }
    }
    return _hostedBackendUpload(
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      bytes: bytes,
      contentType: contentType,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  }

  /// 经后端 presign 的简单上传。
  Future<CloudUploadResult> _hostedBackendUpload({
    required String fileName,
    required int fileSize,
    String? filePath,
    List<int>? bytes,
    String? contentType,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
  }) async {
    final pres = await s3_api.presignUpload(
      fileName,
      contentType: contentType,
      contentLength: fileSize,
    );
    final uploadUrl = Uri.parse(pres.uploadUrl);
    await _simpleUploadOnce(
      uploadUrl: uploadUrl,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      bytes: bytes,
      contentType: contentType,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    return CloudUploadResult(key: pres.key, fileName: fileName);
  }

  /// Built-in R2 / 任意经后端 presign 的分片上传（无需本地凭证）。
  /// 与 [_multipartUpload] 类似，但所有 multipart 调用都走 `/api/s3/multipart/*`。
  Future<CloudUploadResult> _hostedBackendMultipartUpload({
    required String fileName,
    required int fileSize,
    required String filePath,
    String? contentType,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
  }) async {
    final mgr = TransferStateManager.instance;

    String? fileHash;
    try {
      fileHash = await computeFileHash(filePath);
      logChat.info('hosted multipart file hash=$fileHash');
    } catch (e) {
      logChat.warning('hosted multipart hash computation failed: $e');
    }

    TransferRecord? existing = await mgr.findResumable(
      channel: 's3',
      direction: 'upload',
      fileName: fileName,
      fileSize: fileSize,
    );
    if (existing != null &&
        (existing.s3UploadId == null || existing.s3Key == null)) {
      logChat.info(
        'hosted multipart found stub record, removing and starting fresh',
      );
      await mgr.removeRecord(existing.transferId);
      existing = null;
    }

    String uploadId;
    String key;
    List<CompletedPart> completedParts;
    late TransferRecord record;

    if (existing != null &&
        existing.s3UploadId != null &&
        existing.s3Key != null) {
      record = existing;
      uploadId = existing.s3UploadId!;
      key = existing.s3Key!;
      completedParts = List.of(existing.s3CompletedParts ?? []);
      logChat.info(
        'hosted multipart resume uploadId=$uploadId completed=${completedParts.length}',
      );
    } else {
      final initResp = await s3_api.initiateMultipartUpload(
        fileName,
        contentType: contentType ?? 'application/octet-stream',
      );
      if (cancelToken?.isCancelled == true) throw Exception('已取消');
      uploadId = initResp.uploadId;
      key = initResp.key;
      completedParts = [];

      record = TransferRecord(
        transferId: const Uuid().v4(),
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        channel: 's3',
        direction: 'upload',
        fileHash: fileHash,
        s3UploadId: uploadId,
        s3Key: key,
        s3CompletedParts: [],
      );
      await mgr.saveRecord(record);
    }

    final totalParts = (fileSize / _partSize).ceil();
    final completedNumbers = completedParts.map((p) => p.partNumber).toSet();

    int totalSent = completedParts.fold(0, (sum, p) {
      final start = (p.partNumber - 1) * _partSize;
      final end = (start + _partSize).clamp(0, fileSize);
      return sum + (end - start);
    });
    onProgress?.call(totalSent, fileSize);

    try {
      for (int partNum = 1; partNum <= totalParts; partNum++) {
        if (cancelToken?.isCancelled == true) {
          throw Exception('已取消');
        }

        if (completedNumbers.contains(partNum)) continue;

        final start = (partNum - 1) * _partSize;
        final end = (start + _partSize).clamp(0, fileSize);
        final partLength = end - start;

        final presignedUrl = await s3_api.presignUploadPart(
          uploadId: uploadId,
          key: key,
          partNumber: partNum,
        );

        final eTag = await _uploadPart(
          presignedUrl: presignedUrl,
          filePath: filePath,
          start: start,
          length: partLength,
          contentType: contentType,
          cancelToken: cancelToken,
          onPartProgress: (sent) {
            onProgress?.call(totalSent + sent, fileSize);
          },
        );

        completedParts.add(CompletedPart(partNumber: partNum, eTag: eTag));
        totalSent += partLength;
        onProgress?.call(totalSent, fileSize);

        await mgr.updateProgress(
          record.transferId,
          totalSent,
          completedParts: List.of(completedParts),
        );
      }

      final partsForComplete = completedParts
          .map((p) => {'partNumber': p.partNumber, 'eTag': p.eTag})
          .toList()
        ..sort((a, b) =>
            (a['partNumber'] as int).compareTo(b['partNumber'] as int));

      await s3_api.completeMultipartUpload(
        uploadId: uploadId,
        key: key,
        parts: partsForComplete,
      );

      await mgr.markStatus(record.transferId, TransferStatus.completed);
      onProgress?.call(fileSize, fileSize);
      logChat.info(
        'hosted multipart upload ok key=$key parts=$totalParts',
      );

      return CloudUploadResult(key: key, fileName: fileName);
    } catch (e) {
      if (cancelToken?.isCancelled == true) {
        // User-initiated stop: keep uploadId so we can resume later.
        await mgr.markStatus(record.transferId, TransferStatus.paused);
      } else {
        await mgr.markStatus(record.transferId, TransferStatus.failed);
        try {
          await s3_api.abortMultipartUpload(uploadId: uploadId, key: key);
        } catch (abortErr) {
          logChat.warning('hosted abortMultipartUpload failed: $abortErr');
        }
      }
      rethrow;
    }
  }

  Future<void> _simpleUploadOnce({
    required Uri uploadUrl,
    required String fileName,
    required int fileSize,
    String? filePath,
    List<int>? bytes,
    String? contentType,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
  }) async {
    final total = fileSize;
    final client = HttpClient();
    try {
      final request = await client.putUrl(uploadUrl);
      request.headers.set(
        'Content-Type',
        contentType ?? 'application/octet-stream',
      );
      request.contentLength = total;

      int sent = 0;
      Stream<List<int>> dataStream;
      if (bytes != null) {
        const cs = TransferProtocol.chunkSize;
        dataStream = Stream.fromIterable(
          Iterable.generate(
            (bytes.length / cs).ceil(),
            (i) => bytes.sublist(
              i * cs,
              (i * cs + cs < bytes.length) ? i * cs + cs : bytes.length,
            ),
          ),
        );
      } else {
        dataStream = File(filePath!).openRead();
      }

      await for (final chunk in dataStream) {
        if (cancelToken?.isCancelled == true) {
          request.abort();
          throw Exception('已取消');
        }
        request.add(chunk);
        await request.flush();
        sent += chunk.length;
        onProgress?.call(sent, total);
      }

      if (cancelToken?.isCancelled == true) throw Exception('已取消');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('上传失败 (HTTP ${response.statusCode})');
      }
      onProgress?.call(total, total);
      logChat.info('S3 simple upload ok');
    } finally {
      client.close();
    }
  }

  Future<String> _uploadPart({
    required String presignedUrl,
    required String filePath,
    required int start,
    required int length,
    String? contentType,
    CancelToken? cancelToken,
    void Function(int sent)? onPartProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse(presignedUrl));
      request.headers.set(
        'Content-Type',
        contentType ?? 'application/octet-stream',
      );
      request.contentLength = length;

      int sent = 0;
      final fileStream = File(filePath).openRead(start, start + length);
      await for (final chunk in fileStream) {
        if (cancelToken?.isCancelled == true) {
          request.abort();
          throw Exception('已取消');
        }
        request.add(chunk);
        await request.flush();
        sent += chunk.length;
        onPartProgress?.call(sent);
      }

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('分片上传失败 (HTTP ${response.statusCode})');
      }
      final eTag = response.headers.value('etag') ?? '';
      return eTag;
    } finally {
      client.close();
    }
  }

  @override
  Future<CloudDownloadResult> download({
    required String key,
    required String savePath,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
    int? lastModifiedMs,
  }) async {
    final urlStr = await s3_api.getDownloadUrl(key);
    final downloadUrl = Uri.parse(urlStr);
    logChat.info('S3TransferService download start key=$key');

    final mgr = TransferStateManager.instance;

    // Always download to a `.partial` sidecar file so resume is decoupled
    // from the final file name resolution (which can append " (1)" suffixes
    // when the caller pre-creates the messageId directory).
    TransferRecord? record = await mgr.findResumable(
      channel: 's3',
      direction: 'download',
      s3Key: key,
    );

    final String partialPath;
    if (record?.filePath != null && record!.filePath!.endsWith('.partial')) {
      partialPath = record.filePath!;
    } else {
      partialPath = '$savePath.partial';
    }
    final partialFile = File(partialPath);

    int offset = 0;
    if (await partialFile.exists()) {
      offset = await partialFile.length();
      if (record != null && offset >= record.fileSize && record.fileSize > 0) {
        // Already fully downloaded — finalize without hitting the network.
        await _finalizePartial(partialFile, savePath);
        await applyReceivedFileTimestamps(savePath, lastModifiedMs);
        await mgr.markStatus(record.transferId, TransferStatus.completed);
        onProgress?.call(record.fileSize, record.fileSize);
        return CloudDownloadResult(
          filePath: savePath,
          totalBytes: record.fileSize,
        );
      }
      logChat.info(
        'S3 download resume partial=$partialPath offset=$offset',
      );
    }

    final client = HttpClient();
    int received = offset;
    try {
      final request = await client.getUrl(downloadUrl);
      if (offset > 0) {
        request.headers.set('Range', 'bytes=$offset-');
      }
      // Wire cancel to abort the inflight HTTP request promptly.
      cancelToken?.onCancel(() {
        try {
          request.abort();
        } catch (_) {}
      });
      final response = await request.close();

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('下载失败 (HTTP ${response.statusCode})');
      }

      int contentLength;
      if (response.statusCode == 206) {
        contentLength = offset + response.contentLength;
      } else {
        contentLength = response.contentLength;
      }

      if (record == null) {
        record = TransferRecord(
          transferId: const Uuid().v4(),
          fileName: savePath.split('/').last,
          fileSize: contentLength,
          filePath: partialPath,
          channel: 's3',
          direction: 'download',
          s3Key: key,
          transferredBytes: offset,
        );
        await mgr.saveRecord(record);
      } else if (record.filePath != partialPath) {
        await mgr.updateFilePath(record.transferId, partialPath);
        record.filePath = partialPath;
      }

      // Ensure the partial file's parent directory exists.
      final parent = partialFile.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      final rec = record;
      final out = partialFile.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response) {
          if (cancelToken?.isCancelled == true) {
            throw Exception('已取消');
          }
          out.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            onProgress?.call(received, contentLength);
          }
          if (contentLength > 0 &&
              (received - rec.transferredBytes) * 50 > contentLength) {
            rec.transferredBytes = received;
            await mgr.updateProgress(rec.transferId, received);
          }
        }
      } finally {
        await out.close();
      }

      if (cancelToken?.isCancelled == true) {
        // Race: cancel arrived between final chunk and the loop exit.
        throw Exception('已取消');
      }

      await _finalizePartial(partialFile, savePath);
      await applyReceivedFileTimestamps(savePath, lastModifiedMs);
      await mgr.markStatus(rec.transferId, TransferStatus.completed);
    } catch (e) {
      if (record != null) {
        record.transferredBytes = received;
        await mgr.updateProgress(record.transferId, received);
        if (cancelToken?.isCancelled == true) {
          await mgr.markStatus(record.transferId, TransferStatus.paused);
        } else {
          await mgr.markStatus(record.transferId, TransferStatus.failed);
        }
      }
      rethrow;
    } finally {
      client.close();
    }
    logChat.info(
      'S3TransferService download ok path=$savePath bytes=$received',
    );
    return CloudDownloadResult(filePath: savePath, totalBytes: received);
  }

  Future<void> _finalizePartial(File partial, String finalPath) async {
    final finalFile = File(finalPath);
    if (await finalFile.exists()) {
      try {
        await finalFile.delete();
      } catch (_) {}
    }
    try {
      await partial.rename(finalPath);
    } catch (_) {
      await partial.copy(finalPath);
      try {
        await partial.delete();
      } catch (_) {}
    }
  }
}
