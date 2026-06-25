import 'package:flutter/material.dart';

import '../ui/app_ui.dart';

class DesktopHoverAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const DesktopHoverAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
}

class DesktopHoverActionBar extends StatelessWidget {
  const DesktopHoverActionBar({
    super.key,
    required this.actions,
    required this.colors,
  });

  final List<DesktopHoverAction> actions;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            DesktopHoverIconButton(
              icon: action.icon,
              tooltip: action.tooltip,
              onTap: action.onTap,
              color: action.color ?? colors.textSecondary,
            ),
        ],
      ),
    );
  }
}

class DesktopHoverIconButton extends StatelessWidget {
  const DesktopHoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  static const _tooltipWait = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: _tooltipWait,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
