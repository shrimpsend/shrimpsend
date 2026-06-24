import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
