import 'package:shared_preferences/shared_preferences.dart';

const webDavUploadMaxConcurrencyPrefKey = 'webdav_upload_max_concurrency';

const webDavUploadConcurrencyMin = 1;
const webDavUploadConcurrencyMax = 12;
const webDavUploadConcurrencyDefault = 3;

int clampWebDavUploadConcurrency(int value) {
  return value.clamp(webDavUploadConcurrencyMin, webDavUploadConcurrencyMax);
}

Future<int> loadWebDavUploadConcurrencyPref() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getInt(webDavUploadMaxConcurrencyPrefKey);
  if (raw == null) return webDavUploadConcurrencyDefault;
  return clampWebDavUploadConcurrency(raw);
}

Future<void> saveWebDavUploadConcurrencyPref(int value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    webDavUploadMaxConcurrencyPrefKey,
    clampWebDavUploadConcurrency(value),
  );
}
