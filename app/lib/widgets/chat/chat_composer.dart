import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../shortcut_preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../logger.dart';
import '../../ui/app_ui.dart';
import '../attachment_picker_sheet.dart';
import '../pending_files_bar.dart';
import 'chat_theme_helpers.dart';

class ChatComposer extends ConsumerStatefulWidget {
  final Future<void> Function(String text) onSend;
  final Future<void> Function(AttachmentPickerChoice choice) onAttachmentChoice;
  final List<PlatformFile> pendingFiles;
  final VoidCallback onSendPendingFiles;
  final void Function(PlatformFile file) onRemovePendingFile;
  final VoidCallback onClearPendingFiles;

  /// On desktop, called when Cmd/Ctrl+V pastes files from clipboard.
  final void Function(List<PlatformFile> files)? onPasteFiles;

  /// On desktop, toggles the sidebar instead of the inline panel.
  final VoidCallback? onToggleDesktopSidebar;

  /// On desktop, expands the sidebar without toggling (no-op if already open).
  final VoidCallback? onExpandDesktopSidebar;

  /// On mobile, toggles the page-level device sidebar.
  final VoidCallback? onToggleDevicePanel;

  /// On mobile, opens the page-level device sidebar (no-op if already open).
  final VoidCallback? onExpandDevicePanel;

  /// On mobile, closes the page-level device sidebar (e.g. when dismissDevicePanel() is called).
  final VoidCallback? onDismissDevicePanel;

  /// When non-null, reflects whether the page-level device sidebar is open (for badge highlight).
  final bool? isDevicePanelOpen;

  /// Optional: report measured height (e.g. so mobile overlay sidebar can stop above composer).
  final void Function(double height)? onHeightChanged;
  final String? lanReceiverUrl;
  final Future<bool> Function(String targetDeviceId)? onProbePull;
  final Future<String> Function(String targetDeviceId)? onWebRTCProbe;
  final Future<({bool success, String? lanHttpUrl, bool senderReachable})>
  Function(String targetDeviceId)?
  onLanHttpProbe;

  const ChatComposer({
    super.key,
    required this.onSend,
    required this.onAttachmentChoice,
    this.pendingFiles = const [],
    required this.onSendPendingFiles,
    required this.onRemovePendingFile,
    required this.onClearPendingFiles,
    this.onPasteFiles,
    this.onToggleDesktopSidebar,
    this.onExpandDesktopSidebar,
    this.onToggleDevicePanel,
    this.onExpandDevicePanel,
    this.onDismissDevicePanel,
    this.isDevicePanelOpen,
    this.onHeightChanged,
    this.lanReceiverUrl,
    this.onProbePull,
    this.onWebRTCProbe,
    this.onLanHttpProbe,
  });

  @override
  ConsumerState<ChatComposer> createState() => ChatComposerState();
}

