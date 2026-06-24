import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';

/// Bottom-bar package icon with pending-file count badge (home + WebDAV).
class PendingOutboxBadgeButton extends StatelessWidget {
  final int count;
  final bool enabled;
  final VoidCallback? onTap;
  final double size;
  final Color iconColor;

  const PendingOutboxBadgeButton({
    super.key,
    required this.count,
    required this.enabled,
    required this.onTap,
    required this.size,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.mobileHomePendingOutbox,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Badge(
                isLabelVisible: count > 0,
                label: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Icon(
                  LucideIcons.package,
                  color: iconColor,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [GlassBottomBarExtraButton.icon] child for the pending outbox slot.
class PendingOutboxBadgeIcon extends StatelessWidget {
  final int count;
  final Color iconColor;

  const PendingOutboxBadgeIcon({
    super.key,
    required this.count,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Icon(
        LucideIcons.package,
        color: iconColor,
        size: 24,
      ),
    );
  }
}
