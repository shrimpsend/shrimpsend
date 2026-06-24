import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/desktop_file_clipboard.dart';
import '../services/file_export_pipeline.dart';
import '../services/file_export_service.dart';
import '../services/file_store.dart';
import '../services/received_file_dao.dart';
import '../services/save_folder_listing_service.dart';
import '../services/visible_export_target.dart';
import '../utils/file_utils.dart';
import '../utils/reveal_file_in_folder.dart';
import '../utils/save_as_feedback.dart';
import '../utils/text_bytes_decoder.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/received_file_info_dialog.dart';

/// Bottom inset reserved for the floating preview action bar.
const double kFilePreviewActionBarInset = 72;

class ReceivedFilePreviewCallbacks {
  final VoidCallback? onEnterMultiSelect;
  final Future<bool> Function(List<PlatformFile> files)? onAddToPending;
  final VoidCallback? onDeleted;

  const ReceivedFilePreviewCallbacks({
    this.onEnterMultiSelect,
    this.onAddToPending,
    this.onDeleted,
  });
}

class ReceivedFileActionItem {
  final IconData icon;
  final String tooltip;
  final Future<void> Function(BuildContext context)? onTap;
  final bool isDanger;

  const ReceivedFileActionItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDanger = false,
  });
}

bool _isDesktopPlatform() =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

bool _isMobilePlatform() => Platform.isAndroid || Platform.isIOS;

bool _canSaveToGallery(ReceivedFileInfo file) =>
    _isMobilePlatform() &&
    (file.category == FileCategory.image ||
        file.category == FileCategory.video);

bool _isTextPreview(ReceivedFileInfo file, {required bool forceText}) {
  if (forceText) return true;
  switch (file.category) {
    case FileCategory.code:
    case FileCategory.document:
      return true;
    default:
      return false;
  }
}

Future<String?> _resolveSharePath(ReceivedFileInfo file) async {
  if (SaveFolderListingService.isSaveFolderEntry(file) &&
      file.path.startsWith('content://')) {
    return SaveFolderListingService.resolveLocalPath(file);
  }
  return file.path;
}

Future<String?> _resolveLocalPathForOpen(ReceivedFileInfo file) async {
  if (SaveFolderListingService.isSaveFolderEntry(file) &&
      file.path.startsWith('content://')) {
    return SaveFolderListingService.resolveLocalPath(file);
  }
  return file.path;
}

/// Deletes a file's on-disk copy. User-initiated, so desktop platforms move it
/// to the system recycle bin. Returns true on success.
Future<bool> _removeFile(ReceivedFileInfo file) async {
  if (SaveFolderListingService.isSaveFolderEntry(file)) {
    return SaveFolderListingService.deleteEntry(file, useTrash: true);
  }
  final ok = await FileStore.deleteFile(file.path, useTrash: true);
  try {
    await ReceivedFileDao.instance.removeByMessageId(file.messageId);
  } catch (_) {}
  return ok;
}

Future<void> _copyTextFileContent(
  BuildContext context,
  String filePath,
) async {
  final l10n = AppLocalizations.of(context);
  const maxBytes = 2 * 1024 * 1024;
  try {
    final file = File(filePath);
    final stat = await file.stat();
    final truncated = stat.size > maxBytes;
    final bytes = await readTextFileBytes(filePath, maxBytes: maxBytes);
    final text = decodeTextBytes(bytes);
    final content = truncated ? l10n.filePreviewTextTruncated(text) : text;
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: l10n.filePreviewCopied,
      duration: const Duration(seconds: 1),
    );
  } catch (_) {
    if (!context.mounted) return;
    AppToast.show(context, message: l10n.filePreviewReadError);
  }
}

String _exportActionLabel(AppLocalizations l10n) => saveAsActionLabel(l10n);

