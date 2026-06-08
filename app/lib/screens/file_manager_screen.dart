import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../color_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/desktop_file_clipboard.dart';
import '../services/file_export_pipeline.dart';
import '../services/file_export_service.dart';
import '../services/file_store.dart';
import '../services/pending_files_store.dart';
import '../services/receive_dir_resolver.dart';
import '../services/received_file_dao.dart';
import '../services/save_folder_listing_service.dart';
import '../services/visible_export_target.dart';
import '../ui/app_ui.dart';
import '../widgets/desktop_paste_shortcuts.dart';
import '../utils/file_utils.dart';
import '../utils/open_directory.dart';
import '../utils/open_received_file.dart';
import '../utils/received_file_actions.dart';
import '../utils/save_as_feedback.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/desktop_file_drag_source.dart';
import '../widgets/file_icon_widget.dart';
import '../widgets/received_file_info_dialog.dart';
import 'settings_screen.dart';

class FileManagerScreen extends StatefulWidget {
  final ValueChanged<PlatformFile>? onAddToPending;

  /// When true (e.g. mobile home tab), hide back [leading] — no route to pop.
  final bool embedded;

  /// Incremented by the parent each time the embedded files tab is selected; triggers a silent refresh.
  final int embeddedFileTabActivation;

  const FileManagerScreen({
    super.key,
    this.onAddToPending,
    this.embedded = false,
    this.embeddedFileTabActivation = 0,
  });

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 50;
  static const _prefSortBy = 'file_manager_sort_by';

  late TabController _tabController;

  List<ReceivedFileInfo> _files = [];
  List<ReceivedFileInfo> _saveFolderFiles = [];
  SaveFolderAccessError? _saveFolderError;
  String? _saveFolderDisplayPath;
  String? _saveFolderDisplayLabel;
  String _saveFolderSearchQuery = '';
  ReceivedFileSortBy _sortBy = ReceivedFileSortBy.createdAt;
  bool _loading = true;
  bool _saveFolderLoading = false;
  bool _categoryView = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showSearch = false;
  String? _hoveredFilePath;
  bool _isSelectionMode = false;
  final Set<String> _selectedFiles = {};
  String? _receiveDirPath;
  Timer? _indexChangeDebounce;

  bool get _isSearching => _searchQuery.isNotEmpty;

  bool get _isSaveFolderTab => _tabController.index == 0;

  List<ReceivedFileInfo> get _activeFiles =>
      _isSaveFolderTab ? _filteredSaveFolderFiles : _files;

  List<ReceivedFileInfo> get _filteredSaveFolderFiles {
    if (_saveFolderSearchQuery.isEmpty) return _saveFolderFiles;
    final q = _saveFolderSearchQuery.toLowerCase();
    return _saveFolderFiles
        .where((f) => f.displayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onMainTabChanged);
    _scrollController.addListener(_onScroll);
    _loadReceiveDirPath();
    unawaited(_loadSaveFolderDisplayInfo());
    unawaited(_loadSaveFolderFiles());
    unawaited(_loadSortPreference().then((_) => _loadFiles()));
    ReceivedFileDao.addChangedListener(_onIndexChanged);
    FileStore.addReceiveDirChangedListener(_onReceiveDirChanged);
  }

