import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_brand.dart';

class WindowsLaunchAtStartupService {
  WindowsLaunchAtStartupService._();

  static const startupArg = '--startup';
  static const _keyEnabled = 'ultrasend_windows_launch_at_startup';
  static String get _appName => desktopWindowTitle();
  static const _msixPackageName = 'DevUltrasend.Shrimpsend';

  static bool _configured = false;

  static bool isStartupLaunch(List<String> args) {
    return Platform.isWindows && args.contains(startupArg);
  }

  static Future<bool> getEnabledPreference() async {
    if (!Platform.isWindows) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? true;
  }

  static Future<void> syncWithPreference() async {
    if (!Platform.isWindows) return;
    final enabled = await getEnabledPreference();
    await _setSystemEnabled(enabled);
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) return;
    await _setSystemEnabled(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  static Future<void> _setSystemEnabled(bool enabled) async {
    _setup();
    final success = enabled
        ? await launchAtStartup.enable()
        : await launchAtStartup.disable();
    if (!success) {
      throw StateError(
        'Failed to ${enabled ? 'enable' : 'disable'} Windows launch at startup',
      );
    }
  }

  static void _setup() {
    if (_configured) return;
    launchAtStartup.setup(
      appName: _appName,
      appPath: Platform.resolvedExecutable,
      packageName: _msixPackageName,
      args: const [startupArg],
    );
    _configured = true;
  }
}
