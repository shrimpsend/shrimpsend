import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/app_ui.dart';
import 'webdav_connection_screen.dart';
import 'webdav_transfer_list_screen.dart';

class WebDavSettingsTab extends ConsumerWidget {
  final WebDavConnectionSummary connection;
  final int activeTransferCount;
  final VoidCallback onSwitchConnection;

  const WebDavSettingsTab({
    super.key,
    required this.connection,
    required this.activeTransferCount,
    required this.onSwitchConnection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.webdavSettingsCurrentConnection,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  connection.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  connection.baseUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          leading: const Icon(LucideIcons.arrowLeftRight),
          title: Text(l10n.webdavSettingsSwitchConnection),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: onSwitchConnection,
        ),
        ListTile(
          leading: const Icon(LucideIcons.plus),
          title: Text(l10n.webdavAddConnection),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WebDavConnectionScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.activity),
          title: Text(l10n.webdavTransferList),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeTransferCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '$activeTransferCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebDavTransferListScreen(
                  connection: connection,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
