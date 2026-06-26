import 'dart:io';

import 'package:feedmatter_flutter_sdk/feedmatter_flutter_sdk.dart';
import 'package:feedmatter_flutter_ui/feedmatter_flutter_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../color_theme_store.dart';
import '../config/env.dart';
import '../config/feedmatter_env.dart';
import '../logger.dart';
import '../preferences/service_region.dart';
import '../providers/auth_provider.dart';
import '../theme_store.dart';

bool _initialized = false;
bool _feedbackEnabled = true;
FeedMatterConfig? _activeConfig;

/// 启动时初始化 FeedMatter SDK，并在登录态变化时同步用户信息。
class FeedmatterBootstrap {
  FeedmatterBootstrap._();

  static bool get isInitialized => _initialized;

  static bool get feedbackEnabled => _feedbackEnabled;

  /// 供 [env_snapshot] 打印；不含 secret。
  static String snapshotSummary() {
    if (!_initialized) {
      final region = Env.prodServiceRegion;
      if (region == ServiceRegion.international) {
        if (FeedmatterEnv.intlApiKey.isEmpty) {
          return 'disabled (missing FM_INTL_API_KEY)';
        }
        return 'disabled (not initialized)';
      }
      if (FeedmatterEnv.cnApiKey.isEmpty) {
        return 'disabled (missing FM_CN_API_KEY)';
      }
      return 'disabled (not initialized)';
    }
    return 'enabled market=${_activeConfig?.appMarket ?? '-'} feedback=$_feedbackEnabled';
  }

  static FeedMatterThemeOptions themeOptionsFrom(BuildContext context) {
    final themeMode = ThemeStoreScope.of(context).notifier.value;
    final accent = ColorThemeStoreScope.of(context).notifier.value.accent;
    return FeedMatterThemeOptions(
      mode: _mapThemeMode(themeMode),
      seedColor: accent,
    );
  }

  static FeedMatterThemeMode _mapThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => FeedMatterThemeMode.light,
      ThemeMode.dark => FeedMatterThemeMode.dark,
      ThemeMode.system => FeedMatterThemeMode.system,
    };
  }

  static String detectAppMarket() {
    if (Platform.isIOS) return 'appstore';
    if (Platform.isAndroid) {
      if (Env.androidPlayDistribution) return 'googleplay';
      return 'android';
    }
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  /// 在 [LocaleRegionStore.loadSync] 之后调用（保证 [Env.prodServiceRegion] 已就绪）。
  static Future<void> initIfEligible() async {
    if (_initialized) return;

    final config = _resolveConfig();
    if (config == null) return;

    FeedMatterClient.instance.init(
      config,
      _guestUser(),
      onError: _handleError,
    );
    _activeConfig = config;
    _initialized = true;
    logBoot.info('FeedmatterBootstrap initialized market=${config.appMarket}');

    await _refreshProjectConfig();
  }

  static FeedMatterConfig? _resolveConfig() {
    if (Env.prodServiceRegion == ServiceRegion.international) {
      if (FeedmatterEnv.intlApiKey.isEmpty ||
          FeedmatterEnv.intlApiSecret.isEmpty) {
        return null;
      }
      return FeedMatterConfig(
        baseUrl: FeedmatterEnv.intlBaseUrl,
        apiKey: FeedmatterEnv.intlApiKey,
        apiSecret: FeedmatterEnv.intlApiSecret,
        appMarket: detectAppMarket(),
        debug: kDebugMode,
      );
    }

    if (FeedmatterEnv.cnApiKey.isEmpty || FeedmatterEnv.cnApiSecret.isEmpty) {
      return null;
    }
    return FeedMatterConfig(
      baseUrl: FeedmatterEnv.cnBaseUrl,
      apiKey: FeedmatterEnv.cnApiKey,
      apiSecret: FeedmatterEnv.cnApiSecret,
      appMarket: detectAppMarket(),
      debug: kDebugMode,
    );
  }

  static FeedMatterUser _guestUser() =>
      FeedMatterUser(userId: '', userName: 'Guest');

  static FeedMatterUser _userFromAuth(AuthState auth) {
    if (auth.isLoggedIn && auth.userId != null && auth.userId!.isNotEmpty) {
      return FeedMatterUser(
        userId: auth.userId!,
        userName: auth.userId!,
      );
    }
    return _guestUser();
  }

  static void syncUser(AuthState auth) {
    if (!_initialized || _activeConfig == null) return;
    FeedMatterClient.instance.init(
      _activeConfig!,
      _userFromAuth(auth),
      onError: _handleError,
    );
  }

  static void onLogout() {
    if (!_initialized || _activeConfig == null) return;
    FeedMatterClient.instance.init(
      _activeConfig!,
      _guestUser(),
      onError: _handleError,
    );
  }

  static Future<void> _refreshProjectConfig() async {
    try {
      final projectConfig = await FeedMatterClient.instance.getProjectConfig();
      _feedbackEnabled = projectConfig.feedbackEnabled;
    } catch (e, st) {
      logBoot.warning('FeedmatterBootstrap getProjectConfig failed: $e', e, st);
      _feedbackEnabled = true;
    }
  }

  static void _handleError(FeedMatterException error) {
    logBoot.warning('FeedMatter error: ${error.message} code=${error.code}');
  }
}
