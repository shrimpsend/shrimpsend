import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/app_ui.dart';

class ApkPickResult {
  final String path;
  final String displayName;
  const ApkPickResult({required this.path, required this.displayName});
}

const _apkChannel = MethodChannel('dev.ultrasend/apk');

Future<String?> _getApkPath(String packageName) async {
  try {
    return await _apkChannel.invokeMethod<String>('getApkPath', {
      'packageName': packageName,
    });
  } catch (_) {
    return null;
  }
}

class ApkPickerScreen extends StatefulWidget {
  const ApkPickerScreen({super.key});

  @override
  State<ApkPickerScreen> createState() => _ApkPickerScreenState();
}

class _ApkPickerScreenState extends State<ApkPickerScreen> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  bool _includeSystem = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: !_includeSystem,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );

      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _apps = apps;
          _filteredApps = apps;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).apkPickerLoadFailed('$e');
          _loading = false;
        });
      }
    }
  }

  void _filterApps(String query) {
    final q = query.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredApps = _apps;
      } else {
        _filteredApps = _apps
            .where(
              (app) =>
                  app.name.toLowerCase().contains(q) ||
                  app.packageName.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  void _toggleSelect(String packageName) {
    setState(() {
      if (_selected.contains(packageName)) {
        _selected.remove(packageName);
      } else {
        _selected.add(packageName);
      }
    });
  }

  Future<void> _confirm() async {
    final entries = <ApkPickResult>[];
    for (final pkgName in _selected) {
      final apkPath = await _getApkPath(pkgName);
      if (apkPath == null) continue;
      final app = _apps.where((a) => a.packageName == pkgName).firstOrNull;
      final displayName = app != null
          ? '${app.name}_${app.versionName}.apk'
          : '${pkgName.split('.').last}.apk';
      entries.add(ApkPickResult(path: apkPath, displayName: displayName));
    }
    if (mounted) {
      Navigator.pop(context, entries);
    }
  }

  Future<void> _pickApkFromFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final entries = result.files
        .where((f) => f.path != null && f.size > 0)
        .map((f) => ApkPickResult(path: f.path!, displayName: f.name))
        .toList();
    if (entries.isNotEmpty) {
      Navigator.pop(context, entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.apkPickerTitle),
        actions: [
          IconButton(
            onPressed: _pickApkFromFiles,
            icon: const Icon(LucideIcons.folderOpen),
            tooltip: l10n.apkPickerTooltipBrowseFiles,
          ),
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(
                l10n.apkPickerConfirmCount(_selected.length),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.apkPickerLoadingInstalled,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildEmptyOrError(context, _error!);
    }

    if (_apps.isEmpty) {
      return _buildEmptyOrError(context, l10n.apkPickerEmptyOrError);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxs,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _filterApps,
            decoration: InputDecoration(
              hintText: l10n.apkPickerSearchHint,
              prefixIcon: Icon(
                LucideIcons.search,
                color: colors.textSecondary,
                size: 20,
              ),
              filled: true,
              fillColor: colors.surfaceMuted,
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.small,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.small,
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            children: [
              Text(
                l10n.apkPickerAppCount(_filteredApps.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _includeSystem = !_includeSystem);
                  _loadApps();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _includeSystem
                          ? LucideIcons.squareCheck
                          : LucideIcons.square,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      l10n.apkPickerSystemApp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: Text(
                    l10n.apkPickerClearSelection,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredApps.length,
            itemBuilder: (context, index) {
              final app = _filteredApps[index];
              final isSelected = _selected.contains(app.packageName);

              return ListTile(
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: app.icon != null
                      ? ClipRRect(
                          borderRadius: AppRadius.small,
                          child: Image.memory(app.icon!, width: 40, height: 40),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: AppRadius.small,
                          ),
                          child: Icon(
                            LucideIcons.smartphone,
                            color: colors.success,
                            size: 24,
                          ),
                        ),
                ),
                title: Text(
                  app.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'v${app.versionName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        LucideIcons.circleCheck,
                        color: theme.colorScheme.primary,
                        size: 22,
                      )
                    : Icon(
                        LucideIcons.circle,
                        color: colors.textSecondary,
                        size: 22,
                      ),
                onTap: () => _toggleSelect(app.packageName),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 2,
                ),
              );
            },
          ),
        ),
        if (_selected.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: colors.surface,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
                  child: Text(
                    l10n.apkPickerConfirmSendMany(_selected.length),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyOrError(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.layoutGrid, color: colors.textSecondary, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pickApkFromFiles,
                icon: const Icon(LucideIcons.folderOpen, size: 18),
                label: Text(l10n.apkPickerFromFiles),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadApps,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(l10n.apkPickerReloadApps),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
