import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/app_ui.dart';

/// User's choice for which on-disk copies to delete alongside a file message.
class DeleteFileMessageChoice {
  /// Delete the staging cache copy.
  final bool deleteCache;

  /// Delete the user-visible exported (转存) copy.
  final bool deleteExport;

  const DeleteFileMessageChoice({
    required this.deleteCache,
    required this.deleteExport,
  });
}

/// Confirm dialog used when deleting file message(s) in a chat session.
///
/// The chat message record is always removed by the caller; the two checkboxes
/// only control whether the cache copy and/or the exported (转存) copy are also
/// deleted. "Delete cache" is checked by default; "delete export" requires an
/// explicit opt-in. Each checkbox is disabled when no such copy exists.
class DeleteFileMessageDialog extends StatefulWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final bool cacheAvailable;
  final bool exportAvailable;

  const DeleteFileMessageDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.cacheAvailable,
    required this.exportAvailable,
  });

  static Future<DeleteFileMessageChoice?> show(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required bool cacheAvailable,
    required bool exportAvailable,
  }) {
    return showDialog<DeleteFileMessageChoice>(
      context: context,
      builder: (_) => DeleteFileMessageDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cacheAvailable: cacheAvailable,
        exportAvailable: exportAvailable,
      ),
    );
  }

  @override
  State<DeleteFileMessageDialog> createState() =>
      _DeleteFileMessageDialogState();
}

class _DeleteFileMessageDialogState extends State<DeleteFileMessageDialog> {
  late bool _deleteCache = widget.cacheAvailable;
  bool _deleteExport = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.confirmContentPadding,
      actionsPadding: AppDialog.actionsPadding,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.dangerSurface,
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(
                    LucideIcons.trash2,
                    size: 22,
                    color: colors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              foregroundColor: colors.textTertiary,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCheckRow(
            colors: colors,
            theme: theme,
            label: l10n.deleteFileCacheLabel,
            available: widget.cacheAvailable,
            unavailableHint: l10n.deleteFileNoCacheCopy,
            value: _deleteCache,
            onChanged: widget.cacheAvailable
                ? (v) => setState(() => _deleteCache = v ?? false)
                : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildCheckRow(
            colors: colors,
            theme: theme,
            label: l10n.deleteFileExportLabel,
            available: widget.exportAvailable,
            unavailableHint: l10n.deleteFileNoExportCopy,
            value: _deleteExport,
            onChanged: widget.exportAvailable
                ? (v) => setState(() => _deleteExport = v ?? false)
                : null,
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  DeleteFileMessageChoice(
                    deleteCache: _deleteCache && widget.cacheAvailable,
                    deleteExport: _deleteExport && widget.exportAvailable,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: colors.danger,
                  foregroundColor: Colors.white,
                ),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckRow({
    required AppThemeColors colors,
    required ThemeData theme,
    required String label,
    required bool available,
    required String unavailableHint,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    final enabled = available && onChanged != null;
    final textColor = enabled ? colors.textPrimary : colors.textTertiary;
    return InkWell(
      borderRadius: AppRadius.small,
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                  if (!available)
                    Text(
                      unavailableHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
