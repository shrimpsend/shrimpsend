import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_desktop_updater/flutter_desktop_updater.dart'
    as desktop_upd;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api.dart';
import '../color_theme.dart';
import '../color_theme_store.dart';
import '../config/env.dart';
import '../legal/open_source_urls.dart';
import '../l10n/app_brand.dart';
import '../l10n/generated/app_localizations.dart';
import '../preferences/country_cluster.dart';
import '../preferences/locale_region_store.dart';
import '../providers/auth_provider.dart';
import '../file_save_preferences.dart';
import '../logger.dart';
import '../providers/app_mode_provider.dart';
import '../providers/app_update_provider.dart';
import '../theme_store.dart';
import '../ui/app_ui.dart';
import '../utils/effective_save_dir_display.dart';
import '../utils/effective_save_dir_display.dart';
import '../utils/gallery_permission.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../services/app_update_service.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/legal_doc_links_row.dart';
import '../services/file_store.dart';
import '../services/receive_dir_resolver.dart';
import '../services/received_file_dao.dart';
import '../services/saf_storage_service.dart';
import '../services/visible_export_target.dart';
import '../services/windows_launch_at_startup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  /// When true (e.g. mobile home tab), hide back [leading] — no route to pop.
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  S3StorageMode _s3Mode = S3StorageMode.disabled;
  bool _loading = true;
  bool _saveToGallery = false;
  bool _deleteCacheAfterSave = false;
  bool _windowsLaunchAtStartup = false;
  String? _customSaveDir;
  String? _customSaveTreeUri;
  String _effectiveSaveDir = '';
  ReceiveDirResolution? _receiveDirResolution;
  ReceiveDirFallbackInfo? _receiveDirFallback;
  UserProfile? _profile;
  MembershipMe? _membership;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      final futures = <Future>[
        isLoggedIn
            ? getS3Config().catchError((_) => S3ConfigDetail.disabled())
            : Future.value(S3ConfigDetail.disabled()),
        getSaveToGallery(),
        getDeleteCacheAfterSave(),
        Platform.isAndroid ? getCustomSaveTreeUri() : getCustomSaveDir(),
        FileStore.getReceiveDirResolution(),
        getReceiveDirFallback(),
        Platform.isWindows
            ? WindowsLaunchAtStartupService.getEnabledPreference()
            : Future.value(false),
        isLoggedIn
            ? fetchUserProfile()
                  .then<UserProfile?>((v) => v)
                  .catchError((_) => null)
            : Future.value(null),
        isLoggedIn
            ? fetchMyMembership()
                  .then<MembershipMe?>((v) => v)
                  .catchError((_) => null)
            : Future.value(null),
      ];
      final results = await Future.wait(futures);
      final s3Detail = results[0] as S3ConfigDetail;
      final saveToGallery = results[1] as bool;
      final deleteCache = results[2] as bool;
      final customSaveDirOrUri = results[3] as String?;
      final receiveResolution = results[4] as ReceiveDirResolution;
      final receiveFallback = results[5] as ReceiveDirFallbackInfo?;
      final windowsLaunchAtStartup = results[6] as bool;
      final profile = results[7] as UserProfile?;
      final membership = results[8] as MembershipMe?;
      logSettings.info(
        'settings_screen load S3 mode=${s3Detail.mode.name} saveToGallery=$saveToGallery deleteCache=$deleteCache windowsLaunchAtStartup=$windowsLaunchAtStartup customSave=${customSaveDirOrUri ?? receiveResolution.customSafTreeUri} effectiveSaveDir=${receiveResolution.path} receiveKind=${receiveResolution.kind.name} fallback=${receiveResolution.usedFallback}',
      );
      if (mounted) {
        setState(() {
          _s3Mode = s3Detail.mode;
          _saveToGallery = saveToGallery;
          _deleteCacheAfterSave = deleteCache;
          _windowsLaunchAtStartup = windowsLaunchAtStartup;
          _customSaveDir = Platform.isAndroid ? null : customSaveDirOrUri;
          _customSaveTreeUri = receiveResolution.customSafTreeUri ??
              (Platform.isAndroid ? customSaveDirOrUri : null);
          _effectiveSaveDir = _formatEffectiveSaveDir(receiveResolution);
          _receiveDirResolution = receiveResolution;
          _receiveDirFallback = receiveFallback;
          _profile = profile;
          _membership = membership;
        });
      }
    } catch (e) {
      logSettings.warning('settings_screen load failed: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  EdgeInsets _settingsBodyPadding() {
    return EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.lg +
          (widget.embedded
              ? AppLayout.floatingBottomBarScrollInset(context)
              : 0),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final colors = context.appColors;

    Widget placeholder({
      required double width,
      required double height,
      BorderRadius? borderRadius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: borderRadius ?? AppRadius.small,
        ),
      );
    }

    Widget row({double titleWidth = 160, double subtitleWidth = 220}) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            placeholder(
              width: AppSize.settingsIcon,
              height: AppSize.settingsIcon,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  placeholder(width: titleWidth, height: 14),
                  const SizedBox(height: AppSpacing.xs),
                  placeholder(width: subtitleWidth, height: 11),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: _settingsBodyPadding(),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSize.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: placeholder(width: 96, height: 12),
                ),
                const SizedBox(height: AppSpacing.xs),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row(),
                      const Divider(height: 1),
                      row(titleWidth: 136, subtitleWidth: 180),
                      const Divider(height: 1),
                      row(titleWidth: 148, subtitleWidth: 210),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: placeholder(width: 88, height: 12),
                ),
                const SizedBox(height: AppSpacing.xs),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row(titleWidth: 128, subtitleWidth: 200),
                      const Divider(height: 1),
                      row(titleWidth: 156, subtitleWidth: 240),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final isOffline = ref.watch(effectiveOfflineModeProvider);
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    final supportsCustomSaveDirPicker =
        Platform.isAndroid ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;
    final showsSavePathInfo = supportsCustomSaveDirPicker || Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.settingsTitle),
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _loading
          ? _buildLoadingSkeleton(context)
          : ListView(
              padding: _settingsBodyPadding(),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSize.contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(
                          title: l10n.settingsSectionFeatures,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildCard(
                          children: [
                            if (!isLoggedIn)
                              _buildNavItem(
                                context: context,
                                icon: LucideIcons.logIn,
                                iconBgColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                iconColor: theme.colorScheme.primary,
                                title: l10n.settingsNavLogin,
                                subtitle: l10n.settingsNavLoginSubtitle,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: AppRadius.small,
                                  ),
                                  child: Text(
                                    l10n.settingsBadgeNotSignedIn,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(context).pushNamed('/login');
                                },
                              )
                            else
                              _buildNavItem(
                                context: context,
                                icon: LucideIcons.circleUserRound,
                                iconBgColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                iconColor: theme.colorScheme.primary,
                                title:
                                    _profile?.email ??
                                    l10n.settingsNavPersonalAccount,
                                subtitle: l10n.settingsNavAccountSubtitle,
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/account',
                                  );
                                  _load();
                                },
                              ),
                            if (isLoggedIn) ...[
                              Divider(
                                height: 1,
                                color: colors.border,
                                indent:
                                    AppSpacing.md +
                                    AppSize.settingsIcon +
                                    AppSpacing.sm,
                              ),
                              _buildNavItem(
                                context: context,
                                icon: LucideIcons.crown,
                                iconBgColor:
                                    (_membership != null &&
                                        _membership!.tierCode.toUpperCase() !=
                                            'FREE')
                                    ? const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.16)
                                    : colors.surfaceMuted,
                                iconColor:
                                    (_membership != null &&
                                        _membership!.tierCode.toUpperCase() !=
                                            'FREE')
                                    ? const Color(0xFFF59E0B)
                                    : colors.textSecondary,
                                title:
                                    (_membership != null &&
                                        _membership!.tierCode.toUpperCase() !=
                                            'FREE')
                                    ? l10n.settingsMembershipTierName(
                                        _membership!.tierName,
                                      )
                                    : l10n.settingsMembershipCenter,
                                subtitle:
                                    (_membership != null &&
                                        _membership!.tierCode.toUpperCase() !=
                                            'FREE')
                                    ? l10n.settingsMembershipDevices(
                                        _membership!.currentDeviceCount,
                                        _membership!.deviceLimit,
                                      )
                                    : l10n.settingsMembershipSubtitleUpgrade,
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/settings/membership',
                                  );
                                  _load();
                                },
                              ),
                              Divider(
                                height: 1,
                                color: colors.border,
                                indent:
                                    AppSpacing.md +
                                    AppSize.settingsIcon +
                                    AppSpacing.sm,
                              ),
                              _buildNavItem(
                                context: context,
                                icon: LucideIcons.monitorSmartphone,
                                iconBgColor: AppColorTheme.lavender.accent
                                    .withValues(alpha: 0.16),
                                iconColor: AppColorTheme.lavender.accent,
                                title: l10n.settingsNavMyDevices,
                                subtitle: isOffline
                                    ? l10n.settingsNavMyDevicesSubtitleOffline
                                    : l10n.settingsNavMyDevicesSubtitleOnline,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/devices'),
                              ),
                              Divider(
                                height: 1,
                                color: colors.border,
                                indent:
                                    AppSpacing.md +
                                    AppSize.settingsIcon +
                                    AppSpacing.sm,
                              ),
                              _buildNavItem(
                                context: context,
                                icon: LucideIcons.cloud,
                                iconBgColor: AppColorTheme.s3Color.withValues(
                                  alpha: 0.14,
                                ),
                                iconColor: AppColorTheme.s3Color,
                                title: l10n.settingsNavS3,
                                subtitle: l10n.settingsNavS3Subtitle,
                                trailing: _buildS3StatusBadge(context),
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/settings/s3',
                                  );
                                  _load();
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(
                          title: l10n.settingsSectionPreferences,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildCard(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Text(
                                LocaleRegionStore.countryLocked
                                    ? l10n.sectionLanguage
                                    : l10n.sectionLanguageRegion,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            ValueListenableBuilder<LocaleRegionState>(
                              valueListenable: LocaleRegionStoreScope.of(
                                context,
                              ).notifier,
                              builder: (context, lr, _) {
                                return Column(
                                  children: [
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                          ),
                                      title: Text(l10n.fieldLanguage),
                                      subtitle: Text(
                                        _languageDisplayLabel(lr.locale, l10n),
                                      ),
                                      trailing: const Icon(
                                        LucideIcons.chevronRight,
                                      ),
                                      onTap: () => _pickLanguage(),
                                    ),
                                    if (!LocaleRegionStore.countryLocked)
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                            ),
                                        title: Text(l10n.fieldCountryRegion),
                                        subtitle: Text(
                                          _countryDisplayLabel(
                                            context,
                                            lr.countryCode,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          LucideIcons.chevronRight,
                                        ),
                                        onTap: () => _pickRegion(),
                                      ),
                                  ],
                                );
                              },
                            ),
                            Divider(height: 1, color: colors.border),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Center(
                                child: Text(
                                  l10n.settingsThemeLabel,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: _ThemeSegment(
                                store: ThemeStoreScope.of(context),
                              ),
                            ),
                            Divider(height: 1, color: colors.border),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Center(
                                child: Text(
                                  l10n.settingsColorThemeLabel,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: _ColorThemePicker(
                                store: ColorThemeStoreScope.of(context),
                              ),
                            ),
                            Divider(height: 1, color: colors.border),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              leading: Icon(
                                LucideIcons.type,
                                color: colors.textSecondary,
                              ),
                              title: Text(l10n.settingsNavFonts),
                              subtitle: Text(l10n.settingsNavFontsSubtitle),
                              trailing: const Icon(LucideIcons.chevronRight),
                              onTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/settings/fonts',
                                );
                              },
                            ),
                            if (_isDesktop) ...[
                              Divider(height: 1, color: colors.border),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                leading: Icon(
                                  LucideIcons.keyboard,
                                  color: colors.textSecondary,
                                ),
                                title: Text(l10n.settingsNavShortcuts),
                                subtitle: Text(l10n.settingsNavShortcutsSubtitle),
                                trailing: const Icon(LucideIcons.chevronRight),
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/settings/shortcuts',
                                  );
                                },
                              ),
                            ],
                            Divider(height: 1, color: colors.border),
                            if (showsSavePathInfo) ...[
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                onTap: _showReceiveDirFallbackWarning,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.settingsFileSavePath,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    if (_shouldShowReceiveDirFallbackWarning)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: AppSpacing.xs,
                                        ),
                                        child: Icon(
                                          LucideIcons.triangleAlert,
                                          size: 18,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_savePathKindLabel(l10n) != null)
                                        Text(
                                          _savePathKindLabel(l10n)!,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (_savePathKindHint(l10n) != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _savePathKindHint(l10n)!,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        _effectiveSaveDir.isEmpty
                                            ? l10n.settingsFileSavePathNotSet
                                            : _effectiveSaveDir,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: AppRadius.small,
                                  ),
                                  child: Text(
                                    _savePathBadgeLabel(l10n),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              if (supportsCustomSaveDirPicker)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    0,
                                    AppSpacing.md,
                                    AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _selectCustomSaveDir,
                                          child: Text(l10n.settingsChooseFolder),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: TextButton(
                                          onPressed: _customSaveDir == null &&
                                                  _customSaveTreeUri == null
                                              ? null
                                              : _restoreDefaultSaveDir,
                                          child: Text(
                                            l10n.settingsRestoreDefaultPath,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!supportsCustomSaveDirPicker)
                                const SizedBox(height: AppSpacing.sm),
                              Divider(height: 1, color: colors.border),
                            ],
                            if (Platform.isAndroid || Platform.isIOS) ...[
                              SwitchListTile(
                                value: _saveToGallery,
                                onChanged: (v) async {
                                  if (v &&
                                      (Platform.isAndroid || Platform.isIOS)) {
                                    final granted =
                                        await requestSaveToGalleryPermission();
                                    if (!mounted) return;
                                    if (!context.mounted) return;
                                    if (!granted) {
                                      AppToast.show(
                                        context,
                                        message:
                                            l10n.settingsGalleryPermissionToast,
                                      );
                                      if (await isSaveToGalleryPermissionBlocked()) {
                                        if (!context.mounted) return;
                                        final openSettings =
                                            await AppConfirmDialog.show(
                                          context,
                                          title: l10n.settingsSaveToGalleryTitle,
                                          content: l10n
                                              .settingsGalleryPermissionToast,
                                          confirmLabel:
                                              l10n.qrScannerOpenSettings,
                                        );
                                        if (openSettings) {
                                          await openAppSettings();
                                        }
                                      }
                                      return;
                                    }
                                  }
                                  await setSaveToGallery(v);
                                  if (mounted) {
                                    setState(() => _saveToGallery = v);
                                  }
                                  if (v && mounted) {
                                    await _showSettingsFeatureHintDialog(
                                      title: l10n.settingsSaveToGalleryTitle,
                                      content: l10n.settingsSaveToGalleryHintBody,
                                    );
                                  }
                                },
                                title: Text(
                                  l10n.settingsSaveToGalleryTitle,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  l10n.settingsSaveToGallerySubtitle,
                                  style: theme.textTheme.bodySmall,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                            ],
                            if (Platform.isWindows) ...[
                              SwitchListTile(
                                value: _windowsLaunchAtStartup,
                                onChanged: (v) async {
                                  try {
                                    await WindowsLaunchAtStartupService.setEnabled(
                                      v,
                                    );
                                    if (mounted) {
                                      setState(
                                        () => _windowsLaunchAtStartup = v,
                                      );
                                    }
                                  } catch (e) {
                                    logSettings.warning(
                                      'set windows launch at startup failed: $e',
                                    );
                                    if (!mounted || !context.mounted) return;
                                    AppToast.show(
                                      context,
                                      message: l10n
                                          .settingsWindowsLaunchAtStartupFailed,
                                    );
                                  }
                                },
                                title: Text(
                                  l10n.settingsWindowsLaunchAtStartupTitle,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  l10n.settingsWindowsLaunchAtStartupSubtitle,
                                  style: theme.textTheme.bodySmall,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                            ],
                            SwitchListTile(
                              value: _deleteCacheAfterSave,
                              onChanged: (v) async {
                                await setDeleteCacheAfterSave(v);
                                if (mounted) {
                                  setState(() => _deleteCacheAfterSave = v);
                                }
                                if (v && mounted) {
                                  await _showSettingsFeatureHintDialog(
                                    title: l10n.settingsDeleteCacheAfterSaveTitle,
                                    content:
                                        l10n.settingsDeleteCacheAfterSaveHintBody,
                                  );
                                }
                              },
                              title: Text(
                                l10n.settingsDeleteCacheAfterSaveTitle,
                                style: theme.textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                l10n.settingsDeleteCacheAfterSaveSubtitle,
                                style: theme.textTheme.bodySmall,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle(
                          title: l10n.settingsSectionAbout,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildCard(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: AppRadius.medium,
                                        child: Image.asset(
                                          'assets/logo.png',
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ValueListenableBuilder<
                                              LocaleRegionState
                                            >(
                                              valueListenable:
                                                  LocaleRegionStoreScope.of(
                                                    context,
                                                  ).notifier,
                                              builder: (context, lr, _) {
                                                return Text(
                                                  brandDisplayName(
                                                    context,
                                                    lr.serviceRegion,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium,
                                                );
                                              },
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xxs,
                                            ),
                                            Text(
                                              l10n.aboutTagline,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xxs,
                                            ),
                                            ref
                                                .watch(packageInfoProvider)
                                                .when(
                                                  data: (info) => Text(
                                                    l10n.settingsVersionWithBuild(
                                                      info.version,
                                                      info.buildNumber,
                                                    ),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .textTertiary,
                                                        ),
                                                  ),
                                                  loading: () => Text(
                                                    l10n.settingsVersionLoading,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .textTertiary,
                                                        ),
                                                  ),
                                                  error: (_, __) => Text(
                                                    l10n.settingsVersionUnknown,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .textTertiary,
                                                        ),
                                                  ),
                                                ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: colors.border),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: LegalDocLinksRow(compact: true),
                            ),
                            Divider(height: 1, color: colors.border),
                            _buildNavItem(
                              context: context,
                              icon: SimpleIcons.github,
                              iconBgColor: colors.surfaceMuted,
                              iconColor: colors.textSecondary,
                              title: l10n.settingsNavSourceCode,
                              subtitle: l10n.settingsNavSourceCodeSubtitle,
                              onTap: () =>
                                  launchExternalUrl(kOpenSourceRepoUrl),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_isDesktop)
                          _buildDesktopUpdateSection(context)
                        else
                          ValueListenableBuilder<UpdateState>(
                            valueListenable: ref
                                .read(appUpdateServiceProvider)
                                .state,
                            builder: (context, updateState, _) =>
                                _buildUpdateSection(context, updateState),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildCard(
                          children: [
                            _buildNavItem(
                              context: context,
                              icon: LucideIcons.history,
                              iconBgColor: colors.surfaceMuted,
                              iconColor: colors.textSecondary,
                              title: l10n.settingsNavVersionHistory,
                              subtitle: l10n.settingsNavVersionHistorySubtitle,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/settings/version-history',
                              ),
                            ),
                            Divider(height: 1, color: colors.border),
                            _buildNavItem(
                              context: context,
                              icon: LucideIcons.scrollText,
                              iconBgColor: colors.surfaceMuted,
                              iconColor: colors.textSecondary,
                              title: l10n.settingsNavAppLog,
                              subtitle: _isDesktop
                                  ? l10n.settingsNavAppLogSubtitleDesktop
                                  : l10n.settingsNavAppLogSubtitleMobile,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/settings/app-log',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildS3StatusBadge(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final Color background;
    final Color foreground;
    final String label;
    switch (_s3Mode) {
      case S3StorageMode.custom:
        background = colors.successSurface;
        foreground = colors.success;
        label = l10n.settingsS3StatusCustom;
        break;
      case S3StorageMode.hosted:
        final scheme = theme.colorScheme;
        background = scheme.primary.withValues(alpha: 0.12);
        foreground = scheme.primary;
        label = l10n.settingsS3StatusHosted;
        break;
      case S3StorageMode.disabled:
        background = colors.surfaceMuted;
        foreground = colors.textSecondary;
        label = l10n.settingsS3StatusNotConfigured;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.small,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _desktopUpdateSubtitle(AppLocalizations l10n) {
    final m = desktop_upd.UpdateManager();
    switch (m.status) {
      case desktop_upd.UpdateStatus.initial:
        return l10n.desktopUpdateTapCheck;
      case desktop_upd.UpdateStatus.checking:
        return l10n.desktopUpdateChecking;
      case desktop_upd.UpdateStatus.updateAvailable:
        return l10n.desktopUpdateAvailableUseBanner;
      case desktop_upd.UpdateStatus.updating:
        return l10n.desktopUpdateDownloadingPercent(
          (m.progress * 100).toStringAsFixed(0),
        );
      case desktop_upd.UpdateStatus.readyToRestart:
        return l10n.desktopUpdateReadyRestart;
      case desktop_upd.UpdateStatus.restarting:
        return l10n.desktopUpdateRestarting;
      case desktop_upd.UpdateStatus.error:
        return m.error ?? l10n.desktopUpdateCheckFailed;
    }
  }

  Widget _buildDesktopUpdateSection(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: desktop_upd.UpdateManager(),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        return _buildCard(
          children: [
            _buildNavItem(
              context: context,
              icon: LucideIcons.download,
              iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              iconColor: theme.colorScheme.primary,
              title: l10n.settingsCheckUpdate,
              subtitle: desktop_upd.UpdateConfig().isConfigured
                  ? _desktopUpdateSubtitle(l10n)
                  : l10n.desktopUpdateNotConfiguredHint,
              onTap: () {
                if (!desktop_upd.UpdateConfig().isConfigured) {
                  AppToast.show(
                    context,
                    message: l10n.desktopToastUpdateNotConfigured,
                  );
                  return;
                }
                _onDesktopCheckUpdate(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _onDesktopCheckUpdate(BuildContext context) async {
    if (!desktop_upd.UpdateConfig().isConfigured) return;
    await desktop_upd.UpdateManager().checkForUpdate();
    if (!mounted || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final m = desktop_upd.UpdateManager();
    if (m.status == desktop_upd.UpdateStatus.error) {
      AppToast.show(context, message: m.error ?? l10n.desktopToastCheckFailed);
      return;
    }
    if (m.status == desktop_upd.UpdateStatus.updateAvailable) {
      AppToast.show(context, message: l10n.desktopToastNewVersionUseBanner);
      return;
    }
    if (m.status == desktop_upd.UpdateStatus.initial) {
      AppToast.show(context, message: l10n.desktopToastAlreadyLatest);
    }
  }

  Widget _buildUpdateSection(BuildContext context, UpdateState updateState) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final service = ref.read(appUpdateServiceProvider);

    if (Platform.isAndroid && Env.androidPlayDistribution) {
      return _buildCard(
        children: [
          _buildNavItem(
            context: context,
            icon: LucideIcons.download,
            iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            iconColor: theme.colorScheme.primary,
            title: l10n.settingsCheckUpdate,
            subtitle: l10n.updateStatusPlayManaged,
            onTap: () => _openPlayStoreListing(context),
          ),
        ],
      );
    }

    return _buildCard(
      children: [
        _buildNavItem(
          context: context,
          icon: LucideIcons.download,
          iconBgColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          iconColor: theme.colorScheme.primary,
          title: l10n.settingsCheckUpdate,
          subtitle: _updateStatusSubtitle(updateState, l10n),
          onTap: () => _onCheckUpdate(context, service),
        ),
        if (updateState.status == UpdateStatus.downloading)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: updateState.progress),
                const SizedBox(height: 4),
                Text(
                  l10n.mobileUpdateDownloadingPercent(
                    (updateState.progress * 100).toStringAsFixed(0),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        if (updateState.status == UpdateStatus.downloaded &&
            updateState.downloadedPath != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.mobileUpdateDownloadedInstall,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.success,
                  ),
                ),
                if (updateState.downloadedVersion != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.appUpdateDownloadedVersionLabel(
                      updateState.downloadedVersion!,
                      '${updateState.info?.buildNumber ?? '—'}',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.appUpdateDownloadedFileLabel(
                      p.basename(updateState.downloadedPath!),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () =>
                          _installApk(context, updateState.downloadedPath!),
                      child: Text(l10n.mobileUpdateInstall),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (updateState.status == UpdateStatus.error &&
            updateState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    updateState.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.danger,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => service.checkForUpdate(),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _updateStatusSubtitle(UpdateState s, AppLocalizations l10n) {
    switch (s.status) {
      case UpdateStatus.idle:
        return l10n.updateStatusAlreadyLatest;
      case UpdateStatus.checking:
        return l10n.updateStatusChecking;
      case UpdateStatus.updateAvailable:
        return s.info != null
            ? l10n.updateStatusNewVersion(s.info!.version)
            : l10n.updateStatusCheckAction;
      case UpdateStatus.downloading:
        return l10n.updateStatusDownloadingPercent(
          (s.progress * 100).toStringAsFixed(0),
        );
      case UpdateStatus.downloaded:
        if (s.downloadedVersion != null && s.downloadedVersion!.isNotEmpty) {
          return '${l10n.updateStatusDownloadedReady} · v${s.downloadedVersion}';
        }
        return l10n.updateStatusDownloadedReady;
      case UpdateStatus.error:
        return l10n.updateStatusCheckFailed;
    }
  }

  Future<void> _onCheckUpdate(
    BuildContext context,
    AppUpdateService service,
  ) async {
    if (_isDesktop) {
      await _onDesktopCheckUpdate(context);
      return;
    }
    final info = await service.checkForUpdate();
    if (!mounted) return;
    if (!context.mounted) return;
    if (info == null) {
      if (service.state.value.status == UpdateStatus.idle) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).desktopToastAlreadyLatest,
        );
      }
      return;
    }
    await showAppUpdateAvailableDialog(
      context: context,
      info: info,
      service: service,
      barrierDismissible: true,
      onIosStore: () => launchExternalUrl(info.iosStoreUrl),
    );
  }

  Future<void> _openPlayStoreListing(BuildContext context) async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      await launchExternalUrl(
        'https://play.google.com/store/apps/details?id=${pkg.packageName}',
      );
    } catch (e) {
      logSettings.warning('open play listing failed: $e');
    }
  }

  static const _apkChannel = MethodChannel('dev.ultrasend/apk');

  Future<void> _installApk(BuildContext context, String filePath) async {
    try {
      final installPath = await AppUpdateService.pathForInstall(filePath);
      final res = await _apkChannel.invokeMethod('installApk', {
        'filePath': installPath,
      });
      if (!mounted || !context.mounted) return;
      if (res == null) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).snackbarAllowInstallUnknownApps,
          duration: const Duration(seconds: 3),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted || !context.mounted) return;
      final loc = AppLocalizations.of(context);
      if (e.code == 'PERMISSION_REQUIRED') {
        AppToast.show(
          context,
          message: loc.snackbarAllowInstallUnknownApps,
          duration: const Duration(seconds: 3),
        );
      } else {
        AppToast.show(
          context,
          message: loc.settingsInstallFailed(e.message ?? ''),
        );
      }
    }
  }

  String _languageDisplayLabel(Locale locale, AppLocalizations l10n) {
    if (locale.languageCode == 'zh') return l10n.localeNameZhHans;
    return l10n.localeNameEnglish;
  }

  String _countryDisplayLabel(BuildContext context, String code) {
    final c = CountryService().findByCode(code);
    if (c == null) return code;
    return c.getTranslatedName(context) ?? c.name;
  }

  Future<void> _pickLanguage() async {
    final store = LocaleRegionStoreScope.of(context);
    final chosen = await showModalBottomSheet<Locale>(
      context: context,
      builder: (ctx) {
        final sheetLoc = AppLocalizations.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(sheetLoc.localeNameZhHans),
                onTap: () => Navigator.pop(ctx, const Locale('zh', 'CN')),
              ),
              ListTile(
                title: Text(sheetLoc.localeNameEnglish),
                onTap: () => Navigator.pop(ctx, const Locale('en')),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    await store.setLocale(chosen);
    Analytics.track(AnalyticsEvents.settingChanged, {
      'key': 'locale',
      'value':
          '${chosen.languageCode}${chosen.countryCode != null ? '_${chosen.countryCode}' : ''}',
    });
  }

  Future<void> _pickRegion() async {
    final store = LocaleRegionStoreScope.of(context);
    final current = store.notifier.value;
    final l10n = AppLocalizations.of(context);

    showCountryPicker(
      context: context,
      useRootNavigator: true,
      showWorldWide: false,
      favorite: const [
        'CN',
        'US',
        'HK',
        'TW',
        'JP',
        'SG',
        'GB',
        'AU',
        'CA',
        'DE',
        'FR',
      ],
      // async 回调若在底部弹窗关闭前触发 showDialog，易导致路由冲突、表现为「点了没反应」；
      // 延后到下一事件循环再执行。
      onSelect: (Country country) {
        Future.microtask(
          () => _applyPickedCountryRegion(country, store, current, l10n),
        );
      },
    );
  }

  Future<void> _applyPickedCountryRegion(
    Country country,
    LocaleRegionStore store,
    LocaleRegionState current,
    AppLocalizations l10n,
  ) async {
    final newCode = country.countryCode;
    if (newCode == current.countryCode) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final beforeCluster = serviceRegionForCountryCode(current.countryCode);
    final snapshot = LocaleRegionState(
      locale: current.locale,
      countryCode: current.countryCode,
      localeGateCompleted: current.localeGateCompleted,
    );

    final clusterSwitch = beforeCluster != serviceRegionForCountryCode(newCode);
    final loggedIn = ref.read(authProvider).isLoggedIn;

    // 与线上/本地无关：只要服务集群（CN vs 非 CN）变化且已登录，即提示退出，便于本地调试复现。
    if (clusterSwitch && loggedIn) {
      final ok = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.serverClusterSwitchTitle),
          content: Text(l10n.serverClusterSwitchMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await ref.read(authProvider.notifier).clearAuth();
      await store.restoreState(snapshot);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      return;
    }

    await store.setCountryCode(newCode);
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: AppSize.settingsIcon,
              height: AppSize.settingsIcon,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: AppRadius.small,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: AppSpacing.xs),
            ],
            Icon(
              LucideIcons.chevronRight,
              color: colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  bool get _shouldShowReceiveDirFallbackWarning =>
      _receiveDirResolution?.usedFallback == true &&
      _receiveDirFallback != null &&
      !_receiveDirFallback!.isEmpty;

  String _savePathBadgeLabel(AppLocalizations l10n) {
    final resolution = _receiveDirResolution;
    final visible = resolution?.visibleExportTarget;

    if (visible?.isCustom == true ||
        resolution?.customSafTreeUri != null ||
        _customSaveDir != null ||
        _customSaveTreeUri != null) {
      return l10n.settingsSavePathBadgeCustom;
    }

    if (visible != null) {
      return switch (visible.kind) {
        VisibleExportKind.downloads => l10n.settingsSavePathBadgeDefault,
        VisibleExportKind.documents => l10n.settingsSavePathKindAppDocuments,
        VisibleExportKind.customDir => l10n.settingsSavePathBadgeCustom,
        VisibleExportKind.safTree => l10n.settingsSavePathBadgeCustom,
      };
    }

    if (resolution == null) return l10n.settingsSavePathBadgeDefault;
    if (resolution.usedFallback) {
      return l10n.settingsSavePathKindAppCache;
    }
    if (resolution.kind == ReceiveStorageKind.appDocuments) {
      return l10n.settingsSavePathKindAppDocuments;
    }
    if (resolution.kind == ReceiveStorageKind.appExternal) {
      return l10n.settingsSavePathKindAppExternal;
    }
    if (resolution.kind == ReceiveStorageKind.appCache) {
      return l10n.settingsSavePathKindAppCache;
    }
    return l10n.settingsSavePathKindExternal;
  }

  String? _savePathKindLabel(AppLocalizations l10n) {
    return l10n.settingsSavePathSafMirrorLabel;
  }

  String? _savePathKindHint(AppLocalizations l10n) {
    return l10n.settingsSavePathSafSyncHint;
  }

  Future<void> _showSettingsFeatureHintDialog({
    required String title,
    required String content,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          titlePadding: AppDialog.titlePadding,
          contentPadding: AppDialog.confirmContentPadding,
          actionsPadding: AppDialog.actionsPadding,
          title: Text(title),
          content: Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.settingsSavePathFallbackDialogOk),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReceiveDirFallbackWarning() async {
    if (!_shouldShowReceiveDirFallbackWarning || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final fallback = _receiveDirFallback!;
    final resolution = _receiveDirResolution!;
  await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          titlePadding: AppDialog.titlePadding,
          contentPadding: AppDialog.confirmContentPadding,
          actionsPadding: AppDialog.actionsPadding,
          title: Text(l10n.settingsSavePathFallbackDialogTitle),
          content: Text(
            l10n.settingsSavePathFallbackDialogBody(
              fallback.intendedPath,
              resolution.path,
              fallback.fallbackReason.isNotEmpty
                  ? fallback.fallbackReason
                  : '—',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.settingsSavePathFallbackDialogOk),
            ),
          ],
        );
      },
    );
  }

  String _formatEffectiveSaveDir(ReceiveDirResolution resolution) =>
      formatEffectiveSaveDir(resolution);

  Future<void> _selectCustomSaveDir() async {
    if (Platform.isAndroid) {
      try {
        final treeUri = await SafStorageService.pickSaveTree();
        if (treeUri == null || treeUri.trim().isEmpty) return;
        await _applyCustomSaveDir(treeUri);
      } catch (_) {
        if (mounted) {
          AppToast.show(
            context,
            message: AppLocalizations.of(context).settingsSavePathFailedToast,
          );
        }
      }
      return;
    }
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null || dirPath.trim().isEmpty) return;
    await _applyCustomSaveDir(dirPath);
  }

  Future<void> _applyCustomSaveDir(String value) async {
    try {
      if (Platform.isAndroid && value.startsWith('content://')) {
        final ok = await SafStorageService.probeWritable(value);
        if (!ok) {
          throw StateError('SAF tree not writable');
        }
        final displayName = await SafStorageService.getDisplayName(value);
        await setCustomSaveTreeUri(treeUri: value, displayName: displayName);
        await clearReceiveDirFallback();
        FileStore.invalidateReceiveDirCache();
        final resolution = await FileStore.getReceiveDirResolution();
        try {
          await ReceivedFileDao.instance.reconcileWithRoot(resolution.path);
        } catch (e) {
          logChat.warning('reconcileWithRoot failed: $e');
        }
        if (!mounted) return;
        final fallback = await getReceiveDirFallback();
        if (!mounted) return;
        setState(() {
          _customSaveDir = null;
          _customSaveTreeUri = value;
          _effectiveSaveDir = _formatEffectiveSaveDir(resolution);
          _receiveDirResolution = resolution;
          _receiveDirFallback = fallback;
        });
        if (!context.mounted) return;
        AppToast.show(
          context,
          message: AppLocalizations.of(context).settingsSavePathUpdatedToast,
        );
        FileStore.notifyReceiveDirChanged();
        return;
      }

      final dir = Directory(value);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await FileStore.assertWritableDirectory(dir.path);
      final normalizedDirPath = normalizeCustomSaveDirValue(dir.path);
      await setCustomSaveDir(normalizedDirPath);
      await clearReceiveDirFallback();
      FileStore.invalidateReceiveDirCache();
      final resolution = await FileStore.getReceiveDirResolution();
      // Keep existing index rows pointing at the old root — those files are
      // still on disk and should remain visible in the file manager. Just
      // pick up any orphan subdirs that may already be present at the new
      // root so they show up as well.
      try {
        await ReceivedFileDao.instance.reconcileWithRoot(resolution.path);
      } catch (e) {
        logChat.warning('reconcileWithRoot failed: $e');
      }
      if (!mounted) return;
      final fallback = await getReceiveDirFallback();
      if (!mounted) return;
      setState(() {
        _customSaveDir = normalizedDirPath;
        _effectiveSaveDir = _formatEffectiveSaveDir(resolution);
        _receiveDirResolution = resolution;
        _receiveDirFallback = fallback;
      });
      if (!context.mounted) return;
      AppToast.show(
        context,
        message: AppLocalizations.of(context).settingsSavePathUpdatedToast,
      );
      FileStore.notifyReceiveDirChanged();
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).settingsSavePathFailedToast,
        );
      }
    }
  }

  Future<void> _restoreDefaultSaveDir() async {
    try {
      await clearCustomSaveDir();
      FileStore.invalidateReceiveDirCache();
      final resolution = await FileStore.getReceiveDirResolution();
      try {
        await ReceivedFileDao.instance.reconcileWithRoot(resolution.path);
      } catch (e) {
        logChat.warning('reconcileWithRoot failed: $e');
      }
      if (!mounted) return;
      final fallback = await getReceiveDirFallback();
      if (!mounted) return;
      setState(() {
        _customSaveDir = null;
        _customSaveTreeUri = null;
        _effectiveSaveDir = _formatEffectiveSaveDir(resolution);
        _receiveDirResolution = resolution;
        _receiveDirFallback = fallback;
      });
      if (!context.mounted) return;
      AppToast.show(
        context,
        message: AppLocalizations.of(context).settingsSavePathRestoredToast,
      );
      FileStore.notifyReceiveDirChanged();
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsSavePathRestoreFailedToast,
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatefulWidget {
  const _ThemeSegment({required this.store});

  final ThemeStore store;

  @override
  State<_ThemeSegment> createState() => _ThemeSegmentState();
}

class _ThemeSegmentState extends State<_ThemeSegment> {
  @override
  void initState() {
    super.initState();
    widget.store.notifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.store.notifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final current = widget.store.notifier.value;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip(l10n.themeModeFollowSystem, ThemeMode.system, current),
        const SizedBox(width: 8),
        _chip(l10n.themeModeLight, ThemeMode.light, current),
        const SizedBox(width: 8),
        _chip(l10n.themeModeDark, ThemeMode.dark, current),
      ],
    );
  }

  Widget _chip(String label, ThemeMode mode, ThemeMode current) {
    final selected = current == mode;
    final theme = Theme.of(context);
    final colors = context.appColors;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        widget.store.setTheme(mode);
        Analytics.track(AnalyticsEvents.settingChanged, {
          'key': 'theme_mode',
          'value': mode.name,
        });
      },
      showCheckmark: false,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: selected ? theme.colorScheme.onPrimary : colors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

String _localizedColorThemeName(AppLocalizations l10n, AppColorTheme preset) {
  switch (preset.id) {
    case 'emerald':
      return l10n.settingsColorThemeEmerald;
    case 'ocean':
      return l10n.settingsColorThemeOcean;
    case 'sunset':
      return l10n.settingsColorThemeSunset;
    case 'lavender':
      return l10n.settingsColorThemeLavender;
    case 'rose':
      return l10n.settingsColorThemeRose;
    case 'graphite':
      return l10n.settingsColorThemeGraphite;
    default:
      return l10n.settingsColorThemeEmerald;
  }
}

class _ColorThemePicker extends StatefulWidget {
  const _ColorThemePicker({required this.store});

  final ColorThemeStore store;

  @override
  State<_ColorThemePicker> createState() => _ColorThemePickerState();
}

class _ColorThemePickerState extends State<_ColorThemePicker> {
  @override
  void initState() {
    super.initState();
    widget.store.notifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.store.notifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.store.notifier.value;
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: 10,
      children: AppColorTheme.presets.map((preset) {
        final selected = current.id == preset.id;
        return GestureDetector(
          onTap: () {
            widget.store.setTheme(preset);
            Analytics.track(AnalyticsEvents.settingChanged, {
              'key': 'color_theme',
              'value': preset.id,
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSize.settingsSwatch,
                height: AppSize.settingsSwatch,
                decoration: BoxDecoration(
                  color: preset.accent,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2.5,
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: preset.accent.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(
                        LucideIcons.check,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _localizedColorThemeName(l10n, preset),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? preset.accent : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
