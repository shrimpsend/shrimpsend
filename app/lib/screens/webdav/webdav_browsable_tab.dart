import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/app_ui.dart';

typedef WebDavSelectionChangedCallback = void Function(
  bool selectionMode,
  int selectedCount,
);

/// Shell AppBar delegates search/selection/batch actions to the active tab.
abstract interface class WebDavBrowsableTabController {
  void toggleSearch();
  void exitSelectionMode();
  Future<void> downloadSelected();
  Future<void> shareSelected();
  Future<void> moveSelected();
  Future<void> deleteSelected();
  bool get isSelectionMode;
  bool get isSearchVisible;
}

Future<String?> showWebDavTextInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  required String cancelLabel,
  required String confirmLabel,
  String initialText = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _WebDavTextInputDialog(
      title: title,
      hint: hint,
      initialText: initialText,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

class _WebDavTextInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initialText;
  final String cancelLabel;
  final String confirmLabel;

  const _WebDavTextInputDialog({
    required this.title,
    required this.hint,
    required this.initialText,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  State<_WebDavTextInputDialog> createState() => _WebDavTextInputDialogState();
}

class _WebDavTextInputDialogState extends State<_WebDavTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = math.min(
      screenWidth - AppSpacing.md * 2,
      AppSize.formMaxWidth,
    );

    return AlertDialog(
      backgroundColor: colors.surface,
      insetPadding: AppDialog.insetPadding,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.contentPadding,
      actionsPadding: AppDialog.actionsPadding,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              foregroundColor: colors.textTertiary,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth - AppSpacing.md * 2,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(hintText: widget.hint),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(widget.cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
