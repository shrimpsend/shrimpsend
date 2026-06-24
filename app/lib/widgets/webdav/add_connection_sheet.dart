import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/app_ui.dart';

enum AddConnectionChoice { scanLogin, addWebDav }

Future<AddConnectionChoice?> showAddConnectionSheet(BuildContext context) {
  return showModalBottomSheet<AddConnectionChoice>(
    context: context,
    backgroundColor: context.appColors.surface,
    showDragHandle: true,
    builder: (ctx) => const AddConnectionSheet(),
  );
}

class AddConnectionSheet extends StatelessWidget {
  const AddConnectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.scanLine, color: theme.colorScheme.primary),
              title: Text(l10n.webdavScanLogin),
              onTap: () => Navigator.pop(context, AddConnectionChoice.scanLogin),
            ),
            ListTile(
              leading: Icon(LucideIcons.hardDrive, color: colors.success),
              title: Text(l10n.webdavAddConnection),
              onTap: () => Navigator.pop(context, AddConnectionChoice.addWebDav),
            ),
          ],
        ),
      ),
    );
  }
}
