import 'package:dio/dio.dart';

String _dioExceptionTypeLabel(DioExceptionType type) {
  return switch (type) {
    DioExceptionType.connectionTimeout => '连接超时',
    DioExceptionType.sendTimeout => '发送超时',
    DioExceptionType.receiveTimeout => '接收超时',
    DioExceptionType.badCertificate => '证书错误',
    DioExceptionType.badResponse => '响应错误',
    DioExceptionType.cancel => '已取消',
    DioExceptionType.connectionError => '连接错误',
    DioExceptionType.transformTimeout => '转换超时',
    DioExceptionType.unknown => '网络错误',
  };
}

/// Formats transfer failures for display in the transfer list.
String formatTransferErrorMessage(Object error) {
  if (error is DioException) {
    final response = error.response;
    final status = response?.statusCode;
    final statusMessage = response?.statusMessage?.trim();
    final body = response?.data;
    final bodyText = body == null
        ? null
        : body is String
            ? body.trim()
            : body.toString().trim();

    final parts = <String>[];
    if (status != null) {
      parts.add('HTTP $status');
    }
    if (statusMessage != null && statusMessage.isNotEmpty) {
      parts.add(statusMessage);
    }
    if (bodyText != null && bodyText.isNotEmpty && bodyText != statusMessage) {
      parts.add(bodyText);
    }
    if (parts.isNotEmpty) {
      return parts.join(' · ');
    }

    final typeLabel = _dioExceptionTypeLabel(error.type);
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '$typeLabel：$message';
    }
    return typeLabel;
  }

  final text = error.toString().trim();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text.isEmpty ? 'Unknown error' : text;
}
