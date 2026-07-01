import 'package:flutter/material.dart';

import '../../providers/device_provider.dart';
import '../chat/chat_header.dart';

/// Keeps visited chat session panes alive (header + body) for instant switching.
class ChatSessionPaneHost extends StatefulWidget {
  final String selectedDeviceId;
  final Widget Function(String sessionId) chatContentBuilder;
  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onFileManager;
  final VoidCallback? onOpenS3Settings;
  final VoidCallback? onSessionDeviceSettings;

  const ChatSessionPaneHost({
    super.key,
    required this.selectedDeviceId,
    required this.chatContentBuilder,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onExitSelection,
    this.onToggleSelectAll,
    this.onDeleteSelected,
    this.onFileManager,
    this.onOpenS3Settings,
    this.onSessionDeviceSettings,
  });

  @override
  State<ChatSessionPaneHost> createState() => _ChatSessionPaneHostState();
}

class _ChatSessionPaneHostState extends State<ChatSessionPaneHost> {
  final List<String> _materializedSessionIds = <String>[];

  @override
  void initState() {
    super.initState();
    _materialize(widget.selectedDeviceId);
  }

  @override
  void didUpdateWidget(covariant ChatSessionPaneHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _materialize(widget.selectedDeviceId);
  }

  void _materialize(String sessionId) {
    if (!isChatSelection(sessionId)) return;
    if (_materializedSessionIds.contains(sessionId)) return;
    _materializedSessionIds.add(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.selectedDeviceId;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final sessionId in _materializedSessionIds)
          Offstage(
            offstage: sessionId != selectedId,
            child: KeyedSubtree(
              key: ValueKey('chat_session_$sessionId'),
              child: Column(
                children: [
                  ChatHeader(
                    isSelectionMode: widget.isSelectionMode,
                    selectedCount: widget.selectedCount,
                    totalCount: widget.totalCount,
                    onExitSelection: widget.onExitSelection,
                    onToggleSelectAll: widget.onToggleSelectAll,
                    onDeleteSelected: widget.onDeleteSelected,
                    onFileManager: widget.onFileManager,
                    onOpenS3Settings: widget.onOpenS3Settings,
                    onSessionDeviceSettings: widget.onSessionDeviceSettings,
                  ),
                  Expanded(child: widget.chatContentBuilder(sessionId)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
