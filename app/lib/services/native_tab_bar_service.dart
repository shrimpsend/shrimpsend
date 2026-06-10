import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
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
  bool? _lastIsDarkMode;

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
    required bool isDarkMode,
  }) async {
    if (visible == _lastVisible &&
        selectedIndex == _lastSelectedIndex &&
        badgeCount == _lastBadgeCount &&
        primaryColorHex == _lastPrimaryColorHex &&
        connectLabel == _lastConnectLabel &&
        filesLabel == _lastFilesLabel &&
        settingsLabel == _lastSettingsLabel &&
        isDarkMode == _lastIsDarkMode) {
      return;
    }
    _lastVisible = visible;
    _lastSelectedIndex = selectedIndex;
    _lastBadgeCount = badgeCount;
    _lastPrimaryColorHex = primaryColorHex;
    _lastConnectLabel = connectLabel;
    _lastFilesLabel = filesLabel;
    _lastSettingsLabel = settingsLabel;
    _lastIsDarkMode = isDarkMode;

    try {
      await _channel.invokeMethod('updateState', {
        'visible': visible,
        'selectedIndex': selectedIndex,
        'badgeCount': badgeCount,
        'primaryColorHex': primaryColorHex,
        'connectLabel': connectLabel,
        'filesLabel': filesLabel,
        'settingsLabel': settingsLabel,
        'isDarkMode': isDarkMode,
      });
    } on PlatformException catch (e) {
      print('NativeTabBarService: failed to update state: $e');
    }
  }

  /// Show or hide the native bottom bar with animation.
  /// Used to hide the bar when a Flutter modal sheet or route is shown on top.
  Future<void> setVisible(bool visible) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('setVisible', visible);
    } on PlatformException catch (e) {
      print('NativeTabBarService: failed to set visible: $e');
    }
  }
}

class NativeTabBarNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateVisibility(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateVisibility(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _updateVisibility(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateVisibility(newRoute);
    }
  }

  void _updateVisibility(Route<dynamic>? activeRoute) {
    if (!Platform.isIOS) return;
    if (activeRoute == null) return;
    final name = activeRoute.settings.name;
    final isHome = name == '/' || name == '/devices';
    unawaited(NativeTabBarService.instance.setVisible(isHome));
  }
}
