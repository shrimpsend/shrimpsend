import 'package:shared_preferences/shared_preferences.dart';

const _keyAutoCopyReceivedText = 'ultrasend_auto_copy_received_text';

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
