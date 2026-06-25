import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/webdav.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/webdav_session.dart';
import '../../ui/app_ui.dart';
import '../../ui/platform_performance.dart';
import '../../utils/file_utils.dart';
import '../../utils/reveal_file_in_folder.dart';
import '../../utils/runtime_platform.dart';
import '../../widgets/desktop_hover_action_bar.dart';
import '../../widgets/file_icon_widget.dart';
import '../file_preview_screen.dart';
import '../webdav_file_detail_screen.dart';
import 'webdav_entry_actions.dart';
import 'webdav_view_mode.dart';

typedef WebDavEntrySubtitleBuilder = Widget Function(
  BuildContext context,
  WebDavEntry entry,
  AppLocalizations l10n,
  ThemeData theme,
  AppThemeColors colors,
  bool isDownloaded,
);

class WebDavEntryContextMenu {
  WebDavEntryContextMenu._();

  static void show({
    required BuildContext context,
    required WebDavEntry entry,
    required bool isFavorite,
    required WebDavEntryActions actions,
    required WebDavConnectionSummary connection,
    required WebDavClient client,
    required VoidCallback onEnterSelectionMode,
    required Future<void> Function() onDeleted,
  }) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _sheetTiles(
              context: context,
              sheetContext: ctx,
              l10n: l10n,
              entry: entry,
              isFavorite: isFavorite,
              actions: actions,
              connection: connection,
              client: client,
              onEnterSelectionMode: onEnterSelectionMode,
              onDeleted: onDeleted,
            ),
          ),
        ),
      ),
    );
  }

  static List<Widget> _sheetTiles({
    required BuildContext context,
    required BuildContext sheetContext,
    required AppLocalizations l10n,
    required WebDavEntry entry,
    required bool isFavorite,
    required WebDavEntryActions actions,
    required WebDavConnectionSummary connection,
    required WebDavClient client,
    required VoidCallback onEnterSelectionMode,
    required Future<void> Function() onDeleted,
  }) {
    return [
      ListTile(
        leading: const Icon(LucideIcons.checkSquare),
        title: Text(l10n.fmMultiSelectMode),
        onTap: () {
          Navigator.pop(sheetContext);
          onEnterSelectionMode();
        },
      ),
      if (!entry.isDirectory) ...[
        ListTile(
          leading: const Icon(LucideIcons.download),
          title: Text(l10n.webdavActionDownload),
          onTap: () {
            Navigator.pop(sheetContext);
            actions.downloadEntries([entry]);
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.externalLink),
          title: Text(l10n.webdavActionOpenWith),
          onTap: () {
            Navigator.pop(sheetContext);
            actions.openLocalCopy(entry);
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.share2),
          title: Text(l10n.webdavActionShare),
          onTap: () {
            Navigator.pop(sheetContext);
            actions.shareEntries([entry]);
          },
        ),
      ],
      ListTile(
        leading: Icon(isFavorite ? LucideIcons.starOff : LucideIcons.star),
        title: Text(
          isFavorite ? l10n.webdavActionUnfavorite : l10n.webdavActionFavorite,
        ),
        onTap: () {
          Navigator.pop(sheetContext);
          actions.toggleFavorite(entry);
        },
      ),
      ListTile(
        leading: const Icon(LucideIcons.pencil),
        title: Text(l10n.webdavActionRename),
        onTap: () {
          Navigator.pop(sheetContext);
          actions.renameEntry(entry);
        },
      ),
      ListTile(
        leading: const Icon(LucideIcons.copy),
        title: Text(l10n.webdavActionCopy),
        onTap: () {
          Navigator.pop(sheetContext);
          actions.copyEntry(entry);
        },
      ),
      ListTile(
        leading: const Icon(LucideIcons.info),
        title: Text(l10n.webdavActionDetails),
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WebDavFileDetailScreen(
                connection: connection,
                client: client,
                entry: entry,
                isFavorite: isFavorite,
                onDeleted: onDeleted,
              ),
            ),
          );
        },
      ),
      ListTile(
        leading: Icon(LucideIcons.trash2, color: context.appColors.danger),
        title: Text(
          l10n.webdavActionDelete,
          style: TextStyle(color: context.appColors.danger),
        ),
        onTap: () async {
          Navigator.pop(sheetContext);
          await actions.deleteEntries([entry]);
        },
      ),
    ];
  }
}

