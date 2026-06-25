import 'dart:async';
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/pending_file_entry.dart';
import '../providers/pending_files_provider.dart';
import '../services/attachment_picker_service.dart';
import '../services/webdav_upload_layout.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../utils/toast.dart';
import 'attachment_picker_sheet.dart';
import 'file_icon_widget.dart';

const int _maxVisibleChipsDesktop = 20;
const double _pendingChipHeight = 32;
const double _pendingOutboxSheetMaxHeightFactor = 0.8;
const double _pendingChipMaxWidth = 150;

/// Optional primary action for [showPendingOutboxSheet] (e.g. upload to WebDAV).
class PendingOutboxPrimaryAction {
  final String label;
  final IconData icon;
  final String? destinationHint;
  final Future<void> Function(
    List<PendingFileEntry> files,
    WebDavUploadLayout layout,
  ) onExecute;

  const PendingOutboxPrimaryAction({
    required this.label,
    required this.icon,
    this.destinationHint,
    required this.onExecute,
  });
}

/// Unified pending outbox sheet (manage-only or with deliver action + add files).
Future<void> showPendingOutboxSheet(
  BuildContext context, {
  PendingOutboxPrimaryAction? primaryAction,
  bool showAddFiles = false,
}) {
  final colors = _pendingBarColors(context);
  final maxHeight =
      MediaQuery.of(context).size.height * _pendingOutboxSheetMaxHeightFactor;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (sheetContext) => _PendingOutboxSheet(
      primaryAction: primaryAction,
      showAddFiles: showAddFiles,
    ),
  );
}

/// Manage-only outbox (home bottom bar). Prefer [showPendingOutboxSheet].
Future<void> showPendingFilesManageSheet(BuildContext context) {
  return showPendingOutboxSheet(context);
}

bool get _isMobilePlatform => Platform.isAndroid || Platform.isIOS;

_PendingBarColors _pendingBarColors(BuildContext context) {
  final theme = Theme.of(context);
  final colors = context.appColors;
  return _PendingBarColors(
    surfaceDim: colors.surfaceMuted,
    surface: colors.surface,
    chipBorder: colors.borderStrong,
    onSurface: colors.textPrimary,
    muted: colors.textSecondary,
    accent: theme.colorScheme.primary,
    handle: colors.borderStrong,
    danger: colors.danger,
  );
}

class _PendingBarColors {
  final Color surfaceDim;
  final Color surface;
  final Color chipBorder;
  final Color onSurface;
  final Color muted;
  final Color accent;
  final Color handle;
  final Color danger;
  _PendingBarColors({
    required this.surfaceDim,
    required this.surface,
    required this.chipBorder,
    required this.onSurface,
    required this.muted,
    required this.accent,
    required this.handle,
    required this.danger,
  });
}

class PendingFilesBar extends StatelessWidget {
  final List<PlatformFile> files;
  final VoidCallback onSend;
  final void Function(PlatformFile file) onRemove;
  final VoidCallback onClearAll;

  const PendingFilesBar({
    super.key,
    required this.files,
    required this.onSend,
    required this.onRemove,
    required this.onClearAll,
  });

  void _showManageSheet(BuildContext context) {
    showPendingOutboxSheet(context);
  }

