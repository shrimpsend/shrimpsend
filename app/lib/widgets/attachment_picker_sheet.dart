import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';
import '../config/env.dart';
import '../ui/app_ui.dart';
import '../utils/runtime_platform.dart';

enum AttachmentPickerChoice { imageVideo, file, folder, apk }

class AttachmentPickerSheet extends StatelessWidget {
  const AttachmentPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.sm,
                left: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.composerPickAttachmentTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            if (!RuntimePlatform.isDesktop)
              _OptionTile(
                icon: LucideIcons.images,
                iconColor: colors.success,
                label: l10n.composerAttachImageVideo,
                subtitle: l10n.composerAttachImageVideoDesc,
                onTap: () =>
                    Navigator.pop(context, AttachmentPickerChoice.imageVideo),
                subtitleColor: colors.textSecondary,
              ),
            _OptionTile(
              icon: LucideIcons.file,
              iconColor: theme.colorScheme.primary,
              label: l10n.composerAttachFile,
              subtitle: l10n.composerAttachFileDesc,
              onTap: () => Navigator.pop(context, AttachmentPickerChoice.file),
              subtitleColor: colors.textSecondary,
            ),
            if (!Platform.isIOS)
              _OptionTile(
                icon: LucideIcons.folder,
                iconColor: colors.warning,
                label: l10n.composerAttachFolder,
                subtitle: l10n.composerAttachFolderDesc,
                onTap: () =>
                    Navigator.pop(context, AttachmentPickerChoice.folder),
                subtitleColor: colors.textSecondary,
              ),
            if (Platform.isAndroid && !Env.androidPlayDistribution)
              _OptionTile(
                icon: LucideIcons.smartphone,
                iconColor: colors.success,
                label: l10n.composerAttachApk,
                subtitle: l10n.composerAttachApkDesc,
                onTap: () => Navigator.pop(context, AttachmentPickerChoice.apk),
                subtitleColor: colors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color subtitleColor;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: AppRadius.small,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
    );
  }
}
