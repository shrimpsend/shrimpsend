import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/speed_tracker.dart';
import '../services/transfer_record.dart';
import '../services/transfer_state_manager.dart';
import '../services/transfer_status.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../providers/webdav_provider.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../widgets/file_icon_widget.dart';

class WebDavTransferListScreen extends StatefulWidget {
  final WebDavConnectionSummary connection;

  const WebDavTransferListScreen({super.key, required this.connection});

  @override
  State<WebDavTransferListScreen> createState() =>
      _WebDavTransferListScreenState();
}

class _WebDavTransferListScreenState extends State<WebDavTransferListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  WebDavClient? _client;
  List<TransferRecord> _persisted = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
    WebDavTransferService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    WebDavTransferService.instance.removeListener(_refresh);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final creds = await resolveWebDavCredentials(widget.connection.id);
      _client = WebDavClient(creds);
    } catch (_) {}
    await _refresh();
  }

  Future<void> _refresh() async {
    final rows = await TransferStateManager.instance.listWebDavTransfers(
      connectionId: webDavConnectionKey(widget.connection.id),
      activeOnly: true,
    );
    if (!mounted) return;
    setState(() {
      _persisted = rows;
      _loading = false;
    });
  }

  List<WebDavTransferSnapshot> _liveFor(String direction) {
    return WebDavTransferService.instance.allSnapshots
        .where(
          (s) =>
              s.direction == direction &&
              s.transferId.startsWith(
                'webdav_${webDavConnectionKey(widget.connection.id)}_',
              ),
        )
        .toList();
  }

  List<TransferRecord> _persistedFor(String direction) {
    return _persisted.where((r) => r.direction == direction).toList();
  }

  Future<void> _pauseAll() async {
    await WebDavTransferService.instance.pauseAll(widget.connection.id);
    await _refresh();
  }

  Future<void> _terminateAll() async {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.webdavTransferTerminateConfirmTitle),
        content: Text(l10n.webdavTransferTerminateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(l10n.webdavTransferTerminateAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await WebDavTransferService.instance.terminateAllUploads(
      widget.connection.id,
    );
    await _refresh();
  }

  Future<void> _resume(TransferRecord record) async {
    final client = _client;
    if (client == null) return;
    if (record.direction == 'download') {
      await WebDavTransferService.instance.resumeDownload(
        client: client,
        connection: widget.connection,
        record: record,
      );
    } else {
      await WebDavTransferService.instance.resumeUpload(
        client: client,
        connection: widget.connection,
        record: record,
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.webdavTransferList),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.webdavTransferUploading),
            Tab(text: l10n.webdavTransferDownloading),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(
                  direction: 'upload',
                  l10n: l10n,
                  colors: colors,
                  theme: theme,
                ),
                _buildList(
                  direction: 'download',
                  l10n: l10n,
                  colors: colors,
                  theme: theme,
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pauseAll,
                  child: Text(l10n.webdavTransferPauseAll),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _terminateAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.danger,
                    side: BorderSide(color: colors.danger),
                  ),
                  child: Text(l10n.webdavTransferTerminateAll),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required String direction,
    required AppLocalizations l10n,
    required AppThemeColors colors,
    required ThemeData theme,
  }) {
    final live = _liveFor(direction);
    final persisted = _persistedFor(direction);
    final liveIds = live.map((s) => s.transferId).toSet();
    final merged = [
      ...live,
      ...persisted
          .where((r) => !liveIds.contains(r.transferId))
          .map(
            (r) => WebDavTransferSnapshot(
              transferId: r.transferId,
              fileName: r.fileName,
              fileSize: r.fileSize,
              transferredBytes: r.transferredBytes,
              direction: r.direction,
              status: r.status,
              bytesPerSecond: 0,
              webdavRemotePath: r.webdavRemotePath,
            ),
          ),
    ];

    if (merged.isEmpty) {
      return Center(child: Text(l10n.webdavTransferEmpty));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: merged.length,
        itemBuilder: (context, index) {
          final item = merged[index];
          final pct = item.progressPercent;
          final speed = item.bytesPerSecond > 0
              ? SpeedTracker.formatSpeed(item.bytesPerSecond)
              : '';
          final isPaused = TransferStatus.isUserPaused(item.status);
          final record = persisted.cast<TransferRecord?>().firstWhere(
                (r) => r?.transferId == item.transferId,
                orElse: () => null,
              );

          return ListTile(
            leading: FileIconWidget(
              category: getFileCategory(item.fileName),
              size: 28,
            ),
            title: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(value: pct / 100),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$pct%${speed.isNotEmpty ? ' · $speed' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            trailing: item.status == TransferStatus.inProgress
                ? IconButton(
                    icon: const Icon(LucideIcons.pause),
                    onPressed: () =>
                        WebDavTransferService.instance.pause(item.transferId),
                  )
                : isPaused && record != null
                ? IconButton(
                    icon: const Icon(LucideIcons.play),
                    onPressed: () => _resume(record),
                  )
                : null,
          );
        },
      ),
    );
  }
}
