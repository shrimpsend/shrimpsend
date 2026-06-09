import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:simple_icons/simple_icons.dart';

IconData platformIcon(String? platform) => switch (platform) {
  'android' => SimpleIcons.android,
  'ios' || 'macos' => SimpleIcons.apple,
  'windows' => LucideIcons.monitor,
  'linux' => SimpleIcons.linux,
  'web' => LucideIcons.globe,
  _ => LucideIcons.monitorSmartphone,
};

Color platformColor(String? platform, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (platform) {
    'android' => SimpleIconColors.android,
    'ios' || 'macos' => isDark ? const Color(0xFFB0B0B0) : const Color(0xFF555555),
    'windows' => const Color(0xFF0078D7),
    'linux' => isDark ? SimpleIconColors.linux : const Color(0xFFE5A400),
    'web' => const Color(0xFF2196F3),
    _ => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
  };
}
