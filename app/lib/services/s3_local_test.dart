import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../logger.dart';

const _legacyStorageKey = 's3_config_local';

/// User-Agent for direct S3 presigned requests (some providers e.g. CSTCloud Data Capsule validate UA).
const kS3CompatibleUserAgent = 'ShrimpSend/1.0 S3Compat';

/// Remove legacy SharedPreferences entry that stored AK/SK before cache removal.
Future<void> clearLegacyS3ConfigCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_legacyStorageKey);
}

String sanitizePresignedUrlForLog(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url.split('?').first;
  return uri.replace(queryParameters: {}).toString();
}

String? presignQueryParam(String url, String key) {
  return Uri.tryParse(url)?.queryParameters[key];
}

void logPresignedUrlSummary(String url, {String? bucket}) {
  final sanitized = sanitizePresignedUrlForLog(url);
  final signedHeaders = presignQueryParam(url, 'X-Amz-SignedHeaders');
  final credential = presignQueryParam(url, 'X-Amz-Credential');
  final pathStyleHint = bucket != null && bucket.isNotEmpty
      ? sanitized.contains('/$bucket')
      : null;
  logApi.info(
    's3 presigned url host=${Uri.tryParse(url)?.host} '
    'pathStyleLikely=$pathStyleHint signedHeaders=$signedHeaders '
    'credentialScope=${credential != null && credential.contains('/') ? credential.split('/').skip(1).join('/') : credential}',
  );
}

Future<void> headPresignedUrl(
  String url, {
  Duration timeout = const Duration(seconds: 15),
  String? userAgent,
}) async {
  final ua = (userAgent != null && userAgent.isNotEmpty)
      ? userAgent
      : kS3CompatibleUserAgent;
  final response = await http
      .head(
        Uri.parse(url),
        headers: {'User-Agent': ua},
      )
      .timeout(timeout);
  if (response.statusCode >= 200 && response.statusCode < 300) return;

  final sanitized = sanitizePresignedUrlForLog(url);
  final bodySnippet = response.body.length > 500
      ? response.body.substring(0, 500)
      : response.body;
  logApi.warning(
    's3 HEAD failed status=${response.statusCode} url=$sanitized '
    'x-amz-error-code=${response.headers['x-amz-error-code']} '
    'x-amz-error-message=${response.headers['x-amz-error-message']} '
    'content-type=${response.headers['content-type']} '
    'body=$bodySnippet',
  );
  throw Exception('S3 HEAD failed (HTTP ${response.statusCode})');
}
