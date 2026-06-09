// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get brandNameMainlandChina => '虾传';

  @override
  String get brandNameInternational => 'ShrimpSend';

  @override
  String get localeRegionGateTitle => '语言';

  @override
  String get localeRegionGateSubtitle => '请选择界面显示语言。本安装包所连接的服务区域已固定。';

  @override
  String get localeRegionGateCountryHint =>
      '点按选择；中国大陆对应虾传服务集群，其余对应 ShrimpSend。';

  @override
  String get fieldLanguage => '语言';

  @override
  String get sectionLanguage => '语言';

  @override
  String get fieldCountryRegion => '国家或地区';

  @override
  String get regionMainlandChina => '中国大陆';

  @override
  String get regionInternational => '中国大陆以外';

  @override
  String get continueAction => '继续';

  @override
  String get loginSessionExpired => '登录已失效，请重新登录';

  @override
  String get settingsTitle => '设置';

  @override
  String get sectionLanguageRegion => '语言与地区';

  @override
  String get serverClusterSwitchTitle => '即将退出登录';

  @override
  String get serverClusterSwitchMessage =>
      '所选国家/地区对应的服务域名将与当前不同，访问集群将切换。继续后将立刻退出登录；你需要在新的服务域名下重新登录后才能继续使用。当前选择的国家/地区会先恢复为修改前的记录，可在重新登录后再选择目标区域。';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get signOutRequired => '需要退出登录';

  @override
  String get loginTitleSubtitleLogin => '登录后继续你的跨端传输';

  @override
  String get loginTitleSubtitleRegister => '创建账号后即可开始同步消息和文件';

  @override
  String get enterOfflineMode => '以离线模式进入';

  @override
  String get legalPrivacyPolicy => '隐私政策';

  @override
  String get legalTermsOfService => '用户服务协议';

  @override
  String get legalCouldNotOpenLink => '无法打开链接';

  @override
  String get envLabelDev => '测试';

  @override
  String get envLabelProd => '线上';

  @override
  String get applyingUpdate => '正在应用更新，完成后将自动启动（约数秒）';

  @override
  String get localeNameZhHans => '简体中文';

  @override
  String get localeNameEnglish => 'English';

  @override
  String get loginTabLogin => '登录';

  @override
  String get loginTabRegister => '注册';

  @override
  String get loginMethodPassword => '密码';

  @override
  String get loginMethodCode => '验证码';

  @override
  String get fieldEmail => '邮箱';

  @override
  String get hintEmail => 'you@example.com';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldVerificationCode => '验证码';

  @override
  String get hintVerificationCode6 => '6位验证码';

  @override
  String get fieldNicknameOptional => '昵称（可选）';

  @override
  String get hintDisplayName => '显示名称';

  @override
  String get loginGetVerificationCode => '获取验证码';

  @override
  String get loginSendVerificationCode => '发送验证码';

  @override
  String codeCooldownSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get loginSubmitRegister => '注册';

  @override
  String get loginSubmitWithCode => '验证码登录';

  @override
  String get loginSubmitPassword => '登录';

  @override
  String get loginQrLogin => '扫码登录';

  @override
  String get loginPromptNoAccount => '没有账号？';

  @override
  String get loginPromptHasAccount => '已有账号？';

  @override
  String get loginLinkToRegister => '注册';

  @override
  String get loginLinkToLogin => '登录';

  @override
  String get loginErrorEmailRequired => '请先输入邮箱';

  @override
  String get loginErrorCodeSixDigits => '请输入6位验证码';

  @override
  String get snackbarAllowInstallUnknownApps => '请在设置中允许安装未知应用，返回后将自动继续安装';

  @override
  String get settingsSectionFeatures => '功能';

  @override
  String get settingsSectionPreferences => '偏好设置';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsNavLogin => '登录账号';

  @override
  String get settingsNavLoginSubtitle => '登录后可使用云端同步和更多功能';

  @override
  String get settingsBadgeNotSignedIn => '未登录';

  @override
  String get settingsNavPersonalAccount => '个人账号';

  @override
  String get settingsNavAccountSubtitle => '查看和管理你的账号';

  @override
  String get settingsMembershipCenter => '会员中心';

  @override
  String get settingsMembershipSubtitleUpgrade => '买断会员，提升可绑定设备数';

  @override
  String settingsMembershipTierName(String tierName) {
    return '$tierName 会员';
  }

  @override
  String settingsMembershipDevices(int current, int limit) {
    return '$current/$limit 台设备';
  }

  @override
  String get settingsNavMyDevices => '我的设备';

  @override
  String get settingsNavMyDevicesSubtitleOffline => '登录后管理已绑定设备';

  @override
  String get settingsNavMyDevicesSubtitleOnline => '已绑定的设备';

  @override
  String get settingsNavS3 => 'S3';

  @override
  String get settingsNavS3Subtitle => '广域网文件传输';

  @override
  String get settingsNavShortcuts => '快捷键';

  @override
  String get settingsNavShortcutsSubtitle => '发送消息等键盘操作';

  @override
  String get settingsNavFonts => '字体';

  @override
  String get settingsNavFontsSubtitle => '调整字号与粗细';

  @override
  String get settingsFontsPageTitle => '字体';

  @override
  String get settingsShortcutsPageTitle => '快捷键';

  @override
  String get settingsThemeLabel => '主题';

  @override
  String get settingsColorThemeLabel => '颜色主题';

  @override
  String get settingsColorThemeEmerald => '翡翠绿';

  @override
  String get settingsColorThemeOcean => '海洋蓝';

  @override
  String get settingsColorThemeSunset => '暖阳橙';

  @override
  String get settingsColorThemeLavender => '薰衣草紫';

  @override
  String get settingsColorThemeRose => '玫瑰粉';

  @override
  String get settingsColorThemeGraphite => '石墨灰';

  @override
  String get settingsFontLabel => '字体';

  @override
  String get settingsFontLatinLabel => '英文字体';

  @override
  String get settingsFontCjkLabel => '中文字体';

  @override
  String get settingsFontMonoLabel => '等宽字体';

  @override
  String get settingsFontSystem => '系统默认';

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
  String get settingsFontLxgwWenkai => '霞鹜文楷';

  @override
  String get settingsFontSmileySans => '得意黑';

  @override
  String get settingsFontIbmPlexMono => 'IBM Plex Mono';

  @override
  String get settingsFontPreview => 'ShrimpSend · 你好世界 · 123';

  @override
  String get settingsFontSizeLabel => '字体大小';

  @override
  String get settingsFontSizeSmaller => '更小';

  @override
  String get settingsFontSizeSmall => '小';

  @override
  String get settingsFontSizeStandard => '标准';

  @override
  String get settingsFontSizeLarge => '大';

  @override
  String get settingsFontSizeLarger => '更大';

  @override
  String get settingsFontWeightLabel => '字体粗细';

  @override
  String get settingsFontWeightLighter => '更细';

  @override
  String get settingsFontWeightLight => '细';

  @override
  String get settingsFontWeightNormal => '正常';

  @override
  String get settingsFontWeightMedium => '中等';

  @override
  String get settingsFontWeightSemibold => '较粗';

  @override
  String get settingsFontLicenses =>
      'Windows 版内置文源黑体 WenYuan Sans SC（SIL Open Font License 1.1）；其他平台使用系统字体。来源：https://github.com/takushun-wu/WenYuanFonts';

  @override
  String get settingsFileSavePath => '文件保存路径';

  @override
  String get settingsFileSavePathNotSet => '未设置';

  @override
  String get settingsSavePathBadgeDefault => '默认';

  @override
  String get settingsSavePathBadgeCustom => '自定义';

  @override
  String get settingsSavePathKindExternal => '外部存储';

  @override
  String get settingsSavePathKindAppDocuments => '应用文档';

  @override
  String get settingsSavePathKindAppCache => '应用缓存';

  @override
  String get settingsSavePathKindAppExternal => '应用专属存储';

  @override
  String get settingsSavePathKindHintAppDocuments => '文件保存在应用文档目录，可在「文件」应用中查看';

  @override
  String get settingsSavePathKindHintAppExternal =>
      '文件保存在应用专属外部目录，清理应用数据后可能被系统删除';

  @override
  String get settingsSavePathFallbackDialogOk => '知道了';

  @override
  String get settingsSavePathFallbackDialogTitle => '无法使用外部保存路径';

  @override
  String settingsSavePathFallbackDialogBody(
    String intendedPath,
    String currentPath,
    String reason,
  ) {
    return '部分车机或定制系统不允许在外部存储创建文件夹，已改为应用缓存保存。\n\n预期路径：$intendedPath\n当前路径：$currentPath\n原因：$reason';
  }

  @override
  String get settingsChooseFolder => '选择文件夹';

  @override
  String get settingsRestoreDefaultPath => '恢复默认';

  @override
  String get settingsGalleryPermissionToast => '需要相册权限才能自动保存到相册，请在系统设置中允许';

  @override
  String get settingsSaveToGalleryTitle => '图片/视频保存到相册';

  @override
  String get settingsSaveToGallerySubtitle => '接收的图片、视频自动写入系统相册';

  @override
  String get settingsSaveToGalleryHintBody =>
      '开启后，图片和视频会写入系统相册，不会复制到你设置的「保存文件夹」。因此在文件管理中：「缓存」里能看到这些文件，「保存文件夹」里不会出现它们。';

  @override
  String get settingsWindowsLaunchAtStartupTitle => '开机自启动';

  @override
  String get settingsWindowsLaunchAtStartupSubtitle => '登录 Windows 后自动启动并隐藏到托盘';

  @override
  String get settingsWindowsLaunchAtStartupFailed => '更新开机自启动设置失败，请稍后重试';

  @override
  String get settingsDeleteCacheAfterSaveTitle => '保存后删除缓存';

  @override
  String get settingsDeleteCacheAfterSaveSubtitle => '导出到保存文件夹成功后，删除应用内缓存副本';

  @override
  String get settingsDeleteCacheAfterSaveHintBody => '接收的文件缓存会被删除，文件管理的缓存中不会出现';

  @override
  String get aboutTagline => '消息/文件中转，多端实时同步';

  @override
  String settingsVersionWithBuild(String version, String buildNumber) {
    return '版本 $version ($buildNumber)';
  }

  @override
  String get settingsVersionLoading => '版本 ...';

  @override
  String get settingsVersionUnknown => '版本 -';

  @override
  String get settingsNavVersionHistory => '版本历史';

  @override
  String get settingsNavVersionHistorySubtitle => '查看已启用的版本列表';

  @override
  String get settingsNavAppLog => '应用日志';

  @override
  String get settingsNavAppLogSubtitleDesktop => '管理日志文件，可在文件夹中打开';

  @override
  String get settingsNavAppLogSubtitleMobile => '管理日志文件，可分享';

  @override
  String get settingsNavSourceCode => '源代码';

  @override
  String get settingsNavSourceCodeSubtitle => '在 GitHub 查看应用源代码';

  @override
  String get settingsS3StatusConfigured => '已配置';

  @override
  String get settingsS3StatusNotConfigured => '未配置';

  @override
  String get settingsS3StatusHosted => '内置';

  @override
  String get settingsS3StatusCustom => '自建';

  @override
  String get settingsCheckUpdate => '检查更新';

  @override
  String get desktopUpdateTapCheck => '点击检查更新';

  @override
  String get desktopUpdateChecking => '正在检查…';

  @override
  String get desktopUpdateAvailableUseBanner => '新版本可用，请使用顶部横幅更新';

  @override
  String desktopUpdateDownloadingPercent(String percent) {
    return '下载中 $percent%';
  }

  @override
  String get desktopUpdateReadyRestart => '更新已就绪，请重启应用';

  @override
  String get desktopUpdateRestarting => '正在重启…';

  @override
  String get desktopUpdateCheckFailed => '检查失败';

  @override
  String get desktopUpdateNotConfiguredHint => '桌面更新未配置（缺少 UpdateConfig）';

  @override
  String get desktopToastUpdateNotConfigured => '桌面更新未配置';

  @override
  String get desktopToastCheckFailed => '检查更新失败';

  @override
  String get desktopToastNewVersionUseBanner => '已发现新版本，请使用顶部横幅下载更新';

  @override
  String get desktopToastAlreadyLatest => '已是最新版本';

  @override
  String mobileUpdateDownloadingPercent(String percent) {
    return '下载中 $percent%';
  }

  @override
  String get mobileUpdateDownloadedInstall => '新版本已下载，点击安装';

  @override
  String get appUpdateDownloadProgressTitle => '正在下载更新';

  @override
  String get appUpdateDownloadProgressBackground => '后台下载';

  @override
  String get appUpdateDownloadProgressBackgroundToast =>
      '下载将在后台继续，可在「设置 - 检查更新」中查看进度。';

  @override
  String get appUpdateDownloadCompleteTitle => '下载完成';

  @override
  String appUpdateDownloadedVersionLabel(String version, String build) {
    return '对应版本：$version（build $build）';
  }

  @override
  String appUpdateDownloadedFileLabel(String fileName) {
    return '安装包：$fileName';
  }

  @override
  String get appUpdateDownloadRetry => '重试';

  @override
  String get mobileUpdateInstall => '安装';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSave => '保存';

  @override
  String get updateStatusAlreadyLatest => '已是最新';

  @override
  String get updateStatusChecking => '正在检查…';

  @override
  String updateStatusNewVersion(String version) {
    return '发现新版本 $version';
  }

  @override
  String get updateStatusCheckAction => '检查更新';

  @override
  String updateStatusDownloadingPercent(String percent) {
    return '下载中 $percent%';
  }

  @override
  String get updateStatusDownloadedReady => '已下载，可安装';

  @override
  String get updateStatusCheckFailed => '检查失败';

  @override
  String get updateStatusPlayManaged => '由 Google Play 商店管理';

  @override
  String settingsInstallFailed(String message) {
    return '安装失败: $message';
  }

  @override
  String get settingsStoragePermissionToast => '需要存储权限才能选择保存路径';

  @override
  String get settingsSavePathNotExistToast => '选择的路径不存在';

  @override
  String get settingsSavePathUpdatedToast => '保存路径已更新';

  @override
  String get settingsSavePathFailedToast => '设置保存路径失败';

  @override
  String get settingsSavePathRestoredToast => '已恢复默认保存路径';

  @override
  String get settingsSavePathRestoreFailedToast => '恢复默认路径失败';

  @override
  String get settingsSavePathSafSyncHint => '接收完成后自动保存到此文件夹';

  @override
  String get settingsSavePathSafMirrorLabel => '保存文件夹';

  @override
  String get settingsSavePathCacheHint => '应用缓存目录（临时副本，可安全清理）';

  @override
  String get settingsSavePathAppReceiveLabel => '应用内接收目录';

  @override
  String get themeModeFollowSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String chatSelectedCount(int count) {
    return '已选 $count';
  }

  @override
  String get chatSelectAll => '全选';

  @override
  String get chatDeselectAll => '取消全选';

  @override
  String get chatTooltipDelete => '删除';

  @override
  String get chatS3RelayTitle => 'S3 云端中转';

  @override
  String get chatS3StatusChecking => '检测中…';

  @override
  String get chatS3StatusNotConfigured => '未配置';

  @override
  String get chatS3StatusOnlineSendAll => '在线 · 发送到所有设备';

  @override
  String get chatS3StatusUnavailableCheck => '不可用 · 请检查 S3 配置';

  @override
  String get chatDeviceOnline => '在线';

  @override
  String get chatDevicePullOnline => '可拉取';

  @override
  String get chatDeviceChecking => '检测中…';

  @override
  String get chatDeviceOffline => '离线';

  @override
  String chatHeaderDeviceNumberTooltip(String code) {
    return '设备号：$code';
  }

  @override
  String get chatPickDeviceToStart => '选择一个设备开始对话';

  @override
  String get chatTooltipBackDeviceList => '返回设备列表';

  @override
  String get chatTooltipS3Settings => 'S3 设置';

  @override
  String get chatTooltipFileManager => '文件管理';

  @override
  String get chatTooltipSessionSettings => '会话设置';

  @override
  String get chatDropReleaseToAdd => '松开以添加文件';

  @override
  String get chatMenuMultiSelect => '多选模式';

  @override
  String get chatMenuLocalFileUnavailable => '本地文件不可用';

  @override
  String get chatMenuLocalFileUnavailableSubtitle => '文件不存在，可能已被删除';

  @override
  String get chatMenuOpen => '打开';

  @override
  String get chatMenuAddToPending => '添加到待发';

  @override
  String get chatMenuShare => '分享';

  @override
  String get chatMenuSaveToGallery => '保存到相册';

  @override
  String get chatMenuDownloadFromCloud => '从云端下载';

  @override
  String get fileExportSaveToDownloads => '转存到下载目录';

  @override
  String get fileExportSaveToFiles => '保存到文件';

  @override
  String get fileExportSaveAs => '另存为';

  @override
  String fileExportSavedAs(String name) {
    return '已保存：$name';
  }

  @override
  String get fileExportSaveAsDialogTitle => '选择保存位置';

  @override
  String fileExportSavedToDownloads(String name) {
    return '已转存到下载目录：$name';
  }

  @override
  String get fileExportOpenedShareSheet => '请选择保存位置';

  @override
  String get fileExportFailed => '转存失败';

  @override
  String get chatMenuCopyText => '复制文本';

  @override
  String get chatMenuSelectText => '选择文本';

  @override
  String get chatMenuDeleteMessage => '删除';

  @override
  String get chatGallerySaved => '已保存到相册';

  @override
  String get chatGallerySaveFailed => '保存失败';

  @override
  String get chatCopied => '已复制';

  @override
  String get chatSelectTextTitle => '选择文本';

  @override
  String get chatDeleteMessageTitle => '删除消息';

  @override
  String get chatDeleteMessageBody => '确定删除这条消息？将同时删除本地和云端记录。';

  @override
  String get chatDeleteMessageConfirm => '删除';

  @override
  String get chatFileMissingDeleted => '文件不存在，可能已被删除';

  @override
  String get chatFileNoLocalOpenPath => '未找到可打开的本地文件';

  @override
  String get devicesRemoveTitle => '移除设备';

  @override
  String get devicesRemoveBody =>
      '移除后，该设备上的账号将退出登录；若正在使用会立即失效，若未启动则下次打开应用时需重新登录。';

  @override
  String get devicesRemoveConfirm => '移除';

  @override
  String get devicesRemovedToast => '已移除设备';

  @override
  String devicesRemoveFailed(String error) {
    return '移除失败: $error';
  }

  @override
  String get devicesRenameTitle => '修改设备名称';

  @override
  String get devicesNameHint => '设备名称';

  @override
  String get devicesRenameMenu => '改名';

  @override
  String get devicesRemoveMenu => '移除';

  @override
  String get devicesSavedToast => '已保存';

  @override
  String devicesSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get devicesTitle => '我的设备';

  @override
  String get devicesOfflinePrompt => '请登录后查看与管理已绑定设备';

  @override
  String devicesBoundCount(int count) {
    return '已绑定 $count 台';
  }

  @override
  String get devicesSyncing => '正在同步…';

  @override
  String get devicesSubtitleLoadFailed => '加载失败';

  @override
  String get devicesTooltipRefresh => '刷新';

  @override
  String devicesLoadFailedDetail(String error) {
    return '加载失败：$error';
  }

  @override
  String get devicesEmptyList => '暂无已注册设备';

  @override
  String get devicesCurrentDeviceBadge => '当前设备';

  @override
  String get fmRefreshFailed => '刷新失败';

  @override
  String get fmListLoadFailed => '加载文件列表失败';

  @override
  String get fmLoadMoreFailed => '加载更多失败';

  @override
  String get fmSearchFailed => '搜索失败';

  @override
  String get fmDeleteTitle => '删除文件';

  @override
  String fmDeleteConfirmOne(String name) {
    return '确定删除 $name？';
  }

  @override
  String fmDeleteConfirmMany(int count) {
    return '确定删除 $count 个文件？';
  }

  @override
  String get fmDeleteConfirm => '删除';

  @override
  String get fmAndroidApkOnly => '仅 Android 设备支持安装 APK';

  @override
  String get fmPreviewUnavailableTitle => '无法预览';

  @override
  String get fmPreviewUnavailableBody => '当前文件没有有效的预览方式，是否以文本的方式打开？';

  @override
  String get fmPreviewOpenAsText => '以文本打开';

  @override
  String fmPendingAddedOne(String name) {
    return '已添加「$name」到待发文件箱';
  }

  @override
  String fmPendingAddedMany(int count) {
    return '已添加 $count 个文件到待发文件箱';
  }

  @override
  String get fmMultiSelectMode => '多选模式';

  @override
  String get fmToolbarTitle => '文件管理';

  @override
  String get fmHintTitle => '关于文件管理';

  @override
  String get fmHintTooltip => '说明';

  @override
  String get fmTabCache => '缓存';

  @override
  String get fmTabSaveFolder => '保存文件夹';

  @override
  String get fmSaveFolderEmpty => '保存文件夹为空';

  @override
  String get fmSaveFolderNotAccessible => '无法读取保存文件夹';

  @override
  String get fmSaveFolderPermissionDenied => '没有访问权限，请在设置中重新选择保存位置';

  @override
  String get fmSaveFolderNotConfigured => '尚未配置保存位置';

  @override
  String get fmSaveFolderPathLabel => '当前保存位置';

  @override
  String get fmSaveFolderGoSettings => '前往设置';

  @override
  String get fmSaveFolderHintTitle => '关于保存文件夹';

  @override
  String get fmSaveFolderHintBody => '展示你在设置中所选文件夹内、通过本应用接收的文件；非本应用接收的文件不会显示。';

  @override
  String get fmSaveFolderHintBodyDesktop => '展示你在设置中所选的保存文件夹中的所有文件。';

  @override
  String get fmSaveFolderHintOk => '知道了';

  @override
  String fmSaveFolderErrorDetail(String reason) {
    return '$reason';
  }

  @override
  String get fmCacheHintTitle => '关于缓存';

  @override
  String get fmCacheHintOk => '知道了';

  @override
  String get fmCachePathLabel => '缓存目录';

  @override
  String get fmCacheSubtitle =>
      '接收文件时，会先将内容写入应用缓存，再转存到「保存文件夹」。缓存只是本地副本，手动清理不会影响已保存的文件。\n\n若在设置中开启「保存后删除缓存」，转存成功后会立即删除对应的缓存副本。';

  @override
  String get fmExportStatusPending => '待保存';

  @override
  String get fmExportStatusExporting => '保存中';

  @override
  String get fmExportStatusDone => '已保存';

  @override
  String get fmExportStatusFailed => '保存失败';

  @override
  String get fmExportRetry => '重试保存';

  @override
  String get fmClearCache => '清理';

  @override
  String get fmClearCacheTitle => '清理缓存';

  @override
  String get fmClearCacheConfirm => '将删除应用缓存目录下的所有文件。已保存到保存文件夹的文件不受影响。';

  @override
  String get fmClearCacheDone => '缓存已清理';

  @override
  String get fmClearCacheFailed => '清理缓存失败';

  @override
  String get fmSearchCloseTooltip => '关闭搜索';

  @override
  String get fmSearchTooltip => '搜索';

  @override
  String get fmSortCategoryTooltip => '分类查看';

  @override
  String get fmSortTimeTooltip => '时间排序';

  @override
  String get fmSortMenuTooltip => '排序';

  @override
  String get fmSortByCreated => '按创建时间';

  @override
  String get fmSortByModified => '按更新时间';

  @override
  String get fmSearchHint => '搜索文件名...';

  @override
  String get fmEmptyNoMatch => '未找到匹配文件';

  @override
  String get fmEmptyNoReceived => '暂无接收文件';

  @override
  String fmSelectedCount(int count) {
    return '已选 $count';
  }

  @override
  String get fmTooltipShareSelection => '分享';

  @override
  String get fmTooltipAddPending => '添加到待发';

  @override
  String get fmRevealInFolder => '在文件夹中显示';

  @override
  String get fmFileInfoAction => '信息';

  @override
  String get fmFileInfoTitle => '文件信息';

  @override
  String get fmFileInfoName => '名称';

  @override
  String get fmFileInfoPath => '路径';

  @override
  String get fmFileInfoSize => '大小';

  @override
  String get fmFileInfoMd5 => 'MD5';

  @override
  String get fmFileInfoReceivedAt => '接收时间';

  @override
  String get fmFileInfoModifiedAt => '修改时间';

  @override
  String get fmFileInfoCategory => '类型';

  @override
  String get fmFileInfoProtocol => '传输协议';

  @override
  String get fmFileInfoMessageId => '消息 ID';

  @override
  String get fmFileInfoS3Key => 'S3 Key';

  @override
  String get fmFileInfoFromDevice => '来源设备';

  @override
  String get fmFileInfoMd5Computing => '计算中…';

  @override
  String get fmFileInfoMd5Failed => '无法计算';

  @override
  String get fmFileInfoFileMissing => '本地文件不存在';

  @override
  String get fmCategoryImage => '图片';

  @override
  String get fmCategoryVideo => '视频';

  @override
  String get fmCategoryAudio => '音频';

  @override
  String get fmCategoryPdf => 'PDF';

  @override
  String get fmCategoryArchive => '压缩包';

  @override
  String get fmCategoryDocument => '文档';

  @override
  String get fmCategoryCode => '代码';

  @override
  String get fmCategoryOther => '其他';

  @override
  String get fmTimeJustNow => '刚刚';

  @override
  String fmTimeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String fmTimeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String fmTimeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String fmTimeMonthDayClock(int month, int day, String hour, String minute) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get accountScreenTitle => '个人账号';

  @override
  String get accountLogoutDialogTitle => '退出登录';

  @override
  String get accountLogoutDialogBody => '退出后需要重新登录才能使用，确定退出吗？';

  @override
  String get accountLogoutConfirm => '退出';

  @override
  String get accountChangePassword => '修改密码';

  @override
  String get accountDeleteAccount => '删除账户';

  @override
  String get accountLogout => '退出登录';

  @override
  String get accountPasswordChangedToast => '密码修改成功';

  @override
  String get accountChangePasswordTitle => '修改密码';

  @override
  String get accountChangePasswordWarning => '验证码将发送到：';

  @override
  String get accountLabelNewPassword => '新密码';

  @override
  String get accountValidationEnterNewPassword => '请输入新密码';

  @override
  String get accountValidationNewPasswordMinLength => '新密码至少需要6个字符';

  @override
  String get accountLabelConfirmNewPassword => '确认新密码';

  @override
  String get accountValidationPasswordMismatch => '两次输入的密码不一致';

  @override
  String get accountDeleteTitle => '删除账户';

  @override
  String get accountDeleteWarning => '删除后所有数据将被永久清除且无法恢复。验证码将发送到：';

  @override
  String get accountLabelVerificationCode => '验证码';

  @override
  String get accountHintSixDigitCode => '6位验证码';

  @override
  String get accountSendingCode => '发送中...';

  @override
  String get accountSendVerificationCode => '发送验证码';

  @override
  String get accountDeleteForever => '永久删除';

  @override
  String get accountValidationEnterVerificationCode => '请输入验证码';

  @override
  String get versionHistoryTitle => '版本历史';

  @override
  String get versionHistoryEmpty => '暂无版本记录';

  @override
  String get appLogTitle => '应用日志';

  @override
  String get appLogTooltipOpenFolder => '打开日志所在文件夹';

  @override
  String get appLogTooltipRefresh => '刷新';

  @override
  String get appLogErrorDirUnavailable => '日志目录不可用';

  @override
  String get appLogEmptyHint => '（尚无日志输出，使用应用后此处会显示记录）';

  @override
  String appLogReadFailed(String error) {
    return '读取失败: $error';
  }

  @override
  String get appLogToastDirUnavailable => '日志目录不可用';

  @override
  String get appLogToastOpenFolderFailed => '无法打开文件夹';

  @override
  String appLogFileMeta(String size, String modified) {
    return '$size · $modified';
  }

  @override
  String appLogTailHintKb(int kb) {
    return '日志文件较大，仅显示末尾约 $kb KB';
  }

  @override
  String msgSearchFailed(String error) {
    return '搜索失败: $error';
  }

  @override
  String get msgSearchFileFallback => '文件';

  @override
  String get msgSearchUnknownMessage => '[ 未知消息 ]';

  @override
  String msgSearchYesterdayTime(String time) {
    return '昨天 $time';
  }

  @override
  String get msgSearchDeviceSystem => '系统';

  @override
  String get msgSearchCopied => '已复制';

  @override
  String get msgSearchDeleteTitle => '删除消息';

  @override
  String get msgSearchDeleteBody => '确定删除这条消息？将同时删除云端记录。';

  @override
  String get msgSearchSelectTextTitle => '选择文本';

  @override
  String get msgSearchHint => '搜索消息…';

  @override
  String get msgSearchEmptyHint => '输入关键词搜索消息';

  @override
  String get msgSearchNoResults => '没有找到匹配的消息';

  @override
  String get apkPickerTitle => '选择 APK';

  @override
  String get apkPickerTooltipBrowseFiles => '从文件浏览';

  @override
  String apkPickerConfirmCount(int count) {
    return '确定 ($count)';
  }

  @override
  String get apkPickerLoadingInstalled => '正在加载已安装应用…';

  @override
  String get apkPickerEmptyOrError => '未获取到已安装应用列表\n可能需要完全卸载后重新安装应用以授予权限';

  @override
  String get apkPickerSearchHint => '搜索应用…';

  @override
  String apkPickerAppCount(int count) {
    return '共 $count 个应用';
  }

  @override
  String get apkPickerSystemApp => '系统应用';

  @override
  String get apkPickerClearSelection => '清除选择';

  @override
  String apkPickerConfirmSendMany(int count) {
    return '确定发送 $count 个 APK';
  }

  @override
  String get apkPickerFromFiles => '从文件中选择 APK';

  @override
  String get apkPickerReloadApps => '重新加载应用列表';

  @override
  String apkPickerLoadFailed(String error) {
    return '加载应用列表失败: $error';
  }

  @override
  String get s3SettingsSaved => '保存成功';

  @override
  String get s3SettingsTestOk => '连接成功';

  @override
  String get s3SettingsClearTitle => '清空配置';

  @override
  String get s3SettingsClearBody => '确定要清空所有配置项吗？将删除服务端与本地缓存中的 S3 配置。';

  @override
  String get s3SettingsClearConfirm => '清空';

  @override
  String get s3SettingsCleared => '已清空配置';

  @override
  String get s3SettingsLoginExpired => '登录已失效，请重新登录';

  @override
  String get s3SettingsClearing => '清空中…';

  @override
  String get s3SettingsIntro =>
      '配置 S3 兼容的对象存储服务，用于广域网文件传输。支持 AWS S3、MinIO、阿里云 OSS 等。';

  @override
  String get s3SettingsConfiguredHint => '已配置。重新填写并提交可覆盖现有配置。';

  @override
  String get s3SettingsSectionStorage => '存储配置';

  @override
  String get s3SettingsRequired => '必填';

  @override
  String get s3SettingsSecretHintIfConfigured => '留空则不修改';

  @override
  String get s3SettingsSaving => '保存中…';

  @override
  String get s3SettingsSave => '保存配置';

  @override
  String get s3SettingsTesting => '测试中…';

  @override
  String get s3SettingsTestConnection => '测试连接';

  @override
  String get s3SettingsPageTitle => 'S3 设置';

  @override
  String get s3SettingsSectionConnection => '连接与存储';

  @override
  String get s3SettingsSectionCredentials => '访问密钥';

  @override
  String get s3SettingsFieldEndpoint => 'Endpoint';

  @override
  String get s3SettingsFieldRegion => 'Region';

  @override
  String get s3SettingsFieldBucket => 'Bucket';

  @override
  String get s3SettingsFieldPathStyle => 'Path-style 访问';

  @override
  String get s3SettingsPathStyleHint =>
      'MinIO 及多数自建网关通常需开启；AWS S3 等区域 Endpoint 可关闭以使用虚拟托管。';

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
  String get s3SettingsHostedTitle => '正在使用内置 S3';

  @override
  String get s3SettingsHostedBody => '由平台托管的对象存储，无需任何配置即可使用，可直接进行广域网传输。';

  @override
  String get s3SettingsHostedUsageLabel => '本月已用';

  @override
  String s3SettingsHostedUsageMonthly(String used, String quota) {
    return '$used / $quota';
  }

  @override
  String s3SettingsHostedUsageMonthlyUnlimited(String used) {
    return '$used（不限）';
  }

  @override
  String get s3SettingsHostedUsageHint => '用量按 UTC 自然月统计，每月 1 日重置；升级会员可获得更高额度。';

  @override
  String get s3SettingsCustomConfiguredHint =>
      '已切换为自建 S3，所有上传/下载将使用您自己的 Bucket。';

  @override
  String get s3SettingsDisabledHint => '尚未启用 S3。请填入您的 S3 配置以启用广域网传输。';

  @override
  String get s3SettingsSwitchToCustom => '切换为自建 S3';

  @override
  String get s3SettingsCollapseCustomForm => '取消并保留内置 S3';

  @override
  String get s3SettingsSwitchBackToHosted => '切换回内置 S3';

  @override
  String get s3SettingsSwitchBackTitle => '切换回内置 S3？';

  @override
  String get s3SettingsSwitchBackBody =>
      '切换回平台内置存储后，所有上传/下载将走内置 S3。已保存的自建 S3 配置仍会保留，方便随时一键切回。';

  @override
  String get s3SettingsUseSavedCustom => '使用已保存的自建 S3';

  @override
  String get s3SettingsSwitchedToCustomOk => '已切换为自建 S3';

  @override
  String get s3SettingsSwitchBackConfirm => '切换回内置';

  @override
  String get s3SettingsSwitchedBackOk => '已切换回内置 S3';

  @override
  String get s3SettingsSwitching => '切换中…';

  @override
  String get s3SettingsDocsTooltip => '配置说明（含 CORS）';

  @override
  String get s3SettingsDocsUnavailable => '暂无可打开的文档链接';

  @override
  String get sendModeNearby => '附近';

  @override
  String get linkRoutesTitleRetest => '重新检测连接';

  @override
  String get linkRoutesTitleSwitch => '切换连接线路';

  @override
  String linkRoutesPeerSession(String label) {
    return '当前会话设备：$label';
  }

  @override
  String get linkRoutesBodyRetest => '将对当前线路重新发起检测，以下是双方可用线路及预计速度。';

  @override
  String linkRoutesBodySwitch(String mode) {
    return '将切换到 $mode，并立即发起检测。以下是双方可用线路及预计速度。';
  }

  @override
  String get linkRoutesTagAvailable => '可用';

  @override
  String get linkRoutesTagUnavailable => '不可用';

  @override
  String get linkRoutesTagCurrent => '当前';

  @override
  String get linkRoutesTagTarget => '目标';

  @override
  String linkRoutesSpeedLine(String tier, String desc) {
    return '预计速度：$tier · $desc';
  }

  @override
  String get linkRoutesWaitingResult => '等待检测结果';

  @override
  String get linkRoutesRetest => '重新检测';

  @override
  String get linkRoutesSwitchAndDetect => '切换并检测';

  @override
  String get linkRoutesPickerTitle => '选择连接线路';

  @override
  String get linkRoutesPickerHint => '选择目标线路后将立即切换并检测。';

  @override
  String get linkSpeedNearbyTier => '中高';

  @override
  String get linkSpeedNearbyDesc => '同网段直连，速度受局域网质量影响';

  @override
  String get linkSpeedLanTier => '高';

  @override
  String get linkSpeedLanDesc => 'HTTP 直连，通常是局域网最快路径';

  @override
  String get linkSpeedWebrtcTier => '中';

  @override
  String get linkSpeedWebrtcDesc => '穿透能力强，速度受 NAT 与网络波动影响';

  @override
  String get linkSpeedS3Tier => '中低';

  @override
  String get linkSpeedS3Desc => '经云中转，带宽受公网与节点影响';

  @override
  String get membershipCenterTitle => '会员中心';

  @override
  String membershipLoadFailed(String error) {
    return '加载会员信息失败: $error';
  }

  @override
  String get membershipBuyMiniOrProFirst => '请先开通 Pro 会员';

  @override
  String get membershipPurchaseSuccessSync => '购买成功，权益将由服务器同步，请稍候刷新';

  @override
  String membershipPurchaseFailed(String error) {
    return '购买失败: $error';
  }

  @override
  String get membershipPaymentCancelled => '已取消支付';

  @override
  String get membershipPaymentPending => '支付结果确认中，请稍候查看';

  @override
  String get membershipNetworkError => '网络异常，请重试';

  @override
  String get membershipOrderPayFailed => '订单支付失败，请重试';

  @override
  String get membershipCompletePaymentInApp => '请完成支付后返回本应用，支付结果将自动更新';

  @override
  String get membershipAlipayAppNotConfigured =>
      '当前未配置 APP 支付。请使用电脑浏览器打开网页端完成支付，或联系管理员配置支付宝 APP 应用。';

  @override
  String get membershipOrderCreatedAlipay => '订单已创建，请在支付宝完成支付';

  @override
  String get membershipPurchaseSuccessActive => '支付成功，会员权益已生效';

  @override
  String get membershipCurrentTier => '当前会员';

  @override
  String membershipTierSummary(String tier, int limit) {
    return '$tier · 可绑定 $limit 台设备';
  }

  @override
  String membershipBoundDevices(int count) {
    return '当前已绑定 $count 台';
  }

  @override
  String membershipAddonLine(int packs, int devices) {
    return '已增购 $packs 包（+$devices 台）';
  }

  @override
  String membershipSubscriptionRenewsAt(String date) {
    return '下次续费时间：$date';
  }

  @override
  String membershipSubscriptionEndsAfterCancel(String date) {
    return '已关闭自动续费，会员权益至 $date 结束';
  }

  @override
  String membershipSubscriptionValidUntil(String date) {
    return '当前订阅周期至 $date';
  }

  @override
  String get membershipMigrationCardTitle => '闪电藤会员迁移';

  @override
  String get membershipMigrationCardSubtitle => '如果您是闪电藤会员，可迁移到虾传';

  @override
  String membershipDeviceBadgeDevices(int count) {
    return '$count 台设备';
  }

  @override
  String membershipDeviceBadgeAddon(int count) {
    return '+$count 台';
  }

  @override
  String get membershipTierSubtitleAddon => '每包 +5 台设备，可多次购买';

  @override
  String get membershipTierSubtitleBuyout => '买断会员（永久）';

  @override
  String get membershipCannotBuyLowerTier => '当前档位或更低档位不可购买';

  @override
  String membershipUpgradeDue(String amount) {
    return '升级应付：¥$amount';
  }

  @override
  String get membershipNeedMiniProFirst => '需先开通 Pro 会员';

  @override
  String get membershipPurchasing => '购买中…';

  @override
  String get membershipWaitingPayment => '等待支付结果…';

  @override
  String get membershipPleaseSubscribeFirst => '请先开通 Pro 会员';

  @override
  String get membershipBuyApple => 'Apple 购买';

  @override
  String get membershipBuyAlipay => '支付宝购买';

  @override
  String get membershipBillingMonthly => '按月';

  @override
  String get membershipBillingYearly => '按年';

  @override
  String membershipPlanYearlySave(int pct) {
    return '年付省约 $pct%';
  }

  @override
  String membershipSavingsVsMonthlyYear(int pct) {
    return '相较连续按月付满一年，最高省约 $pct%';
  }

  @override
  String membershipPricePerMonthEquiv(String price) {
    return '约合 $price/月';
  }

  @override
  String membershipPricePerYear(String price) {
    return '$price/年';
  }

  @override
  String membershipPricePerMonth(String price) {
    return '$price/月';
  }

  @override
  String membershipFeatureDevices(int count) {
    return '最高 $count 台设备绑定';
  }

  @override
  String membershipFeatureUploadHosted(int gib) {
    return '内置云传输 $gib GiB / 月（上传计量）';
  }

  @override
  String get membershipPlanPopular => '推荐';

  @override
  String get membershipOverseasNoAlipay => '海外版不支持支付宝，请使用应用内订阅完成支付。';

  @override
  String get membershipSubscribeInApp => '应用内订阅';

  @override
  String get membershipRcUnavailable => '应用内购买暂不可用，请检查网络或稍后再试。';

  @override
  String get membershipTierSubtitleSubscription => '自动续订，可在商店订阅管理中随时取消。';

  @override
  String get membershipOverseasSubscribeHint =>
      '通过 App Store 或 Google Play 订阅，自动续订。';

  @override
  String get membershipOverseasSubscribeHintIos => '通过 App Store 订阅，自动续订。';

  @override
  String get membershipChannelLockedOtherPlatform => '你的订阅在其他平台购买，请在购买设备上管理。';

  @override
  String get membershipChannelLockedStripe =>
      '你的会员通过网页 Stripe 订阅。请在网页升级或管理，避免重复扣款。';

  @override
  String get membershipChannelLockedAppStore =>
      '你的会员通过 App Store 订阅。请在 iPhone/iPad 的设置 → Apple ID → 订阅 中管理或升级。';

  @override
  String get membershipChannelLockedPlayStore =>
      '你的会员通过 Google Play 订阅。请在 Play 商店账户 → 订阅 中管理或升级。';

  @override
  String get membershipChannelLifetime => '你已是终身会员，无需再升级订阅。';

  @override
  String get membershipManageStripe => '管理订阅（网页）';

  @override
  String get membershipManageStripeFailed => '打开订阅管理失败，请稍后重试。';

  @override
  String get membershipRestorePurchases => '恢复购买';

  @override
  String get membershipRestoreSuccess => '已恢复购买，权益将由服务器同步，请稍候刷新';

  @override
  String membershipRestoreFailed(String error) {
    return '恢复购买失败: $error';
  }

  @override
  String get membershipOpenAppStoreSubs => '前往 App Store 订阅';

  @override
  String get membershipOpenPlayStoreSubs => '前往 Play 商店订阅';

  @override
  String get membershipStripePriceMissing => '未配置 Stripe Price，请联系管理员或使用其他端订阅。';

  @override
  String get membershipStripeCheckoutFailed => '创建 Stripe 订阅会话失败，请稍后重试。';

  @override
  String get membershipOpenBrowserToPay => '即将打开浏览器完成支付，付款后回到本应用即可。';

  @override
  String get membershipUpgradeStripeSuccess => '升级成功，会员权益已生效。';

  @override
  String get membershipSubscribeStripe => '用 Stripe 订阅';

  @override
  String get membershipUpgradeStripe => '用 Stripe 升级';

  @override
  String get membershipOpeningStripe => '正在打开 Stripe…';

  @override
  String get membershipMigrationTitle => '闪电藤会员迁移';

  @override
  String get membershipMigrationConfirmTitle => '确认迁移';

  @override
  String membershipMigrationConfirmBody(String tier, int limit) {
    return '验证成功！\n\n您将获得 $tier 会员，可绑定 $limit 台设备。\n\n确认要迁移会员资格吗？';
  }

  @override
  String get membershipMigrationConfirmAction => '确认迁移';

  @override
  String get membershipMigrationEnterPhone => '请先输入手机号';

  @override
  String get membershipMigrationInvalidPhone => '手机号格式不正确';

  @override
  String get membershipMigrationCodeSent => '验证码已发送';

  @override
  String get membershipMigrationEnterCode => '请输入6位验证码';

  @override
  String get membershipMigrationSuccess => '会员迁移成功！';

  @override
  String get membershipMigrationIntroTitle => '会员迁移说明';

  @override
  String get membershipMigrationIntroBody =>
      '如果您是闪电藤的会员用户，可以通过手机号验证将您的会员资格迁移到虾传。\n\n迁移后，您将获得虾传 Pro 会员（12台设备）。';

  @override
  String get membershipMigrationPhoneLabel => '手机号';

  @override
  String get membershipMigrationPhoneHint => '请输入手机号';

  @override
  String get membershipMigrationCodeLabel => '验证码';

  @override
  String get membershipMigrationVerifyAndMigrate => '验证并迁移';

  @override
  String get membershipMigrationSending => '发送中...';

  @override
  String get membershipMigrationSendCode => '发送验证码';

  @override
  String get connectionBarGoToS3Setup => '去配置 S3';

  @override
  String get connectionBarManualPrefix => '手动·';

  @override
  String chatProbeDetecting(String mode) {
    return '$mode检测中';
  }

  @override
  String chatProbeAvailable(String mode) {
    return '$mode可用';
  }

  @override
  String chatProbeUnavailable(String mode) {
    return '$mode暂不可用';
  }

  @override
  String chatProbeTriggered(String mode) {
    return '$mode检测已触发';
  }

  @override
  String chatProbeUnverifiedAttemptable(String mode) {
    return '$mode未验证，仍可尝试传输';
  }

  @override
  String get connectionOrchestratorHttpUnverifiedSubtitle => '连接未验证，将尝试直连/反向拉取';

  @override
  String connectionOrchestratorManualOk(String mode) {
    return '手动·$mode';
  }

  @override
  String connectionOrchestratorManualUnavailable(String mode) {
    return '手动·$mode不可用';
  }

  @override
  String get connectionOrchestratorLinkUnavailable => '当前链路不可用';

  @override
  String get connectionOrchestratorAutoS3 => '自动·S3';

  @override
  String get connectionOrchestratorS3FallbackSubtitle => '直连失败，已降级到云中转';

  @override
  String connectionOrchestratorAutoMode(String mode) {
    return '自动·$mode';
  }

  @override
  String get connectionOrchestratorNoDirect => '无可用直连';

  @override
  String get connectionOrchestratorLoginPromptSubtitle =>
      '登录后可使用 HTTP、WebRTC、S3';

  @override
  String get connectionOrchestratorNoDirectS3Fallback => '无可用直连，已降级';

  @override
  String get connectionOrchestratorS3Unavailable => 'S3 不可用';

  @override
  String get connectionOrchestratorS3NotConfigured => 'S3 未配置';

  @override
  String membershipMigrationCooldownSeconds(int seconds) {
    return '$seconds秒后重试';
  }

  @override
  String get mobileHomeTabConnect => '连接';

  @override
  String get mobileHomeTabFiles => '文件';

  @override
  String chatReceivedExportingToast(String name) {
    return '已接收 $name，正在保存到文件夹…';
  }

  @override
  String get mobileHomeTabSettings => '设置';

  @override
  String get mobileHomePendingOutbox => '待发文件箱';

  @override
  String get pendingFilesSend => '发送';

  @override
  String get pendingFilesManage => '管理';

  @override
  String pendingFilesManageWithCount(int count) {
    return '管理（共$count个）';
  }

  @override
  String pendingFilesSelectedCount(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String get pendingFilesClearAll => '清空全部';

  @override
  String fileSendTitleSingle(String name) {
    return '发送：$name';
  }

  @override
  String fileSendTitleMany(String firstName, int count) {
    return '发送：$firstName 等$count个文件';
  }

  @override
  String get fileSendS3Intro => '通过 S3 云端中转发送到所有已登录设备，适用于跨网络传输。';

  @override
  String get fileSendS3ConfigurePrompt => '请先配置 S3 以使用云端发送。';

  @override
  String get fileSendResumeSupported => '支持断点续传';

  @override
  String get fileSendResumeNotSupported => '不支持断点续传';

  @override
  String get fileSendStatusChecking => '检测中';

  @override
  String get fileSendLanStatusOnlineDirect => '在线 · 可直连';

  @override
  String get fileSendLanStatusPullAvailable => '可反向拉取';

  @override
  String get fileSendLanStatusUnreachable => '无法连通';

  @override
  String get fileSendLanStatusOfflineDirect => '离线';

  @override
  String get fileSendWebRtcStatusOnline => '在线';

  @override
  String get fileSendWebRtcStatusConnectable => '可尝试';

  @override
  String get fileSendWebRtcStatusOffline => '离线';

  @override
  String get fileSendWebRtcIntro => '通过 WebRTC 传输，数据不经服务器。连接失败时自动降级到 S3。';

  @override
  String get fileSendWebRtcEmptyNoDevices => '暂无发现其他设备。';

  @override
  String get fileSendEmptyNearbyOffline => '暂无发现其他设备，请确保设备在同一局域网内。';

  @override
  String get fileSendEmptyMyDevicesOnLan => '暂无我的设备在局域网内。';

  @override
  String get fileSendSendToSelected => '发送到已选设备';

  @override
  String get fileSendViaWebRtc => '通过 WebRTC 发送';

  @override
  String get fileSendConfigureS3First => '请先配置 S3';

  @override
  String get fileSendToAllDevices => '发送到全部设备';

  @override
  String get fileSendTabMyDevices => '我的设备';

  @override
  String get fileSendTabWebRtc => 'WebRTC';

  @override
  String get devicePanelStatusServerUnreachable => '服务器不可达';

  @override
  String get devicePanelStatusValidating => '验证登录…';

  @override
  String get devicePanelStatusSessionExpired => '登录已失效';

  @override
  String get devicePanelStatusConnected => '已连接';

  @override
  String get devicePanelStatusConnecting => '连接中…';

  @override
  String get devicePanelEmptyNoOtherDevices => '暂无其他设备';

  @override
  String get devicePanelEmptyHintOfflineLan => '确保其他设备在同一局域网内即可开始传输';

  @override
  String get devicePanelEmptyHintOnlineAccount => '在其他设备上登录同一账号即可开始传输';

  @override
  String devicePanelDevicesOnlineCount(int count) {
    return '$count 台在线';
  }

  @override
  String get connectionBarDefaultTitle => '连接状态';

  @override
  String get connectionBarManualShort => '手动';

  @override
  String get connectionBarAutoShort => '自动';

  @override
  String get connectionBarResumeAuto => '恢复自动';

  @override
  String get connectionBarSwitchMode => '切换';

  @override
  String get connectionBarRefreshOnlineStatus => '刷新在线状态';

  @override
  String get transportModeLabel => '传输方式';

  @override
  String get transportModeHttpLan => 'HTTP 局域网直连';

  @override
  String get transportModeWebrtcLan => 'WebRTC 局域网直连';

  @override
  String get connectionDiagTitle => '连接诊断';

  @override
  String connectionDiagSubtitleRunning(String peer) {
    return '正在检测与 $peer 的连接…';
  }

  @override
  String connectionDiagSubtitleDone(String peer) {
    return '与 $peer 的连接检测已完成';
  }

  @override
  String get connectionDiagContinueInBackground => '后台继续';

  @override
  String get connectionDiagDone => '完成';

  @override
  String get connectionDiagStepS3 => 'S3 云端';

  @override
  String get connectionDiagStepHttpDirect => 'HTTP 局域网直连';

  @override
  String get connectionDiagStepHttpSignaling => 'HTTP 信令检测';

  @override
  String get connectionDiagStepHttpPull => 'HTTP 反向拉取';

  @override
  String get connectionDiagStepWebrtc => 'WebRTC 连通性';

  @override
  String get connectionDiagStatusPending => '等待';

  @override
  String get connectionDiagStatusRunning => '检测中';

  @override
  String get connectionDiagStatusSuccess => '可用';

  @override
  String get connectionDiagStatusFailure => '不可用';

  @override
  String get connectionDiagStatusSkipped => '已跳过';

  @override
  String get connectionDiagReasonS3Online => 'S3 配置正常，云端可达';

  @override
  String get connectionDiagReasonS3NotConfigured => 'S3 未配置';

  @override
  String get connectionDiagReasonS3Unavailable => 'S3 已配置但云端不可达';

  @override
  String get connectionDiagReasonHttpDirectOk => '局域网 HTTP 直连成功';

  @override
  String get connectionDiagReasonHttpDirectFail => '无法访问对端 HTTP 服务（超时或无响应）';

  @override
  String get connectionDiagReasonHttpSignalingOk => '对端 HTTP 服务自检通过';

  @override
  String get connectionDiagReasonHttpSignalingFail => '信令检测失败，对端 HTTP 服务未响应';

  @override
  String get connectionDiagReasonHttpPullOk => '对端可反向拉取本机文件';

  @override
  String get connectionDiagReasonHttpPullFail => '反向拉取失败，对端无法访问本机 HTTP';

  @override
  String get connectionDiagReasonWebrtcOnline => '同网段，WebRTC 可直接连通';

  @override
  String get connectionDiagReasonWebrtcConnectable => '跨网段，WebRTC 可能通过中继连通';

  @override
  String get connectionDiagReasonWebrtcFail => 'WebRTC 信令或 ICE 不可达';

  @override
  String get connectionDiagReasonWebrtcSkippedLanOk =>
      '局域网 HTTP 已可用，跳过 WebRTC 检测';

  @override
  String get connectionDiagReasonSkippedLanDirectOk => 'HTTP 直连已成功，跳过';

  @override
  String get connectionDiagReasonSkippedOffline => '当前离线，无法通过云端信令检测';

  @override
  String get connectionDiagReasonSkippedPeerOffline => '对端显示离线且无局域网地址，跳过检测';

  @override
  String get connectionDiagReasonHttpDirectNoUrl => '未发现局域网地址，无法测试 HTTP 直连';

  @override
  String get connectionDiagReasonOfflineCloud => '当前离线，无法通过云端信令检测';

  @override
  String get connectionDiagReasonS3LoginRequired => '需要登录后才可检测 S3';

  @override
  String connectionDiagSummaryRecommend(String mode, String reason) {
    return '推荐：$mode（$reason）';
  }

  @override
  String get connectionDiagSummaryNoRoute => '未找到可用传输线路';

  @override
  String connectionDiagElapsed(String elapsed) {
    return '耗时 $elapsed';
  }

  @override
  String get connectionDiagHelpHttpDirectTitle => 'HTTP 局域网直连';

  @override
  String get connectionDiagHelpHttpDirectBody =>
      '本机直接向对端的局域网 HTTP 地址发起 /probe 请求，不经过云端服务器。\n\n用于确认：在已知对端局域网地址（如 mDNS 发现）且网络可达时，能否建立最快的 HTTP 文件传输路径。';

  @override
  String get connectionDiagHelpHttpSignalingTitle => 'HTTP 信令检测';

  @override
  String get connectionDiagHelpHttpSignalingBody =>
      '通过云端消息（Centrifugo）通知对端自检其 HTTP 服务，并将结果回传。\n\n用于确认：即使尚未发现对端局域网地址，只要双方在线，对端 HTTP 服务是否正常，并可能获取或更新其局域网地址。';

  @override
  String get connectionDiagHelpHttpPullTitle => 'HTTP 反向拉取';

  @override
  String get connectionDiagHelpHttpPullBody =>
      '通过云端通知对端，尝试访问本机的 HTTP 服务。\n\n用于确认：在 NAT 或网络不对称（只能单向连通）时，对端能否反向拉取本机文件。这是 HTTP 直连不可用时的备选传输方向。';

  @override
  String get connectionDiagHelpWebrtcTitle => 'WebRTC 连通性';

  @override
  String get connectionDiagHelpWebrtcBody =>
      '通过云端交换 ICE 网络候选信息，分析双方是否在同一网段、能否 P2P 直连，或需经中继连通。\n\n用于确认：WebRTC 文件传输路径是否可用（通常比 HTTP 直连慢，但可跨网段）。';

  @override
  String get connectionDiagHelpS3Title => 'S3 云端';

  @override
  String get connectionDiagHelpS3Body =>
      '检测账号的 S3 存储配置是否完整，并向云端发起连通性测试。\n\n用于确认：当所有局域网/直连方式均不可用时，是否可降级到 S3 云中转传输文件。';

  @override
  String get connectionDiagHelpTooltip => '了解检测原理';

  @override
  String get composerPickAttachmentTitle => '选择附件';

  @override
  String get composerAttachImageVideo => '图片/视频';

  @override
  String get composerAttachImageVideoDesc => '从相册中选择图片或视频';

  @override
  String get chatGalleryReadPermissionTitle => '访问相册';

  @override
  String get chatGalleryReadPermissionBody =>
      '选择图片或视频需要访问您的相册。建议允许访问「全部照片和视频」。';

  @override
  String get chatGalleryReadPermissionConfirm => '继续';

  @override
  String get chatGalleryReadPermissionDenied => '未获得相册访问权限，无法选择图片或视频';

  @override
  String get chatGalleryReadPermissionLimited => '当前仅可访问部分照片，建议前往系统设置允许访问全部资源';

  @override
  String get chatGalleryReadPermissionContinuePartial => '继续访问部分资源';

  @override
  String get composerAttachFile => '系统文件';

  @override
  String get composerAttachFileDesc => '通过系统文件选择器选取';

  @override
  String get composerAttachFolder => '选择文件夹';

  @override
  String get composerAttachFolderDesc => '选择整个文件夹中的所有文件';

  @override
  String get composerAttachApk => '选择 APK';

  @override
  String get composerAttachApkDesc => '从设备中选择 APK 安装包';

  @override
  String get composerMessageHint => '输入消息…';

  @override
  String get composerClearInputTooltip => '清空';

  @override
  String get shortcutsSendTitle => '发送消息';

  @override
  String get shortcutsSendDescription => '选择用哪个按键在输入框中发送消息';

  @override
  String get shortcutsSendEnter => '按 Enter 键发送';

  @override
  String get shortcutsSendModifier => '按 Ctrl+Enter 键发送';

  @override
  String get shortcutsSendModifierMac => '按 ⌘+Enter 键发送';

  @override
  String get shortcutsSendButtonHint => '发送按钮始终可用，不受此设置影响。';

  @override
  String get composerSendTooltipEnter => '发送 (Enter)';

  @override
  String get composerSendTooltipModifier => '发送 (Ctrl+Enter)';

  @override
  String get composerSendTooltipModifierMac => '发送 (⌘+Enter)';

  @override
  String chatTransferSendingPct(String fileName, int pct) {
    return '$fileName 发送中 $pct%';
  }

  @override
  String chatTransferReceivingPct(String fileName, int pct) {
    return '$fileName 接收中 $pct%';
  }

  @override
  String chatTransferWaitingPeerLine(String fileName) {
    return '$fileName 等待接收方连接…';
  }

  @override
  String get chatTransferWaitingPeerShort => '等待接收方连接…';

  @override
  String get chatTransferCancelledBare => '已取消';

  @override
  String chatTransferCancelledNamed(String fileName) {
    return '$fileName 已取消';
  }

  @override
  String chatTransferSendFailedNamed(String fileName) {
    return '$fileName 发送失败';
  }

  @override
  String chatTransferReceiveFailedNamed(String fileName) {
    return '$fileName 接收失败';
  }

  @override
  String get chatTransferProgressSending => '发送中';

  @override
  String get chatTransferProgressReceiving => '接收中';

  @override
  String chatTransferEtaSecondsRemaining(int seconds) {
    return '剩余 $seconds 秒';
  }

  @override
  String chatTransferEtaMinutesSecondsRemaining(int minutes, int seconds) {
    return '剩余 $minutes分$seconds秒';
  }

  @override
  String chatWebRtcSentParen(String fileName) {
    return '$fileName (WebRTC 已发送)';
  }

  @override
  String get chatScreenGenericFile => '文件';

  @override
  String get chatScreenDeleteThisDeviceTitle => '删除本设备';

  @override
  String get chatScreenDeleteThisDeviceBody =>
      '将从账号下移除本设备并退出登录。移除后需重新登录才可继续使用云端功能。';

  @override
  String get chatScreenRemovePeerTitle => '移除设备';

  @override
  String get chatScreenRemovePeerBody =>
      '移除后，该设备上的账号将退出登录；若正在使用会立即失效，若未启动则下次打开应用时需重新登录。';

  @override
  String get chatScreenConfirmRemoveLabel => '移除';

  @override
  String get chatScreenConfirmDeleteLabel => '删除';

  @override
  String get chatScreenToastDeletedThisDevice => '已删除本设备';

  @override
  String chatScreenToastDeleteDeviceFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get chatScreenToastRemovedPeer => '已移除设备';

  @override
  String chatScreenToastRemovePeerFailed(String error) {
    return '移除失败：$error';
  }

  @override
  String get chatScreenSessionSettingsTitle => '会话设置';

  @override
  String get chatScreenTileRenameDevice => '修改设备名称';

  @override
  String get chatScreenTileClearMessages => '清空消息';

  @override
  String get chatScreenSubtitleClearMessages => '删除本会话全部聊天记录';

  @override
  String get chatScreenClearMessagesTitle => '清空消息';

  @override
  String get chatScreenClearMessagesConfirm =>
      '将删除本会话的全部聊天记录。已保存到保存文件夹的文件不会删除。';

  @override
  String get chatScreenClearMessagesDeleteCache => '同时删除缓存文件';

  @override
  String get chatScreenClearMessagesDone => '消息已清空';

  @override
  String get chatScreenClearMessagesFailed => '清空消息失败';

  @override
  String get chatScreenTileRemoveThisDevice => '删除本设备';

  @override
  String get chatScreenTileRemovePeer => '移除设备';

  @override
  String get chatScreenSubtitleRemoveThisDevice => '从账号移除本机并退出登录';

  @override
  String get chatScreenSubtitleRemovePeer => '从账号移除当前会话中的设备';

  @override
  String get chatScreenPendingFilesMissing => '部分待发文件已不存在，已自动移除';

  @override
  String get chatScreenConnNotLoggedInHttp => '当前未登录，仅支持 HTTP 传输';

  @override
  String get chatScreenConnOffline => '无法连接服务器，当前为离线模式';

  @override
  String get chatScreenConnServerOk => '服务器连接成功';

  @override
  String get chatScreenSelectTargetFirst => '请先选择目标设备';

  @override
  String get chatScreenFolderNeedsPermission => '需要存储权限才能访问文件夹';

  @override
  String get chatScreenFolderEmpty => '该文件夹为空或无法读取';

  @override
  String get chatScreenFolderSafTryFiles => '无法读取所选文件夹，请改用「选择文件」发送';

  @override
  String get chatScreenRetryCloudOffline => '离线模式下无法重试云传输';

  @override
  String get chatScreenNoDeviceFound => '未发现目标设备，请确认设备在线后重试';

  @override
  String get chatScreenOfflineNoS3 => '离线模式下无法使用S3传输';

  @override
  String get chatScreenS3NotConfiguredTitle => 'S3 未配置';

  @override
  String get chatScreenS3NotConfiguredBody => '当前尚未配置 S3，是否前往设置？';

  @override
  String get chatScreenS3GoConfigure => '去配置';

  @override
  String get chatScreenS3UnavailableTitle => 'S3 不可用';

  @override
  String get chatScreenS3UnavailableBody =>
      'S3 连接测试未通过，请检查配置或网络后重试。是否前往 S3 设置？';

  @override
  String get chatScreenS3GoSettings => '去设置';

  @override
  String get chatScreenNoNearbyDevice => '附近没有可用设备，请重新选择';

  @override
  String get chatScreenDeviceUnavailable => '所选设备不可用，请重新选择';

  @override
  String get chatScreenWebRtcUnsupportedSource =>
      '当前文件来源不支持 WebRTC，请切换到 HTTP 发送';

  @override
  String get chatScreenWebRtcFailedTryHttp => 'WebRTC 发送失败，请切换到 HTTP 模式重试';

  @override
  String get chatScreenConfigureS3FirstToast => '请先在设置中配置 S3';

  @override
  String get chatScreenS3UnavailableToast => 'S3 当前不可用，请在设置中检查配置或重新测试连接';

  @override
  String chatScreenSendFailedWithError(String error) {
    return '发送失败: $error';
  }

  @override
  String get chatScreenFileMissing => '文件不存在，可能已被删除';

  @override
  String get chatScreenCannotOpenFile => '无法打开此文件';

  @override
  String get chatScreenSavedToGallery => '已保存到相册';

  @override
  String chatScreenReceivedAtPath(String path) {
    return '已接收: $path';
  }

  @override
  String chatScreenReceiveFailedWithError(String error) {
    return '接收失败: $error';
  }

  @override
  String get chatScreenCopied => '已复制';

  @override
  String get chatScreenDeleteMessagesTitle => '删除消息';

  @override
  String chatScreenDeleteMessagesBody(int count) {
    return '确定删除 $count 条消息？将同时删除本地和云端记录。';
  }

  @override
  String get chatHttpReceivedSavedGallery => '已通过 HTTP 收到并保存到相册';

  @override
  String chatHttpReceivedWithName(String fileName) {
    return '已通过 HTTP 收到: $fileName';
  }

  @override
  String get chatHttpPullReceivedSavedGallery => '已通过反向拉取收到并保存到相册';

  @override
  String chatHttpPullReceivedWithName(String fileName) {
    return '已通过反向拉取收到: $fileName';
  }

  @override
  String chatHttpReceivedBracket(String fileName) {
    return '$fileName (已通过 HTTP 接收)';
  }

  @override
  String get appGallerySubfolder => '虾传';

  @override
  String get appUpdateTitleNewVersion => '发现新版本';

  @override
  String appUpdateCurrentVersion(String version, String build) {
    return '当前版本：$version ($build)';
  }

  @override
  String appUpdateNewVersion(String version, String build) {
    return '新版本：$version ($build)';
  }

  @override
  String get appUpdateLater => '稍后';

  @override
  String get appUpdateDontShowAgainVersion => '不再提示此版本';

  @override
  String get appUpdateDownload => '下载';

  @override
  String get appUpdateOpenDownloadPage => '在浏览器中打开';

  @override
  String get appUpdateGoAppStore => '前往 App Store';

  @override
  String get appUpdateInstallTitle => '安装更新';

  @override
  String appUpdateInstallBody(String version, String build, String pending) {
    return '当前版本：$version ($build)\n待安装包版本：$pending\n\n新版本已下载，是否立即安装？';
  }

  @override
  String get appUpdateUnknownVersion => '未知';

  @override
  String get appUpdateDontShowAgain => '不再提示';

  @override
  String get appUpdateInstall => '安装';

  @override
  String get desktopUpdateSizeUnknown => '大小未知';

  @override
  String desktopUpdateSizeMb(String mb) {
    return '约 $mb MB';
  }

  @override
  String desktopUpdateSizeKb(String kb) {
    return '约 $kb KB';
  }

  @override
  String get desktopUpdateBannerTitle => '发现新版本';

  @override
  String desktopUpdateBannerSubtitle(String version, String sizeLine) {
    return '版本 $version · $sizeLine';
  }

  @override
  String get desktopUpdateLater => '稍后';

  @override
  String get desktopUpdateNow => '立即更新';

  @override
  String get desktopUpdateDownloading => '正在下载更新…';

  @override
  String get desktopUpdateApplying => '正在关闭并应用更新，请稍候…';

  @override
  String get desktopUpdateReadyTitle => '更新已就绪';

  @override
  String get desktopUpdateReadyBody => '点击下方按钮后将自动关闭并重启，安装约需数秒';

  @override
  String get desktopUpdateQuitRestart => '退出并重启';

  @override
  String get desktopUpdateErrorUnknown => '未知错误';

  @override
  String get desktopUpdateCheckFailedTitle => '更新检查失败';

  @override
  String get desktopUpdateClose => '关闭';

  @override
  String get desktopUpdateRetry => '重试';

  @override
  String get desktopUpdateReleaseNotesAction => '查看更新内容';

  @override
  String desktopUpdateReleaseNotesTitle(String version) {
    return '更新内容（$version）';
  }

  @override
  String get desktopUpdateReleaseNotesEmpty => '该版本暂无更新说明。';

  @override
  String get qrGenerating => '正在生成二维码...';

  @override
  String get qrHintScanWithPhone => '请用已登录的手机扫描二维码';

  @override
  String get qrHintConfirmOnPhone => '已扫码，请在手机上确认登录';

  @override
  String get qrHintLoginSuccess => '登录成功，正在跳转...';

  @override
  String get qrHintExpired => '二维码已过期，请刷新后重试';

  @override
  String get qrHintGenericError => '出错了';

  @override
  String get qrLoginTitle => '扫码登录';

  @override
  String get qrLoginTagline => '消息/文件中转，多端实时同步';

  @override
  String get qrLoginSteps => '打开手机 App → 扫码 → 在手机上确认';

  @override
  String get qrStatusScanned => '已扫码';

  @override
  String get qrStatusConfirmPhone => '请在手机上确认登录';

  @override
  String get qrRefreshButton => '刷新二维码';

  @override
  String get qrUsePasswordLogin => '使用账号密码登录';

  @override
  String qrScannerFailed(String error) {
    return '扫码失败: $error';
  }

  @override
  String get qrConfirmLoginTitle => '确认登录';

  @override
  String get qrConfirmLoginBody => '是否确认在其他设备上登录？';

  @override
  String get qrConfirmLoginConfirm => '确认登录';

  @override
  String get qrConfirmLoginSuccess => '已确认登录';

  @override
  String qrConfirmLoginFailed(String error) {
    return '确认失败: $error';
  }

  @override
  String get qrScannerNeedCamera => '需要相机权限才能扫描二维码';

  @override
  String get qrScannerOpenSettings => '前往设置';

  @override
  String get qrScannerPermissionAgain => '重新请求权限';

  @override
  String get qrScannerProcessing => '处理中...';

  @override
  String get qrScannerAlignQr => '将二维码对准框内扫描';

  @override
  String get qrScannerUnrecognized => '请扫描虾传登录二维码';

  @override
  String get qrScannerTorchOn => '打开闪光灯';

  @override
  String get qrScannerTorchOff => '关闭闪光灯';

  @override
  String get filePreviewTooltipShare => '分享';

  @override
  String get filePreviewTooltipOpenWith => '用其他应用打开';

  @override
  String get filePreviewImageLoadError => '无法加载图片';

  @override
  String get filePreviewVideoError => '无法播放此视频';

  @override
  String filePreviewTextTruncated(String text) {
    return '$text\n\n… 文件过大，仅显示前 2 MB';
  }

  @override
  String get filePreviewReadError => '无法读取文件内容';

  @override
  String get filePreviewCopyAll => '复制全部';

  @override
  String get filePreviewCopied => '已复制到剪贴板';

  @override
  String get fileClipboardCopy => '复制';

  @override
  String fileClipboardCopied(int count) {
    return '已复制 $count 个文件，可在资源管理器中粘贴';
  }

  @override
  String get fileClipboardCopyFailed => '复制失败';

  @override
  String get fileClipboardPasteAdded => '已加入待发文件箱，前往聊天发送';

  @override
  String get fileClipboardNothingToCopy => '请先选择要复制的文件';

  @override
  String get chatMenuCopyFile => '复制文件';
}
