/// Live WebDAV transfer progress for the connection shell banner.
final class WebDavTransferProgressSummary {
  const WebDavTransferProgressSummary({
    required this.uploadBatchTotal,
    required this.uploadSucceeded,
    required this.uploadFailed,
    required this.uploadActive,
    required this.uploadQueued,
    required this.uploadSpeedBps,
    required this.uploadTransferredBytes,
    required this.uploadTotalBytes,
    required this.downloadActive,
    required this.downloadSpeedBps,
  });

  static const empty = WebDavTransferProgressSummary(
    uploadBatchTotal: 0,
    uploadSucceeded: 0,
    uploadFailed: 0,
    uploadActive: 0,
    uploadQueued: 0,
    uploadSpeedBps: 0,
    uploadTransferredBytes: 0,
    uploadTotalBytes: 0,
    downloadActive: 0,
    downloadSpeedBps: 0,
  );

  final int uploadBatchTotal;
  final int uploadSucceeded;
  final int uploadFailed;
  final int uploadActive;
  final int uploadQueued;
  final double uploadSpeedBps;
  final int uploadTransferredBytes;
  final int uploadTotalBytes;
  final int downloadActive;
  final double downloadSpeedBps;

  int get uploadSettled => uploadSucceeded + uploadFailed;

  bool get hasUploadBatch => uploadBatchTotal > 0;

  bool get isUploadBatchComplete =>
      hasUploadBatch && uploadSettled >= uploadBatchTotal && uploadActive == 0;

  bool get shouldShow =>
      uploadActive > 0 ||
      downloadActive > 0 ||
      uploadQueued > 0 ||
      (hasUploadBatch && uploadSettled < uploadBatchTotal) ||
      isUploadBatchComplete;

  double get uploadProgressFraction {
    if (uploadBatchTotal <= 0) return 0;
    return (uploadSettled / uploadBatchTotal).clamp(0.0, 1.0);
  }

  double get activeUploadBytesFraction {
    if (uploadTotalBytes <= 0) return 0;
    return (uploadTransferredBytes / uploadTotalBytes).clamp(0.0, 1.0);
  }
}
