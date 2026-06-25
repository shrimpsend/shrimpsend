import 'dart:convert';

class CompletedPart {
  final int partNumber;
  final String eTag;
  CompletedPart({required this.partNumber, required this.eTag});

  Map<String, dynamic> toJson() => {'partNumber': partNumber, 'eTag': eTag};

  factory CompletedPart.fromJson(Map<String, dynamic> j) => CompletedPart(
    partNumber: j['partNumber'] as int,
    eTag: j['eTag'] as String,
  );
}

class TransferRecord {
  final String transferId;
  final String fileName;
  final int fileSize;
  String? filePath;
  final String channel; // 's3' | 'lan' | 'webrtc' | 'webdav'
  final String direction; // 'upload' | 'download'
  String status; // 'in_progress' | 'paused' | 'completed' | 'failed'
  int transferredBytes;
  String? fileHash;
  final DateTime createdAt;
  DateTime updatedAt;

  // S3 multipart upload
  String? s3UploadId;
  String? s3Key;
  List<CompletedPart>? s3CompletedParts;

  // LAN
  String? lanTargetUrl;
  int? lanResumeOffset;
  List<String>? lanTargetDeviceIds;

  // WebRTC
  String? webrtcFileId;
  int? webrtcOffset;
  String? webrtcTargetDeviceId;

  // WebDAV
  String? webdavConnectionId;
  String? webdavRemotePath;
  String? errorMessage;

