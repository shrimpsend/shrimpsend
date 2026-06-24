import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/webdav_credential_store.dart';
import '../ui/app_ui.dart';
import '../utils/auth_route_guard.dart';
import '../utils/toast.dart';

class WebDavConnectionScreen extends ConsumerStatefulWidget {
  final int? connectionId;

  const WebDavConnectionScreen({super.key, this.connectionId});

  @override
  ConsumerState<WebDavConnectionScreen> createState() =>
      _WebDavConnectionScreenState();
}

class _WebDavConnectionScreenState extends ConsumerState<WebDavConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootPathController = TextEditingController(text: '/');

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isEdit => widget.connectionId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ensureLoggedInForRoute(context, ref)) return;
      if (_isEdit) {
        _loadMeta();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final meta = await getWebDavConnectionMeta(widget.connectionId!);
      final creds = await fetchWebDavCredentials(widget.connectionId!);
      if (!mounted) return;
      setState(() {
        _nameController.text = meta.name;
        _urlController.text = meta.baseUrl;
        _usernameController.text = creds.username;
        _rootPathController.text = meta.rootPath;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPathController.dispose();
    super.dispose();
  }

  WebDavConnectionRequest _buildRequest() {
    return WebDavConnectionRequest(
      name: _nameController.text.trim(),
      baseUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rootPath: _rootPathController.text.trim().isEmpty
          ? '/'
          : _rootPathController.text.trim(),
    );
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _passwordController.text.isEmpty) {
      AppToast.show(context, message: AppLocalizations.of(context).webdavPasswordRequired);
      return;
    }
    setState(() => _testing = true);
    final l10n = AppLocalizations.of(context);
    try {
      final result = _isEdit && _passwordController.text.isEmpty
          ? await testWebDavConnection(widget.connectionId!)
          : await testWebDavConnectionDraft(_buildRequest());
      if (!mounted) return;
      AppToast.show(
        context,
        message: result.ok ? l10n.webdavTestSuccess : result.message,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavTestFailed('$e'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _passwordController.text.isEmpty) {
      AppToast.show(context, message: AppLocalizations.of(context).webdavPasswordRequired);
      return;
    }
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      if (_isEdit) {
        await updateWebDavConnection(widget.connectionId!, _buildRequest());
        await WebDavCredentialStore.instance.remove(widget.connectionId!);
      } else {
        await createWebDavConnection(_buildRequest());
      }
      await ref.read(webDavConnectionsProvider.notifier).refresh();
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavSavedToast);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavSaveFailed('$e'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.webdavEditConnection : l10n.webdavAddConnection),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colors.danger),
                        ),
                      ),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.webdavFormName),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.webdavFormNameRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(labelText: l10n.webdavFormUrl),
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.webdavFormUrlRequired;
                        }
                        final t = v.trim();
                        if (!t.startsWith('http://') && !t.startsWith('https://')) {
                          return l10n.webdavFormUrlInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: l10n.webdavFormUsername),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.webdavFormUsernameRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: l10n.webdavFormPassword,
                        hintText: _isEdit ? l10n.webdavFormPasswordHintEdit : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _rootPathController,
                      decoration: InputDecoration(labelText: l10n.webdavFormRootPath),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton.icon(
                      onPressed: _testing ? null : _test,
                      icon: _testing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(LucideIcons.plugZap, size: 18),
                      label: Text(l10n.webdavTestConnection),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.confirm),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
