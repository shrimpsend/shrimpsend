import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../l10n/generated/app_localizations.dart';
import '../screens/apk_picker_screen.dart';
import '../utils/gallery_permission.dart';
import '../utils/runtime_platform.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/attachment_picker_sheet.dart';

final Logger _log = Logger('虾传.attachment_picker');

final class AttachmentPickerService {
  AttachmentPickerService._();

  static Future<List<PlatformFile>> pick(
    AttachmentPickerChoice choice,
    BuildContext context,
  ) async {
    switch (choice) {
      case AttachmentPickerChoice.imageVideo:
        return _pickImageVideo(context);
      case AttachmentPickerChoice.file:
        return _pickFiles();
      case AttachmentPickerChoice.folder:
        return _pickFolder(context);
      case AttachmentPickerChoice.apk:
        return _pickApk(context);
    }
  }

  static Future<List<PlatformFile>> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return [];
    return _validPlatformFiles(result.files);
  }

  static Future<List<PlatformFile>> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.media,
    );
    if (result == null || result.files.isEmpty) return [];
    return _validPlatformFiles(result.files);
  }

  static List<PlatformFile> _validPlatformFiles(List<PlatformFile> files) {
    return files
        .where((f) => f.size > 0 && (f.bytes != null || f.path != null))
        .toList();
  }

  /// Desktop uses the native file picker; mobile uses the gallery asset picker.
  @visibleForTesting
  static bool get imageVideoUsesDesktopFilePicker => RuntimePlatform.isDesktop;

  static Future<({bool proceed, bool hideLimitedOverlay})>
      _ensureGalleryReadForPicker(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return (proceed: true, hideLimitedOverlay: false);
    }
    if (!context.mounted) return (proceed: false, hideLimitedOverlay: false);
    final l10n = AppLocalizations.of(context);

    var state = await getGalleryReadPermissionState();
    if (!context.mounted) return (proceed: false, hideLimitedOverlay: false);
    state = await repairGalleryReadPermissionIfNeeded(state);
    if (!context.mounted) return (proceed: false, hideLimitedOverlay: false);
    if (isGalleryReadFullyAuthorized(state)) {
      return (proceed: true, hideLimitedOverlay: false);
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.chatGalleryReadPermissionTitle,
      content: l10n.chatGalleryReadPermissionBody,
      confirmLabel: l10n.chatGalleryReadPermissionConfirm,
      icon: LucideIcons.images,
    );
    if (!confirmed || !context.mounted) {
      return (proceed: false, hideLimitedOverlay: false);
    }

    state = await requestGalleryReadPermission();
    if (!context.mounted) return (proceed: false, hideLimitedOverlay: false);

    if (isGalleryReadFullyAuthorized(state)) {
      return (proceed: true, hideLimitedOverlay: false);
    }

    if (state == PermissionState.limited) {
      final openSettings = await AppConfirmDialog.show(
        context,
        title: l10n.chatGalleryReadPermissionTitle,
        content: l10n.chatGalleryReadPermissionLimited,
        confirmLabel: l10n.qrScannerOpenSettings,
        cancelLabel: l10n.chatGalleryReadPermissionContinuePartial,
        icon: LucideIcons.images,
      );
      if (!context.mounted) return (proceed: false, hideLimitedOverlay: false);
      if (openSettings) {
        await openAppSettings();
        return (proceed: false, hideLimitedOverlay: false);
      }
      return (proceed: true, hideLimitedOverlay: true);
    }

    if (!context.mounted) return (proceed: false, hideLimitedOverlay: false);
    AppToast.show(context, message: l10n.chatGalleryReadPermissionDenied);
    return (proceed: false, hideLimitedOverlay: false);
  }

  static Future<List<PlatformFile>> _pickAssetsFromGallery(
    BuildContext context, {
    bool hideLimitedOverlay = false,
  }) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        requestType: RequestType.common,
        maxAssets: 999,
        limitedPermissionOverlayPredicate:
            hideLimitedOverlay ? (_) => false : null,
        textDelegate: assetPickerTextDelegateFromLocale(
          const Locale('zh', 'CN'),
        ),
      ),
    );
    if (assets == null || assets.isEmpty) return [];

    final result = <PlatformFile>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      final stat = await file.stat();
      if (stat.size <= 0) continue;
      result.add(
        PlatformFile(
          name: await asset.titleAsync,
          path: file.path,
          size: stat.size,
        ),
      );
    }
    return result;
  }

  static Future<List<PlatformFile>> _pickImageVideo(BuildContext context) async {
    if (!context.mounted) return [];
    if (imageVideoUsesDesktopFilePicker) {
      try {
        return await _pickMediaFiles();
      } catch (e) {
        _log.warning('pickImageVideo desktop failed: $e');
        return [];
      }
    }
    try {
      final access = await _ensureGalleryReadForPicker(context);
      if (!access.proceed || !context.mounted) return [];
      return await _pickAssetsFromGallery(
        context,
        hideLimitedOverlay: access.hideLimitedOverlay,
      );
    } catch (e) {
      _log.warning('pickImageVideo failed: $e');
      return [];
    }
  }

  static Future<List<PlatformFile>> _pickFolder(BuildContext context) async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return [];

    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final result = <PlatformFile>[];
    var listFailed = false;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.size <= 0) continue;
            result.add(
              PlatformFile(
                name: entity.path.split(Platform.pathSeparator).last,
                path: entity.path,
                size: stat.size,
              ),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      listFailed = true;
      _log.warning('pickFolder list failed: $e');
    }

    if (result.isEmpty && context.mounted) {
      final l10n = AppLocalizations.of(context);
      final message = Platform.isAndroid && listFailed
          ? l10n.chatScreenFolderSafTryFiles
          : l10n.chatScreenFolderEmpty;
      AppToast.show(context, message: message);
    }
    return result;
  }

  static Future<List<PlatformFile>> _pickApk(BuildContext context) async {
    final picks = await Navigator.push<List<ApkPickResult>>(
      context,
      MaterialPageRoute(builder: (_) => const ApkPickerScreen()),
    );
    if (picks == null || picks.isEmpty) return [];

    final result = <PlatformFile>[];
    for (final pick in picks) {
      final file = File(pick.path);
      if (!await file.exists()) continue;
      final stat = await file.stat();
      if (stat.size <= 0) continue;
      result.add(
        PlatformFile(
          name: pick.displayName,
          path: pick.path,
          size: stat.size,
        ),
      );
    }
    return result;
  }
}
