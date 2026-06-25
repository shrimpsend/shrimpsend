import 'package:app/services/transfer_error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTransferErrorMessage', () {
    test('formats dio bad response with status and message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/webdav/file'),
        response: Response(
          requestOptions: RequestOptions(path: '/webdav/file'),
          statusCode: 502,
          statusMessage: 'Bad Gateway',
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        formatTransferErrorMessage(error),
        'HTTP 502 · Bad Gateway',
      );
    });

    test('formats dio send timeout with type label and message', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/webdav/file'),
        type: DioExceptionType.sendTimeout,
        message:
            'The request took longer than 0:01:00.000000 to send data. It was aborted.',
      );

      expect(
        formatTransferErrorMessage(error),
        '发送超时：The request took longer than 0:01:00.000000 to send data. It was aborted.',
      );
    });

    test('unwraps generic exception text', () {
      expect(
        formatTransferErrorMessage(
          Exception('WebDAV 操作失败：发送超时：timeout'),
        ),
        'WebDAV 操作失败：发送超时：timeout',
      );
    });

    test('falls back to exception text', () {
      expect(
        formatTransferErrorMessage(Exception('disk full')),
        contains('disk full'),
      );
    });
  });
}
