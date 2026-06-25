import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/membership.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../screens/webdav_connection_screen.dart';
import '../ui/app_ui.dart';
import '../utils/auth_route_guard.dart';
import '../utils/webdav_membership_gate.dart';
import '../widgets/webdav/webdav_connection_actions.dart';
import '../widgets/webdav/webdav_connection_item.dart';

class WebDavSettingsScreen extends ConsumerStatefulWidget {
  const WebDavSettingsScreen({super.key});

  @override
  ConsumerState<WebDavSettingsScreen> createState() =>
      _WebDavSettingsScreenState();
}

class _WebDavSettingsScreenState extends ConsumerState<WebDavSettingsScreen> {
  MembershipMe? _membership;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ensureLoggedInForRoute(context, ref)) return;
      ref.read(webDavConnectionsProvider.notifier).refresh();
      _loadMembership();
    });
  }

  Future<void> _loadMembership() async {
    try {
      final me = await fetchMyMembership();
      if (mounted) setState(() => _membership = me);
    } catch (_) {}
  }

  Future<void> _openAddConnection() async {
    if (!await ensureCanAddWebDav(context, membership: _membership)) return;
    if (!mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WebDavConnectionScreen()),
    );
    if (ok == true && mounted) {
      await ref.read(webDavConnectionsProvider.notifier).refresh();
    }
  }

  Future<void> _openMembership() async {
    await Navigator.pushNamed(context, '/settings/membership');
    if (mounted) await _loadMembership();
  }

  Future<void> _openEditConnection(int connectionId) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WebDavConnectionScreen(connectionId: connectionId),
      ),
    );
    if (ok == true && mounted) {
      await ref.read(webDavConnectionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final webDavAsync = ref.watch(webDavConnectionsProvider);
    final connections = webDavAsync.valueOrNull ?? const [];
    final canAddWebDav = membershipCanAddWebDav(_membership);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsWebDavListTitle),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: l10n.webdavAddConnection,
            onPressed: _openAddConnection,
          ),
        ],
      ),
      body: webDavAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.homeWebDavLoadFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.danger,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () =>
                      ref.read(webDavConnectionsProvider.notifier).refresh(),
                  child: Text(l10n.homeWebDavRetry),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.hardDrive,
                      size: 48,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      canAddWebDav
                          ? l10n.settingsWebDavListEmpty
                          : l10n.webdavEmptyMemberPrompt,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (canAddWebDav)
                      FilledButton.icon(
                        onPressed: _openAddConnection,
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: Text(l10n.webdavAddConnection),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _openMembership,
                        icon: const Icon(LucideIcons.crown, size: 18),
                        label: Text(l10n.webdavMemberOnlyAction),
                      ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(webDavConnectionsProvider.notifier).refresh();
              await _loadMembership();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final conn = items[index];
                return WebDavConnectionItem(
                  key: ValueKey('settings_webdav_${conn.id}'),
                  connection: conn,
                  onTap: () => _openEditConnection(conn.id),
                  onMore: () => showWebDavConnectionMenu(context, ref, conn),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: connections.isNotEmpty
          ? FloatingActionButton(
              onPressed: _openAddConnection,
              tooltip: l10n.webdavAddConnection,
              child: const Icon(LucideIcons.plus),
            )
          : null,
    );
  }
}
