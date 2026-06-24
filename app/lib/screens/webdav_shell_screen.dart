import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import 'webdav_files_tab.dart';
import 'webdav_recent_favorites_tab.dart';
import 'webdav_settings_tab.dart';
import 'webdav_transfer_list_screen.dart';

class WebDavShellScreen extends ConsumerStatefulWidget {
  final WebDavConnectionSummary connection;

  const WebDavShellScreen({super.key, required this.connection});

  @override
  ConsumerState<WebDavShellScreen> createState() => _WebDavShellScreenState();
}

class _WebDavShellScreenState extends ConsumerState<WebDavShellScreen> {
  WebDavClient? _client;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  int _activeTransfers = 0;
  final _filesTabKey = GlobalKey<WebDavFilesTabState>();
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _init();
    WebDavTransferService.instance.addListener(_onTransferUpdate);
  }

  @override
  void dispose() {
    WebDavTransferService.instance.removeListener(_onTransferUpdate);
    super.dispose();
  }

  void _onTransferUpdate() {
    if (!mounted) return;
    final count = WebDavTransferService.instance.activeCountFor(
      widget.connection.id,
    );
    if (count != _activeTransfers) {
      setState(() => _activeTransfers = count);
    }
  }

  Future<void> _refreshTransferCount() async {
    final count = WebDavTransferService.instance.activeCountFor(
      widget.connection.id,
    );
    if (!mounted) return;
    setState(() => _activeTransfers = count);
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final creds = await resolveWebDavCredentials(widget.connection.id);
      _client = WebDavClient(creds);
      await WebDavTransferService.instance.restorePersistedSnapshots(
        widget.connection.id,
      );
      await _refreshTransferCount();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _switchToFilesTab({String? path}) {
    setState(() => _tabIndex = 0);
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filesTabKey.currentState?.navigateToPath(path);
      });
    }
  }

  Future<void> _openFileFromOtherTab(WebDavEntry entry) async {
    _switchToFilesTab();
    await WebDavTransferService.instance.enqueueDownloads(
      client: _client!,
      connection: widget.connection,
      entries: [entry],
    );
    await _refreshTransferCount();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.connection.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _client == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.connection.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Error', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _init,
                  child: Text(l10n.connectionBarRefreshOnlineStatus),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final client = _client!;
    final filesState = _filesTabKey.currentState;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabIndex == 0 ? widget.connection.name : _tabTitle(l10n),
        ),
        actions: [
          if (_activeTransfers > 0)
            IconButton(
              icon: Badge(
                label: Text('$_activeTransfers'),
                child: const Icon(LucideIcons.activity),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebDavTransferListScreen(
                      connection: widget.connection,
                    ),
                  ),
                );
              },
            ),
          if (_tabIndex == 0) ...[
            IconButton(
              icon: Icon(
                filesState?.isSelectionMode == true
                    ? LucideIcons.x
                    : LucideIcons.checkSquare,
              ),
              onPressed: () => filesState?.toggleSelectionMode(),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          WebDavFilesTab(
            key: _filesTabKey,
            connection: widget.connection,
            client: client,
            initialPath: _currentPath,
            onPathChanged: (p) => _currentPath = p,
            onTransfersChanged: _refreshTransferCount,
          ),
          WebDavRecentTab(
            connection: widget.connection,
            client: client,
            onOpenFolder: (path) => _switchToFilesTab(path: path),
            onOpenFile: _openFileFromOtherTab,
          ),
          WebDavFavoritesTab(
            connection: widget.connection,
            client: client,
            onOpenFolder: (path) => _switchToFilesTab(path: path),
            onOpenFile: _openFileFromOtherTab,
          ),
          WebDavSettingsTab(
            connection: widget.connection,
            activeTransferCount: _activeTransfers,
            onSwitchConnection: () => Navigator.pop(context),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0 && filesState?.isSelectionMode != true
          ? FloatingActionButton(
              onPressed: () => filesState?.showAddSheet(),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.folder),
            label: l10n.webdavTabFiles,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.clock),
            label: l10n.webdavTabRecent,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.star),
            label: l10n.webdavTabFavorites,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.settings),
            label: l10n.webdavTabSettings,
          ),
        ],
      ),
    );
  }

  String _tabTitle(AppLocalizations l10n) {
    return switch (_tabIndex) {
      1 => l10n.webdavTabRecent,
      2 => l10n.webdavTabFavorites,
      3 => l10n.webdavTabSettings,
      _ => widget.connection.name,
    };
  }
}