List<ReceivedFileActionItem> buildReceivedFileActions({
  required ReceivedFileInfo file,
  required AppLocalizations l10n,
  required bool forceText,
  ReceivedFilePreviewCallbacks? callbacks,
}) {
  final isSaveFolderEntry = SaveFolderListingService.isSaveFolderEntry(file);
  final canExport =
      FileExportService.isSupported && !isSaveFolderEntry;
  final canRetryExport =
      file.exportStatus == ExportStatus.failed && !isSaveFolderEntry;

  return [
    ReceivedFileActionItem(
      icon: LucideIcons.info,
      tooltip: l10n.fmFileInfoAction,
      onTap: (ctx) async {
        await showReceivedFileInfoDialog(ctx, file);
      },
    ),
    if (callbacks?.onEnterMultiSelect != null)
      ReceivedFileActionItem(
        icon: LucideIcons.squareCheck,
        tooltip: l10n.fmMultiSelectMode,
        onTap: (ctx) async {
          Navigator.pop(ctx);
          callbacks!.onEnterMultiSelect!();
        },
      ),
    if (callbacks?.onAddToPending != null)
      ReceivedFileActionItem(
        icon: LucideIcons.plus,
        tooltip: l10n.chatMenuAddToPending,
        onTap: (ctx) async {
          final ok = await callbacks!.onAddToPending!(
            [
              PlatformFile(
                name: file.displayName,
                size: file.size,
                path: file.path,
              ),
            ],
          );
          if (!ctx.mounted) return;
          AppToast.show(
            ctx,
            message: ok
                ? l10n.fmPendingAddedOne(file.displayName)
                : l10n.fmPendingAddFailed,
          );
        },
      ),
    if (_isMobilePlatform())
      ReceivedFileActionItem(
        icon: LucideIcons.share2,
        tooltip: l10n.filePreviewTooltipShare,
        onTap: (ctx) async {
          final path = await _resolveSharePath(file);
          if (!ctx.mounted) return;
          if (path == null || path.isEmpty) {
            AppToast.show(ctx, message: l10n.fmPreviewUnavailableTitle);
            return;
          }
          await Share.shareXFiles([XFile(path)]);
        },
      ),
    if (_canSaveToGallery(file))
      ReceivedFileActionItem(
        icon: LucideIcons.imageDown,
        tooltip: l10n.chatMenuSaveToGallery,
        onTap: (ctx) async {
          try {
            final result = await SaverGallery.saveFile(
              filePath: file.path,
              fileName: file.displayName,
              androidRelativePath: 'Pictures/${l10n.brandNameInternational}',
              skipIfExists: false,
            );
            if (!ctx.mounted) return;
            if (result.isSuccess) {
              AppToast.show(ctx, message: l10n.chatGallerySaved);
              Analytics.track(AnalyticsEvents.fileSaveToGallery, {
                'result': 'success',
              });
            } else {
              AppToast.show(ctx, message: l10n.chatGallerySaveFailed);
              Analytics.track(AnalyticsEvents.fileSaveToGallery, {
                'result': 'fail',
              });
            }
          } catch (_) {
            if (!ctx.mounted) return;
            AppToast.show(ctx, message: l10n.chatGallerySaveFailed);
            Analytics.track(AnalyticsEvents.fileSaveToGallery, {
              'result': 'fail',
            });
          }
        },
      ),
    if (canExport)
      ReceivedFileActionItem(
        icon: LucideIcons.download,
        tooltip: _exportActionLabel(l10n),
        onTap: (ctx) => runSaveFileAs(
          context: ctx,
          l10n: l10n,
          sourcePath: file.path,
          fileName: file.displayName,
        ),
      ),
    if (canRetryExport)
      ReceivedFileActionItem(
        icon: LucideIcons.refreshCw,
        tooltip: l10n.fmExportRetry,
        onTap: (ctx) async {
          await FileExportPipeline.instance.retry(file.messageId);
          if (!ctx.mounted) return;
          AppToast.show(ctx, message: l10n.fmExportStatusExporting);
        },
      ),
    // Desktop only: mobile cannot launch file:// URIs (Android FileUriExposedException;
    // iOS sandbox). Mobile users already have in-app preview + share/export/gallery.
    if (_isDesktopPlatform())
      ReceivedFileActionItem(
        icon: LucideIcons.externalLink,
        tooltip: l10n.filePreviewTooltipOpenWith,
        onTap: (ctx) async {
          final path = await _resolveLocalPathForOpen(file);
          if (!ctx.mounted) return;
          if (path == null || path.isEmpty) {
            AppToast.show(ctx, message: l10n.fmPreviewUnavailableTitle);
            return;
          }
          try {
            final ok = await launchUrl(
              Uri.file(path),
              mode: LaunchMode.externalApplication,
            );
            if (!ctx.mounted) return;
            if (!ok) {
              AppToast.show(ctx, message: l10n.fmPreviewUnavailableTitle);
            }
          } catch (_) {
            if (!ctx.mounted) return;
            AppToast.show(ctx, message: l10n.fmPreviewUnavailableTitle);
          }
        },
      ),
    if (_isTextPreview(file, forceText: forceText))
      ReceivedFileActionItem(
        icon: LucideIcons.copy,
        tooltip: l10n.filePreviewCopyAll,
        onTap: (ctx) => _copyTextFileContent(ctx, file.path),
      ),
    if (_isDesktopPlatform())
      ReceivedFileActionItem(
        icon: LucideIcons.copy,
        tooltip: l10n.fileClipboardCopy,
        onTap: (ctx) async {
          final paths = <String>[];
          if (isSaveFolderEntry && file.path.startsWith('content://')) {
            final local = await SaveFolderListingService.resolveLocalPath(file);
            if (local != null && local.isNotEmpty) {
              paths.add(local);
            }
          } else {
            paths.add(file.path);
          }
          if (!ctx.mounted) return;
          if (paths.isEmpty) {
            AppToast.show(ctx, message: l10n.fileClipboardCopyFailed);
            return;
          }
          final ok = await DesktopFileClipboard.writeFilesToClipboard(paths);
          if (!ctx.mounted) return;
          AppToast.show(
            ctx,
            message: ok
                ? l10n.fileClipboardCopied(paths.length)
                : l10n.fileClipboardCopyFailed,
          );
        },
      ),
    if (_isDesktopPlatform())
      ReceivedFileActionItem(
        icon: LucideIcons.folderOpen,
        tooltip: l10n.fmRevealInFolder,
        onTap: (ctx) async {
          final path = await _resolveLocalPathForOpen(file);
          if (path == null || path.isEmpty) {
            if (!ctx.mounted) return;
            AppToast.show(ctx, message: l10n.fmPreviewUnavailableTitle);
            return;
          }
          await revealFileInFolder(path);
        },
      ),
    ReceivedFileActionItem(
      icon: LucideIcons.trash2,
      tooltip: l10n.fmDeleteConfirm,
      isDanger: true,
      onTap: (ctx) async {
        final confirmed = await AppConfirmDialog.show(
          ctx,
          title: l10n.fmDeleteTitle,
          content: l10n.fmDeleteConfirmOne(file.displayName),
          confirmLabel: l10n.fmDeleteConfirm,
          isDanger: true,
          icon: LucideIcons.trash2,
        );
        if (!confirmed) return;
        final ok = await _removeFile(file);
        if (!ctx.mounted) return;
        if (!ok) {
          AppToast.show(ctx, message: l10n.fmDeleteFailed);
          return;
        }
        Navigator.pop(ctx);
        callbacks?.onDeleted?.call();
      },
    ),
  ];
}
