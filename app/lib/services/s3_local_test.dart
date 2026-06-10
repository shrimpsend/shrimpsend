import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _legacyStorageKey = 's3_config_local';

/// Remove legacy SharedPreferences entry that stored AK/SK before cache removal.
Future<void> clearLegacyS3ConfigCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_legacyStorageKey);
}

Future<void> headPresignedUrl(String url, {Duration timeout = const Duration(seconds: 15)}) async {
  final response = await http.head(Uri.parse(url)).timeout(timeout);
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  throw Exception('S3 HEAD failed (HTTP ${response.statusCode})');
}
