import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_desktop_updater/flutter_desktop_updater.dart'
    as desktop_upd;
import 'package:oktoast/oktoast.dart';
import 'package:openpanel_flutter/openpanel_flutter.dart';
import 'api/api.dart';
import 'utils/toast.dart';
import 'config/env.dart';
import 'config/env_snapshot.dart';
import 'color_theme.dart';
import 'color_theme_store.dart';
import 'font_size_store.dart';
import 'typography.dart';
import 'shortcut_preferences.dart';
import 'logger.dart';
import 'providers/app_locale.dart';
import 'providers/auth_provider.dart';
import 'providers/auth_session_provider.dart';
import 'providers/pending_files_provider.dart';
import 'models/pending_file_entry.dart';
import 'theme_store.dart';
import 'ui/app_ui.dart';
import 'l10n/app_brand.dart';
import 'l10n/generated/app_localizations.dart';
import 'preferences/locale_region_store.dart';
import 'screens/app_entry_screen.dart';
import 'screens/login_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/file_manager_screen.dart';
import 'screens/account_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/font_settings_screen.dart';
import 'screens/shortcut_settings_screen.dart';
import 'screens/s3_settings_screen.dart';
import 'screens/webdav_settings_screen.dart';
import 'screens/webdav_connection_screen.dart';
import 'screens/version_history_screen.dart';
import 'screens/app_log_screen.dart';
import 'screens/membership_screen.dart';
import 'services/app_update_service.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/auth_session_lifecycle.dart';
import 'widgets/desktop_update_banner.dart';
import 'services/app_log_file.dart';
import 'services/database.dart';
import 'services/desktop_tray_lifecycle.dart';
import 'services/openpanel_bootstrap.dart';
import 'services/analytics/analytics.dart';
import 'services/analytics/analytics_events.dart';
import 'services/desktop_paste_dispatcher.dart';
import 'services/desktop_file_drop_dispatcher.dart';
import 'services/share_receive_service.dart';
import 'services/saf_storage_service.dart';
import 'services/windows_launch_at_startup_service.dart';
import 'utils/runtime_platform.dart';
import 'utils/windows_distribution_channel.dart';
import 'services/native_tab_bar_service.dart';
import 'services/transfer_keep_alive.dart';
import 'services/transfer_completion_notifier.dart';

class _NoProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) => 'DIRECT';
    return client;
  }
}

const _isrgRootX1Asset = 'assets/certs/isrg_root_x1.pem';

/// Trust Let's Encrypt ISRG Root X1 for HTTPS when the OS store is missing it
/// (common on Win10 without Windows root-cert auto-update).
Future<void> _injectLetsEncryptRootCa() async {
  try {
    final pemBytes = (await rootBundle.load(_isrgRootX1Asset)).buffer.asUint8List();
    SecurityContext.defaultContext.setTrustedCertificatesBytes(pemBytes);
  } catch (e, st) {
    final message = e.toString();
    if (message.contains('CERT_ALREADY_IN_HASH_TABLE')) {
      return;
    }
    logBoot.warning('inject ISRG Root X1 trust anchor failed: $e', e, st);
  }
}

void main(List<String> args) async {
  HttpOverrides.global = _NoProxyHttpOverrides();
  // Run the whole startup inside a guarded zone so async errors thrown before
  // the first frame cannot silently abort main() into a blank window.
  // ensureInitialized() and runApp() must live in the same zone.
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Logging first: any failure during the rest of boot must reach the log
      // file on disk. Otherwise a crash before the first frame is a silent
      // white screen with no diagnostics (cf. 1.4.8 Windows white-screen).
      await AppLogFile.instance.init();
      initLogging();
      _installBootErrorHandlers();
      try {
        await _bootstrap(args);
      } catch (e, st) {
        logBoot.severe('fatal boot error before first frame: $e', e, st);
        runApp(
          BootFailureApp(
            error: e,
            stackTrace: st,
            logFilePath: AppLogFile.instance.currentLogFilePath,
          ),
        );
      }
    },
    (error, stack) {
      logBoot.severe('uncaught zone error: $error', error, stack);
    },
  );
}

