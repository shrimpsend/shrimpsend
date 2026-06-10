import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../l10n/generated/app_localizations.dart';
import '../logger.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';
import '../utils/auth_route_guard.dart';
import '../utils/file_utils.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';

const _defaultRegion = 'cn-east-1';

class S3SettingsScreen extends ConsumerStatefulWidget {
  const S3SettingsScreen({super.key});

  @override
  ConsumerState<S3SettingsScreen> createState() => _S3SettingsScreenState();
}

class _S3SettingsScreenState extends ConsumerState<S3SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController(text: _defaultRegion);
  final _bucketController = TextEditingController();
  final _accessKeyIdController = TextEditingController();
  final _secretAccessKeyController = TextEditingController();

  S3StorageMode _mode = S3StorageMode.disabled;
  bool _hostedAvailable = false;
  bool _customSaved = false;
  MembershipMe? _membership;

  /// HOSTED 模式下，用户点击「切换为自建 S3」后展开表单。
  bool _customFormRevealed = false;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _switchingBack = false;
  bool _switchingToCustom = false;
  bool _clearing = false;
  bool _obscureSecret = true;
  bool _pathStyleAccessEnabled = true;
  String? _errorMessage;
  String? _documentationUrl;

  void _onSummaryFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _isCustom => _mode == S3StorageMode.custom;
  bool get _isHosted => _mode == S3StorageMode.hosted;
  bool get _isDisabled => _mode == S3StorageMode.disabled;

  /// 是否需要在页面上呈现自建 S3 配置表单。
  /// - DISABLED：必须显示（这是用户唯一的开通入口）。
  /// - CUSTOM：必须显示（编辑现有配置）。
  /// - HOSTED：仅在用户点击「切换为自建 S3」后显示。
  bool get _showCustomForm => _isCustom || _isDisabled || _customFormRevealed;

  @override
  void initState() {
    super.initState();
    _endpointController.addListener(_onSummaryFieldChanged);
    _bucketController.addListener(_onSummaryFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ensureLoggedInForRoute(context, ref)) return;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        getS3Config(),
        fetchMyMembership()
            .then<MembershipMe?>((v) => v)
            .catchError((_) => null),
      ]);
      final detail = results[0] as S3ConfigDetail;
      final membership = results[1] as MembershipMe?;
      logSettings.info(
        's3_settings load mode=${detail.mode.name} hostedAvailable=${detail.hostedAvailable}',
      );
      if (mounted) {
        setState(() {
          _mode = detail.mode;
          _hostedAvailable = detail.hostedAvailable;
          _customSaved = detail.customSaved;
          _membership = membership;
          _documentationUrl = detail.documentationUrl;
          _customFormRevealed = false;
          if (detail.mode == S3StorageMode.custom) {
            _endpointController.text = detail.endpoint ?? '';
            _regionController.text = detail.region ?? _defaultRegion;
            _bucketController.text = detail.bucket ?? '';
            _accessKeyIdController.text = detail.accessKeyId ?? '';
            _pathStyleAccessEnabled = detail.pathStyleAccessEnabled ?? true;
          } else {
            _pathStyleAccessEnabled = true;
            _endpointController.clear();
            _regionController.text = _defaultRegion;
            _bucketController.clear();
            _accessKeyIdController.clear();
            _secretAccessKeyController.clear();
          }
        });
      }
    } catch (e) {
      logSettings.warning('s3_settings load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openS3Documentation() async {
    final url = _documentationUrl?.trim();
    final l10n = AppLocalizations.of(context);
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.s3SettingsDocsUnavailable);
      return;
    }
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      logSettings.warning('s3_settings open docs failed: $e');
      if (!mounted) return;
      AppToast.show(context, message: l10n.s3SettingsDocsUnavailable);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    logSettings.info('s3_settings save');
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final endpoint = _endpointController.text.trim();
      final region = _regionController.text.trim().isEmpty
          ? _defaultRegion
          : _regionController.text.trim();
      final bucket = _bucketController.text.trim();
      final accessKeyId = _accessKeyIdController.text.trim();
      final secretAccessKey = _secretAccessKeyController.text.trim();

      await saveS3Config(
        S3ConfigRequest(
          endpoint: endpoint,
          region: region,
          bucket: bucket,
          accessKeyId: accessKeyId,
          secretAccessKey: secretAccessKey,
          pathStyleAccessEnabled: _pathStyleAccessEnabled,
        ),
      );

      if (mounted) {
        setState(() {
          _mode = S3StorageMode.custom;
          _customFormRevealed = false;
          _secretAccessKeyController.clear();
        });
      }
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).s3SettingsSaved,
        );
      }
      logSettings.info('s3_settings save success');
      Analytics.track(AnalyticsEvents.s3SettingsSave, {'result': 'success'});
    } catch (e) {
      logSettings.warning('s3_settings save failed: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
      Analytics.track(AnalyticsEvents.s3SettingsSave, {'result': 'fail'});
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _test() async {
    logSettings.info('s3_settings test mode=${_mode.name}');
    setState(() {
      _testing = true;
      _errorMessage = null;
    });
    try {
      await testS3Config();
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).s3SettingsTestOk,
        );
      }
      logSettings.info('s3_settings test success');
    } catch (e) {
      logSettings.warning('s3_settings test failed: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<void> _confirmClearForm() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.s3SettingsClearTitle,
      content: l10n.s3SettingsClearBody,
      confirmLabel: l10n.s3SettingsClearConfirm,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (confirmed && mounted) await _clearForm();
  }

  Future<void> _clearForm() async {
    setState(() {
      _clearing = true;
      _errorMessage = null;
    });
    try {
      await clearS3Config();
      if (!mounted) return;
      _resetFormFields();
      _formKey.currentState?.reset();
      if (!mounted) return;
      setState(() {
        _mode = S3StorageMode.disabled;
        _customFormRevealed = false;
        _errorMessage = null;
      });
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).s3SettingsCleared,
        );
      }
      logSettings.info('s3_settings clear success');
    } catch (e) {
      logSettings.warning('s3_settings clear failed: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
    if (mounted) setState(() => _clearing = false);
  }

  Future<void> _confirmSwitchBackToHosted() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.s3SettingsSwitchBackTitle,
      content: l10n.s3SettingsSwitchBackBody,
      confirmLabel: l10n.s3SettingsSwitchBackConfirm,
      icon: LucideIcons.cloud,
    );
    if (confirmed && mounted) await _switchBackToHosted();
  }

  Future<void> _switchBackToHosted() async {
    setState(() {
      _switchingBack = true;
      _errorMessage = null;
    });
    try {
      // 仅切换偏好，后端保留 BYO 凭证以便后续一键切回
      await useHostedS3();
      if (!mounted) return;
      _resetFormFields();
      _formKey.currentState?.reset();
      setState(() {
        _mode = S3StorageMode.hosted;
        _customSaved = true;
        _customFormRevealed = false;
        _errorMessage = null;
      });
      AppToast.show(
        context,
        message: AppLocalizations.of(context).s3SettingsSwitchedBackOk,
      );
      logSettings.info('s3_settings switch back to hosted success');
    } catch (e) {
      logSettings.warning('s3_settings switch back failed: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
    if (mounted) setState(() => _switchingBack = false);
  }

  /// HOSTED 模式下，若后端保留了之前保存的 BYO 凭证，一键切回。
  Future<void> _switchToSavedCustom() async {
    setState(() {
      _switchingToCustom = true;
      _errorMessage = null;
    });
    try {
      await useCustomS3();
      await getS3Config();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      AppToast.show(
        context,
        message: AppLocalizations.of(context).s3SettingsSwitchedToCustomOk,
      );
      logSettings.info('s3_settings switch to saved custom success');
    } catch (e) {
      logSettings.warning('s3_settings switch to custom failed: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
    if (mounted) setState(() => _switchingToCustom = false);
  }

  void _resetFormFields() {
    _endpointController.clear();
    _regionController.text = _defaultRegion;
    _bucketController.clear();
    _accessKeyIdController.clear();
    _secretAccessKeyController.clear();
    _pathStyleAccessEnabled = true;
  }

  static String _displayEndpointHost(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    try {
      final uri = Uri.parse(t.contains('://') ? t : 'https://$t');
      if (uri.hasAuthority && uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return t;
  }

  @override
  void dispose() {
    _endpointController.removeListener(_onSummaryFieldChanged);
    _bucketController.removeListener(_onSummaryFieldChanged);
    _endpointController.dispose();
    _regionController.dispose();
    _bucketController.dispose();
    _accessKeyIdController.dispose();
    _secretAccessKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);

    final showCustomForm = _showCustomForm;
    final showClearAction = _isCustom && !_hostedAvailable;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.s3SettingsPageTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bookOpen),
            tooltip: l10n.s3SettingsDocsTooltip,
            onPressed: _loading ? null : _openS3Documentation,
          ),
          if (showClearAction)
            TextButton(
              onPressed: (_loading || _clearing) ? null : _confirmClearForm,
              child: Text(
                _clearing
                    ? l10n.s3SettingsClearing
                    : l10n.s3SettingsClearConfirm,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.formMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  children: [
                    Text(
                      l10n.s3SettingsIntro,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_isHosted) _buildHostedCard(context, l10n),
                    if (_isCustom) ...[
                      _buildCustomConfiguredBanner(context, l10n),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_isDisabled) ...[
                      _buildInfoBanner(
                        context,
                        text: l10n.s3SettingsDisabledHint,
                        success: false,
                        icon: LucideIcons.info,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (showCustomForm) _buildCustomFormCard(context, l10n),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHostedCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(
                    LucideIcons.cloud,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.s3SettingsHostedTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.s3SettingsHostedBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_membership?.hostedUploadQuotaBytes != null &&
                _membership?.hostedUploadUsedBytes != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildHostedUsage(
                context,
                l10n,
                used: _membership!.hostedUploadUsedBytes!,
                quota: _membership!.hostedUploadQuotaBytes!,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _customFormRevealed
                ? TextButton(
                    onPressed: () => setState(() => _customFormRevealed = false),
                    child: Text(l10n.s3SettingsCollapseCustomForm),
                  )
                : (_customSaved
                    ? OutlinedButton.icon(
                        onPressed: _switchingToCustom ? null : _switchToSavedCustom,
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: Text(
                          _switchingToCustom
                              ? l10n.s3SettingsSwitching
                              : l10n.s3SettingsUseSavedCustom,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => setState(() => _customFormRevealed = true),
                        icon: const Icon(LucideIcons.settings2, size: 16),
                        label: Text(l10n.s3SettingsSwitchToCustom),
                      )),
          ],
        ),
      ),
    );
  }

  Widget _buildHostedUsage(
    BuildContext context,
    AppLocalizations l10n, {
    required int used,
    required int quota,
  }) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scheme = theme.colorScheme;
    final ratio = quota > 0 ? (used / quota).clamp(0.0, 1.0) : 0.0;
    final overQuota = quota > 0 && used >= quota;
    final progressColor = overQuota
        ? colors.danger
        : (ratio >= 0.85 ? colors.warning : scheme.primary);
    final summary = quota > 0
        ? l10n.s3SettingsHostedUsageMonthly(
            formatFileSize(used),
            formatFileSize(quota),
          )
        : l10n.s3SettingsHostedUsageMonthlyUnlimited(formatFileSize(used));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.s3SettingsHostedUsageLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              summary,
              style: theme.textTheme.labelMedium?.copyWith(
                color: overQuota ? colors.danger : colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.small,
          child: LinearProgressIndicator(
            value: quota > 0 ? ratio : null,
            minHeight: 6,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.s3SettingsHostedUsageHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomConfiguredBanner(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final epHost = _displayEndpointHost(_endpointController.text);
    final bucketTrim = _bucketController.text.trim();
    final summaryText = epHost.isEmpty && bucketTrim.isEmpty
        ? null
        : bucketTrim.isEmpty
            ? epHost
            : l10n.s3SettingsConfiguredSummary(epHost, bucketTrim);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoBanner(
          context,
          text: l10n.s3SettingsCustomConfiguredHint,
          success: true,
        ),
        if (summaryText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            summaryText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomFormCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.s3SettingsSectionConnection,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLabel(context, l10n.s3SettingsFieldEndpoint),
              const SizedBox(height: AppSpacing.xs),
              _buildTextField(
                controller: _endpointController,
                hint: l10n.s3SettingsPlaceholderEndpoint,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.s3SettingsRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLabel(context, l10n.s3SettingsFieldRegion),
              const SizedBox(height: AppSpacing.xs),
              _buildTextField(
                controller: _regionController,
                hint: l10n.s3SettingsPlaceholderRegion,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLabel(context, l10n.s3SettingsFieldBucket),
              const SizedBox(height: AppSpacing.xs),
              _buildTextField(
                controller: _bucketController,
                hint: l10n.s3SettingsPlaceholderBucket,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.s3SettingsRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.s3SettingsFieldPathStyle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.s3SettingsPathStyleHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                value: _pathStyleAccessEnabled,
                onChanged: (v) => setState(() => _pathStyleAccessEnabled = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.s3SettingsSectionCredentials,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLabel(context, l10n.s3SettingsFieldAccessKeyId),
              const SizedBox(height: AppSpacing.xs),
              _buildTextField(
                controller: _accessKeyIdController,
                hint: l10n.s3SettingsPlaceholderAccessKeyId,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.s3SettingsRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLabel(context, l10n.s3SettingsFieldSecretAccessKey),
              const SizedBox(height: AppSpacing.xs),
              _buildSecretField(context, l10n),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving ? l10n.s3SettingsSaving : l10n.s3SettingsSave,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: (_testing || !_isCustom) ? null : _test,
                child: Text(
                  _testing
                      ? l10n.s3SettingsTesting
                      : l10n.s3SettingsTestConnection,
                ),
              ),
              if (_isCustom && _hostedAvailable) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _switchingBack ? null : _confirmSwitchBackToHosted,
                  icon: const Icon(LucideIcons.cloud, size: 16),
                  label: Text(
                    _switchingBack
                        ? l10n.s3SettingsSwitching
                        : l10n.s3SettingsSwitchBackToHosted,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildInfoBanner(
                  context,
                  text: _errorMessage!,
                  success: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: context.appColors.textSecondary),
    );
  }

  Widget _buildInfoBanner(
    BuildContext context, {
    required String text,
    required bool success,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final foreground = success ? colors.success : colors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: success ? colors.successSurface : colors.dangerSurface,
        borderRadius: AppRadius.small,
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ??
                (success ? LucideIcons.circleCheck : LucideIcons.circleAlert),
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(hintText: hint),
      validator: validator,
    );
  }

  Widget _buildSecretField(BuildContext context, AppLocalizations l10n) {
    return TextFormField(
      controller: _secretAccessKeyController,
      obscureText: _obscureSecret,
      decoration: InputDecoration(
        hintText: _isCustom ? l10n.s3SettingsSecretHintIfConfigured : null,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureSecret ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 20,
          ),
          onPressed: () {
            setState(() => _obscureSecret = !_obscureSecret);
          },
        ),
      ),
      validator: _isCustom
          ? null
          : (v) => (v == null || v.trim().isEmpty)
                ? l10n.s3SettingsRequired
                : null,
    );
  }
}
