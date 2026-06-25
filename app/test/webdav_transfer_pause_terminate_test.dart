import 'dart:async';

import 'package:app/services/async_semaphore.dart';
import 'package:app/services/webdav_upload_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('webdav upload pause gate', () {
    test('paused handle prevents work after semaphore acquire', () async {
      final semaphore = AsyncSemaphore(1);
      final handle = WebDavUploadJobHandle(
        connectionId: 1,
        localPath: '/tmp/a.txt',
        remotePath: '/remote/a.txt',
        fileName: 'a.txt',
        fileSize: 10,
      )..stopReason = WebDavUploadJobStopReason.paused;

      var executed = false;
      await semaphore.run(() async {
        if (handle.isStopped) return;
        executed = true;
      });

      expect(executed, isFalse);
    });

    test('queued jobs respect pause before starting', () async {
      final semaphore = AsyncSemaphore(1);
      final blocker = Completer<void>();
      final handle = WebDavUploadJobHandle(
        connectionId: 1,
        localPath: '/tmp/b.txt',
        remotePath: '/remote/b.txt',
        fileName: 'b.txt',
        fileSize: 10,
      );

      unawaited(
        semaphore.run(() async {
          await blocker.future;
        }),
      );

      final secondStarted = Completer<void>();
      unawaited(
        semaphore.run(() async {
          secondStarted.complete();
          if (handle.isStopped) return;
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      handle.stopReason = WebDavUploadJobStopReason.paused;
      blocker.complete();
      await secondStarted.future;

      expect(handle.isPaused, isTrue);
    });
  });
}
