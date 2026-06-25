import 'package:app/services/webdav_transfer_progress_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebDavTransferProgressSummary', () {
    test('shouldShow while batch in progress', () {
      const summary = WebDavTransferProgressSummary(
        uploadBatchTotal: 100,
        uploadSucceeded: 10,
        uploadFailed: 2,
        uploadActive: 6,
        uploadQueued: 82,
        uploadSpeedBps: 1024 * 1024,
        uploadTransferredBytes: 0,
        uploadTotalBytes: 0,
        downloadActive: 0,
        downloadSpeedBps: 0,
      );
      expect(summary.shouldShow, isTrue);
      expect(summary.uploadProgressFraction, closeTo(0.12, 0.001));
    });

    test('isUploadBatchComplete when all settled and idle', () {
      const summary = WebDavTransferProgressSummary(
        uploadBatchTotal: 5,
        uploadSucceeded: 4,
        uploadFailed: 1,
        uploadActive: 0,
        uploadQueued: 0,
        uploadSpeedBps: 0,
        uploadTransferredBytes: 0,
        uploadTotalBytes: 0,
        downloadActive: 0,
        downloadSpeedBps: 0,
      );
      expect(summary.isUploadBatchComplete, isTrue);
      expect(summary.shouldShow, isTrue);
    });

    test('shouldShow for active downloads without upload batch', () {
      const summary = WebDavTransferProgressSummary(
        uploadBatchTotal: 0,
        uploadSucceeded: 0,
        uploadFailed: 0,
        uploadActive: 0,
        uploadQueued: 0,
        uploadSpeedBps: 0,
        uploadTransferredBytes: 0,
        uploadTotalBytes: 0,
        downloadActive: 2,
        downloadSpeedBps: 512000,
      );
      expect(summary.shouldShow, isTrue);
    });
  });
}
