import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../typography.dart';

import '../color_theme.dart';

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;

  static final BorderRadius small = BorderRadius.circular(sm);
  static final BorderRadius medium = BorderRadius.circular(md);
  static final BorderRadius large = BorderRadius.circular(lg);
  static final BorderRadius pill = BorderRadius.circular(999);
}

class AppSize {
  static const double controlHeight = 52;
  static const double formMaxWidth = 440;
  static const double contentMaxWidth = 640;
  static const double settingsIcon = 36;
  static const double settingsSwatch = 40;
  static const double appBarActionIcon = 20.0;
}

/// Shared layout for [AlertDialog], [Dialog], and [SimpleDialog].
abstract final class AppDialog {
  /// Distance from screen edges (default Material uses 40px horizontal).
  static const EdgeInsets insetPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.lg,
  );

  static const BoxConstraints contentConstraints = BoxConstraints(
    maxWidth: 560,
  );

  static const EdgeInsets titlePadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.xs,
  );

  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xs,
    AppSpacing.md,
    AppSpacing.md,
  );

  static const EdgeInsets actionsPadding = EdgeInsets.all(AppSpacing.md);

  /// Confirm / destructive dialogs (e.g. [AppConfirmDialog]).
  static const EdgeInsets confirmContentPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.sm,
    AppSpacing.md,
    AppSpacing.xs,
  );
}

/// Scroll/list bottom inset when content draws full-bleed under the mobile
/// floating [GlassBottomBar] (narrow home shell — connect / files / settings tabs).
class AppLayout {
  /// Matches [GlassBottomBar.barHeight] on the narrow home shell.
  static const double floatingBottomBarHeight = 64;

  /// Gap above the home indicator ([_kMobileFloatingBarBottomGap] in chat_screen).
  static const double floatingBottomBarBottomGap = 12;

  /// Extra breathing room so the last list row clears the bar.
  static const double floatingBottomBarScrollExtra = 8;

  /// System bottom safe area (Home Indicator / navigation bar).
  static double floatingBottomSystemInset(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = math.max(
      media.viewPadding.bottom,
      media.systemGestureInsets.bottom,
    );
    if (inset > 0) return inset;
    if (Platform.isAndroid) return 48;
    return 0;
  }

  static double floatingBottomBarScrollInset(BuildContext context) {
    return floatingBottomSystemInset(context) +
        floatingBottomBarBottomGap +
        floatingBottomBarHeight +
        floatingBottomBarScrollExtra;
  }
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color danger;
  final Color dangerSurface;
  final Color accentSoft;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.accentSoft,
  });

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? accentSoft,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get appColors => Theme.of(this).extension<AppThemeColors>()!;
}

