import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Product display name when service region is Mainland China (English UI uses Latin script)
  ///
  /// In en, this message translates to:
  /// **'ShrimpSend'**
  String get brandNameMainlandChina;

  /// No description provided for @brandNameInternational.
  ///
  /// In en, this message translates to:
  /// **'ShrimpSend'**
  String get brandNameInternational;

  /// No description provided for @localeRegionGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localeRegionGateTitle;

  /// No description provided for @localeRegionGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the display language. The service region for this app build is fixed.'**
  String get localeRegionGateSubtitle;

  /// No description provided for @localeRegionGateCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose. Mainland China (CN) uses the Xiachuan cluster; others use ShrimpSend.'**
  String get localeRegionGateCountryHint;

  /// No description provided for @fieldLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get fieldLanguage;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @fieldCountryRegion.
  ///
  /// In en, this message translates to:
  /// **'Country or region'**
  String get fieldCountryRegion;

  /// No description provided for @regionMainlandChina.
  ///
  /// In en, this message translates to:
  /// **'Mainland China'**
  String get regionMainlandChina;

  /// No description provided for @regionInternational.
  ///
  /// In en, this message translates to:
  /// **'Outside Mainland China'**
  String get regionInternational;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @loginSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please sign in again'**
  String get loginSessionExpired;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionLanguageRegion.
  ///
  /// In en, this message translates to:
  /// **'Language and region'**
  String get sectionLanguageRegion;

  /// No description provided for @serverClusterSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out'**
  String get serverClusterSwitchTitle;

  /// No description provided for @serverClusterSwitchMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected country or region uses a different service domain and cluster. To protect your account, you will be signed out now and must sign in again on the new domain to continue. Your country selection will revert to the previous value for now; you can choose again after signing in.'**
  String get serverClusterSwitchMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @signOutRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign out required'**
  String get signOutRequired;

  /// No description provided for @loginTitleSubtitleLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your cross-device transfer'**
  String get loginTitleSubtitleLogin;

  /// No description provided for @loginTitleSubtitleRegister.
  ///
  /// In en, this message translates to:
  /// **'Create an account to sync messages and files'**
  String get loginTitleSubtitleRegister;

  /// No description provided for @enterOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Continue in offline mode'**
  String get enterOfflineMode;

  /// No description provided for @legalPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicy;

  /// No description provided for @legalTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTermsOfService;

  /// No description provided for @legalCouldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get legalCouldNotOpenLink;

  /// No description provided for @envLabelDev.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get envLabelDev;

  /// No description provided for @envLabelProd.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get envLabelProd;

  /// No description provided for @applyingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Applying update, the app will restart (a few seconds)…'**
  String get applyingUpdate;

  /// No description provided for @localeNameZhHans.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get localeNameZhHans;

  /// No description provided for @localeNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeNameEnglish;

  /// No description provided for @loginTabLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTabLogin;

  /// No description provided for @loginTabRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginTabRegister;

  /// No description provided for @loginMethodPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginMethodPassword;

  /// No description provided for @loginMethodCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get loginMethodCode;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @hintEmail.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get hintEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get fieldVerificationCode;

  /// No description provided for @hintVerificationCode6.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get hintVerificationCode6;

  /// No description provided for @fieldNicknameOptional.
  ///
  /// In en, this message translates to:
  /// **'Nickname (optional)'**
  String get fieldNicknameOptional;

  /// No description provided for @hintDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get hintDisplayName;

  /// No description provided for @loginGetVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Get code'**
  String get loginGetVerificationCode;

  /// No description provided for @loginSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendVerificationCode;

  /// No description provided for @codeCooldownSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String codeCooldownSeconds(int seconds);

  /// No description provided for @loginSubmitRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginSubmitRegister;

  /// No description provided for @loginSubmitWithCode.
  ///
  /// In en, this message translates to:
  /// **'Log in with code'**
  String get loginSubmitWithCode;

  /// No description provided for @loginSubmitPassword.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginSubmitPassword;

  /// No description provided for @loginQrLogin.
  ///
  /// In en, this message translates to:
  /// **'Scan to sign in'**
  String get loginQrLogin;

  /// No description provided for @loginPromptNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account?'**
  String get loginPromptNoAccount;

  /// No description provided for @loginPromptHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get loginPromptHasAccount;

  /// No description provided for @loginLinkToRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginLinkToRegister;

  /// No description provided for @loginLinkToLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginLinkToLogin;

  /// No description provided for @loginErrorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email first'**
  String get loginErrorEmailRequired;

  /// No description provided for @loginErrorCodeSixDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get loginErrorCodeSixDigits;

  /// No description provided for @snackbarAllowInstallUnknownApps.
  ///
  /// In en, this message translates to:
  /// **'Allow installing unknown apps in Settings; installation will continue when you return'**
  String get snackbarAllowInstallUnknownApps;

  /// No description provided for @settingsSectionFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get settingsSectionFeatures;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsNavLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsNavLogin;

  /// No description provided for @settingsNavLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync and more after you sign in'**
  String get settingsNavLoginSubtitle;

  /// No description provided for @settingsBadgeNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get settingsBadgeNotSignedIn;

  /// No description provided for @settingsNavPersonalAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsNavPersonalAccount;

  /// No description provided for @settingsNavAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and manage your account'**
  String get settingsNavAccountSubtitle;

  /// No description provided for @settingsMembershipCenter.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get settingsMembershipCenter;

  /// No description provided for @settingsMembershipSubtitleUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Lifetime plans and more devices'**
  String get settingsMembershipSubtitleUpgrade;

  /// No description provided for @settingsMembershipTierName.
  ///
  /// In en, this message translates to:
  /// **'{tierName} membership'**
  String settingsMembershipTierName(String tierName);

  /// No description provided for @settingsMembershipDevices.
  ///
  /// In en, this message translates to:
  /// **'{current} of {limit} devices'**
  String settingsMembershipDevices(int current, int limit);

  /// No description provided for @settingsNavMyDevices.
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get settingsNavMyDevices;

  /// No description provided for @settingsNavMyDevicesSubtitleOffline.
  ///
  /// In en, this message translates to:
  /// **'Manage devices after you sign in'**
  String get settingsNavMyDevicesSubtitleOffline;

  /// No description provided for @settingsNavMyDevicesSubtitleOnline.
  ///
  /// In en, this message translates to:
  /// **'Bound devices'**
  String get settingsNavMyDevicesSubtitleOnline;

  /// No description provided for @settingsNavS3.
  ///
  /// In en, this message translates to:
  /// **'S3'**
  String get settingsNavS3;

  /// No description provided for @settingsNavS3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Wide-area file transfer'**
  String get settingsNavS3Subtitle;

  /// No description provided for @settingsNavShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get settingsNavShortcuts;

  /// No description provided for @settingsNavShortcutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard actions such as sending messages'**
  String get settingsNavShortcutsSubtitle;

  /// No description provided for @settingsNavFonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get settingsNavFonts;

  /// No description provided for @settingsNavFontsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust text size and weight'**
  String get settingsNavFontsSubtitle;

  /// No description provided for @settingsFontsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get settingsFontsPageTitle;

  /// No description provided for @settingsShortcutsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get settingsShortcutsPageTitle;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsColorThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get settingsColorThemeLabel;

  /// No description provided for @settingsColorThemeEmerald.
  ///
  /// In en, this message translates to:
  /// **'Emerald'**
  String get settingsColorThemeEmerald;

  /// No description provided for @settingsColorThemeOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get settingsColorThemeOcean;

  /// No description provided for @settingsColorThemeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get settingsColorThemeSunset;

  /// No description provided for @settingsColorThemeLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get settingsColorThemeLavender;

  /// No description provided for @settingsColorThemeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get settingsColorThemeRose;

  /// No description provided for @settingsColorThemeGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get settingsColorThemeGraphite;

  /// No description provided for @settingsFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get settingsFontLabel;

  /// No description provided for @settingsFontLatinLabel.
  ///
  /// In en, this message translates to:
  /// **'English font'**
  String get settingsFontLatinLabel;

  /// No description provided for @settingsFontCjkLabel.
  ///
  /// In en, this message translates to:
  /// **'Chinese font'**
  String get settingsFontCjkLabel;

  /// No description provided for @settingsFontMonoLabel.
  ///
  /// In en, this message translates to:
  /// **'Monospace font'**
  String get settingsFontMonoLabel;

  /// No description provided for @settingsFontSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsFontSystem;

  /// No description provided for @settingsFontInter.
  ///
  /// In en, this message translates to:
  /// **'Inter'**
  String get settingsFontInter;

  /// No description provided for @settingsFontSourceSans3.
  ///
  /// In en, this message translates to:
  /// **'Source Sans 3'**
  String get settingsFontSourceSans3;

  /// No description provided for @settingsFontIbmPlexSans.
  ///
  /// In en, this message translates to:
  /// **'IBM Plex Sans'**
  String get settingsFontIbmPlexSans;

  /// No description provided for @settingsFontNotoSansSc.
  ///
  /// In en, this message translates to:
  /// **'Noto Sans SC'**
  String get settingsFontNotoSansSc;

  /// No description provided for @settingsFontNotoSerifSc.
  ///
  /// In en, this message translates to:
  /// **'Noto Serif SC'**
  String get settingsFontNotoSerifSc;

  /// No description provided for @settingsFontLxgwWenkai.
  ///
  /// In en, this message translates to:
  /// **'LXGW WenKai'**
  String get settingsFontLxgwWenkai;

  /// No description provided for @settingsFontSmileySans.
  ///
  /// In en, this message translates to:
  /// **'Smiley Sans'**
  String get settingsFontSmileySans;

  /// No description provided for @settingsFontIbmPlexMono.
  ///
  /// In en, this message translates to:
  /// **'IBM Plex Mono'**
  String get settingsFontIbmPlexMono;

  /// No description provided for @settingsFontPreview.
  ///
  /// In en, this message translates to:
  /// **'ShrimpSend · Hello world · 123'**
  String get settingsFontPreview;

  /// No description provided for @settingsFontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsFontSizeLabel;

  /// No description provided for @settingsFontSizeSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get settingsFontSizeSmaller;

  /// No description provided for @settingsFontSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsFontSizeSmall;

  /// No description provided for @settingsFontSizeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsFontSizeStandard;

  /// No description provided for @settingsFontSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsFontSizeLarge;

  /// No description provided for @settingsFontSizeLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get settingsFontSizeLarger;

  /// No description provided for @settingsFontWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Text weight'**
  String get settingsFontWeightLabel;

  /// No description provided for @settingsFontWeightLighter.
  ///
  /// In en, this message translates to:
  /// **'Lighter'**
  String get settingsFontWeightLighter;

  /// No description provided for @settingsFontWeightLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsFontWeightLight;

  /// No description provided for @settingsFontWeightNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settingsFontWeightNormal;

  /// No description provided for @settingsFontWeightMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsFontWeightMedium;

  /// No description provided for @settingsFontWeightSemibold.
  ///
  /// In en, this message translates to:
  /// **'Semibold'**
  String get settingsFontWeightSemibold;

  /// No description provided for @settingsFontLicenses.
  ///
  /// In en, this message translates to:
  /// **'Windows builds bundle WenYuan Sans SC / 文源黑体 (SIL Open Font License 1.1). Other platforms use system fonts. Source: https://github.com/takushun-wu/WenYuanFonts'**
  String get settingsFontLicenses;

  /// No description provided for @settingsFileSavePath.
  ///
  /// In en, this message translates to:
  /// **'File save location'**
  String get settingsFileSavePath;

  /// No description provided for @settingsFileSavePathNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsFileSavePathNotSet;

  /// No description provided for @settingsSavePathBadgeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsSavePathBadgeDefault;

  /// No description provided for @settingsSavePathBadgeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsSavePathBadgeCustom;

  /// No description provided for @settingsSavePathKindExternal.
  ///
  /// In en, this message translates to:
  /// **'External storage'**
  String get settingsSavePathKindExternal;

  /// No description provided for @settingsSavePathKindAppDocuments.
  ///
  /// In en, this message translates to:
  /// **'App documents'**
  String get settingsSavePathKindAppDocuments;

  /// No description provided for @settingsSavePathKindAppCache.
  ///
  /// In en, this message translates to:
  /// **'App cache'**
  String get settingsSavePathKindAppCache;

  /// No description provided for @settingsSavePathKindAppExternal.
  ///
  /// In en, this message translates to:
  /// **'App-specific storage'**
  String get settingsSavePathKindAppExternal;

  /// No description provided for @settingsSavePathKindHintAppDocuments.
  ///
  /// In en, this message translates to:
  /// **'Files are saved in the app documents folder and visible in the Files app'**
  String get settingsSavePathKindHintAppDocuments;

  /// No description provided for @settingsSavePathKindHintAppExternal.
  ///
  /// In en, this message translates to:
  /// **'Files are saved in app-specific external storage and may be removed when app data is cleared'**
  String get settingsSavePathKindHintAppExternal;

  /// No description provided for @settingsSavePathFallbackDialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get settingsSavePathFallbackDialogOk;

  /// No description provided for @settingsSavePathFallbackDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'External save location unavailable'**
  String get settingsSavePathFallbackDialogTitle;

  /// No description provided for @settingsSavePathFallbackDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Some in-car or custom systems block creating folders on external storage. Files are saved to app cache instead.\n\nExpected: {intendedPath}\nCurrent: {currentPath}\nReason: {reason}'**
  String settingsSavePathFallbackDialogBody(
    String intendedPath,
    String currentPath,
    String reason,
  );

  /// No description provided for @settingsChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get settingsChooseFolder;

  /// No description provided for @settingsRestoreDefaultPath.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get settingsRestoreDefaultPath;

  /// No description provided for @settingsGalleryPermissionToast.
  ///
  /// In en, this message translates to:
  /// **'Photo library access is required to save to your gallery. Allow it in system Settings.'**
  String get settingsGalleryPermissionToast;

  /// No description provided for @settingsSaveToGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Save images and videos to gallery'**
  String get settingsSaveToGalleryTitle;

  /// No description provided for @settingsSaveToGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming images and videos are saved to the system gallery automatically'**
  String get settingsSaveToGallerySubtitle;

  /// No description provided for @settingsSaveToGalleryHintBody.
  ///
  /// In en, this message translates to:
  /// **'When enabled, images and videos are saved to the system gallery only — they are not copied to your save folder. In File Manager, these files appear under Cache but not under Save folder.'**
  String get settingsSaveToGalleryHintBody;

  /// No description provided for @settingsWindowsLaunchAtStartupTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get settingsWindowsLaunchAtStartupTitle;

  /// No description provided for @settingsWindowsLaunchAtStartupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start automatically after Windows sign-in and stay hidden in the tray'**
  String get settingsWindowsLaunchAtStartupSubtitle;

  /// No description provided for @settingsWindowsLaunchAtStartupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update launch at startup. Try again later.'**
  String get settingsWindowsLaunchAtStartupFailed;

  /// No description provided for @settingsDeleteCacheAfterSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete cache after saving'**
  String get settingsDeleteCacheAfterSaveTitle;

  /// No description provided for @settingsDeleteCacheAfterSaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the in-app cache copy after the file is saved to your folder'**
  String get settingsDeleteCacheAfterSaveSubtitle;

  /// No description provided for @settingsDeleteCacheAfterSaveHintBody.
  ///
  /// In en, this message translates to:
  /// **'Received file cache copies will be deleted and will not appear in File Manager\'s Cache tab.'**
  String get settingsDeleteCacheAfterSaveHintBody;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Relay messages and files across devices in real time'**
  String get aboutTagline;

  /// No description provided for @settingsVersionWithBuild.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String settingsVersionWithBuild(String version, String buildNumber);

  /// No description provided for @settingsVersionLoading.
  ///
  /// In en, this message translates to:
  /// **'Version …'**
  String get settingsVersionLoading;

  /// No description provided for @settingsVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Version —'**
  String get settingsVersionUnknown;

  /// No description provided for @settingsNavVersionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get settingsNavVersionHistory;

  /// No description provided for @settingsNavVersionHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View enabled releases'**
  String get settingsNavVersionHistorySubtitle;

  /// No description provided for @settingsNavAppLog.
  ///
  /// In en, this message translates to:
  /// **'App logs'**
  String get settingsNavAppLog;

  /// No description provided for @settingsNavAppLogSubtitleDesktop.
  ///
  /// In en, this message translates to:
  /// **'Manage log files or open the log folder'**
  String get settingsNavAppLogSubtitleDesktop;

  /// No description provided for @settingsNavAppLogSubtitleMobile.
  ///
  /// In en, this message translates to:
  /// **'Manage log files and share'**
  String get settingsNavAppLogSubtitleMobile;

  /// No description provided for @settingsS3StatusConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get settingsS3StatusConfigured;

  /// No description provided for @settingsS3StatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsS3StatusNotConfigured;

  /// No description provided for @settingsS3StatusHosted.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get settingsS3StatusHosted;

  /// No description provided for @settingsS3StatusCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsS3StatusCustom;

  /// No description provided for @settingsCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckUpdate;

  /// No description provided for @desktopUpdateTapCheck.
  ///
  /// In en, this message translates to:
  /// **'Tap to check for updates'**
  String get desktopUpdateTapCheck;

  /// No description provided for @desktopUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get desktopUpdateChecking;

  /// No description provided for @desktopUpdateAvailableUseBanner.
  ///
  /// In en, this message translates to:
  /// **'Update available — use the banner at the top'**
  String get desktopUpdateAvailableUseBanner;

  /// No description provided for @desktopUpdateDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String desktopUpdateDownloadingPercent(String percent);

  /// No description provided for @desktopUpdateReadyRestart.
  ///
  /// In en, this message translates to:
  /// **'Update ready — restart the app'**
  String get desktopUpdateReadyRestart;

  /// No description provided for @desktopUpdateRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restarting…'**
  String get desktopUpdateRestarting;

  /// No description provided for @desktopUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed'**
  String get desktopUpdateCheckFailed;

  /// No description provided for @desktopUpdateNotConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'Desktop updates not configured (missing UpdateConfig)'**
  String get desktopUpdateNotConfiguredHint;

  /// No description provided for @desktopToastUpdateNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Desktop updates not configured'**
  String get desktopToastUpdateNotConfigured;

  /// No description provided for @desktopToastCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get desktopToastCheckFailed;

  /// No description provided for @desktopToastNewVersionUseBanner.
  ///
  /// In en, this message translates to:
  /// **'New version available — use the top banner to download'**
  String get desktopToastNewVersionUseBanner;

  /// No description provided for @desktopToastAlreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get desktopToastAlreadyLatest;

  /// No description provided for @mobileUpdateDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String mobileUpdateDownloadingPercent(String percent);

  /// No description provided for @mobileUpdateDownloadedInstall.
  ///
  /// In en, this message translates to:
  /// **'New version downloaded — tap Install'**
  String get mobileUpdateDownloadedInstall;

  /// No description provided for @appUpdateDownloadProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get appUpdateDownloadProgressTitle;

  /// No description provided for @appUpdateDownloadProgressBackground.
  ///
  /// In en, this message translates to:
  /// **'Background download'**
  String get appUpdateDownloadProgressBackground;

  /// No description provided for @appUpdateDownloadProgressBackgroundToast.
  ///
  /// In en, this message translates to:
  /// **'Download continues in the background. Open Settings — Check for updates to view progress.'**
  String get appUpdateDownloadProgressBackgroundToast;

  /// No description provided for @appUpdateDownloadCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get appUpdateDownloadCompleteTitle;

  /// No description provided for @appUpdateDownloadedVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Target version: {version} (build {build})'**
  String appUpdateDownloadedVersionLabel(String version, String build);

  /// No description provided for @appUpdateDownloadedFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Package file: {fileName}'**
  String appUpdateDownloadedFileLabel(String fileName);

  /// No description provided for @appUpdateDownloadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get appUpdateDownloadRetry;

  /// No description provided for @mobileUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get mobileUpdateInstall;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @updateStatusAlreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get updateStatusAlreadyLatest;

  /// No description provided for @updateStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updateStatusChecking;

  /// No description provided for @updateStatusNewVersion.
  ///
  /// In en, this message translates to:
  /// **'New version {version}'**
  String updateStatusNewVersion(String version);

  /// No description provided for @updateStatusCheckAction.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateStatusCheckAction;

  /// No description provided for @updateStatusDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String updateStatusDownloadingPercent(String percent);

  /// No description provided for @updateStatusDownloadedReady.
  ///
  /// In en, this message translates to:
  /// **'Downloaded — ready to install'**
  String get updateStatusDownloadedReady;

  /// No description provided for @updateStatusCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed'**
  String get updateStatusCheckFailed;

  /// No description provided for @updateStatusPlayManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed by Google Play Store'**
  String get updateStatusPlayManaged;

  /// No description provided for @settingsInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Install failed: {message}'**
  String settingsInstallFailed(String message);

  /// No description provided for @settingsStoragePermissionToast.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to choose a save location'**
  String get settingsStoragePermissionToast;

  /// No description provided for @settingsSavePathNotExistToast.
  ///
  /// In en, this message translates to:
  /// **'The selected path does not exist'**
  String get settingsSavePathNotExistToast;

  /// No description provided for @settingsSavePathUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Save location updated'**
  String get settingsSavePathUpdatedToast;

  /// No description provided for @settingsSavePathFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set save location'**
  String get settingsSavePathFailedToast;

  /// No description provided for @settingsSavePathRestoredToast.
  ///
  /// In en, this message translates to:
  /// **'Save location reset to default'**
  String get settingsSavePathRestoredToast;

  /// No description provided for @settingsSavePathRestoreFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reset save location'**
  String get settingsSavePathRestoreFailedToast;

  /// No description provided for @settingsSavePathSafSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Files are saved here automatically after each transfer'**
  String get settingsSavePathSafSyncHint;

  /// No description provided for @settingsSavePathSafMirrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Save folder'**
  String get settingsSavePathSafMirrorLabel;

  /// No description provided for @settingsSavePathCacheHint.
  ///
  /// In en, this message translates to:
  /// **'App cache (temporary copies; safe to clear)'**
  String get settingsSavePathCacheHint;

  /// No description provided for @settingsSavePathAppReceiveLabel.
  ///
  /// In en, this message translates to:
  /// **'In-app receive folder'**
  String get settingsSavePathAppReceiveLabel;

  /// No description provided for @themeModeFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeFollowSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @chatSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String chatSelectedCount(int count);

  /// No description provided for @chatSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get chatSelectAll;

  /// No description provided for @chatDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get chatDeselectAll;

  /// No description provided for @chatTooltipDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatTooltipDelete;

  /// No description provided for @chatS3RelayTitle.
  ///
  /// In en, this message translates to:
  /// **'S3 cloud relay'**
  String get chatS3RelayTitle;

  /// No description provided for @chatS3StatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get chatS3StatusChecking;

  /// No description provided for @chatS3StatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get chatS3StatusNotConfigured;

  /// No description provided for @chatS3StatusOnlineSendAll.
  ///
  /// In en, this message translates to:
  /// **'Online · send to all devices'**
  String get chatS3StatusOnlineSendAll;

  /// No description provided for @chatS3StatusUnavailableCheck.
  ///
  /// In en, this message translates to:
  /// **'Unavailable · check S3 settings'**
  String get chatS3StatusUnavailableCheck;

  /// No description provided for @chatDeviceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatDeviceOnline;

  /// No description provided for @chatDevicePullOnline.
  ///
  /// In en, this message translates to:
  /// **'Pull available'**
  String get chatDevicePullOnline;

  /// No description provided for @chatDeviceChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get chatDeviceChecking;

  /// No description provided for @chatDeviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatDeviceOffline;

  /// No description provided for @chatHeaderDeviceNumberTooltip.
  ///
  /// In en, this message translates to:
  /// **'Device no.: {code}'**
  String chatHeaderDeviceNumberTooltip(String code);

  /// No description provided for @chatPickDeviceToStart.
  ///
  /// In en, this message translates to:
  /// **'Choose a device to start chatting'**
  String get chatPickDeviceToStart;

  /// No description provided for @chatTooltipBackDeviceList.
  ///
  /// In en, this message translates to:
  /// **'Back to device list'**
  String get chatTooltipBackDeviceList;

  /// No description provided for @chatTooltipS3Settings.
  ///
  /// In en, this message translates to:
  /// **'S3 settings'**
  String get chatTooltipS3Settings;

  /// No description provided for @chatTooltipFileManager.
  ///
  /// In en, this message translates to:
  /// **'File manager'**
  String get chatTooltipFileManager;

  /// No description provided for @chatTooltipSessionSettings.
  ///
  /// In en, this message translates to:
  /// **'Session settings'**
  String get chatTooltipSessionSettings;

  /// No description provided for @chatDropReleaseToAdd.
  ///
  /// In en, this message translates to:
  /// **'Release to add files'**
  String get chatDropReleaseToAdd;

  /// No description provided for @chatMenuMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Multi-select'**
  String get chatMenuMultiSelect;

  /// No description provided for @chatMenuLocalFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local file unavailable'**
  String get chatMenuLocalFileUnavailable;

  /// No description provided for @chatMenuLocalFileUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The file may have been deleted'**
  String get chatMenuLocalFileUnavailableSubtitle;

  /// No description provided for @chatMenuOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get chatMenuOpen;

  /// No description provided for @chatMenuAddToPending.
  ///
  /// In en, this message translates to:
  /// **'Add to outbox'**
  String get chatMenuAddToPending;

  /// No description provided for @chatMenuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get chatMenuShare;

  /// No description provided for @chatMenuSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get chatMenuSaveToGallery;

  /// No description provided for @chatMenuDownloadFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Download from cloud'**
  String get chatMenuDownloadFromCloud;

  /// No description provided for @fileExportSaveToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Save to Downloads'**
  String get fileExportSaveToDownloads;

  /// No description provided for @fileExportSaveToFiles.
  ///
  /// In en, this message translates to:
  /// **'Save to Files'**
  String get fileExportSaveToFiles;

  /// No description provided for @fileExportSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get fileExportSaveAs;

  /// No description provided for @fileExportSavedAs.
  ///
  /// In en, this message translates to:
  /// **'Saved as {name}'**
  String fileExportSavedAs(String name);

  /// No description provided for @fileExportSaveAsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where to save'**
  String get fileExportSaveAsDialogTitle;

  /// No description provided for @fileExportSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads: {name}'**
  String fileExportSavedToDownloads(String name);

  /// No description provided for @fileExportOpenedShareSheet.
  ///
  /// In en, this message translates to:
  /// **'Choose where to save the file'**
  String get fileExportOpenedShareSheet;

  /// No description provided for @fileExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file'**
  String get fileExportFailed;

  /// No description provided for @chatMenuCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get chatMenuCopyText;

  /// No description provided for @chatMenuSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select text'**
  String get chatMenuSelectText;

  /// No description provided for @chatMenuDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatMenuDeleteMessage;

  /// No description provided for @chatGallerySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get chatGallerySaved;

  /// No description provided for @chatGallerySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get chatGallerySaveFailed;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// No description provided for @chatSelectTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Select text'**
  String get chatSelectTextTitle;

  /// No description provided for @chatDeleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessageTitle;

  /// No description provided for @chatDeleteMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Delete this message? Local and cloud copies will be removed.'**
  String get chatDeleteMessageBody;

  /// No description provided for @chatDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteMessageConfirm;

  /// No description provided for @chatFileMissingDeleted.
  ///
  /// In en, this message translates to:
  /// **'File missing; it may have been deleted'**
  String get chatFileMissingDeleted;

  /// No description provided for @chatFileNoLocalOpenPath.
  ///
  /// In en, this message translates to:
  /// **'No local file available to open'**
  String get chatFileNoLocalOpenPath;

  /// No description provided for @devicesRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get devicesRemoveTitle;

  /// No description provided for @devicesRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The account on this device will be signed out. Active sessions end immediately; offline devices will require sign-in next launch.'**
  String get devicesRemoveBody;

  /// No description provided for @devicesRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get devicesRemoveConfirm;

  /// No description provided for @devicesRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'Device removed'**
  String get devicesRemovedToast;

  /// No description provided for @devicesRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove device: {error}'**
  String devicesRemoveFailed(String error);

  /// No description provided for @devicesRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get devicesRenameTitle;

  /// No description provided for @devicesNameHint.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get devicesNameHint;

  /// No description provided for @devicesRenameMenu.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get devicesRenameMenu;

  /// No description provided for @devicesRemoveMenu.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get devicesRemoveMenu;

  /// No description provided for @devicesSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get devicesSavedToast;

  /// No description provided for @devicesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String devicesSaveFailed(String error);

  /// No description provided for @devicesTitle.
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get devicesTitle;

  /// No description provided for @devicesOfflinePrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view and manage bound devices'**
  String get devicesOfflinePrompt;

  /// No description provided for @devicesBoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} bound'**
  String devicesBoundCount(int count);

  /// No description provided for @devicesSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get devicesSyncing;

  /// No description provided for @devicesSubtitleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get devicesSubtitleLoadFailed;

  /// No description provided for @devicesTooltipRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get devicesTooltipRefresh;

  /// No description provided for @devicesLoadFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load: {error}'**
  String devicesLoadFailedDetail(String error);

  /// No description provided for @devicesEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No registered devices yet'**
  String get devicesEmptyList;

  /// No description provided for @devicesCurrentDeviceBadge.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get devicesCurrentDeviceBadge;

  /// No description provided for @fmRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed'**
  String get fmRefreshFailed;

  /// No description provided for @fmListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load files'**
  String get fmListLoadFailed;

  /// No description provided for @fmLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more'**
  String get fmLoadMoreFailed;

  /// No description provided for @fmSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get fmSearchFailed;

  /// No description provided for @fmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get fmDeleteTitle;

  /// No description provided for @fmDeleteConfirmOne.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String fmDeleteConfirmOne(String name);

  /// No description provided for @fmDeleteConfirmMany.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} files?'**
  String fmDeleteConfirmMany(int count);

  /// No description provided for @fmDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get fmDeleteConfirm;

  /// No description provided for @fmAndroidApkOnly.
  ///
  /// In en, this message translates to:
  /// **'APK install is only supported on Android'**
  String get fmAndroidApkOnly;

  /// No description provided for @fmPreviewUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t preview'**
  String get fmPreviewUnavailableTitle;

  /// No description provided for @fmPreviewUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'No preview is available for this file. Open as plain text?'**
  String get fmPreviewUnavailableBody;

  /// No description provided for @fmPreviewOpenAsText.
  ///
  /// In en, this message translates to:
  /// **'Open as text'**
  String get fmPreviewOpenAsText;

  /// No description provided for @fmPendingAddedOne.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\" to outbox'**
  String fmPendingAddedOne(String name);

  /// No description provided for @fmPendingAddedMany.
  ///
  /// In en, this message translates to:
  /// **'Added {count} files to outbox'**
  String fmPendingAddedMany(int count);

  /// No description provided for @fmMultiSelectMode.
  ///
  /// In en, this message translates to:
  /// **'Multi-select mode'**
  String get fmMultiSelectMode;

  /// No description provided for @fmToolbarTitle.
  ///
  /// In en, this message translates to:
  /// **'File Manager'**
  String get fmToolbarTitle;

  /// No description provided for @fmHintTitle.
  ///
  /// In en, this message translates to:
  /// **'About file manager'**
  String get fmHintTitle;

  /// No description provided for @fmHintTooltip.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get fmHintTooltip;

  /// No description provided for @fmTabCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get fmTabCache;

  /// No description provided for @fmTabSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Save folder'**
  String get fmTabSaveFolder;

  /// No description provided for @fmSaveFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Save folder is empty'**
  String get fmSaveFolderEmpty;

  /// No description provided for @fmSaveFolderNotAccessible.
  ///
  /// In en, this message translates to:
  /// **'Cannot read save folder'**
  String get fmSaveFolderNotAccessible;

  /// No description provided for @fmSaveFolderPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied — re-select save location in Settings'**
  String get fmSaveFolderPermissionDenied;

  /// No description provided for @fmSaveFolderNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Save location not configured'**
  String get fmSaveFolderNotConfigured;

  /// No description provided for @fmSaveFolderPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Current save location'**
  String get fmSaveFolderPathLabel;

  /// No description provided for @fmSaveFolderGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get fmSaveFolderGoSettings;

  /// No description provided for @fmSaveFolderHintTitle.
  ///
  /// In en, this message translates to:
  /// **'About save folder'**
  String get fmSaveFolderHintTitle;

  /// No description provided for @fmSaveFolderHintBody.
  ///
  /// In en, this message translates to:
  /// **'Shows files received through this app in your selected save folder. Files not received through this app are not listed.'**
  String get fmSaveFolderHintBody;

  /// No description provided for @fmSaveFolderHintBodyDesktop.
  ///
  /// In en, this message translates to:
  /// **'Shows all files in your selected save folder.'**
  String get fmSaveFolderHintBodyDesktop;

  /// No description provided for @fmSaveFolderHintOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get fmSaveFolderHintOk;

  /// No description provided for @fmSaveFolderErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'{reason}'**
  String fmSaveFolderErrorDetail(String reason);

  /// No description provided for @fmCacheHintTitle.
  ///
  /// In en, this message translates to:
  /// **'About cache'**
  String get fmCacheHintTitle;

  /// No description provided for @fmCacheHintOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get fmCacheHintOk;

  /// No description provided for @fmCachePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Cache folder'**
  String get fmCachePathLabel;

  /// No description provided for @fmCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When receiving files, content is saved to the app cache first, then exported to your save folder. The cache is only a local copy — clearing it manually will not affect files already saved.\n\nIf \"Delete cache after saving\" is enabled in Settings, each cache copy is removed immediately after a successful export.'**
  String get fmCacheSubtitle;

  /// No description provided for @fmExportStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get fmExportStatusPending;

  /// No description provided for @fmExportStatusExporting.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get fmExportStatusExporting;

  /// No description provided for @fmExportStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get fmExportStatusDone;

  /// No description provided for @fmExportStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get fmExportStatusFailed;

  /// No description provided for @fmExportRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get fmExportRetry;

  /// No description provided for @fmClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get fmClearCache;

  /// No description provided for @fmClearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get fmClearCacheTitle;

  /// No description provided for @fmClearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'All files in the app cache will be deleted. Files already saved to your save folder are not affected.'**
  String get fmClearCacheConfirm;

  /// No description provided for @fmClearCacheDone.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get fmClearCacheDone;

  /// No description provided for @fmClearCacheFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear cache'**
  String get fmClearCacheFailed;

  /// No description provided for @fmSearchCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get fmSearchCloseTooltip;

  /// No description provided for @fmSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get fmSearchTooltip;

  /// No description provided for @fmSortCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Category view'**
  String get fmSortCategoryTooltip;

  /// No description provided for @fmSortTimeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort by time'**
  String get fmSortTimeTooltip;

  /// No description provided for @fmSortMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get fmSortMenuTooltip;

  /// No description provided for @fmSortByCreated.
  ///
  /// In en, this message translates to:
  /// **'By date created'**
  String get fmSortByCreated;

  /// No description provided for @fmSortByModified.
  ///
  /// In en, this message translates to:
  /// **'By date modified'**
  String get fmSortByModified;

  /// No description provided for @fmSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search file name…'**
  String get fmSearchHint;

  /// No description provided for @fmEmptyNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get fmEmptyNoMatch;

  /// No description provided for @fmEmptyNoReceived.
  ///
  /// In en, this message translates to:
  /// **'No received files yet'**
  String get fmEmptyNoReceived;

  /// No description provided for @fmSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String fmSelectedCount(int count);

  /// No description provided for @fmTooltipShareSelection.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get fmTooltipShareSelection;

  /// No description provided for @fmTooltipAddPending.
  ///
  /// In en, this message translates to:
  /// **'Add to outbox'**
  String get fmTooltipAddPending;

  /// No description provided for @fmRevealInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get fmRevealInFolder;

  /// No description provided for @fmFileInfoAction.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get fmFileInfoAction;

  /// No description provided for @fmFileInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'File info'**
  String get fmFileInfoTitle;

  /// No description provided for @fmFileInfoName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fmFileInfoName;

  /// No description provided for @fmFileInfoPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get fmFileInfoPath;

  /// No description provided for @fmFileInfoSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fmFileInfoSize;

  /// No description provided for @fmFileInfoMd5.
  ///
  /// In en, this message translates to:
  /// **'MD5'**
  String get fmFileInfoMd5;

  /// No description provided for @fmFileInfoReceivedAt.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get fmFileInfoReceivedAt;

  /// No description provided for @fmFileInfoModifiedAt.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get fmFileInfoModifiedAt;

  /// No description provided for @fmFileInfoCategory.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fmFileInfoCategory;

  /// No description provided for @fmFileInfoProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get fmFileInfoProtocol;

  /// No description provided for @fmFileInfoMessageId.
  ///
  /// In en, this message translates to:
  /// **'Message ID'**
  String get fmFileInfoMessageId;

  /// No description provided for @fmFileInfoS3Key.
  ///
  /// In en, this message translates to:
  /// **'S3 key'**
  String get fmFileInfoS3Key;

  /// No description provided for @fmFileInfoFromDevice.
  ///
  /// In en, this message translates to:
  /// **'From device'**
  String get fmFileInfoFromDevice;

  /// No description provided for @fmFileInfoMd5Computing.
  ///
  /// In en, this message translates to:
  /// **'Computing…'**
  String get fmFileInfoMd5Computing;

  /// No description provided for @fmFileInfoMd5Failed.
  ///
  /// In en, this message translates to:
  /// **'Could not compute'**
  String get fmFileInfoMd5Failed;

  /// No description provided for @fmFileInfoFileMissing.
  ///
  /// In en, this message translates to:
  /// **'File not found on disk'**
  String get fmFileInfoFileMissing;

  /// No description provided for @fmCategoryImage.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get fmCategoryImage;

  /// No description provided for @fmCategoryVideo.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get fmCategoryVideo;

  /// No description provided for @fmCategoryAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get fmCategoryAudio;

  /// No description provided for @fmCategoryPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get fmCategoryPdf;

  /// No description provided for @fmCategoryArchive.
  ///
  /// In en, this message translates to:
  /// **'Archives'**
  String get fmCategoryArchive;

  /// No description provided for @fmCategoryDocument.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get fmCategoryDocument;

  /// No description provided for @fmCategoryCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get fmCategoryCode;

  /// No description provided for @fmCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fmCategoryOther;

  /// No description provided for @fmTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get fmTimeJustNow;

  /// No description provided for @fmTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String fmTimeMinutesAgo(int count);

  /// No description provided for @fmTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String fmTimeHoursAgo(int count);

  /// No description provided for @fmTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String fmTimeDaysAgo(int count);

  /// No description provided for @fmTimeMonthDayClock.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} {hour}:{minute}'**
  String fmTimeMonthDayClock(int month, int day, String hour, String minute);

  /// No description provided for @accountScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountScreenTitle;

  /// No description provided for @accountLogoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountLogoutDialogTitle;

  /// No description provided for @accountLogoutDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to use the app. Sign out?'**
  String get accountLogoutDialogBody;

  /// No description provided for @accountLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountLogoutConfirm;

  /// No description provided for @accountChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePassword;

  /// No description provided for @accountDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAccount;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountLogout;

  /// No description provided for @accountPasswordChangedToast.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get accountPasswordChangedToast;

  /// No description provided for @accountChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePasswordTitle;

  /// No description provided for @accountChangePasswordWarning.
  ///
  /// In en, this message translates to:
  /// **'A verification code will be sent to:'**
  String get accountChangePasswordWarning;

  /// No description provided for @accountLabelNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get accountLabelNewPassword;

  /// No description provided for @accountValidationEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get accountValidationEnterNewPassword;

  /// No description provided for @accountValidationNewPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get accountValidationNewPasswordMinLength;

  /// No description provided for @accountLabelConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get accountLabelConfirmNewPassword;

  /// No description provided for @accountValidationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get accountValidationPasswordMismatch;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all data and cannot be undone. A verification code will be sent to:'**
  String get accountDeleteWarning;

  /// No description provided for @accountLabelVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get accountLabelVerificationCode;

  /// No description provided for @accountHintSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get accountHintSixDigitCode;

  /// No description provided for @accountSendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get accountSendingCode;

  /// No description provided for @accountSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get accountSendVerificationCode;

  /// No description provided for @accountDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get accountDeleteForever;

  /// No description provided for @accountValidationEnterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get accountValidationEnterVerificationCode;

  /// No description provided for @versionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get versionHistoryTitle;

  /// No description provided for @versionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No releases yet'**
  String get versionHistoryEmpty;

  /// No description provided for @appLogTitle.
  ///
  /// In en, this message translates to:
  /// **'App logs'**
  String get appLogTitle;

  /// No description provided for @appLogTooltipOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open log folder'**
  String get appLogTooltipOpenFolder;

  /// No description provided for @appLogTooltipRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get appLogTooltipRefresh;

  /// No description provided for @appLogErrorDirUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Log folder unavailable'**
  String get appLogErrorDirUnavailable;

  /// No description provided for @appLogEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No log output yet — use the app and logs will appear here.'**
  String get appLogEmptyHint;

  /// No description provided for @appLogReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read logs: {error}'**
  String appLogReadFailed(String error);

  /// No description provided for @appLogToastDirUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Log folder unavailable'**
  String get appLogToastDirUnavailable;

  /// No description provided for @appLogToastOpenFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open folder'**
  String get appLogToastOpenFolderFailed;

  /// No description provided for @appLogFileMeta.
  ///
  /// In en, this message translates to:
  /// **'{size} · {modified}'**
  String appLogFileMeta(String size, String modified);

  /// No description provided for @appLogTailHintKb.
  ///
  /// In en, this message translates to:
  /// **'Large log file — showing only the last ~{kb} KB'**
  String appLogTailHintKb(int kb);

  /// No description provided for @msgSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String msgSearchFailed(String error);

  /// No description provided for @msgSearchFileFallback.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get msgSearchFileFallback;

  /// No description provided for @msgSearchUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'[ Unknown message ]'**
  String get msgSearchUnknownMessage;

  /// No description provided for @msgSearchYesterdayTime.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String msgSearchYesterdayTime(String time);

  /// No description provided for @msgSearchDeviceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get msgSearchDeviceSystem;

  /// No description provided for @msgSearchCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get msgSearchCopied;

  /// No description provided for @msgSearchDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get msgSearchDeleteTitle;

  /// No description provided for @msgSearchDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete this message? Cloud copies will be removed too.'**
  String get msgSearchDeleteBody;

  /// No description provided for @msgSearchSelectTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Select text'**
  String get msgSearchSelectTextTitle;

  /// No description provided for @msgSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages…'**
  String get msgSearchHint;

  /// No description provided for @msgSearchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search messages'**
  String get msgSearchEmptyHint;

  /// No description provided for @msgSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get msgSearchNoResults;

  /// No description provided for @apkPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose APK'**
  String get apkPickerTitle;

  /// No description provided for @apkPickerTooltipBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get apkPickerTooltipBrowseFiles;

  /// No description provided for @apkPickerConfirmCount.
  ///
  /// In en, this message translates to:
  /// **'Confirm ({count})'**
  String apkPickerConfirmCount(int count);

  /// No description provided for @apkPickerLoadingInstalled.
  ///
  /// In en, this message translates to:
  /// **'Loading installed apps…'**
  String get apkPickerLoadingInstalled;

  /// No description provided for @apkPickerEmptyOrError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load installed apps.\nYou may need to reinstall the app to grant permission.'**
  String get apkPickerEmptyOrError;

  /// No description provided for @apkPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps…'**
  String get apkPickerSearchHint;

  /// No description provided for @apkPickerAppCount.
  ///
  /// In en, this message translates to:
  /// **'{count} apps'**
  String apkPickerAppCount(int count);

  /// No description provided for @apkPickerSystemApp.
  ///
  /// In en, this message translates to:
  /// **'System app'**
  String get apkPickerSystemApp;

  /// No description provided for @apkPickerClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get apkPickerClearSelection;

  /// No description provided for @apkPickerConfirmSendMany.
  ///
  /// In en, this message translates to:
  /// **'Send {count} APK files?'**
  String apkPickerConfirmSendMany(int count);

  /// No description provided for @apkPickerFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Pick APK from files'**
  String get apkPickerFromFiles;

  /// No description provided for @apkPickerReloadApps.
  ///
  /// In en, this message translates to:
  /// **'Reload app list'**
  String get apkPickerReloadApps;

  /// No description provided for @apkPickerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load apps: {error}'**
  String apkPickerLoadFailed(String error);

  /// No description provided for @s3SettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get s3SettingsSaved;

  /// No description provided for @s3SettingsTestOk.
  ///
  /// In en, this message translates to:
  /// **'Connection OK'**
  String get s3SettingsTestOk;

  /// No description provided for @s3SettingsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear configuration'**
  String get s3SettingsClearTitle;

  /// No description provided for @s3SettingsClearBody.
  ///
  /// In en, this message translates to:
  /// **'Clear all fields? This removes S3 settings from the server and local cache.'**
  String get s3SettingsClearBody;

  /// No description provided for @s3SettingsClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get s3SettingsClearConfirm;

  /// No description provided for @s3SettingsCleared.
  ///
  /// In en, this message translates to:
  /// **'Configuration cleared'**
  String get s3SettingsCleared;

  /// No description provided for @s3SettingsLoginExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired — please sign in again'**
  String get s3SettingsLoginExpired;

  /// No description provided for @s3SettingsClearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing…'**
  String get s3SettingsClearing;

  /// No description provided for @s3SettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Configure S3-compatible object storage for wide-area file transfer (AWS S3, MinIO, Alibaba OSS, etc.).'**
  String get s3SettingsIntro;

  /// No description provided for @s3SettingsConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'Configured. Submit again to overwrite.'**
  String get s3SettingsConfiguredHint;

  /// No description provided for @s3SettingsSectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage settings'**
  String get s3SettingsSectionStorage;

  /// No description provided for @s3SettingsRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get s3SettingsRequired;

  /// No description provided for @s3SettingsSecretHintIfConfigured.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep unchanged'**
  String get s3SettingsSecretHintIfConfigured;

  /// No description provided for @s3SettingsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get s3SettingsSaving;

  /// No description provided for @s3SettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get s3SettingsSave;

  /// No description provided for @s3SettingsTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get s3SettingsTesting;

  /// No description provided for @s3SettingsTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get s3SettingsTestConnection;

  /// No description provided for @s3SettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'S3 settings'**
  String get s3SettingsPageTitle;

  /// No description provided for @s3SettingsSectionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection & storage'**
  String get s3SettingsSectionConnection;

  /// No description provided for @s3SettingsSectionCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get s3SettingsSectionCredentials;

  /// No description provided for @s3SettingsFieldEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get s3SettingsFieldEndpoint;

  /// No description provided for @s3SettingsFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get s3SettingsFieldRegion;

  /// No description provided for @s3SettingsFieldBucket.
  ///
  /// In en, this message translates to:
  /// **'Bucket'**
  String get s3SettingsFieldBucket;

  /// No description provided for @s3SettingsFieldPathStyle.
  ///
  /// In en, this message translates to:
  /// **'Path-style access'**
  String get s3SettingsFieldPathStyle;

  /// No description provided for @s3SettingsPathStyleHint.
  ///
  /// In en, this message translates to:
  /// **'Usually required for MinIO and self-hosted gateways. Turn off for AWS regional endpoints to use virtual-hosted URLs.'**
  String get s3SettingsPathStyleHint;

  /// No description provided for @s3SettingsFieldAccessKeyId.
  ///
  /// In en, this message translates to:
  /// **'Access Key ID'**
  String get s3SettingsFieldAccessKeyId;

  /// No description provided for @s3SettingsFieldSecretAccessKey.
  ///
  /// In en, this message translates to:
  /// **'Secret Access Key'**
  String get s3SettingsFieldSecretAccessKey;

  /// No description provided for @s3SettingsPlaceholderEndpoint.
  ///
  /// In en, this message translates to:
  /// **'https://s3.amazonaws.com'**
  String get s3SettingsPlaceholderEndpoint;

  /// No description provided for @s3SettingsPlaceholderRegion.
  ///
  /// In en, this message translates to:
  /// **'cn-east-1'**
  String get s3SettingsPlaceholderRegion;

  /// No description provided for @s3SettingsPlaceholderBucket.
  ///
  /// In en, this message translates to:
  /// **'my-bucket'**
  String get s3SettingsPlaceholderBucket;

  /// No description provided for @s3SettingsPlaceholderAccessKeyId.
  ///
  /// In en, this message translates to:
  /// **'AKIAIOSFODNN7EXAMPLE'**
  String get s3SettingsPlaceholderAccessKeyId;

  /// No description provided for @s3SettingsConfiguredSummary.
  ///
  /// In en, this message translates to:
  /// **'{endpoint} · {bucket}'**
  String s3SettingsConfiguredSummary(String endpoint, String bucket);

  /// No description provided for @s3SettingsHostedTitle.
  ///
  /// In en, this message translates to:
  /// **'Using built-in S3'**
  String get s3SettingsHostedTitle;

  /// No description provided for @s3SettingsHostedBody.
  ///
  /// In en, this message translates to:
  /// **'Platform-managed object storage. No configuration required — wide-area transfers are ready out of the box.'**
  String get s3SettingsHostedBody;

  /// No description provided for @s3SettingsHostedUsageLabel.
  ///
  /// In en, this message translates to:
  /// **'Used this month'**
  String get s3SettingsHostedUsageLabel;

  /// No description provided for @s3SettingsHostedUsageMonthly.
  ///
  /// In en, this message translates to:
  /// **'{used} / {quota}'**
  String s3SettingsHostedUsageMonthly(String used, String quota);

  /// No description provided for @s3SettingsHostedUsageMonthlyUnlimited.
  ///
  /// In en, this message translates to:
  /// **'{used} (unlimited)'**
  String s3SettingsHostedUsageMonthlyUnlimited(String used);

  /// No description provided for @s3SettingsHostedUsageHint.
  ///
  /// In en, this message translates to:
  /// **'Counted in UTC calendar months and reset on the 1st. Upgrade your membership for a larger quota.'**
  String get s3SettingsHostedUsageHint;

  /// No description provided for @s3SettingsCustomConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'Switched to custom S3. All uploads/downloads will go through your own bucket.'**
  String get s3SettingsCustomConfiguredHint;

  /// No description provided for @s3SettingsDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'S3 is not enabled yet. Fill in your S3 configuration to enable wide-area transfers.'**
  String get s3SettingsDisabledHint;

  /// No description provided for @s3SettingsSwitchToCustom.
  ///
  /// In en, this message translates to:
  /// **'Switch to custom S3'**
  String get s3SettingsSwitchToCustom;

  /// No description provided for @s3SettingsCollapseCustomForm.
  ///
  /// In en, this message translates to:
  /// **'Cancel and keep built-in S3'**
  String get s3SettingsCollapseCustomForm;

  /// No description provided for @s3SettingsSwitchBackToHosted.
  ///
  /// In en, this message translates to:
  /// **'Switch back to built-in S3'**
  String get s3SettingsSwitchBackToHosted;

  /// No description provided for @s3SettingsSwitchBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch back to built-in S3?'**
  String get s3SettingsSwitchBackTitle;

  /// No description provided for @s3SettingsSwitchBackBody.
  ///
  /// In en, this message translates to:
  /// **'After switching back, all uploads/downloads will use the built-in S3. Your saved custom S3 configuration will be kept on file so you can switch back to it any time.'**
  String get s3SettingsSwitchBackBody;

  /// No description provided for @s3SettingsUseSavedCustom.
  ///
  /// In en, this message translates to:
  /// **'Use saved custom S3'**
  String get s3SettingsUseSavedCustom;

  /// No description provided for @s3SettingsSwitchedToCustomOk.
  ///
  /// In en, this message translates to:
  /// **'Switched to custom S3'**
  String get s3SettingsSwitchedToCustomOk;

  /// No description provided for @s3SettingsSwitchBackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch back'**
  String get s3SettingsSwitchBackConfirm;

  /// No description provided for @s3SettingsSwitchedBackOk.
  ///
  /// In en, this message translates to:
  /// **'Switched back to built-in S3'**
  String get s3SettingsSwitchedBackOk;

  /// No description provided for @s3SettingsSwitching.
  ///
  /// In en, this message translates to:
  /// **'Switching…'**
  String get s3SettingsSwitching;

  /// No description provided for @s3SettingsDocsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Setup guide (incl. CORS)'**
  String get s3SettingsDocsTooltip;

  /// No description provided for @s3SettingsDocsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No documentation link available'**
  String get s3SettingsDocsUnavailable;

  /// No description provided for @sendModeNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get sendModeNearby;

  /// No description provided for @linkRoutesTitleRetest.
  ///
  /// In en, this message translates to:
  /// **'Retest connection'**
  String get linkRoutesTitleRetest;

  /// No description provided for @linkRoutesTitleSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch route'**
  String get linkRoutesTitleSwitch;

  /// No description provided for @linkRoutesPeerSession.
  ///
  /// In en, this message translates to:
  /// **'Session device: {label}'**
  String linkRoutesPeerSession(String label);

  /// No description provided for @linkRoutesBodyRetest.
  ///
  /// In en, this message translates to:
  /// **'We\'ll retest the current route. Available routes and estimated speeds are shown below.'**
  String get linkRoutesBodyRetest;

  /// No description provided for @linkRoutesBodySwitch.
  ///
  /// In en, this message translates to:
  /// **'Switching to {mode} and starting detection. Available routes and estimated speeds are shown below.'**
  String linkRoutesBodySwitch(String mode);

  /// No description provided for @linkRoutesTagAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get linkRoutesTagAvailable;

  /// No description provided for @linkRoutesTagUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get linkRoutesTagUnavailable;

  /// No description provided for @linkRoutesTagCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get linkRoutesTagCurrent;

  /// No description provided for @linkRoutesTagTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get linkRoutesTagTarget;

  /// No description provided for @linkRoutesSpeedLine.
  ///
  /// In en, this message translates to:
  /// **'Estimated speed: {tier} · {desc}'**
  String linkRoutesSpeedLine(String tier, String desc);

  /// No description provided for @linkRoutesWaitingResult.
  ///
  /// In en, this message translates to:
  /// **'Waiting for detection…'**
  String get linkRoutesWaitingResult;

  /// No description provided for @linkRoutesRetest.
  ///
  /// In en, this message translates to:
  /// **'Retest'**
  String get linkRoutesRetest;

  /// No description provided for @linkRoutesSwitchAndDetect.
  ///
  /// In en, this message translates to:
  /// **'Switch & detect'**
  String get linkRoutesSwitchAndDetect;

  /// No description provided for @linkRoutesPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose route'**
  String get linkRoutesPickerTitle;

  /// No description provided for @linkRoutesPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Selecting a route switches immediately and starts detection.'**
  String get linkRoutesPickerHint;

  /// No description provided for @linkSpeedNearbyTier.
  ///
  /// In en, this message translates to:
  /// **'Medium–high'**
  String get linkSpeedNearbyTier;

  /// No description provided for @linkSpeedNearbyDesc.
  ///
  /// In en, this message translates to:
  /// **'Same-subnet direct link; speed depends on LAN quality.'**
  String get linkSpeedNearbyDesc;

  /// No description provided for @linkSpeedLanTier.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get linkSpeedLanTier;

  /// No description provided for @linkSpeedLanDesc.
  ///
  /// In en, this message translates to:
  /// **'HTTP direct — usually the fastest path on LAN.'**
  String get linkSpeedLanDesc;

  /// No description provided for @linkSpeedWebrtcTier.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get linkSpeedWebrtcTier;

  /// No description provided for @linkSpeedWebrtcDesc.
  ///
  /// In en, this message translates to:
  /// **'Good NAT traversal; speed varies with NAT and network conditions.'**
  String get linkSpeedWebrtcDesc;

  /// No description provided for @linkSpeedS3Tier.
  ///
  /// In en, this message translates to:
  /// **'Medium–low'**
  String get linkSpeedS3Tier;

  /// No description provided for @linkSpeedS3Desc.
  ///
  /// In en, this message translates to:
  /// **'Relayed via cloud; throughput depends on public network and nodes.'**
  String get linkSpeedS3Desc;

  /// No description provided for @membershipCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get membershipCenterTitle;

  /// No description provided for @membershipLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load membership: {error}'**
  String membershipLoadFailed(String error);

  /// No description provided for @membershipBuyMiniOrProFirst.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to Pro first'**
  String get membershipBuyMiniOrProFirst;

  /// No description provided for @membershipPurchaseSuccessSync.
  ///
  /// In en, this message translates to:
  /// **'Purchase successful — benefits will sync shortly'**
  String get membershipPurchaseSuccessSync;

  /// No description provided for @membershipPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed: {error}'**
  String membershipPurchaseFailed(String error);

  /// No description provided for @membershipPaymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get membershipPaymentCancelled;

  /// No description provided for @membershipPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Confirming payment…'**
  String get membershipPaymentPending;

  /// No description provided for @membershipNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error — try again'**
  String get membershipNetworkError;

  /// No description provided for @membershipOrderPayFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed — try again'**
  String get membershipOrderPayFailed;

  /// No description provided for @membershipCompletePaymentInApp.
  ///
  /// In en, this message translates to:
  /// **'Complete payment and return here — status updates automatically.'**
  String get membershipCompletePaymentInApp;

  /// No description provided for @membershipAlipayAppNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'In-app Alipay isn\'t configured. Pay on desktop or contact an admin to enable the Alipay app.'**
  String get membershipAlipayAppNotConfigured;

  /// No description provided for @membershipOrderCreatedAlipay.
  ///
  /// In en, this message translates to:
  /// **'Order created — complete payment in Alipay'**
  String get membershipOrderCreatedAlipay;

  /// No description provided for @membershipPurchaseSuccessActive.
  ///
  /// In en, this message translates to:
  /// **'Payment successful — membership is active'**
  String get membershipPurchaseSuccessActive;

  /// No description provided for @membershipCurrentTier.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get membershipCurrentTier;

  /// No description provided for @membershipTierSummary.
  ///
  /// In en, this message translates to:
  /// **'{tier} · up to {limit} devices'**
  String membershipTierSummary(String tier, int limit);

  /// No description provided for @membershipBoundDevices.
  ///
  /// In en, this message translates to:
  /// **'{count} devices bound'**
  String membershipBoundDevices(int count);

  /// No description provided for @membershipAddonLine.
  ///
  /// In en, this message translates to:
  /// **'{packs} add-on pack(s) (+{devices} devices)'**
  String membershipAddonLine(int packs, int devices);

  /// No description provided for @membershipSubscriptionRenewsAt.
  ///
  /// In en, this message translates to:
  /// **'Next billing: {date}'**
  String membershipSubscriptionRenewsAt(String date);

  /// No description provided for @membershipSubscriptionEndsAfterCancel.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew is off. Access remains until {date}.'**
  String membershipSubscriptionEndsAfterCancel(String date);

  /// No description provided for @membershipSubscriptionValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Current period ends {date}'**
  String membershipSubscriptionValidUntil(String date);

  /// No description provided for @membershipMigrationCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Lightning Vine migration'**
  String get membershipMigrationCardTitle;

  /// No description provided for @membershipMigrationCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lightning Vine members can migrate to ShrimpSend'**
  String get membershipMigrationCardSubtitle;

  /// No description provided for @membershipDeviceBadgeDevices.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String membershipDeviceBadgeDevices(int count);

  /// No description provided for @membershipDeviceBadgeAddon.
  ///
  /// In en, this message translates to:
  /// **'+{count} devices'**
  String membershipDeviceBadgeAddon(int count);

  /// No description provided for @membershipTierSubtitleAddon.
  ///
  /// In en, this message translates to:
  /// **'+5 devices per pack — buy multiple'**
  String get membershipTierSubtitleAddon;

  /// No description provided for @membershipTierSubtitleBuyout.
  ///
  /// In en, this message translates to:
  /// **'Lifetime membership'**
  String get membershipTierSubtitleBuyout;

  /// No description provided for @membershipCannotBuyLowerTier.
  ///
  /// In en, this message translates to:
  /// **'Can\'t purchase this tier or lower'**
  String get membershipCannotBuyLowerTier;

  /// No description provided for @membershipUpgradeDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due: ¥{amount}'**
  String membershipUpgradeDue(String amount);

  /// No description provided for @membershipNeedMiniProFirst.
  ///
  /// In en, this message translates to:
  /// **'Pro membership required first'**
  String get membershipNeedMiniProFirst;

  /// No description provided for @membershipPurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing…'**
  String get membershipPurchasing;

  /// No description provided for @membershipWaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment…'**
  String get membershipWaitingPayment;

  /// No description provided for @membershipPleaseSubscribeFirst.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to Pro first'**
  String get membershipPleaseSubscribeFirst;

  /// No description provided for @membershipBuyApple.
  ///
  /// In en, this message translates to:
  /// **'Buy with Apple'**
  String get membershipBuyApple;

  /// No description provided for @membershipBuyAlipay.
  ///
  /// In en, this message translates to:
  /// **'Pay with Alipay'**
  String get membershipBuyAlipay;

  /// No description provided for @membershipBillingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get membershipBillingMonthly;

  /// No description provided for @membershipBillingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get membershipBillingYearly;

  /// No description provided for @membershipPlanYearlySave.
  ///
  /// In en, this message translates to:
  /// **'~{pct}% off vs monthly'**
  String membershipPlanYearlySave(int pct);

  /// No description provided for @membershipSavingsVsMonthlyYear.
  ///
  /// In en, this message translates to:
  /// **'Save up to {pct}% vs paying monthly for a year'**
  String membershipSavingsVsMonthlyYear(int pct);

  /// No description provided for @membershipPricePerMonthEquiv.
  ///
  /// In en, this message translates to:
  /// **'~{price}/mo billed yearly'**
  String membershipPricePerMonthEquiv(String price);

  /// No description provided for @membershipPricePerYear.
  ///
  /// In en, this message translates to:
  /// **'{price}/yr'**
  String membershipPricePerYear(String price);

  /// No description provided for @membershipPricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String membershipPricePerMonth(String price);

  /// No description provided for @membershipFeatureDevices.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} linked devices'**
  String membershipFeatureDevices(int count);

  /// No description provided for @membershipFeatureUploadHosted.
  ///
  /// In en, this message translates to:
  /// **'{gib} GiB / month hosted upload quota'**
  String membershipFeatureUploadHosted(int gib);

  /// No description provided for @membershipPlanPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get membershipPlanPopular;

  /// No description provided for @membershipOverseasNoAlipay.
  ///
  /// In en, this message translates to:
  /// **'Overseas builds don’t support Alipay — subscribe in the app.'**
  String get membershipOverseasNoAlipay;

  /// No description provided for @membershipSubscribeInApp.
  ///
  /// In en, this message translates to:
  /// **'Subscribe in app'**
  String get membershipSubscribeInApp;

  /// No description provided for @membershipRcUnavailable.
  ///
  /// In en, this message translates to:
  /// **'In-app purchase isn’t available. Check your connection and try again.'**
  String get membershipRcUnavailable;

  /// No description provided for @membershipTierSubtitleSubscription.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically — cancel anytime in the store.'**
  String get membershipTierSubtitleSubscription;

  /// No description provided for @membershipOverseasSubscribeHint.
  ///
  /// In en, this message translates to:
  /// **'Subscribe via the App Store or Google Play. Secure checkout.'**
  String get membershipOverseasSubscribeHint;

  /// No description provided for @membershipOverseasSubscribeHintIos.
  ///
  /// In en, this message translates to:
  /// **'Subscribe via the App Store. Secure checkout.'**
  String get membershipOverseasSubscribeHintIos;

  /// No description provided for @membershipChannelLockedOtherPlatform.
  ///
  /// In en, this message translates to:
  /// **'Your subscription was purchased on another platform. Manage it on the device where you subscribed.'**
  String get membershipChannelLockedOtherPlatform;

  /// No description provided for @membershipChannelLockedStripe.
  ///
  /// In en, this message translates to:
  /// **'Your membership is billed via Stripe on the web. Please upgrade or manage it from the web to avoid duplicate charges.'**
  String get membershipChannelLockedStripe;

  /// No description provided for @membershipChannelLockedAppStore.
  ///
  /// In en, this message translates to:
  /// **'Your membership is billed via the App Store. Manage or upgrade it on your iPhone/iPad in Settings → Apple ID → Subscriptions.'**
  String get membershipChannelLockedAppStore;

  /// No description provided for @membershipChannelLockedPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Your membership is billed via Google Play. Manage or upgrade it in the Play Store under Account → Subscriptions.'**
  String get membershipChannelLockedPlayStore;

  /// No description provided for @membershipChannelLifetime.
  ///
  /// In en, this message translates to:
  /// **'You already have a lifetime membership — no further subscription upgrade is needed.'**
  String get membershipChannelLifetime;

  /// No description provided for @membershipManageStripe.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription (web)'**
  String get membershipManageStripe;

  /// No description provided for @membershipManageStripeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open subscription management. Please try again.'**
  String get membershipManageStripeFailed;

  /// No description provided for @membershipRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get membershipRestorePurchases;

  /// No description provided for @membershipRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored — benefits will sync shortly'**
  String get membershipRestoreSuccess;

  /// No description provided for @membershipRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String membershipRestoreFailed(String error);

  /// No description provided for @membershipOpenAppStoreSubs.
  ///
  /// In en, this message translates to:
  /// **'Open App Store subscriptions'**
  String get membershipOpenAppStoreSubs;

  /// No description provided for @membershipOpenPlayStoreSubs.
  ///
  /// In en, this message translates to:
  /// **'Open Play Store subscriptions'**
  String get membershipOpenPlayStoreSubs;

  /// No description provided for @membershipStripePriceMissing.
  ///
  /// In en, this message translates to:
  /// **'Stripe Price not configured. Please contact admin or subscribe on another platform.'**
  String get membershipStripePriceMissing;

  /// No description provided for @membershipStripeCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create Stripe checkout session. Please try again.'**
  String get membershipStripeCheckoutFailed;

  /// No description provided for @membershipOpenBrowserToPay.
  ///
  /// In en, this message translates to:
  /// **'Opening your browser to complete payment. Return to the app once you\'re done.'**
  String get membershipOpenBrowserToPay;

  /// No description provided for @membershipUpgradeStripeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upgrade successful. Your membership has been updated.'**
  String get membershipUpgradeStripeSuccess;

  /// No description provided for @membershipSubscribeStripe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe with Stripe'**
  String get membershipSubscribeStripe;

  /// No description provided for @membershipUpgradeStripe.
  ///
  /// In en, this message translates to:
  /// **'Upgrade with Stripe'**
  String get membershipUpgradeStripe;

  /// No description provided for @membershipOpeningStripe.
  ///
  /// In en, this message translates to:
  /// **'Opening Stripe…'**
  String get membershipOpeningStripe;

  /// No description provided for @membershipMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Lightning Vine migration'**
  String get membershipMigrationTitle;

  /// No description provided for @membershipMigrationConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm migration'**
  String get membershipMigrationConfirmTitle;

  /// No description provided for @membershipMigrationConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Verification succeeded.\n\nYou\'ll receive {tier} membership with up to {limit} devices.\n\nConfirm migration?'**
  String membershipMigrationConfirmBody(String tier, int limit);

  /// No description provided for @membershipMigrationConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm migration'**
  String get membershipMigrationConfirmAction;

  /// No description provided for @membershipMigrationEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number first'**
  String get membershipMigrationEnterPhone;

  /// No description provided for @membershipMigrationInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get membershipMigrationInvalidPhone;

  /// No description provided for @membershipMigrationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get membershipMigrationCodeSent;

  /// No description provided for @membershipMigrationEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get membershipMigrationEnterCode;

  /// No description provided for @membershipMigrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Migration successful!'**
  String get membershipMigrationSuccess;

  /// No description provided for @membershipMigrationIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration guide'**
  String get membershipMigrationIntroTitle;

  /// No description provided for @membershipMigrationIntroBody.
  ///
  /// In en, this message translates to:
  /// **'If you\'re a Lightning Vine member, verify your phone to migrate membership to ShrimpSend.\n\nAfter migration you\'ll get ShrimpSend Pro (12 devices).'**
  String get membershipMigrationIntroBody;

  /// No description provided for @membershipMigrationPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get membershipMigrationPhoneLabel;

  /// No description provided for @membershipMigrationPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get membershipMigrationPhoneHint;

  /// No description provided for @membershipMigrationCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get membershipMigrationCodeLabel;

  /// No description provided for @membershipMigrationVerifyAndMigrate.
  ///
  /// In en, this message translates to:
  /// **'Verify & migrate'**
  String get membershipMigrationVerifyAndMigrate;

  /// No description provided for @membershipMigrationSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get membershipMigrationSending;

  /// No description provided for @membershipMigrationSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get membershipMigrationSendCode;

  /// No description provided for @connectionBarGoToS3Setup.
  ///
  /// In en, this message translates to:
  /// **'Configure S3'**
  String get connectionBarGoToS3Setup;

  /// No description provided for @connectionBarManualPrefix.
  ///
  /// In en, this message translates to:
  /// **'Manual · '**
  String get connectionBarManualPrefix;

  /// No description provided for @chatProbeDetecting.
  ///
  /// In en, this message translates to:
  /// **'{mode} · detecting…'**
  String chatProbeDetecting(String mode);

  /// No description provided for @chatProbeAvailable.
  ///
  /// In en, this message translates to:
  /// **'{mode} · available'**
  String chatProbeAvailable(String mode);

  /// No description provided for @chatProbeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{mode} · unavailable'**
  String chatProbeUnavailable(String mode);

  /// No description provided for @chatProbeTriggered.
  ///
  /// In en, this message translates to:
  /// **'{mode} · probe requested'**
  String chatProbeTriggered(String mode);

  /// No description provided for @chatProbeUnverifiedAttemptable.
  ///
  /// In en, this message translates to:
  /// **'{mode} unverified — you can still try'**
  String chatProbeUnverifiedAttemptable(String mode);

  /// No description provided for @connectionOrchestratorHttpUnverifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Link unverified — will try direct or reverse pull'**
  String get connectionOrchestratorHttpUnverifiedSubtitle;

  /// No description provided for @connectionOrchestratorManualOk.
  ///
  /// In en, this message translates to:
  /// **'Manual · {mode}'**
  String connectionOrchestratorManualOk(String mode);

  /// No description provided for @connectionOrchestratorManualUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Manual · {mode} unavailable'**
  String connectionOrchestratorManualUnavailable(String mode);

  /// No description provided for @connectionOrchestratorLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current route unavailable'**
  String get connectionOrchestratorLinkUnavailable;

  /// No description provided for @connectionOrchestratorAutoS3.
  ///
  /// In en, this message translates to:
  /// **'Auto · S3'**
  String get connectionOrchestratorAutoS3;

  /// No description provided for @connectionOrchestratorS3FallbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Direct connection failed — using cloud relay'**
  String get connectionOrchestratorS3FallbackSubtitle;

  /// No description provided for @connectionOrchestratorAutoMode.
  ///
  /// In en, this message translates to:
  /// **'Auto · {mode}'**
  String connectionOrchestratorAutoMode(String mode);

  /// No description provided for @connectionOrchestratorNoDirect.
  ///
  /// In en, this message translates to:
  /// **'No direct connection'**
  String get connectionOrchestratorNoDirect;

  /// No description provided for @connectionOrchestratorLoginPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use HTTP, WebRTC, or S3'**
  String get connectionOrchestratorLoginPromptSubtitle;

  /// No description provided for @connectionOrchestratorNoDirectS3Fallback.
  ///
  /// In en, this message translates to:
  /// **'No direct connection — fallback active'**
  String get connectionOrchestratorNoDirectS3Fallback;

  /// No description provided for @connectionOrchestratorS3Unavailable.
  ///
  /// In en, this message translates to:
  /// **'S3 unavailable'**
  String get connectionOrchestratorS3Unavailable;

  /// No description provided for @connectionOrchestratorS3NotConfigured.
  ///
  /// In en, this message translates to:
  /// **'S3 not configured'**
  String get connectionOrchestratorS3NotConfigured;

  /// No description provided for @membershipMigrationCooldownSeconds.
  ///
  /// In en, this message translates to:
  /// **'Retry in {seconds}s'**
  String membershipMigrationCooldownSeconds(int seconds);

  /// No description provided for @mobileHomeTabConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get mobileHomeTabConnect;

  /// No description provided for @mobileHomeTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get mobileHomeTabFiles;

  /// No description provided for @chatReceivedExportingToast.
  ///
  /// In en, this message translates to:
  /// **'Received {name} — saving to folder…'**
  String chatReceivedExportingToast(String name);

  /// No description provided for @mobileHomeTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mobileHomeTabSettings;

  /// No description provided for @mobileHomePendingOutbox.
  ///
  /// In en, this message translates to:
  /// **'Outbox'**
  String get mobileHomePendingOutbox;

  /// No description provided for @pendingFilesSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get pendingFilesSend;

  /// No description provided for @pendingFilesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get pendingFilesManage;

  /// No description provided for @pendingFilesManageWithCount.
  ///
  /// In en, this message translates to:
  /// **'Manage ({count})'**
  String pendingFilesManageWithCount(int count);

  /// No description provided for @pendingFilesSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files selected'**
  String pendingFilesSelectedCount(int count);

  /// No description provided for @pendingFilesClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get pendingFilesClearAll;

  /// No description provided for @fileSendTitleSingle.
  ///
  /// In en, this message translates to:
  /// **'Send: {name}'**
  String fileSendTitleSingle(String name);

  /// No description provided for @fileSendTitleMany.
  ///
  /// In en, this message translates to:
  /// **'Send: {firstName} ({count} files)'**
  String fileSendTitleMany(String firstName, int count);

  /// No description provided for @fileSendS3Intro.
  ///
  /// In en, this message translates to:
  /// **'Send via S3 cloud relay to all signed-in devices. Works across networks.'**
  String get fileSendS3Intro;

  /// No description provided for @fileSendS3ConfigurePrompt.
  ///
  /// In en, this message translates to:
  /// **'Configure S3 first to use cloud send.'**
  String get fileSendS3ConfigurePrompt;

  /// No description provided for @fileSendResumeSupported.
  ///
  /// In en, this message translates to:
  /// **'Resume supported'**
  String get fileSendResumeSupported;

  /// No description provided for @fileSendResumeNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Resume not supported'**
  String get fileSendResumeNotSupported;

  /// No description provided for @fileSendStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get fileSendStatusChecking;

  /// No description provided for @fileSendLanStatusOnlineDirect.
  ///
  /// In en, this message translates to:
  /// **'Online · direct'**
  String get fileSendLanStatusOnlineDirect;

  /// No description provided for @fileSendLanStatusPullAvailable.
  ///
  /// In en, this message translates to:
  /// **'Reverse pull available'**
  String get fileSendLanStatusPullAvailable;

  /// No description provided for @fileSendLanStatusUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get fileSendLanStatusUnreachable;

  /// No description provided for @fileSendLanStatusOfflineDirect.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get fileSendLanStatusOfflineDirect;

  /// No description provided for @fileSendWebRtcStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get fileSendWebRtcStatusOnline;

  /// No description provided for @fileSendWebRtcStatusConnectable.
  ///
  /// In en, this message translates to:
  /// **'Can connect'**
  String get fileSendWebRtcStatusConnectable;

  /// No description provided for @fileSendWebRtcStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get fileSendWebRtcStatusOffline;

  /// No description provided for @fileSendWebRtcIntro.
  ///
  /// In en, this message translates to:
  /// **'WebRTC sends peer-to-peer without routing through servers. Falls back to S3 if the connection fails.'**
  String get fileSendWebRtcIntro;

  /// No description provided for @fileSendWebRtcEmptyNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No other devices found.'**
  String get fileSendWebRtcEmptyNoDevices;

  /// No description provided for @fileSendEmptyNearbyOffline.
  ///
  /// In en, this message translates to:
  /// **'No other devices found. Make sure devices are on the same LAN.'**
  String get fileSendEmptyNearbyOffline;

  /// No description provided for @fileSendEmptyMyDevicesOnLan.
  ///
  /// In en, this message translates to:
  /// **'No \"My devices\" on the LAN.'**
  String get fileSendEmptyMyDevicesOnLan;

  /// No description provided for @fileSendSendToSelected.
  ///
  /// In en, this message translates to:
  /// **'Send to selected devices'**
  String get fileSendSendToSelected;

  /// No description provided for @fileSendViaWebRtc.
  ///
  /// In en, this message translates to:
  /// **'Send via WebRTC'**
  String get fileSendViaWebRtc;

  /// No description provided for @fileSendConfigureS3First.
  ///
  /// In en, this message translates to:
  /// **'Configure S3 first'**
  String get fileSendConfigureS3First;

  /// No description provided for @fileSendToAllDevices.
  ///
  /// In en, this message translates to:
  /// **'Send to all devices'**
  String get fileSendToAllDevices;

  /// No description provided for @fileSendTabMyDevices.
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get fileSendTabMyDevices;

  /// No description provided for @fileSendTabWebRtc.
  ///
  /// In en, this message translates to:
  /// **'WebRTC'**
  String get fileSendTabWebRtc;

  /// No description provided for @devicePanelStatusServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get devicePanelStatusServerUnreachable;

  /// No description provided for @devicePanelStatusValidating.
  ///
  /// In en, this message translates to:
  /// **'Verifying sign-in…'**
  String get devicePanelStatusValidating;

  /// No description provided for @devicePanelStatusSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get devicePanelStatusSessionExpired;

  /// No description provided for @devicePanelStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get devicePanelStatusConnected;

  /// No description provided for @devicePanelStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get devicePanelStatusConnecting;

  /// No description provided for @devicePanelEmptyNoOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'No other devices yet'**
  String get devicePanelEmptyNoOtherDevices;

  /// No description provided for @devicePanelEmptyHintOfflineLan.
  ///
  /// In en, this message translates to:
  /// **'Make sure other devices are on the same LAN to transfer.'**
  String get devicePanelEmptyHintOfflineLan;

  /// No description provided for @devicePanelEmptyHintOnlineAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in on your other devices with the same account to start transferring.'**
  String get devicePanelEmptyHintOnlineAccount;

  /// No description provided for @devicePanelDevicesOnlineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String devicePanelDevicesOnlineCount(int count);

  /// No description provided for @connectionBarDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get connectionBarDefaultTitle;

  /// No description provided for @connectionBarManualShort.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get connectionBarManualShort;

  /// No description provided for @connectionBarAutoShort.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get connectionBarAutoShort;

  /// No description provided for @connectionBarResumeAuto.
  ///
  /// In en, this message translates to:
  /// **'Resume auto'**
  String get connectionBarResumeAuto;

  /// No description provided for @connectionBarSwitchMode.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get connectionBarSwitchMode;

  /// No description provided for @connectionBarRefreshOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh online status'**
  String get connectionBarRefreshOnlineStatus;

  /// No description provided for @transportModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transportModeLabel;

  /// No description provided for @transportModeHttpLan.
  ///
  /// In en, this message translates to:
  /// **'HTTP LAN direct'**
  String get transportModeHttpLan;

  /// No description provided for @transportModeWebrtcLan.
  ///
  /// In en, this message translates to:
  /// **'WebRTC LAN direct'**
  String get transportModeWebrtcLan;

  /// No description provided for @connectionDiagTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection diagnostic'**
  String get connectionDiagTitle;

  /// No description provided for @connectionDiagSubtitleRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing connection to {peer}…'**
  String connectionDiagSubtitleRunning(String peer);

  /// No description provided for @connectionDiagSubtitleDone.
  ///
  /// In en, this message translates to:
  /// **'Connection test to {peer} complete'**
  String connectionDiagSubtitleDone(String peer);

  /// No description provided for @connectionDiagContinueInBackground.
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get connectionDiagContinueInBackground;

  /// No description provided for @connectionDiagDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get connectionDiagDone;

  /// No description provided for @connectionDiagStepS3.
  ///
  /// In en, this message translates to:
  /// **'S3 cloud'**
  String get connectionDiagStepS3;

  /// No description provided for @connectionDiagStepHttpDirect.
  ///
  /// In en, this message translates to:
  /// **'HTTP LAN direct'**
  String get connectionDiagStepHttpDirect;

  /// No description provided for @connectionDiagStepHttpSignaling.
  ///
  /// In en, this message translates to:
  /// **'HTTP signaling'**
  String get connectionDiagStepHttpSignaling;

  /// No description provided for @connectionDiagStepHttpPull.
  ///
  /// In en, this message translates to:
  /// **'HTTP reverse pull'**
  String get connectionDiagStepHttpPull;

  /// No description provided for @connectionDiagStepWebrtc.
  ///
  /// In en, this message translates to:
  /// **'WebRTC connectivity'**
  String get connectionDiagStepWebrtc;

  /// No description provided for @connectionDiagStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get connectionDiagStatusPending;

  /// No description provided for @connectionDiagStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get connectionDiagStatusRunning;

  /// No description provided for @connectionDiagStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get connectionDiagStatusSuccess;

  /// No description provided for @connectionDiagStatusFailure.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get connectionDiagStatusFailure;

  /// No description provided for @connectionDiagStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get connectionDiagStatusSkipped;

  /// No description provided for @connectionDiagReasonS3Online.
  ///
  /// In en, this message translates to:
  /// **'S3 configured and cloud reachable'**
  String get connectionDiagReasonS3Online;

  /// No description provided for @connectionDiagReasonS3NotConfigured.
  ///
  /// In en, this message translates to:
  /// **'S3 not configured'**
  String get connectionDiagReasonS3NotConfigured;

  /// No description provided for @connectionDiagReasonS3Unavailable.
  ///
  /// In en, this message translates to:
  /// **'S3 configured but cloud unreachable'**
  String get connectionDiagReasonS3Unavailable;

  /// No description provided for @connectionDiagReasonHttpDirectOk.
  ///
  /// In en, this message translates to:
  /// **'LAN HTTP direct connection succeeded'**
  String get connectionDiagReasonHttpDirectOk;

  /// No description provided for @connectionDiagReasonHttpDirectFail.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach peer HTTP service (timeout or no response)'**
  String get connectionDiagReasonHttpDirectFail;

  /// No description provided for @connectionDiagReasonHttpSignalingOk.
  ///
  /// In en, this message translates to:
  /// **'Peer HTTP self-check passed'**
  String get connectionDiagReasonHttpSignalingOk;

  /// No description provided for @connectionDiagReasonHttpSignalingFail.
  ///
  /// In en, this message translates to:
  /// **'Signaling probe failed; peer HTTP did not respond'**
  String get connectionDiagReasonHttpSignalingFail;

  /// No description provided for @connectionDiagReasonHttpPullOk.
  ///
  /// In en, this message translates to:
  /// **'Peer can reverse-pull from this device'**
  String get connectionDiagReasonHttpPullOk;

  /// No description provided for @connectionDiagReasonHttpPullFail.
  ///
  /// In en, this message translates to:
  /// **'Reverse pull failed; peer cannot reach local HTTP'**
  String get connectionDiagReasonHttpPullFail;

  /// No description provided for @connectionDiagReasonWebrtcOnline.
  ///
  /// In en, this message translates to:
  /// **'Same network — WebRTC can connect directly'**
  String get connectionDiagReasonWebrtcOnline;

  /// No description provided for @connectionDiagReasonWebrtcConnectable.
  ///
  /// In en, this message translates to:
  /// **'Cross-network — WebRTC may connect via relay'**
  String get connectionDiagReasonWebrtcConnectable;

  /// No description provided for @connectionDiagReasonWebrtcFail.
  ///
  /// In en, this message translates to:
  /// **'WebRTC signaling or ICE unreachable'**
  String get connectionDiagReasonWebrtcFail;

  /// No description provided for @connectionDiagReasonWebrtcSkippedLanOk.
  ///
  /// In en, this message translates to:
  /// **'LAN HTTP already works — WebRTC skipped'**
  String get connectionDiagReasonWebrtcSkippedLanOk;

  /// No description provided for @connectionDiagReasonSkippedLanDirectOk.
  ///
  /// In en, this message translates to:
  /// **'HTTP direct succeeded — skipped'**
  String get connectionDiagReasonSkippedLanDirectOk;

  /// No description provided for @connectionDiagReasonSkippedOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — cloud signaling probes unavailable'**
  String get connectionDiagReasonSkippedOffline;

  /// No description provided for @connectionDiagReasonSkippedPeerOffline.
  ///
  /// In en, this message translates to:
  /// **'Peer offline with no LAN address — skipped'**
  String get connectionDiagReasonSkippedPeerOffline;

  /// No description provided for @connectionDiagReasonHttpDirectNoUrl.
  ///
  /// In en, this message translates to:
  /// **'No LAN address found — cannot test HTTP direct'**
  String get connectionDiagReasonHttpDirectNoUrl;

  /// No description provided for @connectionDiagReasonOfflineCloud.
  ///
  /// In en, this message translates to:
  /// **'Offline — cloud signaling probes unavailable'**
  String get connectionDiagReasonOfflineCloud;

  /// No description provided for @connectionDiagReasonS3LoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in required to test S3'**
  String get connectionDiagReasonS3LoginRequired;

  /// No description provided for @connectionDiagSummaryRecommend.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {mode} ({reason})'**
  String connectionDiagSummaryRecommend(String mode, String reason);

  /// No description provided for @connectionDiagSummaryNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No available transport route found'**
  String get connectionDiagSummaryNoRoute;

  /// No description provided for @connectionDiagElapsed.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} elapsed'**
  String connectionDiagElapsed(String elapsed);

  /// No description provided for @connectionDiagHelpHttpDirectTitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP LAN direct'**
  String get connectionDiagHelpHttpDirectTitle;

  /// No description provided for @connectionDiagHelpHttpDirectBody.
  ///
  /// In en, this message translates to:
  /// **'Your device sends an HTTP GET to the peer\'s LAN address (/probe) without going through the cloud.\n\nThis checks whether a direct HTTP file transfer is possible when the peer\'s LAN URL is known (e.g. via mDNS) and reachable on the local network.'**
  String get connectionDiagHelpHttpDirectBody;

  /// No description provided for @connectionDiagHelpHttpSignalingTitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP signaling'**
  String get connectionDiagHelpHttpSignalingTitle;

  /// No description provided for @connectionDiagHelpHttpSignalingBody.
  ///
  /// In en, this message translates to:
  /// **'A cloud message (Centrifugo) asks the peer to self-check its HTTP service and report back.\n\nThis checks whether the peer\'s HTTP service is healthy when you don\'t yet know its LAN address, as long as both sides are online. The result may also include or update the peer\'s LAN URL.'**
  String get connectionDiagHelpHttpSignalingBody;

  /// No description provided for @connectionDiagHelpHttpPullTitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP reverse pull'**
  String get connectionDiagHelpHttpPullTitle;

  /// No description provided for @connectionDiagHelpHttpPullBody.
  ///
  /// In en, this message translates to:
  /// **'A cloud message asks the peer to try reaching your device\'s HTTP service.\n\nThis checks reverse-pull connectivity when the network is asymmetric (e.g. NAT) and the peer can pull from you even if you cannot push to them directly.'**
  String get connectionDiagHelpHttpPullBody;

  /// No description provided for @connectionDiagHelpWebrtcTitle.
  ///
  /// In en, this message translates to:
  /// **'WebRTC connectivity'**
  String get connectionDiagHelpWebrtcTitle;

  /// No description provided for @connectionDiagHelpWebrtcBody.
  ///
  /// In en, this message translates to:
  /// **'ICE network candidates are exchanged via the cloud to analyze whether both sides are on the same network, can connect P2P, or need a relay.\n\nThis checks whether WebRTC file transfer is viable (often slower than HTTP direct, but can work across networks).'**
  String get connectionDiagHelpWebrtcBody;

  /// No description provided for @connectionDiagHelpS3Title.
  ///
  /// In en, this message translates to:
  /// **'S3 cloud'**
  String get connectionDiagHelpS3Title;

  /// No description provided for @connectionDiagHelpS3Body.
  ///
  /// In en, this message translates to:
  /// **'Verifies that S3 storage is configured for your account and tests cloud reachability.\n\nThis checks whether files can fall back to S3 cloud relay when all LAN/direct paths are unavailable.'**
  String get connectionDiagHelpS3Body;

  /// No description provided for @connectionDiagHelpTooltip.
  ///
  /// In en, this message translates to:
  /// **'How this check works'**
  String get connectionDiagHelpTooltip;

  /// No description provided for @composerPickAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose attachment'**
  String get composerPickAttachmentTitle;

  /// No description provided for @composerAttachImageVideo.
  ///
  /// In en, this message translates to:
  /// **'Photos & videos'**
  String get composerAttachImageVideo;

  /// No description provided for @composerAttachImageVideoDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick photos or videos from your gallery'**
  String get composerAttachImageVideoDesc;

  /// No description provided for @chatGalleryReadPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Photo Library'**
  String get chatGalleryReadPermissionTitle;

  /// No description provided for @chatGalleryReadPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'To pick images or videos, the app needs access to your photo library. We recommend allowing access to all photos and videos.'**
  String get chatGalleryReadPermissionBody;

  /// No description provided for @chatGalleryReadPermissionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get chatGalleryReadPermissionConfirm;

  /// No description provided for @chatGalleryReadPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo library access was not granted. Cannot pick images or videos.'**
  String get chatGalleryReadPermissionDenied;

  /// No description provided for @chatGalleryReadPermissionLimited.
  ///
  /// In en, this message translates to:
  /// **'Only partial photo access is granted. Open Settings to allow access to all photos.'**
  String get chatGalleryReadPermissionLimited;

  /// No description provided for @chatGalleryReadPermissionContinuePartial.
  ///
  /// In en, this message translates to:
  /// **'Continue with limited access'**
  String get chatGalleryReadPermissionContinuePartial;

  /// No description provided for @composerAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get composerAttachFile;

  /// No description provided for @composerAttachFileDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose with the system file picker'**
  String get composerAttachFileDesc;

  /// No description provided for @composerAttachFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get composerAttachFolder;

  /// No description provided for @composerAttachFolderDesc.
  ///
  /// In en, this message translates to:
  /// **'All files in the selected folder'**
  String get composerAttachFolderDesc;

  /// No description provided for @composerAttachApk.
  ///
  /// In en, this message translates to:
  /// **'APK'**
  String get composerAttachApk;

  /// No description provided for @composerAttachApkDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick an APK package from this device'**
  String get composerAttachApkDesc;

  /// No description provided for @composerMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get composerMessageHint;

  /// No description provided for @composerClearInputTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get composerClearInputTooltip;

  /// No description provided for @shortcutsSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get shortcutsSendTitle;

  /// No description provided for @shortcutsSendDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which key sends a message from the input field'**
  String get shortcutsSendDescription;

  /// No description provided for @shortcutsSendEnter.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to send'**
  String get shortcutsSendEnter;

  /// No description provided for @shortcutsSendModifier.
  ///
  /// In en, this message translates to:
  /// **'Press Ctrl+Enter to send'**
  String get shortcutsSendModifier;

  /// No description provided for @shortcutsSendModifierMac.
  ///
  /// In en, this message translates to:
  /// **'Press ⌘+Enter to send'**
  String get shortcutsSendModifierMac;

  /// No description provided for @shortcutsSendButtonHint.
  ///
  /// In en, this message translates to:
  /// **'The send button always works regardless of this setting.'**
  String get shortcutsSendButtonHint;

  /// No description provided for @composerSendTooltipEnter.
  ///
  /// In en, this message translates to:
  /// **'Send (Enter)'**
  String get composerSendTooltipEnter;

  /// No description provided for @composerSendTooltipModifier.
  ///
  /// In en, this message translates to:
  /// **'Send (Ctrl+Enter)'**
  String get composerSendTooltipModifier;

  /// No description provided for @composerSendTooltipModifierMac.
  ///
  /// In en, this message translates to:
  /// **'Send (⌘+Enter)'**
  String get composerSendTooltipModifierMac;

  /// No description provided for @chatTransferSendingPct.
  ///
  /// In en, this message translates to:
  /// **'{fileName} Sending {pct}%'**
  String chatTransferSendingPct(String fileName, int pct);

  /// No description provided for @chatTransferReceivingPct.
  ///
  /// In en, this message translates to:
  /// **'{fileName} Receiving {pct}%'**
  String chatTransferReceivingPct(String fileName, int pct);

  /// No description provided for @chatTransferWaitingPeerLine.
  ///
  /// In en, this message translates to:
  /// **'{fileName} Waiting for peer…'**
  String chatTransferWaitingPeerLine(String fileName);

  /// No description provided for @chatTransferWaitingPeerShort.
  ///
  /// In en, this message translates to:
  /// **'Waiting for peer…'**
  String get chatTransferWaitingPeerShort;

  /// No description provided for @chatTransferCancelledBare.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get chatTransferCancelledBare;

  /// No description provided for @chatTransferCancelledNamed.
  ///
  /// In en, this message translates to:
  /// **'{fileName} cancelled'**
  String chatTransferCancelledNamed(String fileName);

  /// No description provided for @chatTransferSendFailedNamed.
  ///
  /// In en, this message translates to:
  /// **'{fileName} send failed'**
  String chatTransferSendFailedNamed(String fileName);

  /// No description provided for @chatTransferReceiveFailedNamed.
  ///
  /// In en, this message translates to:
  /// **'{fileName} receive failed'**
  String chatTransferReceiveFailedNamed(String fileName);

  /// No description provided for @chatTransferProgressSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get chatTransferProgressSending;

  /// No description provided for @chatTransferProgressReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get chatTransferProgressReceiving;

  /// No description provided for @chatTransferEtaSecondsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s left'**
  String chatTransferEtaSecondsRemaining(int seconds);

  /// No description provided for @chatTransferEtaMinutesSecondsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s left'**
  String chatTransferEtaMinutesSecondsRemaining(int minutes, int seconds);

  /// No description provided for @chatWebRtcSentParen.
  ///
  /// In en, this message translates to:
  /// **'{fileName} (sent via WebRTC)'**
  String chatWebRtcSentParen(String fileName);

  /// No description provided for @chatScreenGenericFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatScreenGenericFile;

  /// No description provided for @chatScreenDeleteThisDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this device'**
  String get chatScreenDeleteThisDeviceTitle;

  /// No description provided for @chatScreenDeleteThisDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'This removes this device from your account and signs you out. Sign in again to use cloud features.'**
  String get chatScreenDeleteThisDeviceBody;

  /// No description provided for @chatScreenRemovePeerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get chatScreenRemovePeerTitle;

  /// No description provided for @chatScreenRemovePeerBody.
  ///
  /// In en, this message translates to:
  /// **'The account on that device will be signed out. If it is in use, access ends immediately; otherwise the next launch will require signing in again.'**
  String get chatScreenRemovePeerBody;

  /// No description provided for @chatScreenConfirmRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get chatScreenConfirmRemoveLabel;

  /// No description provided for @chatScreenConfirmDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatScreenConfirmDeleteLabel;

  /// No description provided for @chatScreenToastDeletedThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device was removed'**
  String get chatScreenToastDeletedThisDevice;

  /// No description provided for @chatScreenToastDeleteDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this device: {error}'**
  String chatScreenToastDeleteDeviceFailed(String error);

  /// No description provided for @chatScreenToastRemovedPeer.
  ///
  /// In en, this message translates to:
  /// **'Device removed'**
  String get chatScreenToastRemovedPeer;

  /// No description provided for @chatScreenToastRemovePeerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove device: {error}'**
  String chatScreenToastRemovePeerFailed(String error);

  /// No description provided for @chatScreenSessionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation settings'**
  String get chatScreenSessionSettingsTitle;

  /// No description provided for @chatScreenTileRenameDevice.
  ///
  /// In en, this message translates to:
  /// **'Rename device'**
  String get chatScreenTileRenameDevice;

  /// No description provided for @chatScreenTileClearMessages.
  ///
  /// In en, this message translates to:
  /// **'Clear messages'**
  String get chatScreenTileClearMessages;

  /// No description provided for @chatScreenSubtitleClearMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete all chat history in this conversation'**
  String get chatScreenSubtitleClearMessages;

  /// No description provided for @chatScreenClearMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear messages'**
  String get chatScreenClearMessagesTitle;

  /// No description provided for @chatScreenClearMessagesConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete all chat history in this conversation. Files saved to your save folder will not be removed.'**
  String get chatScreenClearMessagesConfirm;

  /// No description provided for @chatScreenClearMessagesDeleteCache.
  ///
  /// In en, this message translates to:
  /// **'Also delete cached files'**
  String get chatScreenClearMessagesDeleteCache;

  /// No description provided for @chatScreenClearMessagesDone.
  ///
  /// In en, this message translates to:
  /// **'Messages cleared'**
  String get chatScreenClearMessagesDone;

  /// No description provided for @chatScreenClearMessagesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear messages'**
  String get chatScreenClearMessagesFailed;

  /// No description provided for @chatScreenTileRemoveThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove this device'**
  String get chatScreenTileRemoveThisDevice;

  /// No description provided for @chatScreenTileRemovePeer.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get chatScreenTileRemovePeer;

  /// No description provided for @chatScreenSubtitleRemoveThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove this device from your account and sign out'**
  String get chatScreenSubtitleRemoveThisDevice;

  /// No description provided for @chatScreenSubtitleRemovePeer.
  ///
  /// In en, this message translates to:
  /// **'Remove the device in this conversation from your account'**
  String get chatScreenSubtitleRemovePeer;

  /// No description provided for @chatScreenPendingFilesMissing.
  ///
  /// In en, this message translates to:
  /// **'Some queued files were missing and were removed'**
  String get chatScreenPendingFilesMissing;

  /// No description provided for @chatScreenConnNotLoggedInHttp.
  ///
  /// In en, this message translates to:
  /// **'Not signed in — HTTP transfer only'**
  String get chatScreenConnNotLoggedInHttp;

  /// No description provided for @chatScreenConnOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach server — offline mode'**
  String get chatScreenConnOffline;

  /// No description provided for @chatScreenConnServerOk.
  ///
  /// In en, this message translates to:
  /// **'Connected to server'**
  String get chatScreenConnServerOk;

  /// No description provided for @chatScreenSelectTargetFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination device first'**
  String get chatScreenSelectTargetFirst;

  /// No description provided for @chatScreenFolderNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to open folders'**
  String get chatScreenFolderNeedsPermission;

  /// No description provided for @chatScreenFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty or cannot be read'**
  String get chatScreenFolderEmpty;

  /// No description provided for @chatScreenFolderSafTryFiles.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the selected folder. Try choosing files instead.'**
  String get chatScreenFolderSafTryFiles;

  /// No description provided for @chatScreenRetryCloudOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot retry cloud transfer in offline mode'**
  String get chatScreenRetryCloudOffline;

  /// No description provided for @chatScreenNoDeviceFound.
  ///
  /// In en, this message translates to:
  /// **'Target device not found — check that it is online'**
  String get chatScreenNoDeviceFound;

  /// No description provided for @chatScreenOfflineNoS3.
  ///
  /// In en, this message translates to:
  /// **'S3 transfer is unavailable in offline mode'**
  String get chatScreenOfflineNoS3;

  /// No description provided for @chatScreenS3NotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'S3 not configured'**
  String get chatScreenS3NotConfiguredTitle;

  /// No description provided for @chatScreenS3NotConfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'S3 is not set up yet. Open settings to configure it?'**
  String get chatScreenS3NotConfiguredBody;

  /// No description provided for @chatScreenS3GoConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get chatScreenS3GoConfigure;

  /// No description provided for @chatScreenS3UnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'S3 unavailable'**
  String get chatScreenS3UnavailableTitle;

  /// No description provided for @chatScreenS3UnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The S3 connection test failed. Check settings or your network. Open S3 settings?'**
  String get chatScreenS3UnavailableBody;

  /// No description provided for @chatScreenS3GoSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get chatScreenS3GoSettings;

  /// No description provided for @chatScreenNoNearbyDevice.
  ///
  /// In en, this message translates to:
  /// **'No nearby device available — choose again'**
  String get chatScreenNoNearbyDevice;

  /// No description provided for @chatScreenDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Selected device is unavailable — choose again'**
  String get chatScreenDeviceUnavailable;

  /// No description provided for @chatScreenWebRtcUnsupportedSource.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be sent via WebRTC — use HTTP'**
  String get chatScreenWebRtcUnsupportedSource;

  /// No description provided for @chatScreenWebRtcFailedTryHttp.
  ///
  /// In en, this message translates to:
  /// **'WebRTC send failed — try HTTP mode'**
  String get chatScreenWebRtcFailedTryHttp;

  /// No description provided for @chatScreenConfigureS3FirstToast.
  ///
  /// In en, this message translates to:
  /// **'Configure S3 in settings first'**
  String get chatScreenConfigureS3FirstToast;

  /// No description provided for @chatScreenS3UnavailableToast.
  ///
  /// In en, this message translates to:
  /// **'S3 is unavailable — check settings or run the connection test'**
  String get chatScreenS3UnavailableToast;

  /// No description provided for @chatScreenSendFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String chatScreenSendFailedWithError(String error);

  /// No description provided for @chatScreenFileMissing.
  ///
  /// In en, this message translates to:
  /// **'File no longer exists — it may have been deleted'**
  String get chatScreenFileMissing;

  /// No description provided for @chatScreenCannotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot open this file'**
  String get chatScreenCannotOpenFile;

  /// No description provided for @chatScreenSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos'**
  String get chatScreenSavedToGallery;

  /// No description provided for @chatScreenReceivedAtPath.
  ///
  /// In en, this message translates to:
  /// **'Received: {path}'**
  String chatScreenReceivedAtPath(String path);

  /// No description provided for @chatScreenReceiveFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Receive failed: {error}'**
  String chatScreenReceiveFailedWithError(String error);

  /// No description provided for @chatScreenCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatScreenCopied;

  /// No description provided for @chatScreenDeleteMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete messages'**
  String get chatScreenDeleteMessagesTitle;

  /// No description provided for @chatScreenDeleteMessagesBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} messages? This removes them locally and from the cloud.'**
  String chatScreenDeleteMessagesBody(int count);

  /// No description provided for @chatHttpReceivedSavedGallery.
  ///
  /// In en, this message translates to:
  /// **'Received via HTTP and saved to Photos'**
  String get chatHttpReceivedSavedGallery;

  /// No description provided for @chatHttpReceivedWithName.
  ///
  /// In en, this message translates to:
  /// **'Received via HTTP: {fileName}'**
  String chatHttpReceivedWithName(String fileName);

  /// No description provided for @chatHttpPullReceivedSavedGallery.
  ///
  /// In en, this message translates to:
  /// **'Received via reverse pull and saved to Photos'**
  String get chatHttpPullReceivedSavedGallery;

  /// No description provided for @chatHttpPullReceivedWithName.
  ///
  /// In en, this message translates to:
  /// **'Received via reverse pull: {fileName}'**
  String chatHttpPullReceivedWithName(String fileName);

  /// No description provided for @chatHttpReceivedBracket.
  ///
  /// In en, this message translates to:
  /// **'{fileName} (received via HTTP)'**
  String chatHttpReceivedBracket(String fileName);

  /// No description provided for @appGallerySubfolder.
  ///
  /// In en, this message translates to:
  /// **'ShrimpSend'**
  String get appGallerySubfolder;

  /// No description provided for @appUpdateTitleNewVersion.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get appUpdateTitleNewVersion;

  /// No description provided for @appUpdateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current: {version} ({build})'**
  String appUpdateCurrentVersion(String version, String build);

  /// No description provided for @appUpdateNewVersion.
  ///
  /// In en, this message translates to:
  /// **'New: {version} ({build})'**
  String appUpdateNewVersion(String version, String build);

  /// No description provided for @appUpdateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get appUpdateLater;

  /// No description provided for @appUpdateDontShowAgainVersion.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again for this version'**
  String get appUpdateDontShowAgainVersion;

  /// No description provided for @appUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get appUpdateDownload;

  /// No description provided for @appUpdateOpenDownloadPage.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get appUpdateOpenDownloadPage;

  /// No description provided for @appUpdateGoAppStore.
  ///
  /// In en, this message translates to:
  /// **'Go to App Store'**
  String get appUpdateGoAppStore;

  /// No description provided for @appUpdateInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get appUpdateInstallTitle;

  /// No description provided for @appUpdateInstallBody.
  ///
  /// In en, this message translates to:
  /// **'Current: {version} ({build})\nPending package: {pending}\n\nThe update is downloaded. Install now?'**
  String appUpdateInstallBody(String version, String build, String pending);

  /// No description provided for @appUpdateUnknownVersion.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get appUpdateUnknownVersion;

  /// No description provided for @appUpdateDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get appUpdateDontShowAgain;

  /// No description provided for @appUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get appUpdateInstall;

  /// No description provided for @desktopUpdateSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Size unknown'**
  String get desktopUpdateSizeUnknown;

  /// No description provided for @desktopUpdateSizeMb.
  ///
  /// In en, this message translates to:
  /// **'~{mb} MB'**
  String desktopUpdateSizeMb(String mb);

  /// No description provided for @desktopUpdateSizeKb.
  ///
  /// In en, this message translates to:
  /// **'~{kb} KB'**
  String desktopUpdateSizeKb(String kb);

  /// No description provided for @desktopUpdateBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get desktopUpdateBannerTitle;

  /// No description provided for @desktopUpdateBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {sizeLine}'**
  String desktopUpdateBannerSubtitle(String version, String sizeLine);

  /// No description provided for @desktopUpdateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get desktopUpdateLater;

  /// No description provided for @desktopUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get desktopUpdateNow;

  /// No description provided for @desktopUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get desktopUpdateDownloading;

  /// No description provided for @desktopUpdateApplying.
  ///
  /// In en, this message translates to:
  /// **'Closing and applying update, please wait…'**
  String get desktopUpdateApplying;

  /// No description provided for @desktopUpdateReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Update ready'**
  String get desktopUpdateReadyTitle;

  /// No description provided for @desktopUpdateReadyBody.
  ///
  /// In en, this message translates to:
  /// **'The app will restart automatically; installation takes a few seconds.'**
  String get desktopUpdateReadyBody;

  /// No description provided for @desktopUpdateQuitRestart.
  ///
  /// In en, this message translates to:
  /// **'Quit and restart'**
  String get desktopUpdateQuitRestart;

  /// No description provided for @desktopUpdateErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get desktopUpdateErrorUnknown;

  /// No description provided for @desktopUpdateCheckFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get desktopUpdateCheckFailedTitle;

  /// No description provided for @desktopUpdateClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get desktopUpdateClose;

  /// No description provided for @desktopUpdateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get desktopUpdateRetry;

  /// No description provided for @desktopUpdateReleaseNotesAction.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get desktopUpdateReleaseNotesAction;

  /// No description provided for @desktopUpdateReleaseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'What’s new in {version}'**
  String desktopUpdateReleaseNotesTitle(String version);

  /// No description provided for @desktopUpdateReleaseNotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No release notes provided for this version.'**
  String get desktopUpdateReleaseNotesEmpty;

  /// No description provided for @qrGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating QR code…'**
  String get qrGenerating;

  /// No description provided for @qrHintScanWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Scan with your signed-in phone'**
  String get qrHintScanWithPhone;

  /// No description provided for @qrHintConfirmOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Scanned — confirm on your phone'**
  String get qrHintConfirmOnPhone;

  /// No description provided for @qrHintLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in, redirecting…'**
  String get qrHintLoginSuccess;

  /// No description provided for @qrHintExpired.
  ///
  /// In en, this message translates to:
  /// **'QR code expired — refresh and try again'**
  String get qrHintExpired;

  /// No description provided for @qrHintGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get qrHintGenericError;

  /// No description provided for @qrLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to sign in'**
  String get qrLoginTitle;

  /// No description provided for @qrLoginTagline.
  ///
  /// In en, this message translates to:
  /// **'Messages & files in sync across devices'**
  String get qrLoginTagline;

  /// No description provided for @qrLoginSteps.
  ///
  /// In en, this message translates to:
  /// **'Open the mobile app → Scan → Confirm on your phone'**
  String get qrLoginSteps;

  /// No description provided for @qrStatusScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get qrStatusScanned;

  /// No description provided for @qrStatusConfirmPhone.
  ///
  /// In en, this message translates to:
  /// **'Confirm sign-in on your phone'**
  String get qrStatusConfirmPhone;

  /// No description provided for @qrRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh QR code'**
  String get qrRefreshButton;

  /// No description provided for @qrUsePasswordLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email & password'**
  String get qrUsePasswordLogin;

  /// No description provided for @qrScannerFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String qrScannerFailed(String error);

  /// No description provided for @qrConfirmLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm sign-in'**
  String get qrConfirmLoginTitle;

  /// No description provided for @qrConfirmLoginBody.
  ///
  /// In en, this message translates to:
  /// **'Allow sign-in on the other device?'**
  String get qrConfirmLoginBody;

  /// No description provided for @qrConfirmLoginConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm sign-in'**
  String get qrConfirmLoginConfirm;

  /// No description provided for @qrConfirmLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sign-in confirmed'**
  String get qrConfirmLoginSuccess;

  /// No description provided for @qrConfirmLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Confirmation failed: {error}'**
  String qrConfirmLoginFailed(String error);

  /// No description provided for @qrScannerNeedCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan QR codes'**
  String get qrScannerNeedCamera;

  /// No description provided for @qrScannerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get qrScannerOpenSettings;

  /// No description provided for @qrScannerPermissionAgain.
  ///
  /// In en, this message translates to:
  /// **'Request permission again'**
  String get qrScannerPermissionAgain;

  /// No description provided for @qrScannerProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get qrScannerProcessing;

  /// No description provided for @qrScannerAlignQr.
  ///
  /// In en, this message translates to:
  /// **'Align the QR code inside the frame'**
  String get qrScannerAlignQr;

  /// No description provided for @qrScannerUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'Scan a ShrimpSend login QR code'**
  String get qrScannerUnrecognized;

  /// No description provided for @qrScannerTorchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on flashlight'**
  String get qrScannerTorchOn;

  /// No description provided for @qrScannerTorchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off flashlight'**
  String get qrScannerTorchOff;

  /// No description provided for @filePreviewTooltipShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get filePreviewTooltipShare;

  /// No description provided for @filePreviewTooltipOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get filePreviewTooltipOpenWith;

  /// No description provided for @filePreviewImageLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get filePreviewImageLoadError;

  /// No description provided for @filePreviewVideoError.
  ///
  /// In en, this message translates to:
  /// **'Could not play this video'**
  String get filePreviewVideoError;

  /// No description provided for @filePreviewTextTruncated.
  ///
  /// In en, this message translates to:
  /// **'{text}\n\n… File too large — showing first 2 MB only'**
  String filePreviewTextTruncated(String text);

  /// No description provided for @filePreviewReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read file contents'**
  String get filePreviewReadError;

  /// No description provided for @filePreviewCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get filePreviewCopyAll;

  /// No description provided for @filePreviewCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get filePreviewCopied;

  /// No description provided for @fileClipboardCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fileClipboardCopy;

  /// No description provided for @fileClipboardCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} file(s) — paste in Finder or Explorer'**
  String fileClipboardCopied(int count);

  /// No description provided for @fileClipboardCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed'**
  String get fileClipboardCopyFailed;

  /// No description provided for @fileClipboardPasteAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to outbox — open chat to send'**
  String get fileClipboardPasteAdded;

  /// No description provided for @fileClipboardNothingToCopy.
  ///
  /// In en, this message translates to:
  /// **'Select files to copy first'**
  String get fileClipboardNothingToCopy;

  /// No description provided for @chatMenuCopyFile.
  ///
  /// In en, this message translates to:
  /// **'Copy file'**
  String get chatMenuCopyFile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
