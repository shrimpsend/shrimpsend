import 'package:flutter/services.dart';

class NativeTabBarService {
  static const _channel = MethodChannel('dev.ultrasend/native_tab_bar');

  static final NativeTabBarService instance = NativeTabBarService._internal();

  NativeTabBarService._internal();

  void Function(int index)? onSelectTab;
  void Function()? onOpenPendingFiles;

  bool? _lastVisible;
  int? _lastSelectedIndex;
  int? _lastBadgeCount;
  String? _lastPrimaryColorHex;
  String? _lastConnectLabel;
  String? _lastFilesLabel;
  String? _lastSettingsLabel;

  void init() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'selectTab':
          final index = call.arguments as int;
          onSelectTab?.call(index);
          break;
        case 'openPendingFiles':
          onOpenPendingFiles?.call();
          break;
      }
    });
  }

  Future<void> updateState({
    required bool visible,
    required int selectedIndex,
    required int badgeCount,
    required String primaryColorHex,
    required String connectLabel,
    required String filesLabel,
    required String settingsLabel,
  }) async {
    if (visible == _lastVisible &&
        selectedIndex == _lastSelectedIndex &&
        badgeCount == _lastBadgeCount &&
        primaryColorHex == _lastPrimaryColorHex &&
        connectLabel == _lastConnectLabel &&
        filesLabel == _lastFilesLabel &&
        settingsLabel == _lastSettingsLabel) {
      return;
    }
    _lastVisible = visible;
    _lastSelectedIndex = selectedIndex;
    _lastBadgeCount = badgeCount;
    _lastPrimaryColorHex = primaryColorHex;
    _lastConnectLabel = connectLabel;
    _lastFilesLabel = filesLabel;
    _lastSettingsLabel = settingsLabel;

    try {
      await _channel.invokeMethod('updateState', {
        'visible': visible,
        'selectedIndex': selectedIndex,
        'badgeCount': badgeCount,
        'primaryColorHex': primaryColorHex,
        'connectLabel': connectLabel,
        'filesLabel': filesLabel,
        'settingsLabel': settingsLabel,
      });
    } on PlatformException catch (e) {
      print('NativeTabBarService: failed to update state: $e');
    }
  }
}
