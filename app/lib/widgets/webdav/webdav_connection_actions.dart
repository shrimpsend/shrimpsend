import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/webdav_provider.dart';
import '../../screens/webdav_connection_screen.dart';
import '../../services/webdav_credential_store.dart';
import '../../ui/app_ui.dart';
import '../../utils/toast.dart';
import '../app_confirm_dialog.dart';

Future<void> showWebDavConnectionMenu(
  BuildContext context,
  WidgetRef ref,
  WebDavConnectionSummary conn,
) async {
  final theme = Theme.of(context);
  final colors = context.appColors;
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(LucideIcons.pencil, color: theme.colorScheme.primary),
            title: Text(l10n.webdavEditConnection),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => WebDavConnectionScreen(connectionId: conn.id),
                ),
              );
              if (ok == true) {
                await ref.read(webDavConnectionsProvider.notifier).refresh();
              }
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.plugZap, color: colors.success),
            title: Text(l10n.webdavTestConnection),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                final result = await testWebDavConnection(conn.id);
                if (!context.mounted) return;
                AppToast.show(
                  context,
                  message: result.ok ? l10n.webdavTestSuccess : result.message,
                );
              } catch (e) {
                if (!context.mounted) return;
                AppToast.show(context, message: l10n.webdavTestFailed('$e'));
              }
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.trash2, color: colors.danger),
            title: Text(
              l10n.webdavDeleteConnection,
              style: TextStyle(color: colors.danger),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await AppConfirmDialog.show(
                context,
                title: l10n.webdavDeleteConnectionTitle,
                content: l10n.webdavDeleteConnectionBody(conn.name),
                confirmLabel: l10n.confirm,
                icon: LucideIcons.trash2,
                isDanger: true,
              );
              if (!ok) return;
              try {
                await deleteWebDavConnection(conn.id);
                await WebDavCredentialStore.instance.remove(conn.id);
                await ref.read(webDavConnectionsProvider.notifier).refresh();
                if (!context.mounted) return;
                AppToast.show(context, message: l10n.webdavDeletedToast);
              } catch (e) {
                if (!context.mounted) return;
                AppToast.show(context, message: l10n.webdavDeleteFailed('$e'));
              }
            },
          ),
        ],
      ),
    ),
  );
}
