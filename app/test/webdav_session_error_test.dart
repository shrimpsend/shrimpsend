import 'package:app/services/transfer_error_message.dart';
import 'package:app/services/webdav_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('userFacingWebDavError preserves dio send timeout detail', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/webdav/file'),
      type: DioExceptionType.sendTimeout,
      message:
          'The request took longer than 0:01:00.000000 to send data. It was aborted.',
    );

    expect(
      userFacingWebDavError(error),
      'WebDAV 操作失败：发送超时：The request took longer than 0:01:00.000000 to send data. It was aborted.',
    );
  });
}
