import 'package:app/services/webdav_upload_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebDavUploadJobHandle', () {
    WebDavUploadJobHandle _handle() {
      return WebDavUploadJobHandle(
        connectionId: 1,
        localPath: '/tmp/a.txt',
        remotePath: '/remote/a.txt',
        fileName: 'a.txt',
        fileSize: 10,
      );
    }

    test('starts active', () {
      final handle = _handle();
      expect(handle.isStopped, isFalse);
      expect(handle.isPaused, isFalse);
      expect(handle.isTerminated, isFalse);
    });

    test('paused stops execution', () {
      final handle = _handle()..stopReason = WebDavUploadJobStopReason.paused;
      expect(handle.isStopped, isTrue);
      expect(handle.isPaused, isTrue);
      expect(handle.isTerminated, isFalse);
    });

    test('terminated stops execution', () {
      final handle = _handle()
        ..stopReason = WebDavUploadJobStopReason.terminated;
      expect(handle.isStopped, isTrue);
      expect(handle.isPaused, isFalse);
      expect(handle.isTerminated, isTrue);
    });
  });
}