ThemeData buildAppTheme({
  required AppColorTheme colorTheme,
  required Brightness brightness,
  double baseWght = 450,
}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: colorTheme.accent,
    brightness: brightness,
  );
  final colors = AppThemeColors(
    background: isDark ? const Color(0xFF18181B) : const Color(0xFFE8EBF0),
    surface: isDark ? const Color(0xFF27272A) : Colors.white,
    surfaceMuted: isDark ? const Color(0xFF232326) : const Color(0xFFFAFAFA),
    border: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
    borderStrong: isDark ? const Color(0xFF52525B) : const Color(0xFFD4D4D8),
    textPrimary: isDark ? Colors.white : const Color(0xFF18181B),
    textSecondary: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
    textTertiary: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
    success: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
    successSurface: isDark
        ? const Color(0xFF052E16).withValues(alpha: 0.55)
        : const Color(0xFFECFDF5),
    warning: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
    warningSurface: isDark
        ? const Color(0xFF451A03).withValues(alpha: 0.5)
        : const Color(0xFFFFF7ED),
    danger: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
    dangerSurface: isDark
        ? const Color(0xFF450A0A).withValues(alpha: 0.45)
        : const Color(0xFFFEF2F2),
    accentSoft: Color.alphaBlend(
      colorTheme.accent.withValues(alpha: isDark ? 0.22 : 0.1),
      isDark
          ? const Color(0xFF27272A)
          : const Color(0xFFE8EBF0),
    ),
  );
  final base = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: AppRadius.medium,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  TextStyle? applyFontStyle(TextStyle? style) =>
      withAppFontNullable(style, baseWght: baseWght);

  TextTheme applyFonts(TextTheme theme) {
    return theme.copyWith(
      displayLarge: applyFontStyle(theme.displayLarge),
      displayMedium: applyFontStyle(theme.displayMedium),
      displaySmall: applyFontStyle(theme.displaySmall),
      headlineLarge: applyFontStyle(theme.headlineLarge),
      headlineMedium: applyFontStyle(theme.headlineMedium),
      headlineSmall: applyFontStyle(theme.headlineSmall),
      titleLarge: applyFontStyle(theme.titleLarge),
      titleMedium: applyFontStyle(theme.titleMedium),
      titleSmall: applyFontStyle(theme.titleSmall),
      bodyLarge: applyFontStyle(theme.bodyLarge),
      bodyMedium: applyFontStyle(theme.bodyMedium),
      bodySmall: applyFontStyle(theme.bodySmall),
      labelLarge: applyFontStyle(theme.labelLarge),
      labelMedium: applyFontStyle(theme.labelMedium),
      labelSmall: applyFontStyle(theme.labelSmall),
    );
  }

  final themedText = applyFonts(base.textTheme);

  return base.copyWith(
    colorScheme: scheme.copyWith(
      surface: colors.surface,
      onSurface: colors.textPrimary,
      outline: colors.border,
      error: colors.danger,
    ),
    scaffoldBackgroundColor: colors.background,
    dividerColor: colors.border,
    listTileTheme: ListTileThemeData(
      titleTextStyle: withAppFontNullable(
        base.textTheme.bodyLarge,
        baseWght: baseWght,
      )?.copyWith(color: colors.textPrimary),
      subtitleTextStyle: withAppFontNullable(
        base.textTheme.bodyMedium,
        baseWght: baseWght,
      )?.copyWith(color: colors.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: applyFontStyle(base.textTheme.titleMedium)?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(size: AppSize.appBarActionIcon),
      actionsIconTheme: const IconThemeData(size: AppSize.appBarActionIcon),
    ),
    textTheme: themedText.copyWith(
      headlineSmall: themedText.headlineSmall?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: themedText.titleLarge?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: themedText.titleMedium?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: themedText.bodyLarge?.copyWith(color: colors.textPrimary),
      bodyMedium: themedText.bodyMedium?.copyWith(
        color: colors.textPrimary,
      ),
      bodySmall: themedText.bodySmall?.copyWith(
        color: colors.textSecondary,
      ),
      labelLarge: themedText.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: withAppFont(TextStyle(color: colors.textTertiary), baseWght: baseWght),
      labelStyle: withAppFont(TextStyle(color: colors.textSecondary), baseWght: baseWght),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: inputBorder(colors.border),
      enabledBorder: inputBorder(colors.border),
      disabledBorder: inputBorder(colors.border),
      focusedBorder: inputBorder(scheme.primary, 1.4),
      errorBorder: inputBorder(colors.danger),
      focusedErrorBorder: inputBorder(colors.danger, 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(AppSize.controlHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        textStyle: base.textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        minimumSize: const Size.fromHeight(AppSize.controlHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        textStyle: base.textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        textStyle: base.textTheme.labelLarge,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.large,
        side: BorderSide(color: colors.border),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.surfaceMuted,
      disabledColor: colors.surfaceMuted,
      selectedColor: scheme.primary,
      secondarySelectedColor: scheme.primary,
      side: BorderSide(color: colors.border),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      labelStyle: base.textTheme.bodySmall?.copyWith(
        color: colors.textSecondary,
      ),
      secondaryLabelStyle: base.textTheme.bodySmall?.copyWith(
        color: scheme.onPrimary,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary.withValues(alpha: 0.5);
        }
        return colors.borderStrong;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return isDark ? colors.borderStrong : colors.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary.withValues(alpha: 0.35);
        }
        return isDark ? const Color(0xFF3F3F46) : colors.surfaceMuted;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: colors.border,
      circularTrackColor: colors.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      insetPadding: AppDialog.insetPadding,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      constraints: AppDialog.contentConstraints,
    ),
    extensions: [colors, AppTypographyConfig(baseWght: baseWght)],
  );
}
