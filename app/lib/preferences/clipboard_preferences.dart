import 'package:shared_preferences/shared_preferences.dart';

const _keyAutoCopyReceivedText = 'ultrasend_auto_copy_received_text';
const _keyLastAutoCopiedTextTs = 'ultrasend_last_auto_copied_text_ts';

/// Whether incoming text from other devices is automatically written to the
/// system clipboard. Enabled by default.
Future<bool> getAutoCopyReceivedText() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyAutoCopyReceivedText) ?? true;
}

Future<void> setAutoCopyReceivedText(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyAutoCopyReceivedText, value);
}

/// Timestamp (ms) of the most recent incoming text that was auto-copied.
///
/// Persisted durably so the marker survives the app being exited (e.g. via the
/// back button) and reopened: on reopen the latest received text is fetched
/// from local history and copied only when newer than this marker, so the same
/// message is never copied twice. Null when never set (first run).
Future<int?> getLastAutoCopiedTextTs() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_keyLastAutoCopiedTextTs);
}

Future<void> setLastAutoCopiedTextTs(int ts) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_keyLastAutoCopiedTextTs, ts);
}