/// Routes framework + platform-dispatcher errors into the on-disk log so a
/// release build that white-screens still leaves a diagnosable trail.
void _installBootErrorHandlers() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    logBoot.severe(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    previousOnError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    logBoot.severe('PlatformDispatcher uncaught error: $error', error, stack);
    return true;
  };
}

/// App startup sequence. Runs inside [runZonedGuarded] with logging already
/// initialized, so any thrown error is captured and surfaced via
/// [BootFailureApp] instead of producing a blank window.
Future<void> _bootstrap(List<String> args) async {
  // Step markers ('boot: ...'): on a hang or crash before the first frame, the
  // last logged step localizes the failing init phase from the user's log.
  logBoot.info('boot: begin (platform=${Platform.operatingSystem})');
  FlutterForegroundTask.initCommunicationPort();
  await TransferKeepAlive.ensureInitialized();
  await TransferCompletionNotifier.ensureInitialized();
  logBoot.info('boot: keep-alive + notifier ready');
  if (!Platform.isWindows) {
    await LiquidGlassWidgets.initialize();
    logBoot.info('boot: liquid glass initialized');
  }
  await _injectLetsEncryptRootCa();
  logBoot.info('boot: root CA injected');
  final launchedAtStartup = WindowsLaunchAtStartupService.isStartupLaunch(args);
  if (Platform.isWindows) {
    try {
      await WindowsLaunchAtStartupService.syncWithPreference();
    } catch (e, st) {
      logBoot.warning('windows launch at startup sync failed: $e', e, st);
    }
  }

  final localeRegionStore = LocaleRegionStore();
  await localeRegionStore.loadSync();
  await loadSendShortcutMode();
  logBoot.info('boot: locale/region + shortcuts loaded');

  await OpenpanelBootstrap.initIfEligible();
  logBoot.info('boot: openpanel init done');

  // 桌面更新 zip 内需含与 windows/CMakeLists.txt BINARY_NAME 一致的主程序（cn: 虾传.exe，intl: Shrimpsend.exe）。
  // MSIX/商店安装目录不可被 ZIP 覆盖，故不配置内置更新器（由商店负责更新）。
  if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
      !(Platform.isWindows && isWindowsMsixPackaged)) {
    desktop_upd.UpdateConfig().configure(
      updateJsonUrl: '${Env.apiUrl}/api/app/desktop-update.json',
      appExecutableBaseName: Env.overseasBuild ? 'Shrimpsend' : '虾传',
      onLog: (m) => logUpdate.info(m),
      onError: (m) => logUpdate.warning(m),
    );
  }
  logBoot.info('boot: opening database');
  await AppDatabase.instance.open();
  logBoot.info('boot: database opened');

  if (Platform.isAndroid) {
    await SafStorageService.restorePersistedTreeUris();
  }

  if (RuntimePlatform.isDesktop) {
    DesktopPasteDispatcher.instance.ensureInstalled();
  }

  final container = ProviderContainer();
  await container.read(authProvider.notifier).loadFromStorage();
  final isLoggedIn = container.read(authProvider).isLoggedIn;
  final offlineWithoutLogin = await loadOfflineWithoutLogin();
  await localeRegionStore.applyLoggedInDefaultsIfNeeded(isLoggedIn);
  logBoot.info('boot: auth/provider state loaded');

  final authSession = container.read(authSessionControllerProvider.notifier);
  authSession.onStorageLoaded(isLoggedIn: isLoggedIn);

  Future<void> waitForStartupNetworkIfNeeded() async {
    if (!Platform.isWindows || !launchedAtStartup) return;

    const maxWait = Duration(seconds: 30);
    const pollInterval = Duration(seconds: 1);
    final deadline = DateTime.now().add(maxWait);
    logAuth.info(
      'startup network wait: begin maxWait=${maxWait.inSeconds}s',
    );

    while (DateTime.now().isBefore(deadline)) {
      final results = await Connectivity().checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) {
        logAuth.info('startup network wait: connectivity available');
        return;
      }
      await Future.delayed(pollInterval);
    }

    logAuth.warning(
      'startup network wait: timed out after ${maxWait.inSeconds}s, continuing',
    );
  }

  void syncAppLocaleFromStore() {
    container.read(appLocaleProvider.notifier).state =
        localeRegionStore.notifier.value.locale;
  }

  syncAppLocaleFromStore();
  localeRegionStore.notifier.addListener(syncAppLocaleFromStore);

  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> invalidateSessionAndNavigate() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(
          ctx,
        ).pushNamedAndRemoveUntil('/login', (route) => route.isFirst);
        final loc = localeRegionStore.notifier.value.locale;
        AppToast.show(
          ctx,
          message: lookupAppLocalizations(loc).loginSessionExpired,
        );
      }
    });
  }

  authSession.onSessionExpiredNavigate = invalidateSessionAndNavigate;

  setAuthRetryHandler(authSession.handle401WithRetry);

  if (isLoggedIn) {
    unawaited(
      authSession.bootstrapSession(
        useRetry: launchedAtStartup || RuntimePlatform.isDesktop,
        waitForNetwork: waitForStartupNetworkIfNeeded,
      ),
    );
  }

  logAuth.info('main auth loaded, isLoggedIn=$isLoggedIn');

  // Boot env snapshot is scheduled to run after the first frame (see below):
  // on cold start the IDE debug console attaches *after* main() begins, so
  // any log emitted before the first paint is silently dropped. Hot
  // reload/restart, by contrast, runs against an already-attached console
  // which is why the snapshot was visible there but missing on cold start.
  scheduleBootEnvSnapshot();

  if (desktopTraySupported) {
    await initDesktopWindowBeforeRunApp(startHidden: launchedAtStartup);
    logBoot.info('boot: desktop window ready');
  }

  final themeStore = ThemeStore();
  final colorThemeStore = ColorThemeStore();
  final fontSizeStore = FontSizeStore();
  await fontSizeStore.load();
  final appRoot = UncontrolledProviderScope(
    container: container,
    child: MyApp(
      navigatorKey: navigatorKey,
      themeStore: themeStore,
      colorThemeStore: colorThemeStore,
      fontSizeStore: fontSizeStore,
      localeRegionStore: localeRegionStore,
      initialOfflineWithoutLogin: offlineWithoutLogin,
    ),
  );
  // Desktop: skip global glass wrap to reduce route-transition cost; narrow
  // windows may still use GlassBackdropScope / GlassBottomBar (initialize()).
  // Mobile: fixed tier avoids mid-session downgrades on the tab bar; revisit
  // if old devices need the adaptive benchmark.
  final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  final desktopAppRoot = Platform.isWindows
      ? DesktopWindowCloseShortcuts(child: appRoot)
      : appRoot;
  logBoot.info('boot: calling runApp');
  runApp(
    isDesktop
        ? desktopAppRoot
        : LiquidGlassWidgets.wrap(adaptiveQuality: false, child: appRoot),
  );

  // Distinguishes "first frame rendered" from "main() reached runApp but the
  // rasterizer never painted" when triaging white-screen reports.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    logBoot.info('first frame rendered');
  });

  if (desktopTraySupported) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initDesktopTrayAfterFirstFrame();
    });
  }
}

