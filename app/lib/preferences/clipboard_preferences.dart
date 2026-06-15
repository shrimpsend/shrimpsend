import 'package:shared_preferences/shared_preferences.dart';

const _keyAutoCopyReceivedText = 'ultrasend_auto_copy_received_text';
const _keyPendingAutoCopyText = 'ultrasend_pending_auto_copy_text';

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

/// Persist the latest incoming text that could not be copied while the app was
/// backgrounded. Stored durably (not in-memory) so it survives the Activity /
/// engine being destroyed (e.g. exiting via the back button) and can still be
/// flushed when the app is reopened from the notification.
Future<void> setPendingAutoCopyText(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyPendingAutoCopyText, value);
}

Future<String?> getPendingAutoCopyText() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_keyPendingAutoCopyText);
  if (value == null || value.isEmpty) return null;
  return value;
}

Future<void> clearPendingAutoCopyText() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyPendingAutoCopyText);
}