  TransferRecord({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    this.filePath,
    required this.channel,
    required this.direction,
    this.status = 'in_progress',
    this.transferredBytes = 0,
    this.fileHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.s3UploadId,
    this.s3Key,
    this.s3CompletedParts,
    this.lanTargetUrl,
    this.lanResumeOffset,
    this.lanTargetDeviceIds,
    this.webrtcFileId,
    this.webrtcOffset,
    this.webrtcTargetDeviceId,
    this.webdavConnectionId,
    this.webdavRemotePath,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'transferId': transferId,
    'fileName': fileName,
    'fileSize': fileSize,
    if (filePath != null) 'filePath': filePath,
    'channel': channel,
    'direction': direction,
    'status': status,
    'transferredBytes': transferredBytes,
    if (fileHash != null) 'fileHash': fileHash,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (s3UploadId != null) 's3UploadId': s3UploadId,
    if (s3Key != null) 's3Key': s3Key,
    if (s3CompletedParts != null)
      's3CompletedParts': s3CompletedParts!.map((p) => p.toJson()).toList(),
    if (lanTargetUrl != null) 'lanTargetUrl': lanTargetUrl,
    if (lanResumeOffset != null) 'lanResumeOffset': lanResumeOffset,
    if (lanTargetDeviceIds != null) 'lanTargetDeviceIds': lanTargetDeviceIds,
    if (webrtcFileId != null) 'webrtcFileId': webrtcFileId,
    if (webrtcOffset != null) 'webrtcOffset': webrtcOffset,
    if (webrtcTargetDeviceId != null)
      'webrtcTargetDeviceId': webrtcTargetDeviceId,
    if (webdavConnectionId != null) 'webdavConnectionId': webdavConnectionId,
    if (webdavRemotePath != null) 'webdavRemotePath': webdavRemotePath,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  factory TransferRecord.fromJson(Map<String, dynamic> j) => TransferRecord(
    transferId: j['transferId'] as String,
    fileName: j['fileName'] as String,
    fileSize: j['fileSize'] as int,
    filePath: j['filePath'] as String?,
    channel: j['channel'] as String,
    direction: j['direction'] as String,
    status: j['status'] as String? ?? 'in_progress',
    transferredBytes: j['transferredBytes'] as int? ?? 0,
    fileHash: j['fileHash'] as String?,
    createdAt: j['createdAt'] != null
        ? DateTime.parse(j['createdAt'] as String)
        : null,
    updatedAt: j['updatedAt'] != null
        ? DateTime.parse(j['updatedAt'] as String)
        : null,
    s3UploadId: j['s3UploadId'] as String?,
    s3Key: j['s3Key'] as String?,
    s3CompletedParts: j['s3CompletedParts'] != null
        ? (j['s3CompletedParts'] as List)
              .map((e) => CompletedPart.fromJson(e as Map<String, dynamic>))
              .toList()
        : null,
    lanTargetUrl: j['lanTargetUrl'] as String?,
    lanResumeOffset: j['lanResumeOffset'] as int?,
    lanTargetDeviceIds: j['lanTargetDeviceIds'] != null
        ? (j['lanTargetDeviceIds'] as List).cast<String>()
        : null,
    webrtcFileId: j['webrtcFileId'] as String?,
    webrtcOffset: j['webrtcOffset'] as int?,
    webrtcTargetDeviceId: j['webrtcTargetDeviceId'] as String?,
    webdavConnectionId: j['webdavConnectionId'] as String?,
    webdavRemotePath: j['webdavRemotePath'] as String?,
    errorMessage: j['errorMessage'] as String?,
  );

  String toJsonString() => jsonEncode(toJson());

  factory TransferRecord.fromJsonString(String s) =>
      TransferRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Map for SQLite row (snake_case column names).
  Map<String, dynamic> toMap() => {
    'transfer_id': transferId,
    'file_name': fileName,
    'file_size': fileSize,
    'file_path': filePath,
    'channel': channel,
    'direction': direction,
    'status': status,
    'transferred_bytes': transferredBytes,
    'file_hash': fileHash,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    's3_upload_id': s3UploadId,
    's3_key': s3Key,
    's3_completed_parts': s3CompletedParts != null
        ? jsonEncode(s3CompletedParts!.map((p) => p.toJson()).toList())
        : null,
    'lan_target_url': lanTargetUrl,
    'lan_resume_offset': lanResumeOffset,
    'lan_target_device_ids': lanTargetDeviceIds != null
        ? jsonEncode(lanTargetDeviceIds)
        : null,
    'webrtc_file_id': webrtcFileId,
    'webrtc_offset': webrtcOffset,
    'webrtc_target_device_id': webrtcTargetDeviceId,
    'webdav_connection_id': webdavConnectionId,
    'webdav_remote_path': webdavRemotePath,
    'error_message': errorMessage,
  };

  factory TransferRecord.fromMap(Map<String, dynamic> row) {
    List<CompletedPart>? s3Parts;
    final s3PartsRaw = row['s3_completed_parts'];
    if (s3PartsRaw != null && s3PartsRaw is String) {
      try {
        final list = jsonDecode(s3PartsRaw) as List;
        s3Parts = list
            .map((e) => CompletedPart.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    List<String>? lanIds;
    final lanIdsRaw = row['lan_target_device_ids'];
    if (lanIdsRaw != null && lanIdsRaw is String) {
      try {
        lanIds = (jsonDecode(lanIdsRaw) as List).cast<String>();
      } catch (_) {}
    }
    return TransferRecord(
      transferId: row['transfer_id'] as String,
      fileName: row['file_name'] as String,
      fileSize: row['file_size'] as int,
      filePath: row['file_path'] as String?,
      channel: row['channel'] as String,
      direction: row['direction'] as String,
      status: row['status'] as String? ?? 'in_progress',
      transferredBytes: row['transferred_bytes'] as int? ?? 0,
      fileHash: row['file_hash'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      s3UploadId: row['s3_upload_id'] as String?,
      s3Key: row['s3_key'] as String?,
      s3CompletedParts: s3Parts,
      lanTargetUrl: row['lan_target_url'] as String?,
      lanResumeOffset: row['lan_resume_offset'] as int?,
      lanTargetDeviceIds: lanIds,
      webrtcFileId: row['webrtc_file_id'] as String?,
      webrtcOffset: row['webrtc_offset'] as int?,
      webrtcTargetDeviceId: row['webrtc_target_device_id'] as String?,
      webdavConnectionId: row['webdav_connection_id'] as String?,
      webdavRemotePath: row['webdav_remote_path'] as String?,
      errorMessage: row['error_message'] as String?,
    );
  }

  /// Percentage 0–100.
  int get progressPercent =>
      fileSize > 0 ? (transferredBytes * 100 ~/ fileSize).clamp(0, 100) : 0;

  bool get isResumable =>
      status == 'in_progress' || status == 'paused' || status == 'failed';
}
