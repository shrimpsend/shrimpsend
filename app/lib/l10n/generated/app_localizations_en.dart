// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get brandNameMainlandChina => 'ShrimpSend';

  @override
  String get brandNameInternational => 'ShrimpSend';

  @override
  String get localeRegionGateTitle => 'Language';

  @override
  String get localeRegionGateSubtitle =>
      'Choose the display language. The service region for this app build is fixed.';

  @override
  String get localeRegionGateCountryHint =>
      'Tap to choose. Mainland China (CN) uses the Xiachuan cluster; others use ShrimpSend.';

  @override
  String get fieldLanguage => 'Language';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get fieldCountryRegion => 'Country or region';

  @override
  String get regionMainlandChina => 'Mainland China';

  @override
  String get regionInternational => 'Outside Mainland China';

  @override
  String get continueAction => 'Continue';

  @override
  String get loginSessionExpired => 'Session expired, please sign in again';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionLanguageRegion => 'Language and region';

  @override
  String get serverClusterSwitchTitle => 'You will be signed out';

  @override
  String get serverClusterSwitchMessage =>
      'The selected country or region uses a different service domain and cluster. To protect your account, you will be signed out now and must sign in again on the new domain to continue. Your country selection will revert to the previous value for now; you can choose again after signing in.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get signOutRequired => 'Sign out required';

  @override
  String get loginTitleSubtitleLogin =>
      'Sign in to continue your cross-device transfer';

  @override
  String get loginTitleSubtitleRegister =>
      'Create an account to sync messages and files';

  @override
  String get enterOfflineMode => 'Continue in offline mode';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalCouldNotOpenLink => 'Could not open the link';

  @override
  String get envLabelDev => 'Test';

  @override
  String get envLabelProd => 'Online';

  @override
  String get applyingUpdate =>
      'Applying update, the app will restart (a few seconds)…';

  @override
  String get localeNameZhHans => 'Simplified Chinese';

  @override
  String get localeNameEnglish => 'English';

  @override
  String get loginTabLogin => 'Log in';

  @override
  String get loginTabRegister => 'Sign up';

  @override
  String get loginMethodPassword => 'Password';

  @override
  String get loginMethodCode => 'Code';

  @override
  String get fieldEmail => 'Email';

  @override
  String get hintEmail => 'you@example.com';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldVerificationCode => 'Verification code';

  @override
  String get hintVerificationCode6 => '6-digit code';

  @override
  String get fieldNicknameOptional => 'Nickname (optional)';

  @override
  String get hintDisplayName => 'Display name';

  @override
  String get loginGetVerificationCode => 'Get code';

  @override
  String get loginSendVerificationCode => 'Send code';

  @override
  String codeCooldownSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get loginSubmitRegister => 'Sign up';

  @override
  String get loginSubmitWithCode => 'Log in with code';

  @override
  String get loginSubmitPassword => 'Log in';

  @override
  String get loginQrLogin => 'Scan to sign in';

  @override
  String get loginPromptNoAccount => 'No account?';

  @override
  String get loginPromptHasAccount => 'Already have an account?';

  @override
  String get loginLinkToRegister => 'Sign up';

  @override
  String get loginLinkToLogin => 'Log in';

  @override
  String get loginErrorEmailRequired => 'Enter your email first';

  @override
  String get loginErrorCodeSixDigits => 'Enter the 6-digit code';

  @override
  String get snackbarAllowInstallUnknownApps =>
      'Allow installing unknown apps in Settings; installation will continue when you return';

  @override
  String get settingsSectionFeatures => 'Features';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsNavLogin => 'Sign in';

  @override
  String get settingsNavLoginSubtitle =>
      'Cloud sync and more after you sign in';

  @override
  String get settingsBadgeNotSignedIn => 'Not signed in';

  @override
  String get settingsNavPersonalAccount => 'Account';

  @override
  String get settingsNavAccountSubtitle => 'View and manage your account';

  @override
  String get settingsMembershipCenter => 'Membership';

  @override
  String get settingsMembershipSubtitleUpgrade =>
      'Lifetime plans and more devices';

  @override
  String settingsMembershipTierName(String tierName) {
    return '$tierName membership';
  }

  @override
  String settingsMembershipDevices(int current, int limit) {
    return '$current of $limit devices';
  }

  @override
  String get settingsNavMyDevices => 'My devices';

  @override
  String get settingsNavMyDevicesSubtitleOffline =>
      'Manage devices after you sign in';

  @override
  String get settingsNavMyDevicesSubtitleOnline => 'Bound devices';

  @override
  String get settingsNavS3 => 'S3';

  @override
  String get settingsNavS3Subtitle => 'Wide-area file transfer';

  @override
  String get settingsNavShortcuts => 'Shortcuts';

  @override
  String get settingsNavShortcutsSubtitle =>
      'Keyboard actions such as sending messages';

  @override
  String get settingsNavFonts => 'Fonts';

  @override
  String get settingsNavFontsSubtitle => 'Adjust text size and weight';

  @override
  String get settingsFontsPageTitle => 'Fonts';

  @override
  String get settingsShortcutsPageTitle => 'Shortcuts';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsColorThemeLabel => 'Color theme';

  @override
  String get settingsColorThemeEmerald => 'Emerald';

  @override
  String get settingsColorThemeOcean => 'Ocean';

  @override
  String get settingsColorThemeSunset => 'Sunset';

  @override
  String get settingsColorThemeLavender => 'Lavender';

  @override
  String get settingsColorThemeRose => 'Rose';

  @override
  String get settingsColorThemeGraphite => 'Graphite';

  @override
  String get settingsFontLabel => 'Fonts';

  @override
  String get settingsFontLatinLabel => 'English font';

  @override
  String get settingsFontCjkLabel => 'Chinese font';

  @override
  String get settingsFontMonoLabel => 'Monospace font';

  @override
  String get settingsFontSystem => 'System default';

  @override
  String get settingsFontInter => 'Inter';

  @override
  String get settingsFontSourceSans3 => 'Source Sans 3';

  @override
  String get settingsFontIbmPlexSans => 'IBM Plex Sans';

  @override
  String get settingsFontNotoSansSc => 'Noto Sans SC';

  @override
  String get settingsFontNotoSerifSc => 'Noto Serif SC';

  @override
  String get settingsFontLxgwWenkai => 'LXGW WenKai';

  @override
  String get settingsFontSmileySans => 'Smiley Sans';

  @override
  String get settingsFontIbmPlexMono => 'IBM Plex Mono';

  @override
  String get settingsFontPreview => 'ShrimpSend · Hello world · 123';

  @override
  String get settingsFontSizeLabel => 'Text size';

  @override
  String get settingsFontSizeSmaller => 'Smaller';

  @override
  String get settingsFontSizeSmall => 'Small';

  @override
  String get settingsFontSizeStandard => 'Standard';

  @override
  String get settingsFontSizeLarge => 'Large';

  @override
  String get settingsFontSizeLarger => 'Larger';

  @override
  String get settingsFontWeightLabel => 'Text weight';

  @override
  String get settingsFontWeightLighter => 'Lighter';

  @override
  String get settingsFontWeightLight => 'Light';

  @override
  String get settingsFontWeightNormal => 'Normal';

  @override
  String get settingsFontWeightMedium => 'Medium';

  @override
  String get settingsFontWeightSemibold => 'Semibold';

  @override
  String get settingsFontLicenses =>
      'Windows builds bundle WenYuan Sans SC / 文源黑体 (SIL Open Font License 1.1). Other platforms use system fonts. Source: https://github.com/takushun-wu/WenYuanFonts';

  @override
  String get settingsFileSavePath => 'File save location';

  @override
  String get settingsFileSavePathNotSet => 'Not set';

  @override
  String get settingsSavePathBadgeDefault => 'Default';

  @override
  String get settingsSavePathBadgeCustom => 'Custom';

  @override
  String get settingsSavePathKindExternal => 'External storage';

  @override
  String get settingsSavePathKindAppDocuments => 'App documents';

  @override
  String get settingsSavePathKindAppCache => 'App cache';

  @override
  String get settingsSavePathKindAppExternal => 'App-specific storage';

  @override
  String get settingsSavePathKindHintAppDocuments =>
      'Files are saved in the app documents folder and visible in the Files app';

  @override
  String get settingsSavePathKindHintAppExternal =>
      'Files are saved in app-specific external storage and may be removed when app data is cleared';

  @override
  String get settingsSavePathFallbackDialogOk => 'OK';

  @override
  String get settingsSavePathFallbackDialogTitle =>
      'External save location unavailable';

  @override
  String settingsSavePathFallbackDialogBody(
    String intendedPath,
    String currentPath,
    String reason,
  ) {
    return 'Some in-car or custom systems block creating folders on external storage. Files are saved to app cache instead.\n\nExpected: $intendedPath\nCurrent: $currentPath\nReason: $reason';
  }

  @override
  String get settingsChooseFolder => 'Choose folder';

  @override
  String get settingsRestoreDefaultPath => 'Reset to default';

  @override
  String get settingsGalleryPermissionToast =>
      'Photo library access is required to save to your gallery. Allow it in system Settings.';

  @override
  String get settingsSaveToGalleryTitle => 'Save images and videos to gallery';

  @override
  String get settingsSaveToGallerySubtitle =>
      'Incoming images and videos are saved to the system gallery automatically';

  @override
  String get settingsSaveToGalleryHintBody =>
      'When enabled, images and videos are saved to the system gallery only — they are not copied to your save folder. In File Manager, these files appear under Cache but not under Save folder.';

  @override
  String get settingsWindowsLaunchAtStartupTitle => 'Launch at startup';

  @override
  String get settingsWindowsLaunchAtStartupSubtitle =>
      'Start automatically after Windows sign-in and stay hidden in the tray';

  @override
  String get settingsWindowsLaunchAtStartupFailed =>
      'Failed to update launch at startup. Try again later.';

  @override
  String get settingsDeleteCacheAfterSaveTitle => 'Delete cache after saving';

  @override
  String get settingsDeleteCacheAfterSaveSubtitle =>
      'Remove the in-app cache copy after the file is saved to your folder';

  @override
  String get settingsDeleteCacheAfterSaveHintBody =>
      'Received file cache copies will be deleted and will not appear in File Manager\'s Cache tab.';

  @override
  String get aboutTagline =>
      'Relay messages and files across devices in real time';

  @override
  String settingsVersionWithBuild(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get settingsVersionLoading => 'Version …';

  @override
  String get settingsVersionUnknown => 'Version —';

  @override
  String get settingsNavVersionHistory => 'Version history';

  @override
  String get settingsNavVersionHistorySubtitle => 'View enabled releases';

  @override
  String get settingsNavAppLog => 'App logs';

  @override
  String get settingsNavAppLogSubtitleDesktop =>
      'Manage log files or open the log folder';

  @override
  String get settingsNavAppLogSubtitleMobile => 'Manage log files and share';

  @override
  String get settingsNavSourceCode => 'Source code';

  @override
  String get settingsNavSourceCodeSubtitle => 'View the app source on GitHub';

  @override
  String get settingsS3StatusConfigured => 'Configured';

  @override
  String get settingsS3StatusNotConfigured => 'Not configured';

  @override
  String get settingsS3StatusHosted => 'Built-in';

  @override
  String get settingsS3StatusCustom => 'Custom';

  @override
  String get settingsCheckUpdate => 'Check for updates';

  @override
  String get desktopUpdateTapCheck => 'Tap to check for updates';

  @override
  String get desktopUpdateChecking => 'Checking…';

  @override
  String get desktopUpdateAvailableUseBanner =>
      'Update available — use the banner at the top';

  @override
  String desktopUpdateDownloadingPercent(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String get desktopUpdateReadyRestart => 'Update ready — restart the app';

  @override
  String get desktopUpdateRestarting => 'Restarting…';

  @override
  String get desktopUpdateCheckFailed => 'Check failed';

  @override
  String get desktopUpdateNotConfiguredHint =>
      'Desktop updates not configured (missing UpdateConfig)';

  @override
  String get desktopToastUpdateNotConfigured =>
      'Desktop updates not configured';

  @override
  String get desktopToastCheckFailed => 'Update check failed';

  @override
  String get desktopToastNewVersionUseBanner =>
      'New version available — use the top banner to download';

  @override
  String get desktopToastAlreadyLatest => 'You\'re on the latest version';

  @override
  String mobileUpdateDownloadingPercent(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String get mobileUpdateDownloadedInstall =>
      'New version downloaded — tap Install';

  @override
  String get appUpdateDownloadProgressTitle => 'Downloading update';

  @override
  String get appUpdateDownloadProgressBackground => 'Background download';

  @override
  String get appUpdateDownloadProgressBackgroundToast =>
      'Download continues in the background. Open Settings — Check for updates to view progress.';

  @override
  String get appUpdateDownloadCompleteTitle => 'Download complete';

  @override
  String appUpdateDownloadedVersionLabel(String version, String build) {
    return 'Target version: $version (build $build)';
  }

  @override
  String appUpdateDownloadedFileLabel(String fileName) {
    return 'Package file: $fileName';
  }

  @override
  String get appUpdateDownloadRetry => 'Retry';

  @override
  String get mobileUpdateInstall => 'Install';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get updateStatusAlreadyLatest => 'Up to date';

  @override
  String get updateStatusChecking => 'Checking…';

  @override
  String updateStatusNewVersion(String version) {
    return 'New version $version';
  }

  @override
  String get updateStatusCheckAction => 'Check for updates';

  @override
  String updateStatusDownloadingPercent(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String get updateStatusDownloadedReady => 'Downloaded — ready to install';

  @override
  String get updateStatusCheckFailed => 'Check failed';

  @override
  String get updateStatusPlayManaged => 'Managed by Google Play Store';

  @override
  String settingsInstallFailed(String message) {
    return 'Install failed: $message';
  }

  @override
  String get settingsStoragePermissionToast =>
      'Storage permission is required to choose a save location';

  @override
  String get settingsSavePathNotExistToast =>
      'The selected path does not exist';

  @override
  String get settingsSavePathUpdatedToast => 'Save location updated';

  @override
  String get settingsSavePathFailedToast => 'Couldn\'t set save location';

  @override
  String get settingsSavePathRestoredToast => 'Save location reset to default';

  @override
  String get settingsSavePathRestoreFailedToast =>
      'Couldn\'t reset save location';

  @override
  String get settingsSavePathSafSyncHint =>
      'Files are saved here automatically after each transfer';

  @override
  String get settingsSavePathSafMirrorLabel => 'Save folder';

  @override
  String get settingsSavePathCacheHint =>
      'App cache (temporary copies; safe to clear)';

  @override
  String get settingsSavePathAppReceiveLabel => 'In-app receive folder';

  @override
  String get themeModeFollowSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String chatSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get chatSelectAll => 'Select all';

  @override
  String get chatDeselectAll => 'Deselect all';

  @override
  String get chatTooltipDelete => 'Delete';

  @override
  String get chatS3RelayTitle => 'S3 cloud relay';

  @override
  String get chatS3StatusChecking => 'Checking…';

  @override
  String get chatS3StatusNotConfigured => 'Not configured';

  @override
  String get chatS3StatusOnlineSendAll => 'Online · send to all devices';

  @override
  String get chatS3StatusUnavailableCheck => 'Unavailable · check S3 settings';

  @override
  String get chatDeviceOnline => 'Online';

  @override
  String get chatDevicePullOnline => 'Pull available';

  @override
  String get chatDeviceChecking => 'Checking…';

  @override
  String get chatDeviceOffline => 'Offline';

  @override
  String chatHeaderDeviceNumberTooltip(String code) {
    return 'Device no.: $code';
  }

  @override
  String get chatPickDeviceToStart => 'Choose a device to start chatting';

  @override
  String get chatTooltipBackDeviceList => 'Back to device list';

  @override
  String get chatTooltipS3Settings => 'S3 settings';

  @override
  String get chatTooltipFileManager => 'File manager';

  @override
  String get chatTooltipSessionSettings => 'Session settings';

  @override
  String get chatDropReleaseToAdd => 'Release to add files';

  @override
  String get chatMenuMultiSelect => 'Multi-select';

  @override
  String get chatMenuLocalFileUnavailable => 'Local file unavailable';

  @override
  String get chatMenuLocalFileUnavailableSubtitle =>
      'The file may have been deleted';

  @override
  String get chatMenuOpen => 'Open';

  @override
  String get chatMenuAddToPending => 'Add to outbox';

  @override
  String get chatMenuShare => 'Share';

  @override
  String get chatMenuSaveToGallery => 'Save to gallery';

  @override
  String get chatMenuDownloadFromCloud => 'Download from cloud';

  @override
  String get fileExportSaveToDownloads => 'Save to Downloads';

  @override
  String get fileExportSaveToFiles => 'Save to Files';

  @override
  String get fileExportSaveAs => 'Save As…';

  @override
  String fileExportSavedAs(String name) {
    return 'Saved as $name';
  }

  @override
  String get fileExportSaveAsDialogTitle => 'Choose where to save';

  @override
  String fileExportSavedToDownloads(String name) {
    return 'Saved to Downloads: $name';
  }

  @override
  String get fileExportOpenedShareSheet => 'Choose where to save the file';

  @override
  String get fileExportFailed => 'Couldn\'t save the file';

  @override
  String get chatMenuCopyText => 'Copy text';

  @override
  String get chatMenuSelectText => 'Select text';

  @override
  String get chatMenuDeleteMessage => 'Delete';

  @override
  String get chatGallerySaved => 'Saved to gallery';

  @override
  String get chatGallerySaveFailed => 'Save failed';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatSelectTextTitle => 'Select text';

  @override
  String get chatDeleteMessageTitle => 'Delete message';

  @override
  String get chatDeleteMessageBody =>
      'Delete this message? Local and cloud copies will be removed.';

  @override
  String get chatDeleteMessageConfirm => 'Delete';

  @override
  String get chatFileMissingDeleted => 'File missing; it may have been deleted';

  @override
  String get chatFileNoLocalOpenPath => 'No local file available to open';

  @override
  String get devicesRemoveTitle => 'Remove device';

  @override
  String get devicesRemoveBody =>
      'The account on this device will be signed out. Active sessions end immediately; offline devices will require sign-in next launch.';

  @override
  String get devicesRemoveConfirm => 'Remove';

  @override
  String get devicesRemovedToast => 'Device removed';

  @override
  String devicesRemoveFailed(String error) {
    return 'Couldn\'t remove device: $error';
  }

  @override
  String get devicesRenameTitle => 'Rename device';

  @override
  String get devicesNameHint => 'Device name';

  @override
  String get devicesRenameMenu => 'Rename';

  @override
  String get devicesRemoveMenu => 'Remove';

  @override
  String get devicesSavedToast => 'Saved';

  @override
  String devicesSaveFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get devicesTitle => 'My devices';

  @override
  String get devicesOfflinePrompt => 'Sign in to view and manage bound devices';

  @override
  String devicesBoundCount(int count) {
    return '$count bound';
  }

  @override
  String get devicesSyncing => 'Syncing…';

  @override
  String get devicesSubtitleLoadFailed => 'Couldn\'t load';

  @override
  String get devicesTooltipRefresh => 'Refresh';

  @override
  String devicesLoadFailedDetail(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get devicesEmptyList => 'No registered devices yet';

  @override
  String get devicesCurrentDeviceBadge => 'This device';

  @override
  String get fmRefreshFailed => 'Refresh failed';

  @override
  String get fmListLoadFailed => 'Couldn\'t load files';

  @override
  String get fmLoadMoreFailed => 'Couldn\'t load more';

  @override
  String get fmSearchFailed => 'Search failed';

  @override
  String get fmDeleteTitle => 'Delete file';

  @override
  String fmDeleteConfirmOne(String name) {
    return 'Delete $name?';
  }

  @override
  String fmDeleteConfirmMany(int count) {
    return 'Delete $count files?';
  }

  @override
  String get fmDeleteConfirm => 'Delete';

  @override
  String get fmAndroidApkOnly => 'APK install is only supported on Android';

  @override
  String get fmPreviewUnavailableTitle => 'Can\'t preview';

  @override
  String get fmPreviewUnavailableBody =>
      'No preview is available for this file. Open as plain text?';

  @override
  String get fmPreviewOpenAsText => 'Open as text';

  @override
  String fmPendingAddedOne(String name) {
    return 'Added \"$name\" to outbox';
  }

  @override
  String fmPendingAddedMany(int count) {
    return 'Added $count files to outbox';
  }

  @override
  String get fmMultiSelectMode => 'Multi-select mode';

  @override
  String get fmToolbarTitle => 'File Manager';

  @override
  String get fmHintTitle => 'About file manager';

  @override
  String get fmHintTooltip => 'Help';

  @override
  String get fmTabCache => 'Cache';

  @override
  String get fmTabSaveFolder => 'Save folder';

  @override
  String get fmSaveFolderEmpty => 'Save folder is empty';

  @override
  String get fmSaveFolderNotAccessible => 'Cannot read save folder';

  @override
  String get fmSaveFolderPermissionDenied =>
      'Access denied — re-select save location in Settings';

  @override
  String get fmSaveFolderNotConfigured => 'Save location not configured';

  @override
  String get fmSaveFolderPathLabel => 'Current save location';

  @override
  String get fmSaveFolderGoSettings => 'Go to Settings';

  @override
  String get fmSaveFolderHintTitle => 'About save folder';

  @override
  String get fmSaveFolderHintBody =>
      'Shows files received through this app in your selected save folder. Files not received through this app are not listed.';

  @override
  String get fmSaveFolderHintBodyDesktop =>
      'Shows all files in your selected save folder.';

  @override
  String get fmSaveFolderHintOk => 'Got it';

  @override
  String fmSaveFolderErrorDetail(String reason) {
    return '$reason';
  }

  @override
  String get fmCacheHintTitle => 'About cache';

  @override
  String get fmCacheHintOk => 'Got it';

  @override
  String get fmCachePathLabel => 'Cache folder';

  @override
  String get fmCacheSubtitle =>
      'When receiving files, content is saved to the app cache first, then exported to your save folder. The cache is only a local copy — clearing it manually will not affect files already saved.\n\nIf \"Delete cache after saving\" is enabled in Settings, each cache copy is removed immediately after a successful export.';

  @override
  String get fmExportStatusPending => 'Pending';

  @override
  String get fmExportStatusExporting => 'Saving';

  @override
  String get fmExportStatusDone => 'Saved';

  @override
  String get fmExportStatusFailed => 'Save failed';

  @override
  String get fmExportRetry => 'Retry save';

  @override
  String get fmClearCache => 'Clear';

  @override
  String get fmClearCacheTitle => 'Clear cache';

  @override
  String get fmClearCacheConfirm =>
      'All files in the app cache will be deleted. Files already saved to your save folder are not affected.';

  @override
  String get fmClearCacheDone => 'Cache cleared';

  @override
  String get fmClearCacheFailed => 'Could not clear cache';

  @override
  String get fmSearchCloseTooltip => 'Close search';

  @override
  String get fmSearchTooltip => 'Search';

  @override
  String get fmSortCategoryTooltip => 'Category view';

  @override
  String get fmSortTimeTooltip => 'Sort by time';

  @override
  String get fmSortMenuTooltip => 'Sort';

  @override
  String get fmSortByCreated => 'By date created';

  @override
  String get fmSortByModified => 'By date modified';

  @override
  String get fmSearchHint => 'Search file name…';

  @override
  String get fmEmptyNoMatch => 'No matching files';

  @override
  String get fmEmptyNoReceived => 'No received files yet';

  @override
  String fmSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get fmTooltipShareSelection => 'Share';

  @override
  String get fmTooltipAddPending => 'Add to outbox';

  @override
  String get fmRevealInFolder => 'Show in folder';

  @override
  String get fmFileInfoAction => 'Info';

  @override
  String get fmFileInfoTitle => 'File info';

  @override
  String get fmFileInfoName => 'Name';

  @override
  String get fmFileInfoPath => 'Path';

  @override
  String get fmFileInfoSize => 'Size';

  @override
  String get fmFileInfoMd5 => 'MD5';

  @override
  String get fmFileInfoReceivedAt => 'Received';

  @override
  String get fmFileInfoModifiedAt => 'Modified';

  @override
  String get fmFileInfoCategory => 'Type';

  @override
  String get fmFileInfoProtocol => 'Protocol';

  @override
  String get fmFileInfoMessageId => 'Message ID';

  @override
  String get fmFileInfoS3Key => 'S3 key';

  @override
  String get fmFileInfoFromDevice => 'From device';

  @override
  String get fmFileInfoMd5Computing => 'Computing…';

  @override
  String get fmFileInfoMd5Failed => 'Could not compute';

  @override
  String get fmFileInfoFileMissing => 'File not found on disk';

  @override
  String get fmCategoryImage => 'Images';

  @override
  String get fmCategoryVideo => 'Videos';

  @override
  String get fmCategoryAudio => 'Audio';

  @override
  String get fmCategoryPdf => 'PDF';

  @override
  String get fmCategoryArchive => 'Archives';

  @override
  String get fmCategoryDocument => 'Documents';

  @override
  String get fmCategoryCode => 'Code';

  @override
  String get fmCategoryOther => 'Other';

  @override
  String get fmTimeJustNow => 'Just now';

  @override
  String fmTimeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String fmTimeHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String fmTimeDaysAgo(int count) {
    return '$count d ago';
  }

  @override
  String fmTimeMonthDayClock(int month, int day, String hour, String minute) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get accountScreenTitle => 'Account';

  @override
  String get accountLogoutDialogTitle => 'Sign out';

  @override
  String get accountLogoutDialogBody =>
      'You\'ll need to sign in again to use the app. Sign out?';

  @override
  String get accountLogoutConfirm => 'Sign out';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountDeleteAccount => 'Delete account';

  @override
  String get accountLogout => 'Sign out';

  @override
  String get accountPasswordChangedToast => 'Password updated';

  @override
  String get accountChangePasswordTitle => 'Change password';

  @override
  String get accountChangePasswordWarning =>
      'A verification code will be sent to:';

  @override
  String get accountLabelNewPassword => 'New password';

  @override
  String get accountValidationEnterNewPassword => 'Enter a new password';

  @override
  String get accountValidationNewPasswordMinLength =>
      'Password must be at least 6 characters';

  @override
  String get accountLabelConfirmNewPassword => 'Confirm new password';

  @override
  String get accountValidationPasswordMismatch => 'Passwords don\'t match';

  @override
  String get accountDeleteTitle => 'Delete account';

  @override
  String get accountDeleteWarning =>
      'This permanently deletes all data and cannot be undone. A verification code will be sent to:';

  @override
  String get accountLabelVerificationCode => 'Verification code';

  @override
  String get accountHintSixDigitCode => '6-digit code';

  @override
  String get accountSendingCode => 'Sending…';

  @override
  String get accountSendVerificationCode => 'Send code';

  @override
  String get accountDeleteForever => 'Delete permanently';

  @override
  String get accountValidationEnterVerificationCode =>
      'Enter the verification code';

  @override
  String get versionHistoryTitle => 'Version history';

  @override
  String get versionHistoryEmpty => 'No releases yet';

  @override
  String get appLogTitle => 'App logs';

  @override
  String get appLogTooltipOpenFolder => 'Open log folder';

  @override
  String get appLogTooltipRefresh => 'Refresh';

  @override
  String get appLogErrorDirUnavailable => 'Log folder unavailable';

  @override
  String get appLogEmptyHint =>
      'No log output yet — use the app and logs will appear here.';

  @override
  String appLogReadFailed(String error) {
    return 'Couldn\'t read logs: $error';
  }

  @override
  String get appLogToastDirUnavailable => 'Log folder unavailable';

  @override
  String get appLogToastOpenFolderFailed => 'Couldn\'t open folder';

  @override
  String appLogFileMeta(String size, String modified) {
    return '$size · $modified';
  }

  @override
  String appLogTailHintKb(int kb) {
    return 'Large log file — showing only the last ~$kb KB';
  }

  @override
  String msgSearchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get msgSearchFileFallback => 'File';

  @override
  String get msgSearchUnknownMessage => '[ Unknown message ]';

  @override
  String msgSearchYesterdayTime(String time) {
    return 'Yesterday $time';
  }

  @override
  String get msgSearchDeviceSystem => 'System';

  @override
  String get msgSearchCopied => 'Copied';

  @override
  String get msgSearchDeleteTitle => 'Delete message';

  @override
  String get msgSearchDeleteBody =>
      'Delete this message? Cloud copies will be removed too.';

  @override
  String get msgSearchSelectTextTitle => 'Select text';

  @override
  String get msgSearchHint => 'Search messages…';

  @override
  String get msgSearchEmptyHint => 'Enter keywords to search messages';

  @override
  String get msgSearchNoResults => 'No matching messages';

  @override
  String get apkPickerTitle => 'Choose APK';

  @override
  String get apkPickerTooltipBrowseFiles => 'Browse files';

  @override
  String apkPickerConfirmCount(int count) {
    return 'Confirm ($count)';
  }

  @override
  String get apkPickerLoadingInstalled => 'Loading installed apps…';

  @override
  String get apkPickerEmptyOrError =>
      'Couldn\'t load installed apps.\nYou may need to reinstall the app to grant permission.';

  @override
  String get apkPickerSearchHint => 'Search apps…';

  @override
  String apkPickerAppCount(int count) {
    return '$count apps';
  }

  @override
  String get apkPickerSystemApp => 'System app';

  @override
  String get apkPickerClearSelection => 'Clear selection';

  @override
  String apkPickerConfirmSendMany(int count) {
    return 'Send $count APK files?';
  }

  @override
  String get apkPickerFromFiles => 'Pick APK from files';

  @override
  String get apkPickerReloadApps => 'Reload app list';

  @override
  String apkPickerLoadFailed(String error) {
    return 'Couldn\'t load apps: $error';
  }

  @override
  String get s3SettingsSaved => 'Saved';

  @override
  String get s3SettingsTestOk => 'Connection OK';

  @override
  String get s3SettingsClearTitle => 'Clear configuration';

  @override
  String get s3SettingsClearBody =>
      'Clear all fields? This removes S3 settings from the server and local cache.';

  @override
  String get s3SettingsClearConfirm => 'Clear';

  @override
  String get s3SettingsCleared => 'Configuration cleared';

  @override
  String get s3SettingsLoginExpired => 'Session expired — please sign in again';

  @override
  String get s3SettingsClearing => 'Clearing…';

  @override
  String get s3SettingsIntro =>
      'Configure S3-compatible object storage for wide-area file transfer (AWS S3, MinIO, Alibaba OSS, etc.).';

  @override
  String get s3SettingsConfiguredHint =>
      'Configured. Submit again to overwrite.';

  @override
  String get s3SettingsSectionStorage => 'Storage settings';

  @override
  String get s3SettingsRequired => 'Required';

  @override
  String get s3SettingsSecretHintIfConfigured =>
      'Leave blank to keep unchanged';

  @override
  String get s3SettingsSaving => 'Saving…';

  @override
  String get s3SettingsSave => 'Save';

  @override
  String get s3SettingsTesting => 'Testing…';

  @override
  String get s3SettingsTestConnection => 'Test connection';

  @override
  String get s3SettingsPageTitle => 'S3 settings';

  @override
  String get s3SettingsSectionConnection => 'Connection & storage';

  @override
  String get s3SettingsSectionCredentials => 'Credentials';

  @override
  String get s3SettingsFieldEndpoint => 'Endpoint';

  @override
  String get s3SettingsFieldRegion => 'Region';

  @override
  String get s3SettingsFieldBucket => 'Bucket';

  @override
  String get s3SettingsFieldPathStyle => 'Path-style access';

  @override
  String get s3SettingsPathStyleHint =>
      'Usually required for MinIO and self-hosted gateways. Turn off for AWS regional endpoints to use virtual-hosted URLs.';

  @override
  String get s3SettingsFieldAccessKeyId => 'Access Key ID';

  @override
  String get s3SettingsFieldSecretAccessKey => 'Secret Access Key';

  @override
  String get s3SettingsPlaceholderEndpoint => 'https://s3.amazonaws.com';

  @override
  String get s3SettingsPlaceholderRegion => 'cn-east-1';

  @override
  String get s3SettingsPlaceholderBucket => 'my-bucket';

  @override
  String get s3SettingsPlaceholderAccessKeyId => 'AKIAIOSFODNN7EXAMPLE';

  @override
  String s3SettingsConfiguredSummary(String endpoint, String bucket) {
    return '$endpoint · $bucket';
  }

  @override
  String get s3SettingsHostedTitle => 'Using built-in S3';

  @override
  String get s3SettingsHostedBody =>
      'Platform-managed object storage. No configuration required — wide-area transfers are ready out of the box.';

  @override
  String get s3SettingsHostedUsageLabel => 'Used this month';

  @override
  String s3SettingsHostedUsageMonthly(String used, String quota) {
    return '$used / $quota';
  }

  @override
  String s3SettingsHostedUsageMonthlyUnlimited(String used) {
    return '$used (unlimited)';
  }

  @override
  String get s3SettingsHostedUsageHint =>
      'Counted in UTC calendar months and reset on the 1st. Upgrade your membership for a larger quota.';

  @override
  String get s3SettingsCustomConfiguredHint =>
      'Switched to custom S3. All uploads/downloads will go through your own bucket.';

  @override
  String get s3SettingsDisabledHint =>
      'S3 is not enabled yet. Fill in your S3 configuration to enable wide-area transfers.';

  @override
  String get s3SettingsSwitchToCustom => 'Switch to custom S3';

  @override
  String get s3SettingsCollapseCustomForm => 'Cancel and keep built-in S3';

  @override
  String get s3SettingsSwitchBackToHosted => 'Switch back to built-in S3';

  @override
  String get s3SettingsSwitchBackTitle => 'Switch back to built-in S3?';

  @override
  String get s3SettingsSwitchBackBody =>
      'After switching back, all uploads/downloads will use the built-in S3. Your saved custom S3 configuration will be kept on file so you can switch back to it any time.';

  @override
  String get s3SettingsUseSavedCustom => 'Use saved custom S3';

  @override
  String get s3SettingsSwitchedToCustomOk => 'Switched to custom S3';

  @override
  String get s3SettingsSwitchBackConfirm => 'Switch back';

  @override
  String get s3SettingsSwitchedBackOk => 'Switched back to built-in S3';

  @override
  String get s3SettingsSwitching => 'Switching…';

  @override
  String get s3SettingsDocsTooltip => 'Setup guide (incl. CORS)';

  @override
  String get s3SettingsDocsUnavailable => 'No documentation link available';

  @override
  String get sendModeNearby => 'Nearby';

  @override
  String get linkRoutesTitleRetest => 'Retest connection';

  @override
  String get linkRoutesTitleSwitch => 'Switch route';

  @override
  String linkRoutesPeerSession(String label) {
    return 'Session device: $label';
  }

  @override
  String get linkRoutesBodyRetest =>
      'We\'ll retest the current route. Available routes and estimated speeds are shown below.';

  @override
  String linkRoutesBodySwitch(String mode) {
    return 'Switching to $mode and starting detection. Available routes and estimated speeds are shown below.';
  }

  @override
  String get linkRoutesTagAvailable => 'Available';

  @override
  String get linkRoutesTagUnavailable => 'Unavailable';

  @override
  String get linkRoutesTagCurrent => 'Current';

  @override
  String get linkRoutesTagTarget => 'Target';

  @override
  String linkRoutesSpeedLine(String tier, String desc) {
    return 'Estimated speed: $tier · $desc';
  }

  @override
  String get linkRoutesWaitingResult => 'Waiting for detection…';

  @override
  String get linkRoutesRetest => 'Retest';

  @override
  String get linkRoutesSwitchAndDetect => 'Switch & detect';

  @override
  String get linkRoutesPickerTitle => 'Choose route';

  @override
  String get linkRoutesPickerHint =>
      'Selecting a route switches immediately and starts detection.';

  @override
  String get linkSpeedNearbyTier => 'Medium–high';

  @override
  String get linkSpeedNearbyDesc =>
      'Same-subnet direct link; speed depends on LAN quality.';

  @override
  String get linkSpeedLanTier => 'High';

  @override
  String get linkSpeedLanDesc =>
      'HTTP direct — usually the fastest path on LAN.';

  @override
  String get linkSpeedWebrtcTier => 'Medium';

  @override
  String get linkSpeedWebrtcDesc =>
      'Good NAT traversal; speed varies with NAT and network conditions.';

  @override
  String get linkSpeedS3Tier => 'Medium–low';

  @override
  String get linkSpeedS3Desc =>
      'Relayed via cloud; throughput depends on public network and nodes.';

  @override
  String get membershipCenterTitle => 'Membership';

  @override
  String membershipLoadFailed(String error) {
    return 'Couldn\'t load membership: $error';
  }

  @override
  String get membershipBuyMiniOrProFirst => 'Subscribe to Pro first';

  @override
  String get membershipPurchaseSuccessSync =>
      'Purchase successful — benefits will sync shortly';

  @override
  String membershipPurchaseFailed(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get membershipPaymentCancelled => 'Payment cancelled';

  @override
  String get membershipPaymentPending => 'Confirming payment…';

  @override
  String get membershipNetworkError => 'Network error — try again';

  @override
  String get membershipOrderPayFailed => 'Payment failed — try again';

  @override
  String get membershipCompletePaymentInApp =>
      'Complete payment and return here — status updates automatically.';

  @override
  String get membershipAlipayAppNotConfigured =>
      'In-app Alipay isn\'t configured. Pay on desktop or contact an admin to enable the Alipay app.';

  @override
  String get membershipOrderCreatedAlipay =>
      'Order created — complete payment in Alipay';

  @override
  String get membershipPurchaseSuccessActive =>
      'Payment successful — membership is active';

  @override
  String get membershipCurrentTier => 'Current plan';

  @override
  String membershipTierSummary(String tier, int limit) {
    return '$tier · up to $limit devices';
  }

  @override
  String membershipBoundDevices(int count) {
    return '$count devices bound';
  }

  @override
  String membershipAddonLine(int packs, int devices) {
    return '$packs add-on pack(s) (+$devices devices)';
  }

  @override
  String membershipSubscriptionRenewsAt(String date) {
    return 'Next billing: $date';
  }

  @override
  String membershipSubscriptionEndsAfterCancel(String date) {
    return 'Auto-renew is off. Access remains until $date.';
  }

  @override
  String membershipSubscriptionValidUntil(String date) {
    return 'Current period ends $date';
  }

  @override
  String get membershipMigrationCardTitle => 'Lightning Vine migration';

  @override
  String get membershipMigrationCardSubtitle =>
      'Lightning Vine members can migrate to ShrimpSend';

  @override
  String membershipDeviceBadgeDevices(int count) {
    return '$count devices';
  }

  @override
  String membershipDeviceBadgeAddon(int count) {
    return '+$count devices';
  }

  @override
  String get membershipTierSubtitleAddon =>
      '+5 devices per pack — buy multiple';

  @override
  String get membershipTierSubtitleBuyout => 'Lifetime membership';

  @override
  String get membershipCannotBuyLowerTier =>
      'Can\'t purchase this tier or lower';

  @override
  String membershipUpgradeDue(String amount) {
    return 'Amount due: ¥$amount';
  }

  @override
  String get membershipNeedMiniProFirst => 'Pro membership required first';

  @override
  String get membershipPurchasing => 'Purchasing…';

  @override
  String get membershipWaitingPayment => 'Waiting for payment…';

  @override
  String get membershipPleaseSubscribeFirst => 'Subscribe to Pro first';

  @override
  String get membershipBuyApple => 'Buy with Apple';

  @override
  String get membershipBuyAlipay => 'Pay with Alipay';

  @override
  String get membershipBillingMonthly => 'Monthly';

  @override
  String get membershipBillingYearly => 'Yearly';

  @override
  String membershipPlanYearlySave(int pct) {
    return '~$pct% off vs monthly';
  }

  @override
  String membershipSavingsVsMonthlyYear(int pct) {
    return 'Save up to $pct% vs paying monthly for a year';
  }

  @override
  String membershipPricePerMonthEquiv(String price) {
    return '~$price/mo billed yearly';
  }

  @override
  String membershipPricePerYear(String price) {
    return '$price/yr';
  }

  @override
  String membershipPricePerMonth(String price) {
    return '$price/mo';
  }

  @override
  String membershipFeatureDevices(int count) {
    return 'Up to $count linked devices';
  }

  @override
  String membershipFeatureUploadHosted(int gib) {
    return '$gib GiB / month hosted upload quota';
  }

  @override
  String get membershipPlanPopular => 'Popular';

  @override
  String get membershipOverseasNoAlipay =>
      'Overseas builds don’t support Alipay — subscribe in the app.';

  @override
  String get membershipSubscribeInApp => 'Subscribe in app';

  @override
  String get membershipRcUnavailable =>
      'In-app purchase isn’t available. Check your connection and try again.';

  @override
  String get membershipTierSubtitleSubscription =>
      'Renews automatically — cancel anytime in the store.';

  @override
  String get membershipOverseasSubscribeHint =>
      'Subscribe via the App Store or Google Play. Secure checkout.';

  @override
  String get membershipOverseasSubscribeHintIos =>
      'Subscribe via the App Store. Secure checkout.';

  @override
  String get membershipChannelLockedOtherPlatform =>
      'Your subscription was purchased on another platform. Manage it on the device where you subscribed.';

  @override
  String get membershipChannelLockedStripe =>
      'Your membership is billed via Stripe on the web. Please upgrade or manage it from the web to avoid duplicate charges.';

  @override
  String get membershipChannelLockedAppStore =>
      'Your membership is billed via the App Store. Manage or upgrade it on your iPhone/iPad in Settings → Apple ID → Subscriptions.';

  @override
  String get membershipChannelLockedPlayStore =>
      'Your membership is billed via Google Play. Manage or upgrade it in the Play Store under Account → Subscriptions.';

  @override
  String get membershipChannelLifetime =>
      'You already have a lifetime membership — no further subscription upgrade is needed.';

  @override
  String get membershipManageStripe => 'Manage subscription (web)';

  @override
  String get membershipManageStripeFailed =>
      'Failed to open subscription management. Please try again.';

  @override
  String get membershipRestorePurchases => 'Restore purchases';

  @override
  String get membershipRestoreSuccess =>
      'Purchases restored — benefits will sync shortly';

  @override
  String membershipRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get membershipOpenAppStoreSubs => 'Open App Store subscriptions';

  @override
  String get membershipOpenPlayStoreSubs => 'Open Play Store subscriptions';

  @override
  String get membershipStripePriceMissing =>
      'Stripe Price not configured. Please contact admin or subscribe on another platform.';

  @override
  String get membershipStripeCheckoutFailed =>
      'Failed to create Stripe checkout session. Please try again.';

  @override
  String get membershipOpenBrowserToPay =>
      'Opening your browser to complete payment. Return to the app once you\'re done.';

  @override
  String get membershipUpgradeStripeSuccess =>
      'Upgrade successful. Your membership has been updated.';

  @override
  String get membershipSubscribeStripe => 'Subscribe with Stripe';

  @override
  String get membershipUpgradeStripe => 'Upgrade with Stripe';

  @override
  String get membershipOpeningStripe => 'Opening Stripe…';

  @override
  String get membershipMigrationTitle => 'Lightning Vine migration';

  @override
  String get membershipMigrationConfirmTitle => 'Confirm migration';

  @override
  String membershipMigrationConfirmBody(String tier, int limit) {
    return 'Verification succeeded.\n\nYou\'ll receive $tier membership with up to $limit devices.\n\nConfirm migration?';
  }

  @override
  String get membershipMigrationConfirmAction => 'Confirm migration';

  @override
  String get membershipMigrationEnterPhone => 'Enter your phone number first';

  @override
  String get membershipMigrationInvalidPhone => 'Invalid phone number';

  @override
  String get membershipMigrationCodeSent => 'Verification code sent';

  @override
  String get membershipMigrationEnterCode => 'Enter the 6-digit code';

  @override
  String get membershipMigrationSuccess => 'Migration successful!';

  @override
  String get membershipMigrationIntroTitle => 'Migration guide';

  @override
  String get membershipMigrationIntroBody =>
      'If you\'re a Lightning Vine member, verify your phone to migrate membership to ShrimpSend.\n\nAfter migration you\'ll get ShrimpSend Pro (12 devices).';

  @override
  String get membershipMigrationPhoneLabel => 'Phone number';

  @override
  String get membershipMigrationPhoneHint => 'Enter phone number';

  @override
  String get membershipMigrationCodeLabel => 'Verification code';

  @override
  String get membershipMigrationVerifyAndMigrate => 'Verify & migrate';

  @override
  String get membershipMigrationSending => 'Sending…';

  @override
  String get membershipMigrationSendCode => 'Send code';

  @override
  String get connectionBarGoToS3Setup => 'Configure S3';

  @override
  String get connectionBarManualPrefix => 'Manual · ';

  @override
  String chatProbeDetecting(String mode) {
    return '$mode · detecting…';
  }

  @override
  String chatProbeAvailable(String mode) {
    return '$mode · available';
  }

  @override
  String chatProbeUnavailable(String mode) {
    return '$mode · unavailable';
  }

  @override
  String chatProbeTriggered(String mode) {
    return '$mode · probe requested';
  }

  @override
  String chatProbeUnverifiedAttemptable(String mode) {
    return '$mode unverified — you can still try';
  }

  @override
  String get connectionOrchestratorHttpUnverifiedSubtitle =>
      'Link unverified — will try direct or reverse pull';

  @override
  String connectionOrchestratorManualOk(String mode) {
    return 'Manual · $mode';
  }

  @override
  String connectionOrchestratorManualUnavailable(String mode) {
    return 'Manual · $mode unavailable';
  }

  @override
  String get connectionOrchestratorLinkUnavailable =>
      'Current route unavailable';

  @override
  String get connectionOrchestratorAutoS3 => 'Auto · S3';

  @override
  String get connectionOrchestratorS3FallbackSubtitle =>
      'Direct connection failed — using cloud relay';

  @override
  String connectionOrchestratorAutoMode(String mode) {
    return 'Auto · $mode';
  }

  @override
  String get connectionOrchestratorNoDirect => 'No direct connection';

  @override
  String get connectionOrchestratorLoginPromptSubtitle =>
      'Sign in to use HTTP, WebRTC, or S3';

  @override
  String get connectionOrchestratorNoDirectS3Fallback =>
      'No direct connection — fallback active';

  @override
  String get connectionOrchestratorS3Unavailable => 'S3 unavailable';

  @override
  String get connectionOrchestratorS3NotConfigured => 'S3 not configured';

  @override
  String membershipMigrationCooldownSeconds(int seconds) {
    return 'Retry in ${seconds}s';
  }

  @override
  String get mobileHomeTabConnect => 'Connect';

  @override
  String get mobileHomeTabFiles => 'Files';

  @override
  String chatReceivedExportingToast(String name) {
    return 'Received $name — saving to folder…';
  }

  @override
  String get mobileHomeTabSettings => 'Settings';

  @override
  String get mobileHomePendingOutbox => 'Outbox';

  @override
  String get pendingFilesSend => 'Send';

  @override
  String get pendingFilesManage => 'Manage';

  @override
  String pendingFilesManageWithCount(int count) {
    return 'Manage ($count)';
  }

  @override
  String pendingFilesSelectedCount(int count) {
    return '$count files selected';
  }

  @override
  String get pendingFilesClearAll => 'Clear all';

  @override
  String fileSendTitleSingle(String name) {
    return 'Send: $name';
  }

  @override
  String fileSendTitleMany(String firstName, int count) {
    return 'Send: $firstName ($count files)';
  }

  @override
  String get fileSendS3Intro =>
      'Send via S3 cloud relay to all signed-in devices. Works across networks.';

  @override
  String get fileSendS3ConfigurePrompt =>
      'Configure S3 first to use cloud send.';

  @override
  String get fileSendResumeSupported => 'Resume supported';

  @override
  String get fileSendResumeNotSupported => 'Resume not supported';

  @override
  String get fileSendStatusChecking => 'Checking…';

  @override
  String get fileSendLanStatusOnlineDirect => 'Online · direct';

  @override
  String get fileSendLanStatusPullAvailable => 'Reverse pull available';

  @override
  String get fileSendLanStatusUnreachable => 'Unreachable';

  @override
  String get fileSendLanStatusOfflineDirect => 'Offline';

  @override
  String get fileSendWebRtcStatusOnline => 'Online';

  @override
  String get fileSendWebRtcStatusConnectable => 'Can connect';

  @override
  String get fileSendWebRtcStatusOffline => 'Offline';

  @override
  String get fileSendWebRtcIntro =>
      'WebRTC sends peer-to-peer without routing through servers. Falls back to S3 if the connection fails.';

  @override
  String get fileSendWebRtcEmptyNoDevices => 'No other devices found.';

  @override
  String get fileSendEmptyNearbyOffline =>
      'No other devices found. Make sure devices are on the same LAN.';

  @override
  String get fileSendEmptyMyDevicesOnLan => 'No \"My devices\" on the LAN.';

  @override
  String get fileSendSendToSelected => 'Send to selected devices';

  @override
  String get fileSendViaWebRtc => 'Send via WebRTC';

  @override
  String get fileSendConfigureS3First => 'Configure S3 first';

  @override
  String get fileSendToAllDevices => 'Send to all devices';

  @override
  String get fileSendTabMyDevices => 'My devices';

  @override
  String get fileSendTabWebRtc => 'WebRTC';

  @override
  String get devicePanelStatusServerUnreachable => 'Server unreachable';

  @override
  String get devicePanelStatusValidating => 'Verifying sign-in…';

  @override
  String get devicePanelStatusSessionExpired => 'Session expired';

  @override
  String get devicePanelStatusConnected => 'Connected';

  @override
  String get devicePanelStatusConnecting => 'Connecting…';

  @override
  String get devicePanelEmptyNoOtherDevices => 'No other devices yet';

  @override
  String get devicePanelEmptyHintOfflineLan =>
      'Make sure other devices are on the same LAN to transfer.';

  @override
  String get devicePanelEmptyHintOnlineAccount =>
      'Sign in on your other devices with the same account to start transferring.';

  @override
  String devicePanelDevicesOnlineCount(int count) {
    return '$count online';
  }

  @override
  String get connectionBarDefaultTitle => 'Connection status';

  @override
  String get connectionBarManualShort => 'Manual';

  @override
  String get connectionBarAutoShort => 'Auto';

  @override
  String get connectionBarResumeAuto => 'Resume auto';

  @override
  String get connectionBarSwitchMode => 'Switch';

  @override
  String get connectionBarRefreshOnlineStatus => 'Refresh online status';

  @override
  String get transportModeLabel => 'Transport';

  @override
  String get transportModeHttpLan => 'HTTP LAN direct';

  @override
  String get transportModeWebrtcLan => 'WebRTC LAN direct';

  @override
  String get connectionDiagTitle => 'Connection diagnostic';

  @override
  String connectionDiagSubtitleRunning(String peer) {
    return 'Testing connection to $peer…';
  }

  @override
  String connectionDiagSubtitleDone(String peer) {
    return 'Connection test to $peer complete';
  }

  @override
  String get connectionDiagContinueInBackground => 'Continue in background';

  @override
  String get connectionDiagDone => 'Done';

  @override
  String get connectionDiagStepS3 => 'S3 cloud';

  @override
  String get connectionDiagStepHttpDirect => 'HTTP LAN direct';

  @override
  String get connectionDiagStepHttpSignaling => 'HTTP signaling';

  @override
  String get connectionDiagStepHttpPull => 'HTTP reverse pull';

  @override
  String get connectionDiagStepWebrtc => 'WebRTC connectivity';

  @override
  String get connectionDiagStatusPending => 'Waiting';

  @override
  String get connectionDiagStatusRunning => 'Testing';

  @override
  String get connectionDiagStatusSuccess => 'Available';

  @override
  String get connectionDiagStatusFailure => 'Unavailable';

  @override
  String get connectionDiagStatusSkipped => 'Skipped';

  @override
  String get connectionDiagReasonS3Online =>
      'S3 configured and cloud reachable';

  @override
  String get connectionDiagReasonS3NotConfigured => 'S3 not configured';

  @override
  String get connectionDiagReasonS3Unavailable =>
      'S3 configured but cloud unreachable';

  @override
  String get connectionDiagReasonHttpDirectOk =>
      'LAN HTTP direct connection succeeded';

  @override
  String get connectionDiagReasonHttpDirectFail =>
      'Cannot reach peer HTTP service (timeout or no response)';

  @override
  String get connectionDiagReasonHttpSignalingOk =>
      'Peer HTTP self-check passed';

  @override
  String get connectionDiagReasonHttpSignalingFail =>
      'Signaling probe failed; peer HTTP did not respond';

  @override
  String get connectionDiagReasonHttpPullOk =>
      'Peer can reverse-pull from this device';

  @override
  String get connectionDiagReasonHttpPullFail =>
      'Reverse pull failed; peer cannot reach local HTTP';

  @override
  String get connectionDiagReasonWebrtcOnline =>
      'Same network — WebRTC can connect directly';

  @override
  String get connectionDiagReasonWebrtcConnectable =>
      'Cross-network — WebRTC may connect via relay';

  @override
  String get connectionDiagReasonWebrtcFail =>
      'WebRTC signaling or ICE unreachable';

  @override
  String get connectionDiagReasonWebrtcSkippedLanOk =>
      'LAN HTTP already works — WebRTC skipped';

  @override
  String get connectionDiagReasonSkippedLanDirectOk =>
      'HTTP direct succeeded — skipped';

  @override
  String get connectionDiagReasonSkippedOffline =>
      'Offline — cloud signaling probes unavailable';

  @override
  String get connectionDiagReasonSkippedPeerOffline =>
      'Peer offline with no LAN address — skipped';

  @override
  String get connectionDiagReasonHttpDirectNoUrl =>
      'No LAN address found — cannot test HTTP direct';

  @override
  String get connectionDiagReasonOfflineCloud =>
      'Offline — cloud signaling probes unavailable';

  @override
  String get connectionDiagReasonS3LoginRequired =>
      'Sign in required to test S3';

  @override
  String connectionDiagSummaryRecommend(String mode, String reason) {
    return 'Recommended: $mode ($reason)';
  }

  @override
  String get connectionDiagSummaryNoRoute =>
      'No available transport route found';

  @override
  String connectionDiagElapsed(String elapsed) {
    return '$elapsed elapsed';
  }

  @override
  String get connectionDiagHelpHttpDirectTitle => 'HTTP LAN direct';

  @override
  String get connectionDiagHelpHttpDirectBody =>
      'Your device sends an HTTP GET to the peer\'s LAN address (/probe) without going through the cloud.\n\nThis checks whether a direct HTTP file transfer is possible when the peer\'s LAN URL is known (e.g. via mDNS) and reachable on the local network.';

  @override
  String get connectionDiagHelpHttpSignalingTitle => 'HTTP signaling';

  @override
  String get connectionDiagHelpHttpSignalingBody =>
      'A cloud message (Centrifugo) asks the peer to self-check its HTTP service and report back.\n\nThis checks whether the peer\'s HTTP service is healthy when you don\'t yet know its LAN address, as long as both sides are online. The result may also include or update the peer\'s LAN URL.';

  @override
  String get connectionDiagHelpHttpPullTitle => 'HTTP reverse pull';

  @override
  String get connectionDiagHelpHttpPullBody =>
      'A cloud message asks the peer to try reaching your device\'s HTTP service.\n\nThis checks reverse-pull connectivity when the network is asymmetric (e.g. NAT) and the peer can pull from you even if you cannot push to them directly.';

  @override
  String get connectionDiagHelpWebrtcTitle => 'WebRTC connectivity';

  @override
  String get connectionDiagHelpWebrtcBody =>
      'ICE network candidates are exchanged via the cloud to analyze whether both sides are on the same network, can connect P2P, or need a relay.\n\nThis checks whether WebRTC file transfer is viable (often slower than HTTP direct, but can work across networks).';

  @override
  String get connectionDiagHelpS3Title => 'S3 cloud';

  @override
  String get connectionDiagHelpS3Body =>
      'Verifies that S3 storage is configured for your account and tests cloud reachability.\n\nThis checks whether files can fall back to S3 cloud relay when all LAN/direct paths are unavailable.';

  @override
  String get connectionDiagHelpTooltip => 'How this check works';

  @override
  String get composerPickAttachmentTitle => 'Choose attachment';

  @override
  String get composerAttachImageVideo => 'Photos & videos';

  @override
  String get composerAttachImageVideoDesc =>
      'Pick photos or videos from your gallery';

  @override
  String get chatGalleryReadPermissionTitle => 'Access Photo Library';

  @override
  String get chatGalleryReadPermissionBody =>
      'To pick images or videos, the app needs access to your photo library. We recommend allowing access to all photos and videos.';

  @override
  String get chatGalleryReadPermissionConfirm => 'Continue';

  @override
  String get chatGalleryReadPermissionDenied =>
      'Photo library access was not granted. Cannot pick images or videos.';

  @override
  String get chatGalleryReadPermissionLimited =>
      'Only partial photo access is granted. Open Settings to allow access to all photos.';

  @override
  String get chatGalleryReadPermissionContinuePartial =>
      'Continue with limited access';

  @override
  String get composerAttachFile => 'Files';

  @override
  String get composerAttachFileDesc => 'Choose with the system file picker';

  @override
  String get composerAttachFolder => 'Folder';

  @override
  String get composerAttachFolderDesc => 'All files in the selected folder';

  @override
  String get composerAttachApk => 'APK';

  @override
  String get composerAttachApkDesc => 'Pick an APK package from this device';

  @override
  String get composerMessageHint => 'Type a message…';

  @override
  String get composerClearInputTooltip => 'Clear';

  @override
  String get shortcutsSendTitle => 'Send message';

  @override
  String get shortcutsSendDescription =>
      'Choose which key sends a message from the input field';

  @override
  String get shortcutsSendEnter => 'Press Enter to send';

  @override
  String get shortcutsSendModifier => 'Press Ctrl+Enter to send';

  @override
  String get shortcutsSendModifierMac => 'Press ⌘+Enter to send';

  @override
  String get shortcutsSendButtonHint =>
      'The send button always works regardless of this setting.';

  @override
  String get composerSendTooltipEnter => 'Send (Enter)';

  @override
  String get composerSendTooltipModifier => 'Send (Ctrl+Enter)';

  @override
  String get composerSendTooltipModifierMac => 'Send (⌘+Enter)';

  @override
  String chatTransferSendingPct(String fileName, int pct) {
    return '$fileName Sending $pct%';
  }

  @override
  String chatTransferReceivingPct(String fileName, int pct) {
    return '$fileName Receiving $pct%';
  }

  @override
  String chatTransferWaitingPeerLine(String fileName) {
    return '$fileName Waiting for peer…';
  }

  @override
  String get chatTransferWaitingPeerShort => 'Waiting for peer…';

  @override
  String get chatTransferCancelledBare => 'Cancelled';

  @override
  String chatTransferCancelledNamed(String fileName) {
    return '$fileName cancelled';
  }

  @override
  String chatTransferSendFailedNamed(String fileName) {
    return '$fileName send failed';
  }

  @override
  String chatTransferReceiveFailedNamed(String fileName) {
    return '$fileName receive failed';
  }

  @override
  String get chatTransferProgressSending => 'Sending';

  @override
  String get chatTransferProgressReceiving => 'Receiving';

  @override
  String chatTransferEtaSecondsRemaining(int seconds) {
    return '${seconds}s left';
  }

  @override
  String chatTransferEtaMinutesSecondsRemaining(int minutes, int seconds) {
    return '${minutes}m ${seconds}s left';
  }

  @override
  String chatWebRtcSentParen(String fileName) {
    return '$fileName (sent via WebRTC)';
  }

  @override
  String get chatScreenGenericFile => 'File';

  @override
  String get chatScreenDeleteThisDeviceTitle => 'Remove this device';

  @override
  String get chatScreenDeleteThisDeviceBody =>
      'This removes this device from your account and signs you out. Sign in again to use cloud features.';

  @override
  String get chatScreenRemovePeerTitle => 'Remove device';

  @override
  String get chatScreenRemovePeerBody =>
      'The account on that device will be signed out. If it is in use, access ends immediately; otherwise the next launch will require signing in again.';

  @override
  String get chatScreenConfirmRemoveLabel => 'Remove';

  @override
  String get chatScreenConfirmDeleteLabel => 'Delete';

  @override
  String get chatScreenToastDeletedThisDevice => 'This device was removed';

  @override
  String chatScreenToastDeleteDeviceFailed(String error) {
    return 'Could not remove this device: $error';
  }

  @override
  String get chatScreenToastRemovedPeer => 'Device removed';

  @override
  String chatScreenToastRemovePeerFailed(String error) {
    return 'Could not remove device: $error';
  }

  @override
  String get chatScreenSessionSettingsTitle => 'Conversation settings';

  @override
  String get chatScreenTileRenameDevice => 'Rename device';

  @override
  String get chatScreenTileClearMessages => 'Clear messages';

  @override
  String get chatScreenSubtitleClearMessages =>
      'Delete all chat history in this conversation';

  @override
  String get chatScreenClearMessagesTitle => 'Clear messages';

  @override
  String get chatScreenClearMessagesConfirm =>
      'This will delete all chat history in this conversation. Files saved to your save folder will not be removed.';

  @override
  String get chatScreenClearMessagesDeleteCache => 'Also delete cached files';

  @override
  String get chatScreenClearMessagesDone => 'Messages cleared';

  @override
  String get chatScreenClearMessagesFailed => 'Failed to clear messages';

  @override
  String get chatScreenTileRemoveThisDevice => 'Remove this device';

  @override
  String get chatScreenTileRemovePeer => 'Remove device';

  @override
  String get chatScreenSubtitleRemoveThisDevice =>
      'Remove this device from your account and sign out';

  @override
  String get chatScreenSubtitleRemovePeer =>
      'Remove the device in this conversation from your account';

  @override
  String get chatScreenPendingFilesMissing =>
      'Some queued files were missing and were removed';

  @override
  String get chatScreenConnNotLoggedInHttp =>
      'Not signed in — HTTP transfer only';

  @override
  String get chatScreenConnOffline => 'Cannot reach server — offline mode';

  @override
  String get chatScreenConnServerOk => 'Connected to server';

  @override
  String get chatScreenSelectTargetFirst => 'Choose a destination device first';

  @override
  String get chatScreenFolderNeedsPermission =>
      'Storage permission is required to open folders';

  @override
  String get chatScreenFolderEmpty => 'This folder is empty or cannot be read';

  @override
  String get chatScreenFolderSafTryFiles =>
      'Couldn\'t read the selected folder. Try choosing files instead.';

  @override
  String get chatScreenRetryCloudOffline =>
      'Cannot retry cloud transfer in offline mode';

  @override
  String get chatScreenNoDeviceFound =>
      'Target device not found — check that it is online';

  @override
  String get chatScreenOfflineNoS3 =>
      'S3 transfer is unavailable in offline mode';

  @override
  String get chatScreenS3NotConfiguredTitle => 'S3 not configured';

  @override
  String get chatScreenS3NotConfiguredBody =>
      'S3 is not set up yet. Open settings to configure it?';

  @override
  String get chatScreenS3GoConfigure => 'Configure';

  @override
  String get chatScreenS3UnavailableTitle => 'S3 unavailable';

  @override
  String get chatScreenS3UnavailableBody =>
      'The S3 connection test failed. Check settings or your network. Open S3 settings?';

  @override
  String get chatScreenS3GoSettings => 'Open settings';

  @override
  String get chatScreenNoNearbyDevice =>
      'No nearby device available — choose again';

  @override
  String get chatScreenDeviceUnavailable =>
      'Selected device is unavailable — choose again';

  @override
  String get chatScreenWebRtcUnsupportedSource =>
      'This file cannot be sent via WebRTC — use HTTP';

  @override
  String get chatScreenWebRtcFailedTryHttp =>
      'WebRTC send failed — try HTTP mode';

  @override
  String get chatScreenConfigureS3FirstToast =>
      'Configure S3 in settings first';

  @override
  String get chatScreenS3UnavailableToast =>
      'S3 is unavailable — check settings or run the connection test';

  @override
  String chatScreenSendFailedWithError(String error) {
    return 'Send failed: $error';
  }

  @override
  String get chatScreenFileMissing =>
      'File no longer exists — it may have been deleted';

  @override
  String get chatScreenCannotOpenFile => 'Cannot open this file';

  @override
  String get chatScreenSavedToGallery => 'Saved to Photos';

  @override
  String chatScreenReceivedAtPath(String path) {
    return 'Received: $path';
  }

  @override
  String chatScreenReceiveFailedWithError(String error) {
    return 'Receive failed: $error';
  }

  @override
  String get chatScreenCopied => 'Copied';

  @override
  String get chatScreenDeleteMessagesTitle => 'Delete messages';

  @override
  String chatScreenDeleteMessagesBody(int count) {
    return 'Delete $count messages? This removes them locally and from the cloud.';
  }

  @override
  String get chatHttpReceivedSavedGallery =>
      'Received via HTTP and saved to Photos';

  @override
  String chatHttpReceivedWithName(String fileName) {
    return 'Received via HTTP: $fileName';
  }

  @override
  String get chatHttpPullReceivedSavedGallery =>
      'Received via reverse pull and saved to Photos';

  @override
  String chatHttpPullReceivedWithName(String fileName) {
    return 'Received via reverse pull: $fileName';
  }

  @override
  String chatHttpReceivedBracket(String fileName) {
    return '$fileName (received via HTTP)';
  }

  @override
  String get appGallerySubfolder => 'ShrimpSend';

  @override
  String get appUpdateTitleNewVersion => 'Update available';

  @override
  String appUpdateCurrentVersion(String version, String build) {
    return 'Current: $version ($build)';
  }

  @override
  String appUpdateNewVersion(String version, String build) {
    return 'New: $version ($build)';
  }

  @override
  String get appUpdateLater => 'Later';

  @override
  String get appUpdateDontShowAgainVersion =>
      'Don\'t show again for this version';

  @override
  String get appUpdateDownload => 'Download';

  @override
  String get appUpdateOpenDownloadPage => 'Open in browser';

  @override
  String get appUpdateGoAppStore => 'Go to App Store';

  @override
  String get appUpdateInstallTitle => 'Install update';

  @override
  String appUpdateInstallBody(String version, String build, String pending) {
    return 'Current: $version ($build)\nPending package: $pending\n\nThe update is downloaded. Install now?';
  }

  @override
  String get appUpdateUnknownVersion => 'Unknown';

  @override
  String get appUpdateDontShowAgain => 'Don\'t show again';

  @override
  String get appUpdateInstall => 'Install';

  @override
  String get desktopUpdateSizeUnknown => 'Size unknown';

  @override
  String desktopUpdateSizeMb(String mb) {
    return '~$mb MB';
  }

  @override
  String desktopUpdateSizeKb(String kb) {
    return '~$kb KB';
  }

  @override
  String get desktopUpdateBannerTitle => 'Update available';

  @override
  String desktopUpdateBannerSubtitle(String version, String sizeLine) {
    return 'Version $version · $sizeLine';
  }

  @override
  String get desktopUpdateLater => 'Later';

  @override
  String get desktopUpdateNow => 'Update now';

  @override
  String get desktopUpdateDownloading => 'Downloading update…';

  @override
  String get desktopUpdateApplying =>
      'Closing and applying update, please wait…';

  @override
  String get desktopUpdateReadyTitle => 'Update ready';

  @override
  String get desktopUpdateReadyBody =>
      'The app will restart automatically; installation takes a few seconds.';

  @override
  String get desktopUpdateQuitRestart => 'Quit and restart';

  @override
  String get desktopUpdateErrorUnknown => 'Unknown error';

  @override
  String get desktopUpdateCheckFailedTitle => 'Update check failed';

  @override
  String get desktopUpdateClose => 'Close';

  @override
  String get desktopUpdateRetry => 'Retry';

  @override
  String get desktopUpdateReleaseNotesAction => 'Release notes';

  @override
  String desktopUpdateReleaseNotesTitle(String version) {
    return 'What’s new in $version';
  }

  @override
  String get desktopUpdateReleaseNotesEmpty =>
      'No release notes provided for this version.';

  @override
  String get qrGenerating => 'Generating QR code…';

  @override
  String get qrHintScanWithPhone => 'Scan with your signed-in phone';

  @override
  String get qrHintConfirmOnPhone => 'Scanned — confirm on your phone';

  @override
  String get qrHintLoginSuccess => 'Signed in, redirecting…';

  @override
  String get qrHintExpired => 'QR code expired — refresh and try again';

  @override
  String get qrHintGenericError => 'Something went wrong';

  @override
  String get qrLoginTitle => 'Scan to sign in';

  @override
  String get qrLoginTagline => 'Messages & files in sync across devices';

  @override
  String get qrLoginSteps =>
      'Open the mobile app → Scan → Confirm on your phone';

  @override
  String get qrStatusScanned => 'Scanned';

  @override
  String get qrStatusConfirmPhone => 'Confirm sign-in on your phone';

  @override
  String get qrRefreshButton => 'Refresh QR code';

  @override
  String get qrUsePasswordLogin => 'Sign in with email & password';

  @override
  String qrScannerFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get qrConfirmLoginTitle => 'Confirm sign-in';

  @override
  String get qrConfirmLoginBody => 'Allow sign-in on the other device?';

  @override
  String get qrConfirmLoginConfirm => 'Confirm sign-in';

  @override
  String get qrConfirmLoginSuccess => 'Sign-in confirmed';

  @override
  String qrConfirmLoginFailed(String error) {
    return 'Confirmation failed: $error';
  }

  @override
  String get qrScannerNeedCamera =>
      'Camera permission is required to scan QR codes';

  @override
  String get qrScannerOpenSettings => 'Open Settings';

  @override
  String get qrScannerPermissionAgain => 'Request permission again';

  @override
  String get qrScannerProcessing => 'Processing…';

  @override
  String get qrScannerAlignQr => 'Align the QR code inside the frame';

  @override
  String get qrScannerUnrecognized => 'Scan a ShrimpSend login QR code';

  @override
  String get qrScannerTorchOn => 'Turn on flashlight';

  @override
  String get qrScannerTorchOff => 'Turn off flashlight';

  @override
  String get filePreviewTooltipShare => 'Share';

  @override
  String get filePreviewTooltipOpenWith => 'Open with…';

  @override
  String get filePreviewImageLoadError => 'Could not load image';

  @override
  String get filePreviewVideoError => 'Could not play this video';

  @override
  String filePreviewTextTruncated(String text) {
    return '$text\n\n… File too large — showing first 2 MB only';
  }

  @override
  String get filePreviewReadError => 'Could not read file contents';

  @override
  String get filePreviewCopyAll => 'Copy all';

  @override
  String get filePreviewCopied => 'Copied to clipboard';

  @override
  String get fileClipboardCopy => 'Copy';

  @override
  String fileClipboardCopied(int count) {
    return 'Copied $count file(s) — paste in Finder or Explorer';
  }

  @override
  String get fileClipboardCopyFailed => 'Copy failed';

  @override
  String get fileClipboardPasteAdded => 'Added to outbox — open chat to send';

  @override
  String get fileClipboardNothingToCopy => 'Select files to copy first';

  @override
  String get chatMenuCopyFile => 'Copy file';
}
