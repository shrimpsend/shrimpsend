import 'package:feedmatter_flutter_sdk/feedmatter_flutter_sdk.dart' as fm;
import 'package:feedmatter_flutter_ui/feedmatter_flutter_ui.dart';
// ignore: implementation_imports
import 'package:feedmatter_flutter_ui/src/widgets/feedmatter_help_tips_sheet.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Host shell for FeedMatter feedback: inner [Navigator] keeps sub-routes inside
/// the themed route, and the AppBar exposes an explicit back button.
class FeedmatterFeedbackScreen extends StatefulWidget {
  const FeedmatterFeedbackScreen({super.key, required this.options});

  final FeedMatterUiOptions options;

  @override
  State<FeedmatterFeedbackScreen> createState() =>
      _FeedmatterFeedbackScreenState();
}

class _FeedmatterFeedbackScreenState extends State<FeedmatterFeedbackScreen> {
  final _innerNavigatorKey = GlobalKey<NavigatorState>();
  final _homeKey = GlobalKey<FeedMatterHomePageState>();

  fm.ProjectConfig _config = fm.ProjectConfig.defaultConfig();
  bool _loadingConfig = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final config = await fm.FeedMatterClient.instance.getProjectConfig();
      if (mounted) setState(() => _config = config);
    } catch (e) {
      if (mounted) {
        showFeedMatterSnackBar(context, '项目配置加载失败：$e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _openSubmitPage() async {
    if (!_config.feedbackEnabled) {
      showFeedMatterSnackBar(context, '当前项目已关闭反馈发布', isError: true);
      return;
    }
    final navigator = _innerNavigatorKey.currentState;
    if (navigator == null) return;

    final created = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => FeedMatterSubmitPage(
          config: _config,
          options: widget.options,
        ),
      ),
    );
    if (created == true && mounted) {
      await _homeKey.currentState?.reload();
    }
  }

  Future<void> _openFaqPage() async {
    final navigator = _innerNavigatorKey.currentState;
    if (navigator == null) return;

    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => FeedMatterFaqPage(
          config: _config,
          options: widget.options,
          onSubmitFeedback: _openSubmitPage,
        ),
      ),
    );
  }

  void _onHelpTap() {
    final handler = widget.options.onHelpTap;
    if (handler != null) {
      handler();
      return;
    }
    showFeedMatterHelpTipsSheet(context, theme: widget.options.theme);
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) return;
    _popHostOrInner();
  }

  void _popHostOrInner() {
    final innerNav = _innerNavigatorKey.currentState;
    if (innerNav != null && innerNav.canPop()) {
      innerNav.pop();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FeedMatterUiTheme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_loadingConfig) {
      return Scaffold(
        backgroundColor: theme.pageBackground,
        appBar: AppBar(
          backgroundColor: theme.surfaceColor,
          foregroundColor: theme.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: BackButton(onPressed: _popHostOrInner),
          title: Text(
            l10n.settingsFeedbackLabel,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _handlePopInvoked(didPop);
      },
      child: Navigator(
        key: _innerNavigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => _buildHomeShell(context, l10n),
          );
        },
      ),
    );
  }

  Widget _buildHomeShell(BuildContext context, AppLocalizations l10n) {
    final theme = FeedMatterUiTheme.of(context);

    return Scaffold(
      backgroundColor: theme.pageBackground,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        foregroundColor: theme.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(onPressed: _popHostOrInner),
        title: Text(
          l10n.settingsFeedbackLabel,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _onHelpTap,
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: _FeedbackBottomActionOverlay(
        leftAction: _config.faqEnabled
            ? _FeedbackBottomPill(
                onPressed: _openFaqPage,
                label: '常见问题',
                icon: Icons.quiz_outlined,
              )
            : null,
        rightAction: _FeedbackSubmitFab(onPressed: _openSubmitPage),
        child: FeedMatterHomePage(
          key: _homeKey,
          options: widget.options,
          embedded: true,
          showFloatingSubmit: false,
        ),
      ),
    );
  }
}

class _FeedbackBottomActionOverlay extends StatelessWidget {
  const _FeedbackBottomActionOverlay({
    required this.child,
    this.leftAction,
    this.rightAction,
  });

  final Widget child;
  final Widget? leftAction;
  final Widget? rightAction;

  @override
  Widget build(BuildContext context) {
    final hasActions = leftAction != null || rightAction != null;
    if (!hasActions) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (leftAction != null) leftAction!,
                const Spacer(),
                if (rightAction != null) rightAction!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackBottomPill extends StatelessWidget {
  const _FeedbackBottomPill({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = FeedMatterUiTheme.of(context);
    final enabled = onPressed != null;

    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(theme.fabRadius),
      color: enabled ? theme.surfaceColor : theme.surfaceColor.withAlpha(180),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(theme.fabRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.textPrimary, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackSubmitFab extends StatelessWidget {
  const _FeedbackSubmitFab({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FeedMatterUiTheme.of(context);

    return Material(
      elevation: 4,
      shadowColor: theme.primaryBlue.withAlpha(80),
      borderRadius: BorderRadius.circular(theme.fabRadius),
      color: onPressed == null
          ? theme.primaryBlue.withAlpha(128)
          : theme.primaryBlue,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(theme.fabRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                '提交反馈',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
