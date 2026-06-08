import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../color_theme.dart';
import '../../providers/device_provider.dart';
import '../../ui/app_ui.dart';
import '../../ui/platform_performance.dart';
import '../../ui/platform_icon.dart';
import 'device_id_chip.dart';

class DeviceConversationItem extends StatelessWidget {
  final DeviceDto device;

  /// 账号下已注册设备为「我的」，仅局域网发现等为「外部」。
  final bool isMyDevice;
  final bool selected;
  final DeviceReachStatus reachStatus;
  final String? lastMessage;
  final VoidCallback onTap;

  const DeviceConversationItem({
    super.key,
    required this.device,
    required this.isMyDevice,
    required this.selected,
    required this.reachStatus,
    this.lastMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final brightness = theme.brightness;
    final platform = device.platform;
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
                // Platform icon with online indicator
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          platformIcon(platform),
                          size: 22,
                          color: platformColor(platform, brightness),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: switch (reachStatus) {
                            DeviceReachStatus.online => colors.success,
                            DeviceReachStatus.pullOnline => AppColorTheme.s3Color,
                            DeviceReachStatus.checking => colors.warning,
                            DeviceReachStatus.offline =>
                              colors.textTertiary.withValues(alpha: 0.4),
                          },
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                // Name and subtitle
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    device.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMyDevice
                                        ? colors.surfaceMuted
                                        : colors.warning.withValues(
                                            alpha: 0.14,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isMyDevice ? '我的' : '外部',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isMyDevice
                                          ? colors.textSecondary
                                          : colors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          DisplayCodeChip(
                            displayCode: device.displayCode,
                            background: selected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  )
                                : colors.surfaceMuted,
                            foreground: selected
                                ? theme.colorScheme.primary
                                : colors.textTertiary,
                            borderColor: selected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.38,
                                  )
                                : colors.border.withValues(alpha: 0.65),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastMessage ??
                            switch (reachStatus) {
                              DeviceReachStatus.online => '在线',
                              DeviceReachStatus.pullOnline => '可拉取',
                              DeviceReachStatus.checking => '检测中…',
                              DeviceReachStatus.offline => '离线',
                            },
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
