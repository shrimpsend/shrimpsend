import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../network/transfer_mode_dot.dart';
import '../../ui/app_ui.dart';

Future<void> showTransferModeDotLegend(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final colors = context.appColors;
  final primary = theme.colorScheme.primary;
  final entries = transferModeDotLegendEntries(l10n);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.transportModeDotLegendTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: transferModeDotColor(
                          state: entry.state,
                          colors: colors,
                          primary: primary,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.connectionDiagDone),
        ),
      ],
    ),
  );
}

class TransferModeDotLegendButton extends StatelessWidget {
  const TransferModeDotLegendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;

    return SizedBox(
      width: 22,
      height: 22,
      child: IconButton(
        onPressed: () => showTransferModeDotLegend(context),
        tooltip: l10n.transportModeDotLegendTooltip,
        padding: EdgeInsets.zero,
        icon: Icon(
          LucideIcons.circleHelp,
          size: 13,
          color: colors.textTertiary,
        ),
      ),
    );
  }
}
