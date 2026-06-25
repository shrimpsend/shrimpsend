import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/webdav_provider.dart';
import '../../screens/webdav_connection_screen.dart';
import '../../services/webdav_credential_store.dart';
import '../../services/webdav_session.dart';
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
            leading: Icon(LucideIcons.stethoscope, color: theme.colorScheme.primary),
            title: Text(l10n.webdavDiagnoseUpload),
            onTap: () async {
              Navigator.pop(ctx);
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogCtx) => AlertDialog(
                  content: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Expanded(child: Text(l10n.webdavDiagnoseUploadRunning)),
                    ],
                  ),
                ),
              );
              try {
                final creds = await resolveWebDavCredentials(
                  conn.id,
                  forceRefresh: true,
                );
                final client = WebDavClient(creds);
                final lines = await client.diagnoseUpload();
                if (!context.mounted) return;
                Navigator.pop(context);
                await showDialog<void>(
                  context: context,
                  builder: (resultCtx) => AlertDialog(
                    title: Text(l10n.webdavDiagnoseUploadTitle),
                    content: SingleChildScrollView(
                      child: SelectableText(lines.join('\n\n')),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(resultCtx),
                        child: Text(l10n.confirm),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                AppToast.show(
                  context,
                  message: l10n.webdavDiagnoseUploadFailed('$e'),
                );
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
