import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api.dart';
import '../../ui/app_ui.dart';
import '../../ui/platform_performance.dart';

String webDavConnectionSubtitle(WebDavConnectionSummary connection) {
  final baseUrl = connection.baseUrl.trim();
  if (baseUrl.isEmpty) return connection.rootPath;

  Uri? uri;
  try {
    uri = Uri.parse(baseUrl);
  } catch (_) {
    uri = null;
  }

  final host = uri?.host.isNotEmpty == true ? uri!.host : baseUrl;
  final root = connection.rootPath.trim();
  if (root.isEmpty || root == '/') {
    return host;
  }
  if (baseUrl.length <= 48) return baseUrl;
  return '$host$root';
}

class WebDavConnectionItem extends StatelessWidget {
  final WebDavConnectionSummary connection;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const WebDavConnectionItem({
    super.key,
    required this.connection,
    this.selected = false,
    required this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final lightweightTap = AppPlatformPerformance.preferLightweightTapFeedback;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 4, AppSpacing.xs, 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : colors.surface,
        borderRadius: AppRadius.small,
        clipBehavior: lightweightTap ? Clip.none : Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.small,
          splashFactory: lightweightTap ? NoSplash.splashFactory : null,
          highlightColor: lightweightTap ? Colors.transparent : null,
          focusColor: lightweightTap ? Colors.transparent : null,
          hoverColor: lightweightTap
              ? colors.surfaceMuted.withValues(alpha: 0.7)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.hardDrive,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        webDavConnectionSubtitle(connection),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onMore != null)
                  IconButton(
                    icon: Icon(
                      LucideIcons.ellipsisVertical,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    onPressed: onMore,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