  Widget _buildSendButton(BuildContext context, _PendingBarColors colors) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: onSend,
      icon: const Icon(LucideIcons.send, size: 16),
      label: Text(l10n.pendingFilesSend),
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildManageButton(
    BuildContext context,
    _PendingBarColors colors,
    ThemeData theme, {
    required bool showCount,
  }) {
    final l10n = AppLocalizations.of(context);
    final label = showCount
        ? l10n.pendingFilesManageWithCount(files.length)
        : l10n.pendingFilesManage;
    return OutlinedButton(
      onPressed: () => _showManageSheet(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        side: BorderSide(color: colors.chipBorder),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    _PendingBarColors colors,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.pendingFilesSelectedCount(files.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildManageButton(context, colors, theme, showCount: false),
        const SizedBox(width: AppSpacing.xs),
        _buildSendButton(context, colors),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    _PendingBarColors colors,
    ThemeData theme,
  ) {
    final chipCount = files.length.clamp(0, _maxVisibleChipsDesktop);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: _pendingChipHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chipCount,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return _CompactChip(
                  name: files[index].name,
                  onDelete: () => onRemove(files[index]),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildManageButton(context, colors, theme, showCount: true),
        const SizedBox(width: AppSpacing.xs),
        _buildSendButton(context, colors),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _pendingBarColors(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      color: colors.surfaceDim,
      child: _isMobilePlatform
          ? _buildMobileLayout(context, colors, theme)
          : _buildDesktopLayout(context, colors, theme),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;

  const _CompactChip({required this.name, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = _pendingBarColors(context);
    final theme = Theme.of(context);
    return Container(
      height: _pendingChipHeight,
      constraints: const BoxConstraints(maxWidth: _pendingChipMaxWidth),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: colors.chipBorder),
      ),
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDelete,
            child: Icon(LucideIcons.x, size: 14, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _PendingOutboxSheet extends ConsumerStatefulWidget {
  final PendingOutboxPrimaryAction? primaryAction;
  final bool showAddFiles;

  const _PendingOutboxSheet({
    this.primaryAction,
    this.showAddFiles = false,
  });

  @override
  ConsumerState<_PendingOutboxSheet> createState() =>
      _PendingOutboxSheetState();
}

class _PendingOutboxSheetState extends ConsumerState<_PendingOutboxSheet> {
  WebDavUploadLayout? _uploadLayout;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUploadLayoutPref());
  }

  Future<void> _loadUploadLayoutPref() async {
    final layout = await loadWebDavUploadLayoutPref();
    if (mounted) setState(() => _uploadLayout = layout);
  }

  bool _hasFolderStructure(List<PendingFileEntry> entries) {
    return entries.any(
      (e) =>
          e.relativeSubPath != null &&
          e.relativeSubPath!.contains('/'),
    );
  }

  Future<void> _addFiles() async {
    final choice = await showModalBottomSheet<AttachmentPickerChoice>(
      context: context,
      backgroundColor: context.appColors.surface,
      builder: (ctx) => const AttachmentPickerSheet(),
    );
    if (choice == null || !mounted) return;

    final picked = await AttachmentPickerService.pick(choice, context);
    if (picked.isEmpty || !mounted) return;
    final result = await ref.read(pendingFilesProvider.notifier).add(picked);
    if (!mounted) return;
    if (result.added == 0) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).fmPendingAddFailed,
      );
    }
  }

  Future<void> _executePrimary(List<PendingFileEntry> entries) async {
    final action = widget.primaryAction;
    if (action == null || entries.isEmpty) return;

    final layout = _uploadLayout ?? WebDavUploadLayout.flat;
    await saveWebDavUploadLayoutPref(layout);
    if (!mounted) return;

    final rootContext = context;
    if (!mounted) return;
    Navigator.pop(rootContext);
    if (!rootContext.mounted) return;

    await action.onExecute(entries, layout);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _pendingBarColors(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(pendingFilesProvider);
    final notifier = ref.read(pendingFilesProvider.notifier);
    final primaryAction = widget.primaryAction;
    final showUploadLayout = primaryAction != null && _hasFolderStructure(entries);
    final uploadLayout = _uploadLayout ?? WebDavUploadLayout.flat;

    void removeAt(int index) {
      final entry = entries[index];
      notifier.remove(entry);
      if (ref.read(pendingFilesProvider).isEmpty && context.mounted) {
        Navigator.pop(context);
      }
    }

    void clearAll() {
      notifier.clear();
      Navigator.pop(context);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.handle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  l10n.mobileHomePendingOutbox,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  TextButton(
                    onPressed: clearAll,
                    child: Text(
                      l10n.pendingFilesClearAll,
                      style: TextStyle(color: colors.danger),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.chipBorder),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.webdavOutboxEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final file = entry.file;
                  final category = getFileCategory(file.name);
                  final subtitle = entry.relativeSubPath != null &&
                          entry.relativeSubPath!.contains('/')
                      ? '${formatFileSize(file.size)} · ${entry.relativeSubPath}'
                      : formatFileSize(file.size);
                  return ListTile(
                    dense: true,
                    leading: FileIconWidget(category: category, size: 32),
                    title: Text(
                      file.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                    trailing: GestureDetector(
                      onTap: () => removeAt(index),
                      child: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: colors.muted,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  );
                },
              ),
            ),
          if (primaryAction != null || widget.showAddFiles) ...[
            Divider(height: 1, color: colors.chipBorder),
            if (primaryAction?.destinationHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.folder,
                      size: 16,
                      color: colors.muted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        primaryAction!.destinationHint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showUploadLayout) ...[
                    Text(
                      l10n.webdavUploadLayoutTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<WebDavUploadLayout>(
                      segments: [
                        ButtonSegment(
                          value: WebDavUploadLayout.flat,
                          label: Text(l10n.webdavUploadLayoutFlat),
                        ),
                        ButtonSegment(
                          value: WebDavUploadLayout.preserveStructure,
                          label: Text(l10n.webdavUploadLayoutPreserve),
                        ),
                      ],
                      selected: {uploadLayout},
                      onSelectionChanged: (selected) {
                        setState(() => _uploadLayout = selected.first);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (primaryAction != null)
                    FilledButton.icon(
                      onPressed: entries.isEmpty
                          ? null
                          : () => _executePrimary(List.of(entries)),
                      icon: Icon(primaryAction.icon, size: 16),
                      label: Text(primaryAction.label),
                    ),
                  if (primaryAction != null && widget.showAddFiles)
                    const SizedBox(height: AppSpacing.xs),
                  if (widget.showAddFiles)
                    OutlinedButton.icon(
                      onPressed: _addFiles,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(l10n.webdavOutboxAddFiles),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