  void _onMainTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_isSelectionMode) {
      _exitSelectionMode();
    }
    if (_isSaveFolderTab) {
      unawaited(_loadSaveFolderFiles());
    }
    if (mounted) setState(() {});
  }

  /// Coalesce bursts of file-receive events into a single silent refresh so
  /// rapid multi-file transfers do not thrash the list.
  void _onIndexChanged() {
    if (!mounted) return;
    _indexChangeDebounce?.cancel();
    _indexChangeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _silentRefreshFiles();
      unawaited(_silentRefreshSaveFolder());
    });
  }

  /// Receive root just changed in settings — refresh the displayed dir path
  /// and reload the listing.
  void _onReceiveDirChanged() {
    if (!mounted) return;
    unawaited(_loadReceiveDirPath(invalidateDirCache: true));
    unawaited(_loadSaveFolderDisplayInfo(forceRefresh: true));
    _onIndexChanged();
    if (_isSaveFolderTab) {
      unawaited(_silentRefreshSaveFolder());
    }
  }

  @override
  void didUpdateWidget(FileManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedded &&
        widget.embeddedFileTabActivation !=
            oldWidget.embeddedFileTabActivation &&
        widget.embeddedFileTabActivation > 0) {
      _silentRefreshFiles();
      if (_isSaveFolderTab) {
        unawaited(_silentRefreshSaveFolder());
      }
    }
  }

  Future<void> _loadReceiveDirPath({bool invalidateDirCache = false}) async {
    if (invalidateDirCache) {
      FileStore.invalidateReceiveDirCache();
    }
    try {
      final p = await FileStore.getCacheDir();
      if (mounted) {
        setState(() => _receiveDirPath = p);
      }
    } catch (e, st) {
      debugPrint('FileManagerScreen._loadReceiveDirPath failed: $e\n$st');
    }
  }

  /// Reload listing without clearing the list or showing the full-screen loading state.
  Future<void> _silentRefreshFiles() async {
    if (!mounted) return;

    try {
      await _loadReceiveDirPath(invalidateDirCache: true);

      if (_categoryView) {
        final files = await _queryAllForCategoryView();
        if (mounted) {
          setState(() {
            _files = files;
            _hasMore = false;
          });
        }
      } else if (_isSearching) {
        await _performSearch(_searchQuery);
      } else {
        final files = await _queryPaged(0, _pageSize);
        if (mounted) {
          setState(() {
            _files = files;
            _hasMore = files.length == _pageSize;
          });
        }
      }
    } catch (e, st) {
      debugPrint('FileManagerScreen._silentRefreshFiles failed: $e\n$st');
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).fmRefreshFailed,
        );
      }
    }
  }

  Future<void> _loadSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefSortBy);
      if (!mounted) return;
      if (raw == ReceivedFileSortBy.modified.name) {
        setState(() => _sortBy = ReceivedFileSortBy.modified);
      } else {
        setState(() => _sortBy = ReceivedFileSortBy.createdAt);
      }
    } catch (_) {}
  }

  Future<void> _persistSortPreference(ReceivedFileSortBy sortBy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSortBy, sortBy.name);
    } catch (_) {}
  }

  Future<void> _onSortByChanged(ReceivedFileSortBy sortBy) async {
    if (_sortBy == sortBy) return;
    setState(() => _sortBy = sortBy);
    await _persistSortPreference(sortBy);
    if (_categoryView) {
      await _loadAllForCategory();
    } else if (_isSearching) {
      await _performSearch(_searchQuery);
    } else {
      await _loadFiles();
    }
  }

  DateTime _displayTimeFor(ReceivedFileInfo file) =>
      _sortBy == ReceivedFileSortBy.modified ? file.modified : file.createdAt;

  void _sortFilesInPlace(List<ReceivedFileInfo> files) {
    files.sort((a, b) => _displayTimeFor(b).compareTo(_displayTimeFor(a)));
  }

  Future<List<ReceivedFileInfo>> _queryPaged(int offset, int limit) async {
    final rows = await ReceivedFileDao.instance.listPaged(
      offset: offset,
      limit: limit,
      sortBy: _sortBy,
      cacheTabOnly: true,
    );
    return rows.map((r) => r.toInfo()).toList();
  }

  /// Used by the category view (small datasets — first page is enough; we
  /// load up to 1000 entries to keep grouping responsive without OOM).
  Future<List<ReceivedFileInfo>> _queryAllForCategoryView() async {
    final rows = await ReceivedFileDao.instance.listPaged(
      offset: 0,
      limit: 1000,
      sortBy: _sortBy,
      cacheTabOnly: true,
    );
    return rows.map((r) => r.toInfo()).toList();
  }

  /// Run reconcile in the background; never blocks the UI thread.
  Future<void> _reconcileIndex() async {
    try {
      final root = await FileStore.getCacheDir();
      await ReceivedFileDao.instance.reconcileWithRoot(root);
    } catch (e, st) {
      debugPrint('FileManagerScreen._reconcileIndex failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onMainTabChanged);
    _tabController.dispose();
    _indexChangeDebounce?.cancel();
    ReceivedFileDao.removeChangedListener(_onIndexChanged);
    FileStore.removeReceiveDirChangedListener(_onReceiveDirChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isSaveFolderTab) return;
    if (!_categoryView &&
        _hasMore &&
        !_loadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMoreFiles();
    }
  }

  /// [showBlockingLoading] — false for pull-to-refresh (keeps list visible; only the indicator shows progress).
  Future<void> _loadFiles({bool showBlockingLoading = true}) async {
    if (!mounted) return;
    if (showBlockingLoading) {
      setState(() => _loading = true);
    }
    try {
      final files = await _queryPaged(0, _pageSize);
      if (!mounted) return;
      setState(() {
        _files = files;
        _hasMore = files.length == _pageSize;
      });
    } catch (e, st) {
      debugPrint('FileManagerScreen._loadFiles failed: $e\n$st');
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).fmListLoadFailed,
        );
      }
    } finally {
      if (showBlockingLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Reconcile the index against the disk, then reload the current view.
  Future<void> _pullRefresh() async {
    if (_isSaveFolderTab) {
      await _loadSaveFolderFiles(showBlockingLoading: false);
      return;
    }
    await _loadReceiveDirPath(invalidateDirCache: true);
    await _reconcileIndex();
    if (_categoryView) {
      await _loadAllForCategory(showBlockingLoading: false);
    } else if (_isSearching) {
      await _performSearch(_searchQuery);
    } else {
      await _loadFiles(showBlockingLoading: false);
    }
  }

  Future<void> _loadSaveFolderFiles({bool showBlockingLoading = true}) async {
    if (!mounted) return;
    if (showBlockingLoading) {
      setState(() => _saveFolderLoading = true);
    }
    try {
      final result = await SaveFolderListingService.list();
      if (!mounted) return;
      setState(() {
        _saveFolderFiles = result.files
            .map(SaveFolderListingService.toReceivedFileInfo)
            .toList();
        _saveFolderError = result.error;
        _saveFolderDisplayPath = result.displayPath;
        _saveFolderDisplayLabel = result.displayLabel;
      });
    } catch (e, st) {
      debugPrint('FileManagerScreen._loadSaveFolderFiles failed: $e\n$st');
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).fmListLoadFailed,
        );
      }
    } finally {
      if (showBlockingLoading && mounted) {
        setState(() => _saveFolderLoading = false);
      }
    }
  }

  Future<void> _silentRefreshSaveFolder() async {
    if (!mounted) return;
    await _loadSaveFolderFiles(showBlockingLoading: false);
  }

  String _saveFolderErrorMessage(AppLocalizations l10n) {
    final error = _saveFolderError;
    if (error == null) return l10n.fmSaveFolderNotAccessible;
    switch (error.kind) {
      case SaveFolderAccessErrorKind.notConfigured:
        return l10n.fmSaveFolderNotConfigured;
      case SaveFolderAccessErrorKind.permissionDenied:
        return l10n.fmSaveFolderPermissionDenied;
      case SaveFolderAccessErrorKind.notAccessible:
        return l10n.fmSaveFolderNotAccessible;
      case SaveFolderAccessErrorKind.ioError:
        final detail = error.detail?.trim();
        if (detail != null && detail.isNotEmpty) {
          return l10n.fmSaveFolderErrorDetail(detail);
        }
        return l10n.fmSaveFolderNotAccessible;
    }
  }

  Future<void> _loadMoreFiles() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _queryPaged(_files.length, _pageSize);
      if (!mounted) return;
      setState(() {
        _files.addAll(more);
        _hasMore = more.length == _pageSize;
      });
    } catch (e, st) {
      debugPrint('FileManagerScreen._loadMoreFiles failed: $e\n$st');
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).fmLoadMoreFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadAllForCategory({bool showBlockingLoading = true}) async {
    if (!mounted) return;
    if (showBlockingLoading) {
      setState(() => _loading = true);
    }
    try {
      final files = await _queryAllForCategoryView();
      if (!mounted) return;
      setState(() {
        _files = files;
        _hasMore = false;
      });
    } catch (e, st) {
      debugPrint('FileManagerScreen._loadAllForCategory failed: $e\n$st');
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).fmListLoadFailed,
        );
      }
    } finally {
      if (showBlockingLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleSearch() {
    final opening = !_showSearch;
    setState(() => _showSearch = opening);
    if (opening) {
      _searchFocusNode.requestFocus();
    } else {
      _searchFocusNode.unfocus();
      if (_isSearching || _saveFolderSearchQuery.isNotEmpty) {
        _searchController.clear();
        _onSearchChanged('');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    if (_isSaveFolderTab) {
      setState(() => _saveFolderSearchQuery = query);
      return;
    }
    if (query.isEmpty) {
      if (_categoryView) {
        _loadAllForCategory();
      } else {
        _loadFiles();
      }
    } else {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      final rows = await ReceivedFileDao.instance.listPaged(
        offset: 0,
        limit: 1000,
        query: query,
        sortBy: _sortBy,
        cacheTabOnly: true,
      );
      final results = rows.map((r) => r.toInfo()).toList();
      if (!mounted) return;
      if (_searchQuery == query) {
        setState(() {
          _files = results;
          _hasMore = false;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('FileManagerScreen._performSearch failed: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(
        context,
        message: AppLocalizations.of(context).fmSearchFailed,
      );
    }
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  EdgeInsets _listVerticalPadding(BuildContext context) {
    return EdgeInsets.only(
      top: AppSpacing.xs,
      bottom: AppSpacing.xs +
          (widget.embedded
              ? AppLayout.floatingBottomBarScrollInset(context)
              : 0),
    );
  }

  Future<void> _clearCacheDirectory() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.fmClearCacheTitle,
      content: l10n.fmClearCacheConfirm,
      confirmLabel: l10n.fmClearCache,
      isDanger: true,
      icon: LucideIcons.brush,
    );
    if (!confirmed || !mounted) return;
    try {
      final cacheRoot = await FileStore.getCacheDir();
      await FileStore.clearCacheContents();
      await ReceivedFileDao.instance.reconcileAfterCacheClear(cacheRoot);
      await _reconcileIndex();
      _indexChangeDebounce?.cancel();
      if (!mounted) return;
      if (_categoryView) {
        await _loadAllForCategory(showBlockingLoading: false);
      } else if (_isSearching) {
        await _performSearch(_searchQuery);
      } else {
        await _loadFiles(showBlockingLoading: false);
      }
      if (!mounted) return;
      AppToast.show(context, message: l10n.fmClearCacheDone);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, message: l10n.fmClearCacheFailed);
      }
    }
  }

  Future<void> _deleteFile(ReceivedFileInfo file) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.fmDeleteTitle,
      content: l10n.fmDeleteConfirmOne(file.displayName),
      confirmLabel: l10n.fmDeleteConfirm,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (confirmed) {
      await _removeFile(file);
      await _reloadAfterDelete();
    }
  }

  Future<void> _reloadAfterDelete() async {
    if (_isSaveFolderTab) {
      await _loadSaveFolderFiles(showBlockingLoading: false);
      return;
    }
    if (_categoryView) {
      await _refreshCategory();
    } else if (_isSearching) {
      await _performSearch(_searchQuery);
    } else {
      await _loadFiles();
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final count = _selectedFiles.length;
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.fmDeleteTitle,
      content: l10n.fmDeleteConfirmMany(count),
      confirmLabel: l10n.fmDeleteConfirm,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed) return;

    final deletedPaths = Set<String>.from(_selectedFiles);
    final byPath = {for (final f in _activeFiles) f.path: f};
    for (final path in deletedPaths) {
      final f = byPath[path];
      if (f != null) {
        await _removeFile(f);
      } else {
        await FileStore.deleteFile(path);
      }
    }

    setState(() {
      _selectedFiles.removeWhere((path) => deletedPaths.contains(path));
    });

    if (_isSaveFolderTab) {
      await _loadSaveFolderFiles(showBlockingLoading: false);
    } else if (_categoryView) {
      await _refreshCategory();
    } else if (_isSearching) {
      await _performSearch(_searchQuery);
    } else {
      await _loadFiles();
    }
  }

  Future<void> _removeFile(ReceivedFileInfo file) async {
    if (SaveFolderListingService.isSaveFolderEntry(file)) {
      await SaveFolderListingService.deleteEntry(file);
      return;
    }
    await FileStore.deleteFile(file.path);
    try {
      await ReceivedFileDao.instance.removeByMessageId(file.messageId);
    } catch (_) {}
  }

  void _openFile(ReceivedFileInfo file) {
    unawaited(_openFileResolved(file));
  }

  ReceivedFilePreviewCallbacks _previewCallbacksFor(ReceivedFileInfo file) {
    return ReceivedFilePreviewCallbacks(
      onEnterMultiSelect: () {
        setState(() {
          _isSelectionMode = true;
          _selectedFiles.add(file.path);
        });
      },
      onAddToPending: widget.onAddToPending,
      onDeleted: () => unawaited(_reloadAfterDelete()),
    );
  }

  Future<void> _openFileResolved(ReceivedFileInfo file) async {
    if (SaveFolderListingService.isSaveFolderEntry(file) &&
        file.path.startsWith('content://')) {
      final localPath = await SaveFolderListingService.resolveLocalPath(file);
      if (!mounted) return;
      if (localPath == null || localPath.isEmpty) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).fmPreviewUnavailableTitle,
        );
        return;
      }
      final previewFile = ReceivedFileInfo(
        messageId: file.messageId,
        path: localPath,
        displayName: file.displayName,
        protocol: file.protocol,
        size: file.size,
        modified: file.modified,
        createdAt: file.createdAt,
        category: file.category,
      );
      await openReceivedFile(
        context,
        previewFile,
        callbacks: _previewCallbacksFor(previewFile),
      );
      return;
    }
    if (!mounted) return;
    await openReceivedFile(
      context,
      file,
      callbacks: _previewCallbacksFor(file),
    );
  }

  Future<void> _shareFile(ReceivedFileInfo file) async {
    final path = await _resolveSharePath(file);
    if (path == null) return;
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final xFiles = <XFile>[];
    for (final path in _selectedFiles) {
      final file = _fileByPath(path);
      if (file == null) {
        xFiles.add(XFile(path));
        continue;
      }
      final resolved = await _resolveSharePath(file);
      if (resolved != null) {
        xFiles.add(XFile(resolved));
      }
    }
    if (xFiles.isEmpty) return;
    await Share.shareXFiles(xFiles);
  }

  Future<String?> _resolveSharePath(ReceivedFileInfo file) async {
    if (SaveFolderListingService.isSaveFolderEntry(file) &&
        file.path.startsWith('content://')) {
      return SaveFolderListingService.resolveLocalPath(file);
    }
    return file.path;
  }

  Future<void> _saveToGallery(ReceivedFileInfo file) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await SaverGallery.saveFile(
        filePath: file.path,
        fileName: file.displayName,
        androidRelativePath: 'Pictures/${l10n.brandNameInternational}',
        skipIfExists: false,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        AppToast.show(context, message: l10n.chatGallerySaved);
        Analytics.track(AnalyticsEvents.fileSaveToGallery, {
          'result': 'success',
        });
      } else {
        AppToast.show(context, message: l10n.chatGallerySaveFailed);
        Analytics.track(AnalyticsEvents.fileSaveToGallery, {'result': 'fail'});
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.chatGallerySaveFailed);
      Analytics.track(AnalyticsEvents.fileSaveToGallery, {'result': 'fail'});
    }
  }

  Future<void> _exportFile(ReceivedFileInfo file) async {
    await runSaveFileAs(
      context: context,
      l10n: AppLocalizations.of(context),
      sourcePath: file.path,
      fileName: file.displayName,
    );
  }

  String _exportActionLabel(AppLocalizations l10n) => saveAsActionLabel(l10n);

  void _addToPending(ReceivedFileInfo file) {
    final l10n = AppLocalizations.of(context);
    final platformFile = PlatformFile(
      name: file.displayName,
      size: file.size,
      path: file.path,
    );
    widget.onAddToPending?.call(platformFile);
    AppToast.show(context, message: l10n.fmPendingAddedOne(file.displayName));
  }

  void _addSelectedToPending() {
    if (_selectedFiles.isEmpty || widget.onAddToPending == null) return;

    final selectedFiles = _activeFiles
        .where((f) => _selectedFiles.contains(f.path))
        .toList();

    for (final file in selectedFiles) {
      final platformFile = PlatformFile(
        name: file.displayName,
        size: file.size,
        path: file.path,
      );
      widget.onAddToPending?.call(platformFile);
    }

    final count = selectedFiles.length;
    AppToast.show(
      context,
      message: AppLocalizations.of(context).fmPendingAddedMany(count),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedFiles.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedFiles.length == _activeFiles.length) {
        _selectedFiles.clear();
      } else {
        _selectedFiles.clear();
        _selectedFiles.addAll(_activeFiles.map((f) => f.path));
      }
    });
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  List<String> _pathsToCopy() {
    if (_selectedFiles.isNotEmpty) {
      return _selectedFiles.toList();
    }
    final hovered = _hoveredFilePath;
    if (hovered != null) return [hovered];
    return const [];
  }

  Future<void> _copyFilesToClipboard([List<String>? paths]) async {
    final l10n = AppLocalizations.of(context);
    final toCopy = paths ?? _pathsToCopy();
    if (toCopy.isEmpty) {
      AppToast.show(context, message: l10n.fileClipboardNothingToCopy);
      return;
    }
    final resolvedPaths = <String>[];
    for (final path in toCopy) {
      final file = _fileByPath(path);
      if (file != null &&
          SaveFolderListingService.isSaveFolderEntry(file) &&
          file.path.startsWith('content://')) {
        final local = await SaveFolderListingService.resolveLocalPath(file);
        if (local != null && local.isNotEmpty) {
          resolvedPaths.add(local);
        }
      } else {
        resolvedPaths.add(path);
      }
    }
    if (resolvedPaths.isEmpty) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.fileClipboardCopyFailed);
      return;
    }
    final ok = await DesktopFileClipboard.writeFilesToClipboard(resolvedPaths);
    if (!mounted) return;
    AppToast.show(
      context,
      message: ok
          ? l10n.fileClipboardCopied(resolvedPaths.length)
          : l10n.fileClipboardCopyFailed,
    );
  }

  Future<void> _handleDesktopPaste(List<PlatformFile> files) async {
    if (!_isDesktop || files.isEmpty || !mounted) return;

    if (widget.onAddToPending != null) {
      for (final f in files) {
        widget.onAddToPending!(f);
      }
      final l10n = AppLocalizations.of(context);
      AppToast.show(
        context,
        message: files.length == 1
            ? l10n.fmPendingAddedOne(files.first.name)
            : l10n.fmPendingAddedMany(files.length),
      );
      return;
    }

    final result = await PendingFilesStore.load();
    final existingPaths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .toSet();
    final merged = List<PlatformFile>.from(result.files);
    for (final f in files) {
      final path = f.path;
      if (path != null && path.isNotEmpty && !existingPaths.contains(path)) {
        merged.add(f);
        existingPaths.add(path);
      }
    }
    await PendingFilesStore.save(merged);
    if (!mounted) return;
    AppToast.show(
      context,
      message: AppLocalizations.of(context).fileClipboardPasteAdded,
    );
  }

  ReceivedFileInfo? _fileByPath(String path) {
    for (final file in _activeFiles) {
      if (file.path == path) return file;
    }
    return null;
  }

  Future<void> _revealInFolder(ReceivedFileInfo file) async {
    await revealFileInFileManager(file.path);
  }

  void _showFileInfo(ReceivedFileInfo file) {
    unawaited(showReceivedFileInfoDialog(context, file));
  }

  Widget _buildFileHoverActions(ReceivedFileInfo file, AppThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fileHoverBtn(
            LucideIcons.info,
            colors.textSecondary,
            () => _showFileInfo(file),
          ),
          _fileHoverBtn(LucideIcons.squareCheck, colors.textSecondary, () {
            setState(() {
              _isSelectionMode = true;
              _selectedFiles.add(file.path);
            });
          }),
          _fileHoverBtn(
            LucideIcons.copy,
            colors.textSecondary,
            () => unawaited(_copyFilesToClipboard([file.path])),
          ),
          _fileHoverBtn(
            LucideIcons.externalLink,
            colors.textSecondary,
            () => _openFile(file),
          ),
          _fileHoverBtn(
            LucideIcons.folderOpen,
            colors.textSecondary,
            () => _revealInFolder(file),
          ),
          if (FileExportService.isSupported &&
              !SaveFolderListingService.isSaveFolderEntry(file))
            _fileHoverBtn(
              LucideIcons.download,
              colors.textSecondary,
              () => unawaited(_exportFile(file)),
            ),
          _fileHoverBtn(
            LucideIcons.plus,
            colors.textSecondary,
            () => _addToPending(file),
          ),
          _fileHoverBtn(
            LucideIcons.trash2,
            colors.danger,
            () => _deleteFile(file),
          ),
        ],
      ),
    );
  }

  Widget _fileHoverBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _showFileActions(ReceivedFileInfo file) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canSaveToGallery =
        _isMobile &&
        (file.category == FileCategory.image ||
            file.category == FileCategory.video);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FileIconWidget(
                          category: file.category,
                          size: 32,
                          filePath: file.path,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            file.displayName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  ListTile(
                    leading: const Icon(LucideIcons.info),
                    title: Text(l10n.fmFileInfoAction),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFileInfo(file);
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.squareCheck),
                    title: Text(l10n.fmMultiSelectMode),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _isSelectionMode = true;
                        _selectedFiles.add(file.path);
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.plus),
                    title: Text(l10n.chatMenuAddToPending),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addToPending(file);
                    },
                  ),
                  if (_isMobile)
                    ListTile(
                      leading: const Icon(LucideIcons.share2),
                      title: Text(l10n.chatMenuShare),
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareFile(file);
                      },
                    ),
                  if (canSaveToGallery)
                    ListTile(
                      leading: const Icon(LucideIcons.download),
                      title: Text(l10n.chatMenuSaveToGallery),
                      onTap: () {
                        Navigator.pop(ctx);
                        _saveToGallery(file);
                      },
                    ),
                  if (FileExportService.isSupported &&
                      !SaveFolderListingService.isSaveFolderEntry(file))
                    ListTile(
                      leading: const Icon(LucideIcons.download),
                      title: Text(_exportActionLabel(l10n)),
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_exportFile(file));
                      },
                    ),
                  if (file.exportStatus == ExportStatus.failed &&
                      !SaveFolderListingService.isSaveFolderEntry(file))
                    ListTile(
                      leading: const Icon(LucideIcons.refreshCw),
                      title: Text(l10n.fmExportRetry),
                      onTap: () {
                        Navigator.pop(ctx);
                        FileExportPipeline.instance.retry(file.messageId);
                        AppToast.show(context, message: l10n.fmExportStatusExporting);
                      },
                    ),
                  ListTile(
                    leading: Icon(LucideIcons.trash2, color: colors.danger),
                    title: Text(
                      l10n.fmDeleteConfirm,
                      style: TextStyle(color: colors.danger),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteFile(file);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _saveFolderTabLabel(AppLocalizations l10n) {
    final label = _saveFolderDisplayLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return l10n.fmTabSaveFolder;
  }

  Future<void> _loadSaveFolderDisplayInfo({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        FileStore.invalidateReceiveDirCache();
      }
      final info = await _resolveSaveFolderDisplayInfo(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _saveFolderDisplayLabel = info.label;
          _saveFolderDisplayPath = info.path;
        });
      }
    } catch (e, st) {
      debugPrint(
        'FileManagerScreen._loadSaveFolderDisplayInfo failed: $e\n$st',
      );
    }
  }

  Future<({String? label, String? path})> _resolveSaveFolderDisplayInfo({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _saveFolderDisplayPath != null &&
        _saveFolderDisplayPath!.isNotEmpty) {
      return (label: _saveFolderDisplayLabel, path: _saveFolderDisplayPath);
    }
    try {
      final target = await FileStore.getVisibleExportTarget();
      final label = target.displayName;
      final safUri = target.safTreeUri?.trim();
      if (safUri != null && safUri.isNotEmpty) {
        return (label: label, path: safUri);
      }
      final posixPath = target.posixPath?.trim();
      if (posixPath != null && posixPath.isNotEmpty) {
        return (label: label, path: posixPath);
      }
      if (target.kind == VisibleExportKind.downloads) {
        final base = await ReceiveDirResolver.getPublicDownloadsBase();
        return (label: label, path: base ?? label);
      }
      return (label: label, path: label);
    } catch (_) {
      return (label: null, path: null);
    }
  }

  Future<void> _showFileManagerHintDialog() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final saveFolderInfo = await _resolveSaveFolderDisplayInfo();
    if (!mounted) return;
    final sectionTitleStyle = theme.textTheme.titleSmall?.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.textSecondary,
      height: 1.4,
    );
    final pathLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final pathStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.textSecondary,
      height: 1.35,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        titlePadding: AppDialog.titlePadding,
        contentPadding: AppDialog.confirmContentPadding,
        actionsPadding: AppDialog.actionsPadding,
        title: Text(l10n.fmHintTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.fmSaveFolderHintTitle, style: sectionTitleStyle),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _isDesktop
                    ? l10n.fmSaveFolderHintBodyDesktop
                    : l10n.fmSaveFolderHintBody,
                style: bodyStyle,
              ),
              if (saveFolderInfo.path != null &&
                  saveFolderInfo.path!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.fmSaveFolderPathLabel, style: pathLabelStyle),
                const SizedBox(height: AppSpacing.xxs),
                SelectableText(
                  saveFolderInfo.label != null &&
                          saveFolderInfo.label!.isNotEmpty &&
                          saveFolderInfo.label != saveFolderInfo.path
                      ? '${saveFolderInfo.label!}\n${saveFolderInfo.path!}'
                      : saveFolderInfo.path!,
                  style: pathStyle,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.fmCacheHintTitle, style: sectionTitleStyle),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(_clearCacheDirectory());
                    },
                    icon: Icon(
                      LucideIcons.brush,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(l10n.fmClearCache),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(l10n.fmCacheSubtitle, style: bodyStyle),
              if (_receiveDirPath != null && _receiveDirPath!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.fmCachePathLabel, style: pathLabelStyle),
                const SizedBox(height: AppSpacing.xxs),
                SelectableText(_receiveDirPath!, style: pathStyle),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.fmCacheHintOk),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    if (widget.embedded) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    Navigator.pushNamed(context, '/settings');
  }

  List<Widget> _buildNormalAppBarActions(AppLocalizations l10n) {
    if (_isSaveFolderTab) {
      return [
        IconButton(
          icon: Icon(
            _showSearch ? LucideIcons.searchX : LucideIcons.search,
          ),
          tooltip: _showSearch
              ? l10n.fmSearchCloseTooltip
              : l10n.fmSearchTooltip,
          onPressed: _toggleSearch,
        ),
      ];
    }
    return [
      IconButton(
        icon: const Icon(LucideIcons.brush),
        tooltip: l10n.fmClearCache,
        onPressed: () => unawaited(_clearCacheDirectory()),
      ),
      IconButton(
        icon: Icon(
          _showSearch ? LucideIcons.searchX : LucideIcons.search,
        ),
        tooltip: _showSearch
            ? l10n.fmSearchCloseTooltip
            : l10n.fmSearchTooltip,
        onPressed: _toggleSearch,
      ),
      PopupMenuButton<ReceivedFileSortBy>(
        tooltip: l10n.fmSortMenuTooltip,
        initialValue: _sortBy,
        onSelected: _onSortByChanged,
        icon: const Icon(LucideIcons.arrowDownWideNarrow),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: ReceivedFileSortBy.createdAt,
            child: _buildSortMenuRow(
              context,
              label: l10n.fmSortByCreated,
              selected: _sortBy == ReceivedFileSortBy.createdAt,
            ),
          ),
          PopupMenuItem(
            value: ReceivedFileSortBy.modified,
            child: _buildSortMenuRow(
              context,
              label: l10n.fmSortByModified,
              selected: _sortBy == ReceivedFileSortBy.modified,
            ),
          ),
        ],
      ),
      IconButton(
        icon: Icon(
          _categoryView ? LucideIcons.clock : LucideIcons.folder,
        ),
        tooltip: _categoryView
            ? l10n.fmSortTimeTooltip
            : l10n.fmSortCategoryTooltip,
        onPressed: () {
          final toCategory = !_categoryView;
          setState(() => _categoryView = toCategory);
          if (toCategory) {
            _loadAllForCategory();
          } else {
            _loadFiles();
          }
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final scaffold = Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: _isSelectionMode
            ? Text(l10n.fmSelectedCount(_selectedFiles.length))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.fmToolbarTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.circleHelp,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    tooltip: l10n.fmHintTooltip,
                    onPressed: _showFileManagerHintDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
        bottom: _isSelectionMode
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: colors.textPrimary,
                unselectedLabelColor: colors.textSecondary,
                dividerColor: colors.border,
                tabs: [
                  Tab(text: _saveFolderTabLabel(l10n)),
                  Tab(text: l10n.fmTabCache),
                ],
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: _exitSelectionMode,
              )
            : widget.embedded
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => Navigator.pop(context),
              ),
        actions: _isSelectionMode
            ? [
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectedFiles.length == _activeFiles.length
                        ? l10n.chatDeselectAll
                        : l10n.chatSelectAll,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (_isDesktop)
                  IconButton(
                    icon: const Icon(LucideIcons.copy),
                    tooltip: l10n.fileClipboardCopy,
                    onPressed: _selectedFiles.isEmpty
                        ? null
                        : () => unawaited(_copyFilesToClipboard()),
                  ),
                IconButton(
                  icon: Icon(LucideIcons.trash2, color: colors.danger),
                  tooltip: l10n.chatTooltipDelete,
                  onPressed: _selectedFiles.isEmpty
                      ? null
                      : () => _deleteSelectedFiles(),
                ),
                if (_isMobile)
                  IconButton(
                    icon: const Icon(LucideIcons.share2),
                    tooltip: l10n.fmTooltipShareSelection,
                    onPressed: _selectedFiles.isEmpty
                        ? null
                        : () => _shareSelectedFiles(),
                  ),
                IconButton(
                  icon: const Icon(LucideIcons.plus),
                  tooltip: l10n.fmTooltipAddPending,
                  onPressed: _selectedFiles.isEmpty
                      ? null
                      : () => _addSelectedToPending(),
                ),
                TextButton(
                  onPressed: _exitSelectionMode,
                  child: Text(
                    l10n.cancel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ]
            : _buildNormalAppBarActions(l10n),
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: l10n.fmSearchHint,
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                  suffixIcon: (_isSaveFolderTab
                          ? _saveFolderSearchQuery.isNotEmpty
                          : _isSearching)
                      ? IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSaveFolderTabBody(context),
                _buildCacheTabBody(context),
              ],
            ),
          ),
        ],
      ),
    );

    Widget body = scaffold;
    if (_isDesktop && !widget.embedded) {
      body = DesktopPasteShortcuts(
        onPasteFiles: _handleDesktopPaste,
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.keyC, control: true):
                _FmCopyFilesIntent(),
            SingleActivator(LogicalKeyboardKey.keyC, meta: true):
                _FmCopyFilesIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _FmCopyFilesIntent: CallbackAction<_FmCopyFilesIntent>(
                onInvoke: (_) {
                  unawaited(_copyFilesToClipboard());
                  return null;
                },
              ),
            },
            child: body,
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: body,
    );
  }

  Widget _buildCacheTabBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? RefreshIndicator(
              onRefresh: _pullRefresh,
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSearching
                                ? LucideIcons.searchX
                                : LucideIcons.folderOpen,
                            size: 64,
                            color: colors.textTertiary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _isSearching
                                ? l10n.fmEmptyNoMatch
                                : l10n.fmEmptyNoReceived,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _categoryView
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.contentMaxWidth,
                ),
                child: _buildCategoryView(context),
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.contentMaxWidth,
                ),
                child: _buildTimelineView(context, files: _files),
              ),
            ),
    );
  }

  Widget _buildSaveFolderTabBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    if (_saveFolderLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_saveFolderError != null) {
      return RefreshIndicator(
        onRefresh: _pullRefresh,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.folderX,
                      size: 64,
                      color: colors.textTertiary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _saveFolderErrorMessage(l10n),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (_saveFolderDisplayPath != null &&
                        _saveFolderDisplayPath!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.fmSaveFolderPathLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      SelectableText(
                        _saveFolderDisplayLabel != null &&
                                _saveFolderDisplayLabel!.isNotEmpty
                            ? '${_saveFolderDisplayLabel!}\n${_saveFolderDisplayPath!}'
                            : _saveFolderDisplayPath!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _openSettings,
                      child: Text(l10n.fmSaveFolderGoSettings),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    final files = _filteredSaveFolderFiles;
    if (files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _pullRefresh,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _saveFolderSearchQuery.isNotEmpty
                          ? LucideIcons.searchX
                          : LucideIcons.folderOpen,
                      size: 64,
                      color: colors.textTertiary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _saveFolderSearchQuery.isNotEmpty
                          ? l10n.fmEmptyNoMatch
                          : l10n.fmSaveFolderEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
        child: _buildTimelineView(
          context,
          files: files,
          hasMore: false,
        ),
      ),
    );
  }

  Widget _buildTimelineView(
    BuildContext context, {
    required List<ReceivedFileInfo> files,
    bool? hasMore,
  }) {
    final colors = context.appColors;
    final showLoadMore = hasMore ?? _hasMore;
    final itemCount = files.length + (showLoadMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: _pullRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        padding: _listVerticalPadding(context),
        itemCount: itemCount,
        separatorBuilder: (_, index) {
          if (index >= files.length - 1) return const SizedBox.shrink();
          return Divider(height: 1, color: colors.border, indent: 68);
        },
        itemBuilder: (context, index) {
          if (index >= files.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _buildFileItem(context, files[index]);
        },
      ),
    );
  }

  Future<void> _refreshCategory() async {
    await _loadReceiveDirPath(invalidateDirCache: true);
    await _loadAllForCategory();
  }

  Widget _buildSortMenuRow(
    BuildContext context, {
    required String label,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: selected
              ? Icon(
                  LucideIcons.check,
                  size: 16,
                  color: theme.colorScheme.primary,
                )
              : null,
        ),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? theme.colorScheme.primary : colors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryView(BuildContext context) {
    final grouped = <FileCategory, List<ReceivedFileInfo>>{};
    for (final file in _files) {
      grouped.putIfAbsent(file.category, () => []).add(file);
    }
    for (final list in grouped.values) {
      _sortFilesInPlace(list);
    }

    final l10n = AppLocalizations.of(context);
    final categoryNames = <FileCategory, String>{
      FileCategory.image: l10n.fmCategoryImage,
      FileCategory.video: l10n.fmCategoryVideo,
      FileCategory.audio: l10n.fmCategoryAudio,
      FileCategory.pdf: l10n.fmCategoryPdf,
      FileCategory.archive: l10n.fmCategoryArchive,
      FileCategory.document: l10n.fmCategoryDocument,
      FileCategory.code: l10n.fmCategoryCode,
      FileCategory.other: l10n.fmCategoryOther,
    };

    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return RefreshIndicator(
      onRefresh: _pullRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listVerticalPadding(context),
        children: [
          for (final category in sortedCategories)
            _buildCategorySection(
              context,
              categoryNames[category] ?? l10n.fmCategoryOther,
              grouped[category]!,
              category,
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    List<ReceivedFileInfo> files,
    FileCategory category,
  ) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final (_, color) = FileIconWidget.iconData(category);
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      collapsedIconColor: colors.textSecondary,
      iconColor: colors.textSecondary,
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${files.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      children: [for (final file in files) _buildFileItem(context, file)],
    );
  }

  Widget _buildFileItem(BuildContext context, ReceivedFileInfo file) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isHovered = _hoveredFilePath == file.path;
    final isSelected = _selectedFiles.contains(file.path);

    final item = InkWell(
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedFiles.remove(file.path);
                } else {
                  _selectedFiles.add(file.path);
                }
              });
            }
          : () => _openFile(file),
      onLongPress: _isSelectionMode
          ? null
          : (_isDesktop ? null : () => _showFileActions(file)),
      child: Container(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                Icon(
                  isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : colors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              FileIconWidget(
                category: file.category,
                size: 40,
                filePath: file.path,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        _protocolBadge(context, file.protocol),
                        if (!SaveFolderListingService.isSaveFolderEntry(file)) ...[
                          const SizedBox(width: AppSpacing.xs),
                          _exportStatusBadge(context, file),
                        ],
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          formatFileSize(file.size),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatTime(context, _displayTimeFor(file)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isDesktop && !_isSelectionMode)
                Icon(
                  LucideIcons.chevronRight,
                  color: colors.textSecondary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );

    if (!_isDesktop) return item;

    final desktopItem = MouseRegion(
      onEnter: (_) {
        if (!_isSelectionMode) {
          setState(() => _hoveredFilePath = file.path);
        }
      },
      onExit: (_) {
        if (_hoveredFilePath == file.path) {
          setState(() => _hoveredFilePath = null);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          item,
          if (isHovered && !_isSelectionMode)
            Positioned(
              right: AppSpacing.xs,
              bottom: AppSpacing.xxs,
              child: _buildFileHoverActions(file, colors),
            ),
        ],
      ),
    );

    final dragPaths = resolveFileManagerDragPaths(
      currentPath: file.path,
      isSelectionMode: _isSelectionMode,
      selectedFiles: _selectedFiles,
    );

    return DesktopFileDragSource(
      paths: dragPaths,
      enabled: !_isSelectionMode || _selectedFiles.contains(file.path),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showFileContextMenu(file, details.globalPosition),
        child: desktopItem,
      ),
    );
  }

  void _showFileContextMenu(ReceivedFileInfo file, Offset globalPosition) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    showMenu<void>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<void>(
          onTap: () => _showFileInfo(file),
          child: Text(l10n.fmFileInfoAction),
        ),
        PopupMenuItem<void>(
          onTap: () => unawaited(_copyFilesToClipboard([file.path])),
          child: Text(l10n.fileClipboardCopy),
        ),
        PopupMenuItem<void>(
          onTap: () => _openFile(file),
          child: Text(l10n.chatMenuOpen),
        ),
        PopupMenuItem<void>(
          onTap: () => unawaited(_revealInFolder(file)),
          child: Text(l10n.fmRevealInFolder),
        ),
        if (FileExportService.isSupported &&
            !SaveFolderListingService.isSaveFolderEntry(file))
          PopupMenuItem<void>(
            onTap: () => unawaited(_exportFile(file)),
            child: Text(_exportActionLabel(l10n)),
          ),
        PopupMenuItem<void>(
          onTap: () => _addToPending(file),
          child: Text(l10n.chatMenuAddToPending),
        ),
        PopupMenuItem<void>(
          onTap: () => unawaited(_deleteFile(file)),
          child: Row(
            children: [
              Icon(LucideIcons.trash2, size: 20, color: colors.danger),
              const SizedBox(width: 12),
              Text(
                l10n.fmDeleteConfirm,
                style: TextStyle(color: colors.danger),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _exportStatusBadge(BuildContext context, ReceivedFileInfo file) {
    if (SaveFolderListingService.isSaveFolderEntry(file)) {
      return const SizedBox.shrink();
    }
    if (file.exportStatus == ExportStatus.legacy) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final (label, color) = switch (file.exportStatus) {
      ExportStatus.pending => (l10n.fmExportStatusPending, colors.textSecondary),
      ExportStatus.exporting => (l10n.fmExportStatusExporting, AppColorTheme.s3Color),
      ExportStatus.done => (l10n.fmExportStatusDone, AppColorTheme.lanColor),
      ExportStatus.failed => (l10n.fmExportStatusFailed, colors.danger),
      ExportStatus.legacy => ('', colors.textSecondary),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _protocolBadge(BuildContext context, String protocol) {
    final colors = context.appColors;
    final label = switch (protocol) {
      'lan' => 'HTTP',
      's3' => 'S3',
      'webrtc' => 'WebRTC',
      _ => protocol.toUpperCase(),
    };
    final color = switch (protocol) {
      'lan' => AppColorTheme.lanColor,
      's3' => AppColorTheme.s3Color,
      'webrtc' => AppColorTheme.webrtcColor,
      _ => colors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.fmTimeJustNow;
    if (diff.inHours < 1) {
      return l10n.fmTimeMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return l10n.fmTimeHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return l10n.fmTimeDaysAgo(diff.inDays);
    }
    return l10n.fmTimeMonthDayClock(
      dt.month,
      dt.day,
      dt.hour.toString().padLeft(2, '0'),
      dt.minute.toString().padLeft(2, '0'),
    );
  }
}

class _FmCopyFilesIntent extends Intent {
  const _FmCopyFilesIntent();
}