class WebDavDownloadedBadge extends StatelessWidget {
  final AppLocalizations l10n;
  final AppThemeColors colors;

  const WebDavDownloadedBadge({
    super.key,
    required this.l10n,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.08),
        border: Border.all(color: colors.success.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.webdavLocalDownloaded,
        style: TextStyle(
          color: colors.success,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

WebDavEntrySubtitleBuilder webDavDefaultFileSubtitleBuilder() {
  return (
    context,
    entry,
    l10n,
    theme,
    colors,
    isDownloaded,
  ) {
    return Row(
      children: [
        Text(
          entry.isDirectory
              ? l10n.webdavEntryFolder
              : formatFileSize(entry.size ?? 0),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (isDownloaded) ...[
          const SizedBox(width: AppSpacing.xs),
          WebDavDownloadedBadge(l10n: l10n, colors: colors),
        ],
      ],
    );
  };
}

/// Local path for list/grid thumbnail when the downloaded file is a previewable image.
String? webDavLocalImageThumbnailPath(String fileName, String? localPath) {
  if (localPath == null || localPath.isEmpty) return null;
  final category = getFileCategory(fileName);
  if (category != FileCategory.image || !isPreviewable(category, fileName)) {
    return null;
  }
  final ext = fileName.split('.').last.toLowerCase();
  const rasterThumbnailExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'ico',
  };
  if (!rasterThumbnailExts.contains(ext)) return null;
  return localPath;
}

class WebDavEntryTile extends StatelessWidget {
  final WebDavEntry entry;
  final bool grid;
  final bool selectionMode;
  final bool selected;
  final bool isFavorite;
  final bool isDownloaded;
  final String? localFilePath;
  final Widget subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const WebDavEntryTile({
    super.key,
    required this.entry,
    required this.grid,
    required this.selectionMode,
    required this.selected,
    required this.isFavorite,
    required this.isDownloaded,
    this.localFilePath,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    final category = getFileCategory(entry.name);
    final iconFilePath = entry.isDirectory
        ? null
        : webDavLocalImageThumbnailPath(entry.name, localFilePath);

    if (grid) {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Card(
          color: selectionMode && selected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                entry.isDirectory
                    ? Icon(LucideIcons.folder, color: colors.warning, size: 32)
                    : FileIconWidget(
                        category: category,
                        size: 32,
                        filePath: iconFilePath,
                      ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (isDownloaded) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  WebDavDownloadedBadge(
                    l10n: AppLocalizations.of(context),
                    colors: colors,
                  ),
                ],
                if (isFavorite)
                  Icon(LucideIcons.star, size: 12, color: colors.warning),
              ],
            ),
          ),
        ),
      );
    }

    final lightweightTap = AppPlatformPerformance.preferLightweightTapFeedback;

    return Material(
      color: selectionMode && selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashFactory: lightweightTap ? NoSplash.splashFactory : null,
        highlightColor: lightweightTap ? Colors.transparent : null,
        focusColor: lightweightTap ? Colors.transparent : null,
        hoverColor: lightweightTap
            ? colors.surfaceMuted.withValues(alpha: 0.7)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: entry.isDirectory
                    ? Icon(LucideIcons.folder, color: colors.warning, size: 22)
                    : FileIconWidget(
                        category: category,
                        size: 28,
                        filePath: iconFilePath,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    subtitle,
                  ],
                ),
              ),
              if (selectionMode)
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color:
                      selected ? theme.colorScheme.primary : colors.textTertiary,
                )
              else if (trailing != null)
                trailing!
              else if (isFavorite)
                Icon(LucideIcons.star, size: 14, color: colors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

class WebDavSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const WebDavSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: onClear,
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class WebDavEntryListBody extends StatefulWidget {
  final bool loading;
  final String? error;
  final String emptyMessage;
  final String retryLabel;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final List<WebDavEntry> entries;
  final WebDavViewMode viewMode;
  final double scrollBottom;
  final Set<String> favoritePaths;
  final Map<String, String?> localPathByRemotePath;
  final bool selectionMode;
  final Set<String> selectedPaths;
  final WebDavEntryActions actions;
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final WebDavEntrySubtitleBuilder subtitleBuilder;
  final ValueChanged<WebDavEntry> onEntryTap;
  final void Function(WebDavEntry entry) onEnterSelectionMode;
  final Future<void> Function() onDeleted;

  final Widget? Function(WebDavEntry entry)? trailingBuilder;

  const WebDavEntryListBody({
    super.key,
    required this.loading,
    required this.error,
    required this.emptyMessage,
    required this.retryLabel,
    required this.onRetry,
    required this.onRefresh,
    required this.entries,
    required this.viewMode,
    required this.scrollBottom,
    required this.favoritePaths,
    required this.localPathByRemotePath,
    required this.selectionMode,
    required this.selectedPaths,
    required this.actions,
    required this.connection,
    required this.client,
    required this.subtitleBuilder,
    required this.onEntryTap,
    required this.onEnterSelectionMode,
    required this.onDeleted,
    this.trailingBuilder,
  });

  @override
  State<WebDavEntryListBody> createState() => _WebDavEntryListBodyState();
}

class _WebDavEntryListBodyState extends State<WebDavEntryListBody> {
  String? _hoveredEntryPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isDesktop = RuntimePlatform.isDesktop;

    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: widget.onRetry,
                child: Text(widget.retryLabel),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.entries.isEmpty) {
      return Center(child: Text(widget.emptyMessage));
    }

    void showContextMenu(WebDavEntry entry, bool isFav) {
      WebDavEntryContextMenu.show(
        context: context,
        entry: entry,
        isFavorite: isFav,
        actions: widget.actions,
        connection: widget.connection,
        client: widget.client,
        onEnterSelectionMode: () => widget.onEnterSelectionMode(entry),
        onDeleted: widget.onDeleted,
      );
    }

    void openEntryDetails(WebDavEntry entry, bool isFav) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebDavFileDetailScreen(
            connection: widget.connection,
            client: widget.client,
            entry: entry,
            isFavorite: isFav,
            onDeleted: widget.onDeleted,
          ),
        ),
      );
    }

    Widget buildEntryHoverActions(
      WebDavEntry entry,
      bool isFav,
      bool isDownloaded,
      String? localPath,
    ) {
      return DesktopHoverActionBar(
        colors: colors,
        actions: [
          DesktopHoverAction(
            icon: LucideIcons.squareCheck,
            tooltip: l10n.fmMultiSelectMode,
            onTap: () => widget.onEnterSelectionMode(entry),
          ),
          if (!entry.isDirectory) ...[
            DesktopHoverAction(
              icon: LucideIcons.download,
              tooltip: l10n.webdavActionDownload,
              onTap: () => widget.actions.downloadEntries([entry]),
            ),
            if (isDownloaded)
              DesktopHoverAction(
                icon: LucideIcons.externalLink,
                tooltip: l10n.webdavActionOpenWith,
                onTap: () => widget.actions.openLocalCopy(entry),
              ),
            if (isDownloaded && localPath != null)
              DesktopHoverAction(
                icon: LucideIcons.folderOpen,
                tooltip: l10n.fmRevealInFolder,
                onTap: () => unawaited(revealFileInFolder(localPath)),
              ),
            DesktopHoverAction(
              icon: LucideIcons.share2,
              tooltip: l10n.webdavActionShare,
              onTap: () => widget.actions.shareEntries([entry]),
            ),
          ],
          DesktopHoverAction(
            icon: isFav ? LucideIcons.starOff : LucideIcons.star,
            tooltip: isFav
                ? l10n.webdavActionUnfavorite
                : l10n.webdavActionFavorite,
            onTap: () => widget.actions.toggleFavorite(entry),
          ),
          DesktopHoverAction(
            icon: LucideIcons.pencil,
            tooltip: l10n.webdavActionRename,
            onTap: () => widget.actions.renameEntry(entry),
          ),
          DesktopHoverAction(
            icon: LucideIcons.copy,
            tooltip: l10n.webdavActionCopy,
            onTap: () => widget.actions.copyEntry(entry),
          ),
          DesktopHoverAction(
            icon: LucideIcons.info,
            tooltip: l10n.webdavActionDetails,
            onTap: () => openEntryDetails(entry, isFav),
          ),
          DesktopHoverAction(
            icon: LucideIcons.trash2,
            tooltip: l10n.webdavActionDelete,
            color: colors.danger,
            onTap: () => unawaited(widget.actions.deleteEntries([entry])),
          ),
        ],
      );
    }

    Widget buildTile(WebDavEntry entry, {required bool grid}) {
      final isDownloaded = !entry.isDirectory &&
          widget.localPathByRemotePath[entry.path] != null;
      final localPath = widget.localPathByRemotePath[entry.path];
      final isFav = widget.favoritePaths.contains(entry.path);
      final selected = widget.selectedPaths.contains(entry.path);
      final isHovered = isDesktop &&
          !widget.selectionMode &&
          _hoveredEntryPath == entry.path;
      final subtitle = widget.subtitleBuilder(
        context,
        entry,
        l10n,
        theme,
        colors,
        isDownloaded,
      );
      final tile = WebDavEntryTile(
        entry: entry,
        grid: grid,
        selectionMode: widget.selectionMode,
        selected: selected,
        isFavorite: isFav,
        isDownloaded: isDownloaded,
        localFilePath: localPath,
        subtitle: subtitle,
        trailing: widget.trailingBuilder?.call(entry),
        onTap: () => widget.onEntryTap(entry),
        onLongPress: isDesktop
            ? null
            : () => showContextMenu(entry, isFav),
      );

      if (!isDesktop) return tile;

      final desktopTile = MouseRegion(
        onEnter: (_) {
          if (!widget.selectionMode) {
            setState(() => _hoveredEntryPath = entry.path);
          }
        },
        onExit: (_) {
          if (_hoveredEntryPath == entry.path) {
            setState(() => _hoveredEntryPath = null);
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            if (isHovered)
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xxs,
                child: buildEntryHoverActions(
                  entry,
                  isFav,
                  isDownloaded,
                  localPath,
                ),
              ),
          ],
        ),
      );

      return desktopTile;
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: widget.viewMode == WebDavViewMode.grid
          ? GridView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
                widget.scrollBottom,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
              ),
              itemCount: widget.entries.length,
              itemBuilder: (context, index) =>
                  buildTile(widget.entries[index], grid: true),
            )
          : ListView.separated(
              padding: EdgeInsets.only(bottom: widget.scrollBottom),
              itemCount: widget.entries.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
              ),
              itemBuilder: (context, index) =>
                  buildTile(widget.entries[index], grid: false),
            ),
    );
  }
}

class WebDavEntrySurfaceShell extends StatelessWidget {
  final Widget? header;
  final Widget body;

  const WebDavEntrySurfaceShell({
    super.key,
    this.header,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.md),
        ),
        child: ColoredBox(
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                header!,
                Divider(height: 1, thickness: 1, color: colors.border),
              ],
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
