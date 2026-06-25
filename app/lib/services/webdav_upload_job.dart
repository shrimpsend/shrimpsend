/// Tracks a scheduled WebDAV upload from enqueue until settled.
enum WebDavUploadJobStopReason {
  none,
  paused,
  terminated,
}

final class WebDavUploadJobHandle {
  WebDavUploadJobHandle({
    required this.connectionId,
    required this.localPath,
    required this.remotePath,
    required this.fileName,
    required this.fileSize,
    this.ensureParent = true,
  });

  final int connectionId;
  final String localPath;
  final String remotePath;
  final String fileName;
  final int fileSize;
  final bool ensureParent;

  WebDavUploadJobStopReason stopReason = WebDavUploadJobStopReason.none;
  String? transferId;

  bool get isStopped => stopReason != WebDavUploadJobStopReason.none;
  bool get isPaused => stopReason == WebDavUploadJobStopReason.paused;
  bool get isTerminated => stopReason == WebDavUploadJobStopReason.terminated;
}