/// Minimal, theme-independent screen shown when startup fails before the app
/// UI can render. Replaces a silent white window with the error, stack trace
/// and log-file path so users can screenshot or send it to support.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({
    super.key,
    required this.error,
    required this.stackTrace,
    this.logFilePath,
  });

  final Object error;
  final StackTrace stackTrace;
  final String? logFilePath;

  @override
  Widget build(BuildContext context) {
    final buffer = StringBuffer()
      ..writeln('启动失败 / Startup failed')
      ..writeln()
      ..writeln(error.toString())
      ..writeln()
      ..writeln(stackTrace.toString());
    if (logFilePath != null) {
      buffer
        ..writeln()
        ..writeln('日志文件 / Log file:')
        ..writeln(logFilePath);
    }
    final text = buffer.toString();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '应用启动失败',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请截图本页面或把日志文件发给开发者协助排查。',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: const Text('复制错误信息'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateCheckWrapper extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget? child;

  const _UpdateCheckWrapper({required this.navigatorKey, this.child});

  @override
  State<_UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<_UpdateCheckWrapper> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      ShareReceiveService.instance.onFilesSavedFromShare =
          _onFilesSavedFromShare;
      ShareReceiveService.instance.init();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (Platform.isAndroid || Platform.isIOS) {
          _checkUpdate();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          if (desktop_upd.UpdateConfig().isConfigured) {
            desktop_upd.UpdateManager().checkForUpdate();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    if (Platform.isAndroid || Platform.isIOS) {
      ShareReceiveService.instance.dispose();
      ShareReceiveService.instance.onFilesSavedFromShare = null;
    }
    super.dispose();
  }

  Future<void> _onFilesSavedFromShare(int count, List<dynamic> files) async {
    if (!mounted) return;
    var totalBytes = 0;
    final platformFiles = <PlatformFile>[];
    for (final f in files) {
      if (f is PlatformFile) {
        platformFiles.add(f);
        totalBytes += f.size;
      }
    }
    Analytics.track(AnalyticsEvents.shareIntoAppReceived, {
      'file_count': count,
      'total_size_bucket': Analytics.sizeBucket(totalBytes),
    });
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    if (platformFiles.isNotEmpty) {
      await ProviderScope.containerOf(ctx, listen: false)
          .read(pendingFilesProvider.notifier)
          .add(
            platformFiles
                .map((f) => PendingFileEntry.fromPlatformFile(f))
                .toList(),
          );
    }
    if (!mounted) return;
    final msg = count == 1 ? '已添加 1 个文件到待发文件箱' : '已添加 $count 个文件到待发文件箱';
    AppToast.show(ctx, message: msg);
    final applyPending = ShareReceiveService.instance.onPendingShareReady;
    if (applyPending != null) {
      applyPending();
      return;
    }
    Navigator.of(ctx).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _checkUpdate() async {
    if (!mounted) return;
    // Play 渠道：更新由 Google Play 处理，应用内不再触发任何检查/下载流程。
    if (Platform.isAndroid && Env.androidPlayDistribution) return;
    final service = AppUpdateService.instance;
    final info = await service.checkForUpdate();
    if (info == null || !mounted) return;
    final showDialog_ = await service.shouldShowStartupDialog(info);
    if (!showDialog_ || !mounted) return;
    await _showUpdateDialog(info);
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;
    await showAppUpdateAvailableDialog(
      context: navContext,
      info: info,
      service: AppUpdateService.instance,
      barrierDismissible: false,
      onIosStore: () => launchExternalUrl(info.iosStoreUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 让状态栏透明，与应用背景融为一体
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );

    final child = AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: widget.child ?? const SizedBox.shrink(),
    );
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (isDesktop && desktop_upd.UpdateConfig().isConfigured) {
      // 顶栏无 Scaffold 实色底时，透明会透出桌面窗口默认色（常见为黑）；与当前主题脚手架背景一致。
      final theme = Theme.of(context);
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: ListenableBuilder(
          listenable: desktop_upd.UpdateManager(),
          builder: (context, _) {
            final restarting =
                desktop_upd.UpdateManager().status ==
                desktop_upd.UpdateStatus.restarting;
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: AppDesktopUpdateBanner(
                        navigatorKey: widget.navigatorKey,
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
                if (restarting) ...[
                  Positioned.fill(
                    child: ModalBarrier(
                      color: theme.colorScheme.scrim.withValues(alpha: 0.45),
                      dismissible: false,
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (ctx) => Text(
                                AppLocalizations.of(ctx).applyingUpdate,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }
    return child;
  }
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final ThemeStore themeStore;
  final ColorThemeStore colorThemeStore;
  final FontSizeStore fontSizeStore;
  final LocaleRegionStore localeRegionStore;
  final bool initialOfflineWithoutLogin;

  const MyApp({
    super.key,
    required this.navigatorKey,
    required this.themeStore,
    required this.colorThemeStore,
    required this.fontSizeStore,
    required this.localeRegionStore,
    required this.initialOfflineWithoutLogin,
  });

  @override
  Widget build(BuildContext context) {
    return LocaleRegionStoreScope(
      store: localeRegionStore,
      child: ThemeStoreScope(
        store: themeStore,
        child: ColorThemeStoreScope(
          store: colorThemeStore,
          child: FontSizeStoreScope(
            store: fontSizeStore,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeStore.notifier,
              builder: (_, themeMode, __) {
                return ValueListenableBuilder<AppColorTheme>(
                  valueListenable: colorThemeStore.notifier,
                  builder: (_, colorTheme, __) {
                    return ValueListenableBuilder<FontSizeLevel>(
                      valueListenable: fontSizeStore.notifier,
                      builder: (_, fontSizeLevel, __) {
                        return ValueListenableBuilder<FontWeightLevel>(
                          valueListenable: fontSizeStore.weightNotifier,
                          builder: (_, fontWeightLevel, __) {
                            return ValueListenableBuilder<LocaleRegionState>(
                              valueListenable: localeRegionStore.notifier,
                              builder: (_, lr, __) {
                            final l10n = lookupAppLocalizations(lr.locale);
                            final taskTitle = brandProductName(
                              l10n,
                              lr.serviceRegion,
                            );
                            final textScale =
                                scaleForFontSizeLevel(fontSizeLevel);
                            final baseWght =
                                wghtForFontWeightLevel(fontWeightLevel);
                            return OKToast(
                              position: ToastPosition(
                                align: Alignment(0, -0.4),
                                offset: 0,
                              ),
                              textPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              radius: 12,
                              child: MaterialApp(
                                navigatorKey: navigatorKey,
                                navigatorObservers: [
                                  if (OpenpanelBootstrap.isInitialized)
                                    OpenpanelObserver(),
                                  NativeTabBarNavigatorObserver(),
                                ],
                                locale: lr.locale,
                                title: taskTitle,
                                themeMode: themeMode,
                                theme: buildAppTheme(
                                  colorTheme: colorTheme,
                                  brightness: Brightness.light,
                                  baseWght: baseWght,
                                ),
                                darkTheme: buildAppTheme(
                                  colorTheme: colorTheme,
                                  brightness: Brightness.dark,
                                  baseWght: baseWght,
                                ),
                                localizationsDelegates: [
                                  ...AppLocalizations.localizationsDelegates,
                                  CountryLocalizations.delegate,
                                ],
                                supportedLocales:
                                    AppLocalizations.supportedLocales,
                                initialRoute: '/',
                                routes: {
                                  '/login': (_) => const LoginScreen(),
                                  '/': (_) => AppEntryScreen(
                                    localeRegionStore: localeRegionStore,
                                    initialOfflineWithoutLogin:
                                        initialOfflineWithoutLogin,
                                  ),
                                  '/files': (_) => const FileManagerScreen(),
                                  '/settings': (_) => const SettingsScreen(),
                                  '/settings/membership': (_) =>
                                      const MembershipScreen(),
                                  '/settings/s3': (_) =>
                                      const S3SettingsScreen(),
                                  '/settings/webdav': (_) =>
                                      const WebDavSettingsScreen(),
                                  '/webdav/add': (_) =>
                                      const WebDavConnectionScreen(),
                            '/settings/shortcuts': (_) =>
                                const ShortcutSettingsScreen(),
                            '/settings/fonts': (_) =>
                                const FontSettingsScreen(),
                                  '/settings/version-history': (_) =>
                                      const VersionHistoryScreen(),
                                  '/settings/app-log': (_) =>
                                      const AppLogScreen(),
                                  '/devices': (_) => const DevicesScreen(),
                                  '/account': (_) => const AccountScreen(),
                                },
                                builder: (context, child) =>
                                    MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    textScaler: TextScaler.linear(textScale),
                                  ),
                                  child: DesktopFileDropScope(
                                    navigatorKey: navigatorKey,
                                    locale: lr.locale,
                                    child: AuthSessionLifecycle(
                                      child: _UpdateCheckWrapper(
                                        navigatorKey: navigatorKey,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
          ),
        ),
      ),
    );
  }
}