class ChatComposerState extends ConsumerState<ChatComposer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const double _panelOptionIconSize = 48;
  static const double _primaryActionSize = 44;
  final _sizeKey = GlobalKey();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _panelVisible = false;
  SendShortcutMode _sendShortcutMode = sendShortcutModeNotifier.value;
  AttachmentPickerChoice? _pendingPanelChoice;

  /// Tracks when the input most recently gained focus, so we can tell a
  /// transient (implicit/native) keyboard dismiss apart from a deliberate one.
  DateTime? _focusGainedAt;

  /// Set before any intentional keyboard dismiss so the transient-hide guard
  /// never fights a user- or app-initiated dismiss.
  bool _suppressFocusReassert = false;

  /// Last keyboard inset from [didChangeMetrics]; detects IME hide while focused.
  double _previousViewInsetBottom = 0;

  /// Last time the guard reopened the keyboard; cooldown avoids reopen loops.
  DateTime? _lastKeyboardReopenAt;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static const _panelHeight = 220.0;
  late final AnimationController _panelAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 200),
  )..addStatusListener(_onPanelAnimationStatus);

  late final Animation<double> _panelCurve = CurvedAnimation(
    parent: _panelAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.linear,
  );

  void _onPanelAnimationStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.dismissed) {
      setState(() => _panelVisible = false);
      final choice = _pendingPanelChoice;
      _pendingPanelChoice = null;
      if (choice != null) {
        widget.onAttachmentChoice(choice);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sendShortcutMode = sendShortcutModeNotifier.value;
    sendShortcutModeNotifier.addListener(_onSendShortcutModeChanged);
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _onSendShortcutModeChanged() {
    if (!mounted) return;
    setState(() => _sendShortcutMode = sendShortcutModeNotifier.value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sendShortcutModeNotifier.removeListener(_onSendShortcutModeChanged);
    _panelAnimation.removeStatusListener(_onPanelAnimationStatus);
    _panelAnimation.dispose();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void unfocus() {
    _suppressFocusReassert = true;
    _focusNode.unfocus();
  }

  void dismissPanel() {
    if (_panelVisible &&
        mounted &&
        _panelAnimation.status != AnimationStatus.reverse) {
      _panelAnimation.reverse();
    }
  }

  void dismissDevicePanel() {
    if (!_isDesktop && widget.onDismissDevicePanel != null) {
      widget.onDismissDevicePanel!();
      return;
    }
  }

  void restoreDevicePanel(bool open) {
    if (!_isDesktop) return;
    if (open && widget.onExpandDesktopSidebar != null) {
      widget.onExpandDesktopSidebar!();
    }
  }

  void expandDevicePanel() {
    if (_isDesktop && widget.onExpandDesktopSidebar != null) {
      widget.onExpandDesktopSidebar!();
      return;
    }
    if (widget.onExpandDevicePanel != null) {
      widget.onExpandDevicePanel!();
      return;
    }
    _suppressFocusReassert = true;
    _focusNode.unfocus();
    if (_panelVisible) _panelAnimation.reverse();
  }

  void _onFocusChange() {
    if (!mounted) return;
    final hasFocus = _focusNode.hasFocus;
    logChat.fine('composer focus changed hasFocus=$hasFocus');
    if (hasFocus) {
      _focusGainedAt = DateTime.now();
      _suppressFocusReassert = false;
      if (_panelVisible) _panelAnimation.reverse();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;
    logChat.fine(
      'composer metrics insetBottom=$insetBottom hasFocus=${_focusNode.hasFocus}',
    );
    if (!_isDesktop &&
        !_suppressFocusReassert &&
        _focusNode.hasFocus &&
        insetBottom == 0 &&
        _previousViewInsetBottom > 0) {
      logChat.fine('composer keyboard hidden while focused');
      _maybeReopenKeyboardAfterTransientHide();
    }
    _previousViewInsetBottom = insetBottom;
  }

  /// Android may hide the soft keyboard while [FocusNode.hasFocus] stays true
  /// (IME connection dropped during list layout). Re-toggle focus to reopen.
  void _maybeReopenKeyboardAfterTransientHide() {
    if (_isDesktop) return;
    if (_suppressFocusReassert) return;
    final gainedAt = _focusGainedAt;
    if (gainedAt == null) return;
    final now = DateTime.now();
    if (now.difference(gainedAt) > const Duration(milliseconds: 500)) return;
    final last = _lastKeyboardReopenAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    if (!_focusNode.hasFocus) return;

    _lastKeyboardReopenAt = now;
    logChat.fine('composer transient keyboard hide; reopening IME');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _suppressFocusReassert) return;
      if (!_focusNode.hasFocus) return;
      _focusNode.unfocus();
      _focusNode.requestFocus();
    });
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _measure() {
    if (!mounted) return;
    final renderBox = _sizeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final height = renderBox.size.height;
      final bottomSafe = MediaQuery.of(context).padding.bottom;
      // Same convention as flutter_chat_ui Composer: list bottom spacer uses
      // ComposerHeightNotifier + MediaQuery.padding.bottom (see SliverSpacing).
      final contentHeight = height - bottomSafe;
      context.read<ComposerHeightNotifier>().setHeight(contentHeight);
      widget.onHeightChanged?.call(contentHeight.clamp(56.0, 250.0));
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    if (_isDesktop) {
      _focusNode.requestFocus();
    }
  }

  Map<ShortcutActivator, Intent> _buildSendShortcuts() {
    if (!_isDesktop) {
      return _buildMobileSendShortcuts();
    }
    if (_sendShortcutMode == SendShortcutMode.enter) {
      return <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter, shift: false):
            const _SendMessageIntent(),
      };
    }
    return <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.enter, control: true):
          const _SendMessageIntent(),
      SingleActivator(LogicalKeyboardKey.enter, meta: true):
          const _SendMessageIntent(),
    };
  }

  Map<ShortcutActivator, Intent> _buildMobileSendShortcuts() {
    return <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.enter, control: true):
          const _SendMessageIntent(),
      SingleActivator(LogicalKeyboardKey.enter, meta: true):
          const _SendMessageIntent(),
    };
  }

  void _onPlusPressed() {
    _suppressFocusReassert = true;
    _focusNode.unfocus();
    if (!_isDesktop) widget.onDismissDevicePanel?.call();
    if (_panelVisible) {
      _panelAnimation.reverse();
    } else {
      setState(() => _panelVisible = true);
      _panelAnimation.forward();
    }
  }

  Future<void> _onPanelOption(AttachmentPickerChoice choice) async {
    _pendingPanelChoice = choice;
    _panelAnimation.reverse();
  }

  Widget _buildAttachmentPanel(BuildContext context, double bottomSafe) {
    final colors = ChatColors.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final options = <_PanelItem>[
      _PanelItem(
        icon: LucideIcons.images,
        iconColor: colors.success,
        label: l10n.composerAttachImageVideo,
        choice: AttachmentPickerChoice.imageVideo,
      ),
      _PanelItem(
        icon: LucideIcons.file,
        iconColor: theme.colorScheme.primary,
        label: l10n.composerAttachFile,
        choice: AttachmentPickerChoice.file,
      ),
      if (!Platform.isIOS)
        _PanelItem(
          icon: LucideIcons.folder,
          iconColor: colors.warning,
          label: l10n.composerAttachFolder,
          choice: AttachmentPickerChoice.folder,
        ),
      if (Platform.isAndroid)
        _PanelItem(
          icon: LucideIcons.smartphone,
          iconColor: colors.success,
          label: l10n.composerAttachApk,
          choice: AttachmentPickerChoice.apk,
        ),
    ];
    return Container(
      height: _panelHeight + bottomSafe,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + bottomSafe,
      ),
      color: colors.surface,
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        physics: const NeverScrollableScrollPhysics(),
        children: options
            .map(
              (item) => _buildPanelOption(
                icon: item.icon,
                iconColor: item.iconColor,
                label: item.label,
                choice: item.choice,
                labelColor: colors.onSurface,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPanelOption({
    required IconData icon,
    required Color iconColor,
    required String label,
    required AttachmentPickerChoice choice,
    required Color labelColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onPanelOption(choice),
        borderRadius: AppRadius.small,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _panelOptionIconSize,
              height: _panelOptionIconSize,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: AppRadius.small,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: labelColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerContent(
    BuildContext context,
    ChatColors colors,
    Brightness brightness,
    ThemeData theme,
    double bottomSafe,
  ) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: AnimatedBuilder(
          animation: _panelCurve,
          builder: (context, _) {
            final l10n = AppLocalizations.of(context);
            final animValue = _panelCurve.value;
            final isAttachmentActive = _panelVisible || animValue > 0;
            return Container(
              key: _sizeKey,
              color: colors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.pendingFiles.isNotEmpty)
                    PendingFilesBar(
                      files: widget.pendingFiles,
                      onSend: widget.onSendPendingFiles,
                      onRemove: widget.onRemovePendingFile,
                      onClearAll: widget.onClearPendingFiles,
                    ),
                  Shortcuts(
                    shortcuts: _buildSendShortcuts(),
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _SendMessageIntent: CallbackAction<_SendMessageIntent>(
                          onInvoke: (_) {
                            if (_hasText) _handleSend();
                            return null;
                          },
                        ),
                      },
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.xs,
                          right: 4,
                          top: AppSpacing.xs,
                          bottom:
                              AppSpacing.xs +
                              bottomSafe * (isAttachmentActive ? 0.0 : 1.0),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.appBarForeground,
                                ),
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                keyboardAppearance: brightness,
                                decoration: InputDecoration(
                                  hintText: l10n.composerMessageHint,
                                  hintStyle: theme.textTheme.bodyMedium
                                      ?.copyWith(color: colors.inputHint),
                                  filled: true,
                                  fillColor: colors.surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 10,
                                  ),
                                  suffixIcon: _hasText
                                      ? IconButton(
                                          icon: Icon(
                                            LucideIcons.x,
                                            color: colors.muted,
                                            size: 20,
                                          ),
                                          tooltip: l10n.composerClearInputTooltip,
                                          onPressed: () {
                                            _controller.clear();
                                            _focusNode.requestFocus();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: AppRadius.pill,
                                    borderSide: BorderSide(
                                      color: context.appColors.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: AppRadius.pill,
                                    borderSide: BorderSide(
                                      color: context.appColors.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: AppRadius.pill,
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: _primaryActionSize,
                              height: _primaryActionSize,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: _hasText
                                      ? Icon(
                                          LucideIcons.send,
                                          key: const ValueKey('send'),
                                          color: colors.upload,
                                          size: 24,
                                        )
                                      : _isDesktop
                                      ? Icon(
                                          LucideIcons.paperclip,
                                          key: const ValueKey('add_file'),
                                          color: colors.muted,
                                          size: 24,
                                        )
                                      : Icon(
                                          LucideIcons.circlePlus,
                                          key: const ValueKey('add'),
                                          color: colors.muted,
                                          size: 26,
                                        ),
                                ),
                                onPressed: _hasText
                                    ? _handleSend
                                    : _isDesktop
                                    ? () => widget.onAttachmentChoice(
                                        AttachmentPickerChoice.file,
                                      )
                                    : _onPlusPressed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: isAttachmentActive
                          ? animValue.clamp(0.0, 1.0)
                          : 0.0,
                      child: isAttachmentActive
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Divider(
                                  height: 0.5,
                                  thickness: 0.5,
                                  color: colors.muted.withValues(alpha: 0.12),
                                ),
                                _buildAttachmentPanel(context, bottomSafe),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatColors.of(context);
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final content = _buildComposerContent(
      context,
      colors,
      brightness,
      theme,
      bottomSafe,
    );
    return Positioned(left: 0, right: 0, bottom: 0, child: content);
  }
}

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

class _PanelItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final AttachmentPickerChoice choice;

  _PanelItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.choice,
  });
}
