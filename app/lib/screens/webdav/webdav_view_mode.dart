import 'package:shared_preferences/shared_preferences.dart';

enum WebDavViewMode { list, grid }

const webDavViewModePrefKey = 'webdav_view_mode';

Future<WebDavViewMode> loadWebDavViewModePref() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(webDavViewModePrefKey);
  return raw == 'grid' ? WebDavViewMode.grid : WebDavViewMode.list;
}

Future<void> saveWebDavViewModePref(WebDavViewMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    webDavViewModePrefKey,
    mode == WebDavViewMode.grid ? 'grid' : 'list',
  );
}
