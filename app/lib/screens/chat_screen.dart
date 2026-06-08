import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:centrifuge/centrifuge.dart' as centrifuge;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide ChatColors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../api/api.dart';
import '../config/env.dart';
import '../device_id.dart';
import '../providers/app_locale.dart';
import '../providers/auth_provider.dart';
import '../providers/app_mode_provider.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_session_controller.dart';
import '../providers/device_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import '../lan/lan_discovery.dart';
import '../lan/lan_receiver.dart';
import '../lan/transfer_worker.dart';
import '../logger.dart';
import '../utils/file_utils.dart';
import '../utils/gallery_permission.dart';
import '../utils/helpers.dart';
import '../utils/runtime_platform.dart';
import '../utils/open_received_file.dart';
import '../utils/received_file_actions.dart';
import '../utils/save_as_feedback.dart';
import '../utils/reveal_file_in_folder.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/attachment_picker_sheet.dart';
import '../widgets/chat/chat_composer.dart';
import '../widgets/chat/chat_message_bubbles.dart';
import '../widgets/chat/chat_screen_overlays.dart';
import '../widgets/chat/chat_session_body.dart';
import '../widgets/chat/chat_theme_helpers.dart';
import '../widgets/chat/connection_diagnostic_dialog.dart';
import '../widgets/layout/main_layout.dart';
import '../widgets/pending_files_bar.dart';
import '../network/connection_bar_view_model.dart';
import '../network/connection_diagnostic.dart';
import '../network/connection_orchestrator.dart';
import '../network/connection_resolution.dart';
import '../network/probe_priority.dart';
import '../widgets/desktop_file_drag_source.dart';
import '../widgets/file_card_bubble.dart';
import 'file_manager_screen.dart';
import 'message_search_screen.dart';
import 'settings_screen.dart';
import '../services/file_store.dart';
import '../services/file_transfer.dart';
import '../services/file_times_apply.dart';
import '../services/mtime_util.dart';
import '../services/cancel_token.dart';
import '../services/cloud_transfer.dart';
import '../services/s3_transfer.dart';
import '../services/speed_tracker.dart';
import '../services/transfer_protocol.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/chat_message_dao.dart';
import '../services/received_file_dao.dart';
import '../services/received_file_index_pipeline.dart';
import '../services/visible_export_target.dart';
import '../chat/thread_key.dart';
import '../services/desktop_file_clipboard.dart';
import '../services/desktop_file_drop_dispatcher.dart';
import '../services/share/share_pending_cache.dart';
import '../services/share_receive_service.dart';
import '../services/pending_files_store.dart';
import '../widgets/desktop_paste_shortcuts.dart';
import '../services/transfer_record.dart';
import '../services/transfer_state_manager.dart';
import '../services/file_export_service.dart';
import '../ui/app_ui.dart';
import '../ui/platform_performance.dart';
import '../webrtc/webrtc_manager.dart';
import '../webrtc/signaling_channel.dart';
import 'apk_picker_screen.dart';
import 'qr_scanner_screen.dart';

/// Number of messages per page for pagination. Adjust for debugging.
const int kChatPageSize = 20;

/// Extracts the sender [localId] encoded in LAN receive message ids.
String? senderLocalIdFromRecvMessageId(String messageId) {
  const prefixes = ['lan_recv_pull_', 'lan_recv_'];
  for (final prefix in prefixes) {
    if (messageId.startsWith(prefix)) {
      final id = messageId.substring(prefix.length);
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}

enum _SessionSettingsAction { rename, clearMessages, remove }

/// Same breakpoint as [MainLayout] — mobile vs tablet/desktop split.
const double kChatNarrowLayoutBreakpoint = 768;

/// Insets for the floating mobile [GlassBottomBar] (content draws full-bleed underneath).
const double _kMobileFloatingBarEdge = 14;
const double _kMobileFloatingBarBottomGap = 12;

/// Compact pill width; total outer width = [GlassBottomBar] horizontal padding ×2 + this × tab count.
const double _kMobileGlassBarTabWidth = 76;
const int _kMobileGlassBarTabCount = 3;
const double _kMobileGlassBarHPadding = 14;

/// Matches [GlassBottomBar.spacing] / [GlassBottomBarExtraButton.size].
const double _kMobileGlassBarExtraSpacing = 8;
const double _kMobileGlassBarExtraSize = 64;
const double _kMobileGlassBarOuterWidth =
    _kMobileGlassBarHPadding * 2 +
    _kMobileGlassBarTabWidth * _kMobileGlassBarTabCount +
    _kMobileGlassBarExtraSpacing +
    _kMobileGlassBarExtraSize;

class _PlatformGlassBackdrop extends StatelessWidget {
  final Widget child;

  const _PlatformGlassBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppPlatformPerformance.preferPlainNarrowNavigation) return child;
    return GlassBackdropScope(child: child);
  }
}

class _FileMeta {
  final String fileName;
  int? size;
  final String? s3Key;
  final String? transferType;
  String? localPath;
  int? lastModifiedMs;
  _FileMeta({
    required this.fileName,
    this.size,
    this.s3Key,
    this.transferType,
    this.localPath,
    this.lastModifiedMs,
  });
}

class _RetryInfo {
  final String fileName;
  final int fileSize;
  final String? filePath;
  final String channel; // 's3', 'lan', 'webrtc'
  final List<DeviceDto>? lanTargets;
  final String? webrtcTargetDeviceId;
  final String? webrtcFileId;
  final String? toDeviceId;
  _RetryInfo({
    required this.fileName,
    required this.fileSize,
    this.filePath,
    required this.channel,
    this.lanTargets,
    this.webrtcTargetDeviceId,
    this.webrtcFileId,
    this.toDeviceId,
  });
}

/// Per-session record of an in-progress LAN reverse-pull download. Lets a
/// retry triggered after a mid-stream interruption (sender cancel, network
/// blip, …) resume from the bytes we already wrote rather than starting over.
class _PullPartial {
  _PullPartial({required this.path, this.size});
  final String path;
  final int? size;
}

class _QueuedProbeRequest {
  _QueuedProbeRequest({
    required this.device,
    required this.requestId,
    required this.mode,
    required this.source,
    this.reporter,
  });

  final DeviceDto device;
  final int requestId;
  final SendMode? mode;
  final String source;
  final ConnectionDiagnosticReporter? reporter;
  final Completer<bool?> completer = Completer<bool?>();
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  bool _connected = false;
  String _deviceId = '';
  String _deviceName = '';
  final String _presenceSessionId = const Uuid().v4();
  centrifuge.Client? _client;
  late final InMemoryChatController _chatController;
  final ScrollController _chatScrollController = ScrollController();
  final Map<String, String> _fileKeyByMessageId = {};
  final Map<String, String> _fileFileNameByMessageId = {};
  // localIds of inbound LAN/WebRTC transfers we've already shown a local
  // bubble for. Used to skip (and upgrade) the eventual Centrifugo `file`
  // publication so we don't render two bubbles for the same transfer. We
  // intentionally key on per-transfer localId (not fileName) so re-sending a
  // same-named file still produces a fresh chat bubble + received_files row.
  final Set<String> _lanRecvLocalIds = {};
  final Set<String> _webrtcRecvLocalIds = {};
  // Mapping from sender localId → receiver-side messageId for any inbound
  // LAN/WebRTC transfer we are tracking. Lets the Centrifugo handler "upgrade"
  // the local bubble id to the server's `${ts}_${fromDeviceId}` id once the
  // server publication arrives.
  final Map<String, String> _lanLocalIdToMessageId = {};
  // Per-session partial download tracking for LAN reverse-pull. Keyed by the
  // sender's localId (which is stable across retries on a given send) so a
  // retry triggered after a sender-side cancel can pass the partial path as
  // `existingFilePath` to `pullFileHttp` and resume via Range. Entries are
  // cleared on successful completion AND on explicit receiver-side cancel
  // (the latter deletes the partial file too). Cleared by app restart —
  // cold-start resume would require persisting this to TransferStateManager,
  // which is out of scope for the current fix.
  final Map<String, _PullPartial> _lanPullPartialBySenderLocalId = {};
  final Map<String, String> _localMessageStatus = {};
  final Map<String, int> _localMessageProgress = {};
  List<PlatformFile> _pendingFiles = [];
  final _composerKey = GlobalKey<ChatComposerState>();
  String? _initError;
  int _initGeneration = 0;
  bool _desktopDevicePanelVisible = false;
  bool _mobileDevicePanelVisible = false;
  double _mobilePanelDragOffset = 0.0;
  bool _mobilePanelDragging = false;
  bool _mobilePanelPendingClose = false;
  static const _keyDevicePanelOpen = 'ultrasend_device_panel_open';

  /// Mobile home bottom tabs (narrow + no chat session): 0 连接 / 1 文件 / 2 设置
  int _mobileMainTabIndex = 0;

  /// Bumped when the user selects the embedded「文件」tab so [FileManagerScreen] can silent-refresh.
  int _embeddedFileTabActivation = 0;
  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  LanReceiver? _lanReceiver;
  LanDiscoveryService? _lanDiscovery;
  bool _statusCheckDone = false;
  int _serverConnectionCheckGeneration = 0;
  bool get _isOffline => ref.read(isOfflineModeProvider);
  bool get _effectiveOffline => ref.read(effectiveOfflineModeProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(appLocaleProvider));

  final Map<String, Completer<bool>> _pendingPullProbes = {};
  final Map<String, Completer<String>> _pendingWebRTCProbes = {};
  final Map<
    String,
    Completer<({bool success, String? lanHttpUrl, bool senderReachable})>
  >
  _pendingLanHttpProbes = {};

  /// Suppresses duplicate probe requests for the same (peer, mode) within this
  /// window. Opportunistic triggers (selection change, roster patch, LAN
  /// discovery, etc.) collapse into the next scheduled probe.
  /// Manual refresh bypasses this via [_enqueueProbeRequest]'s `force: true`.
  static const Duration _probeDedupeWindow = Duration(seconds: 8);

  /// Shorter timeouts for “scan all” / reachability so UI is not held by the
  /// slowest path (WebRTC was 10s); manual mode switch still uses defaults.
  static const Duration _probeQuickDirectHttp = Duration(seconds: 2);
  static const Duration _probeQuickLanSignaling = Duration(seconds: 3);
  static const Duration _probeQuickWebRTC = Duration(seconds: 4);
  static const int _lanProbeConcurrency = 6;
  static const int _signalingProbeConcurrency = 3;
  final Map<String, DateTime> _lastProbeRequestAt = {};
  final Map<String, int> _probeRequestSeqByPeer = {};
  final Set<String> _probeRunningPeers = {};
  final Map<String, _QueuedProbeRequest> _pendingProbeByPeer = {};
  bool _manualSwitchBusy = false;
  final Map<String, CancelToken> _activeTransfers = {};

  /// Tracks the Future of each active send so we can await it before retry.
  final Map<String, Future<void>> _activeTransferFutures = {};

  /// Tracks active LAN receive message IDs → fileName for cancel support.
  final Map<String, String> _activeLanReceives = {};

  /// Maps the chat message id of an active LAN receive to the sender's
  /// `X-File-Id` so cancel requests target the exact in-flight transfer
  /// instead of every transfer sharing the same display name.
  final Map<String, String> _lanRecvFileIdByMsgId = {};

  /// LAN receive message ids that the user has just cancelled. Stored with a
  /// TTL so straggling `_ReceiveProgress` events still in flight from the
  /// worker isolate (the worker only learns about the cancel after the next
  /// loop tick, by which time it may have queued several chunks in the IPC
  /// pipe) cannot revive the "正在接收 X%" bubble after we showed "已取消".
  /// Without this guard the user perceives that the cancel was ignored
  /// because the progress bubble re-appears moments after they tapped cancel.
  final Map<String, DateTime> _cancelledLanReceives = {};
  static const Duration _cancelledReceiveSuppressionWindow = Duration(
    seconds: 60,
  );

  /// senderLocalIds that this receiver has just cancelled, with the
  /// wall-clock cutoff after which the entry is considered stale. When the
  /// sender's push fails it typically falls back to a `lan_file_offer`
  /// reverse-pull within seconds; we suppress that auto-pull so the user
  /// doesn't have to cancel the same file twice.
  final Map<String, DateTime> _lanRecentlyCancelledSenderLocalIds = {};
  static const Duration _lanCancelSuppressionWindow = Duration(seconds: 60);

  /// senderLocalIds whose receive bubble was cancelled while we were already
  /// pulling — kept separately from the offer-suppression set above because
  /// they cover a different race: the sender may have finished writing all
  /// bytes to its socket BEFORE we closed the receiver end, and then publish
  /// a Centrifugo `file` message. Without this suppression that publication
  /// would "upgrade" the cancelled bubble into a FileMessage and the user
  /// would see "已传输完成" even though they had just pressed cancel.
  final Map<String, DateTime> _lanRecvCancelledSenderLocalIds = {};

  /// Maps a senderLocalId we are currently reverse-pulling to the sender's
  /// deviceId. Used by `_cancelDownload` to address the peer-side
  /// `lan_pull_cancelled` notification so the sender can either cancel the
  /// in-flight transfer or roll back a just-completed bubble.
  final Map<String, String> _lanPullSenderDeviceIdByLocalId = {};

  /// Tracks active S3/LAN-pull downloads (keyed by chat message id) so the
  /// progress bubble can offer a cancel button for the download direction.
  final Map<String, CancelToken> _activeDownloads = {};
  final Map<String, SpeedTracker> _speedTrackers = {};
  final Map<String, DateTime> _transferStartTimes = {};
  late final WebRTCManager _webrtcManager;
  Timer? _iosLanRetryTimer;

  /// Low-frequency safety net. Normal device updates flow through Centrifugo
  /// roster patches and LAN discovery events.
  Timer? _presenceRefreshTimer;
  static const Duration _rosterFallbackRefreshInterval = Duration(minutes: 10);
  bool _presencePausedByLifecycle = false;

  /// When [myDevices]/[nearbyDevices] gain new peer IDs, probe them without
  /// waiting for the periodic presence timer.
  Timer? _newPeerProbeDebounce;
  static const Duration _newPeerProbeDebounceWindow = Duration(
    milliseconds: 400,
  );
  Timer? _dirtyProbeDebounce;
  static const Duration _dirtyProbeDebounceWindow = Duration(milliseconds: 600);
  final Set<String> _dirtyProbeDeviceIds = {};
  final Set<String> _knownPeerIdsForQuickProbe = {};
  final Map<String, String?> _lastPresenceByPeer = {};
  String? _selectedPeerPresenceSnapshot;
  String? _selectedPeerLanUrlSnapshot;
  ProviderSubscription<List<DeviceDto>>? _myDevicesListSub;
  ProviderSubscription<List<DeviceDto>>? _nearbyDevicesListSub;
  StreamSubscription<String>? _lanLostPeerSub;
  final CloudTransferService _cloudTransfer = S3TransferService();
  final Map<String, String> _webrtcFileLocalIdMap = {};
  final Map<String, String> _webrtcLocalIdToFileIdMap = {};
  final Map<String, String> _webrtcFileNameMap = {};
  final Map<String, int> _webrtcFileSizeMap = {};
  final Map<String, int> _webrtcFileMtimeMsMap = {};
  final Map<String, String> _webrtcTransferIdMap = {};
  final Map<String, _FileMeta> _fileMetaByMessageId = {};
  final Map<String, _RetryInfo> _retryInfoByLocalId = {};

  // Desktop hover state for message actions
  String? _hoveredMessageId;

  // Message selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedMessages = {};

  // Pagination state
  bool _loadingMore = false;
  bool _hasNoMoreHistory = false;
  int? _oldestServerMessageId;
  final Map<String, int> _serverIdByMessageId = {};
  final Set<String> _loadedMessageIds = {};

  /// Current user id for local message cache; set on first _loadHistory.
  String? _userId;
  Future<String?> _getCurrentUserId() async {
    // 未登录 / 离线模式必须以离线用户写入 SQLite，不能沿用缓存里可能残留的登录 userId。
    if (_isOffline) {
      final oid = await getOrCreateOfflineUserId();
      _userId = oid;
      return oid;
    }
    if (_userId != null) return _userId;
    _userId = await getStoredUserId();
    return _userId;
  }

  /// UserIds to query messages from DB.
  /// Offline: only the offline userId.
  /// Online: current userId + offline userId (for un-migrated messages).
  Future<List<String>> _getQueryUserIds() async {
    final offlineId = await getOrCreateOfflineUserId();
    if (_isOffline) return [offlineId];
    final userId = await _getCurrentUserId();
    if (userId == null || userId.isEmpty) return [offlineId];
    if (userId == offlineId) return [offlineId];
    return [userId, offlineId];
  }

  /// Merge LAN-discovered devices with cloud devices by deviceId; prefer LAN's lanHttpUrl when both present.
  List<DeviceDto> _mergeLanAndCloudDevices(
    List<DeviceDto> lan,
    List<DeviceDto>? cloud,
  ) {
    if (cloud == null || cloud.isEmpty) return lan;
    final byId = <String, DeviceDto>{};
    for (final d in lan) {
      byId[d.deviceId] = d;
    }
    for (final d in cloud) {
      final existing = byId[d.deviceId];
      if (existing != null) {
        byId[d.deviceId] = DeviceDto(
          deviceId: d.deviceId,
          name: d.name,
          platform: d.platform,
          lanHttpUrl: existing.lanHttpUrl ?? d.lanHttpUrl,
          lastSeen: d.lastSeen,
          presenceStatus: d.presenceStatus,
          presenceUpdatedAt: d.presenceUpdatedAt,
          displayCode: d.displayCode,
        );
      } else {
        byId[d.deviceId] = d;
      }
    }
    return byId.values.toList();
  }

  /// Update both in-memory status and persist to DB.
  void _setMessageStatus(String localId, String status) {
    _localMessageStatus[localId] = status;
    ChatMessageDao.instance.updateStatus('local_$localId', status);
  }

  Future<void> _loadDevicePanelState() async {
    final prefs = await SharedPreferences.getInstance();
    final open = prefs.getBool(_keyDevicePanelOpen) ?? false;
    if (!mounted) return;
    setState(() {
      if (_isDesktopPlatform) {
        _desktopDevicePanelVisible = open;
      } else {
        _mobileDevicePanelVisible = open;
      }
    });
    if (_isDesktopPlatform && open) {
      _composerKey.currentState?.restoreDevicePanel(open);
    }
  }

  void _saveDevicePanelState(bool open) {
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_keyDevicePanelOpen, open),
    );
  }

  void _setMobileDevicePanelVisible(bool visible) {
    if (_mobileDevicePanelVisible == visible &&
        _mobilePanelDragOffset == 0.0 &&
        !_mobilePanelDragging &&
        !_mobilePanelPendingClose) {
      return;
    }
    setState(() {
      _mobileDevicePanelVisible = visible;
      _mobilePanelDragOffset = 0.0;
      _mobilePanelDragging = false;
      _mobilePanelPendingClose = false;
    });
    _saveDevicePanelState(visible);
  }

  void _toggleMobileDevicePanel() {
    _setMobileDevicePanelVisible(!_mobileDevicePanelVisible);
  }

  void _openMobileDevicePanel() {
    _setMobileDevicePanelVisible(true);
  }

  void _closeMobileDevicePanel() {
    _setMobileDevicePanelVisible(false);
  }

  ProviderSubscription? _authSub;
  ProviderSubscription? _selectedDeviceSub;
  ProviderSubscription<ConnectionOrchestratorState>? _connectionOrchestratorSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _lastNetworkSignature;
  bool _lanRepairInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadDevicePanelState();
    _chatController = InMemoryChatController();
    _webrtcManager = WebRTCManager();
    _webrtcManager.onProgress = _onWebRTCProgress;
    _webrtcManager.onFileReceived = _onWebRTCFileReceived;
    _webrtcManager.onFileSent = _onWebRTCFileSent;
    _webrtcManager.onFileFailed = _onWebRTCFileFailed;
    _webrtcManager.onFileCancelled = _onWebRTCFileCancelled;
    _webrtcManager.onStateChange = (sid, state) =>
        logChat.info('WebRTC session=$sid state=$state');
    _authSub = ref.listenManual<AuthState>(authProvider, (prev, next) {
      if (prev?.isLoggedIn != next.isLoggedIn) {
        logChat.info('chat_screen auth changed: loggedIn=${next.isLoggedIn}');
        _userId = null;
        _connected = false;
        _client?.disconnect();
        _client = null;
        if (!next.isLoggedIn) {
          if (!mounted) return;
          ref.read(selectedSendModeProvider.notifier).resetForLogout();
          if (ref.read(selectedDeviceIdProvider) == s3VirtualDeviceId) {
            ref.read(selectedDeviceIdProvider.notifier).select(null);
          }
          // AppEntryScreen replaces ChatScreen; do not restart _init().
          return;
        }
        if (!mounted) return;
        unawaited(_init());
      }
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      unawaited(_handleConnectivityChanged(results));
    });
    _selectedDeviceSub = ref.listenManual<String?>(selectedDeviceIdProvider, (
      prev,
      next,
    ) {
      if (prev != next) {
        ref.read(selectedSendModeProvider.notifier).activateDevice(next);
        ref.read(connectionSwitchProbeProvider.notifier).state = null;
        unawaited(_reloadThreadForSelectionChange());
        if (next != null && next != s3VirtualDeviceId) {
          ref.read(chatSendModeAutoProvider.notifier).state = true;
          ref.read(connectionManualOverrideProvider.notifier).state = false;
          ref.read(connectionManualModeProvider.notifier).state = null;
          ref
              .read(selectedSendModeProvider.notifier)
              .select(SendMode.lan, persist: false);
          _seedSelectedPeerReachabilitySnapshot(next);
        } else {
          _clearSelectedPeerReachabilitySnapshot();
        }
        if (next != null) {
          Analytics.track(AnalyticsEvents.chatSessionOpen, {
            'session_type': next == s3VirtualDeviceId ? 's3' : 'peer',
          });
        }
      }
      if (next != null && next != s3VirtualDeviceId) {
        // Always override multi-select state with the conversation device,
        // even if the same device is re-selected.
        ref.read(selectedLanTargetsProvider.notifier).setAll({next});
        if (next != prev) {
          _probeSingleDevice(next);
        }
      }
    });
    _myDevicesListSub = ref.listenManual<List<DeviceDto>>(
      myDevicesProvider,
      (_, __) {
        _scheduleDiffProbeNewPeers();
        _checkSelectedPeerReachabilitySignal();
      },
    );
    _nearbyDevicesListSub = ref.listenManual<List<DeviceDto>>(
      nearbyDevicesProvider,
      (_, __) {
        _scheduleDiffProbeNewPeers();
        _checkSelectedPeerReachabilitySignal();
      },
    );
    _connectionOrchestratorSub = ref.listenManual<ConnectionOrchestratorState>(
      connectionOrchestratorProvider,
      (prev, next) {
        _reconcileSendModeWithAvailability(next);
      },
      fireImmediately: true,
    );
    FileStore.addReceiveDirChangedListener(_onReceiveDirChanged);
    WidgetsBinding.instance.addObserver(this);
    ShareReceiveService.instance.onPendingShareReady = _onPendingShareReady;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapPendingFilesAfterFirstFrame());
    });
    if (_isDesktopPlatform) {
      DesktopFileDropDispatcher.instance.register(
        owner: this,
        handler: _handleDesktopDropFiles,
      );
    }
    _init();
  }

  Future<void> _bootstrapPendingFilesAfterFirstFrame() async {
    final result = await PendingFilesStore.load();
    if (!mounted) return;
    if (result.droppedMissing > 0) {
      await PendingFilesStore.save(result.files);
      if (!mounted) return;
      AppToast.show(
        context,
        message: AppLocalizations.of(context).chatScreenPendingFilesMissing,
      );
    }
    if (result.files.isNotEmpty) {
      _addPendingFiles(result.files);
    }
    _applyPendingFilesFromShare();
  }

  void _persistPendingFiles() {
    unawaited(PendingFilesStore.save(_pendingFiles));
  }

  void _scheduleDiffProbeNewPeers() {
    if (!mounted) return;
    _newPeerProbeDebounce?.cancel();
    _newPeerProbeDebounce = Timer(_newPeerProbeDebounceWindow, () {
      if (mounted) unawaited(_diffProbeNewPeers());
    });
  }

  /// Marks newly discovered peers as provisionally online and batches a targeted
  /// probe instead of waiting for a periodic full scan.
  Future<void> _diffProbeNewPeers() async {
    if (!mounted) return;
    final currentId = await getOrCreateDeviceId();
    if (!mounted) return;
    final ids = <String>{};
    final presenceById = <String, String?>{};
    for (final d in ref.read(myDevicesProvider)) {
      if (d.deviceId != currentId) {
        ids.add(d.deviceId);
        presenceById[d.deviceId] = d.presenceStatus;
      }
    }
    for (final d in ref.read(nearbyDevicesProvider)) {
      if (d.deviceId != currentId) {
        ids.add(d.deviceId);
        presenceById[d.deviceId] = d.presenceStatus;
      }
    }
    if (_knownPeerIdsForQuickProbe.isEmpty) {
      _knownPeerIdsForQuickProbe
        ..clear()
        ..addAll(ids);
      for (final id in ids) {
        _lastPresenceByPeer[id] = presenceById[id];
      }
      return;
    }
    final newOnes = ids.difference(_knownPeerIdsForQuickProbe);
    final reach = ref.read(deviceReachabilityProvider.notifier);
    final selectedId = ref.read(selectedDeviceIdProvider);
    for (final id in ids.difference(newOnes)) {
      final prev = _lastPresenceByPeer[id];
      final next = presenceById[id];
      if (prev == 'offline' && next != 'offline' && next != null) {
        if (selectedId == id) {
          unawaited(_probeSingleDevice(id, force: true));
        } else {
          reach.setDetail(id, DeviceReachDetail.offlineDetail);
          _enqueueDirtyProbe(id);
        }
      }
    }
    _knownPeerIdsForQuickProbe
      ..clear()
      ..addAll(ids);
    for (final id in ids) {
      _lastPresenceByPeer[id] = presenceById[id];
    }
    if (newOnes.isEmpty) return;
    for (final id in newOnes) {
      if (presenceById[id] == 'offline') {
        reach.setDetail(id, DeviceReachDetail.offlineDetail);
        continue;
      }
      reach.setDetail(id, DeviceReachDetail.offlineDetail);
      _enqueueDirtyProbe(id);
    }
  }

  void _enqueueDirtyProbe(String deviceId) {
    if (!mounted || deviceId.isEmpty || deviceId == _deviceId) return;
    if (deviceId == s3VirtualDeviceId) return;
    final device = _findKnownDeviceById(deviceId);
    if (device != null) {
      final nearbyIds = ref
          .read(nearbyDevicesProvider)
          .map((d) => d.deviceId)
          .toSet();
      final myIds = ref.read(myDevicesProvider).map((d) => d.deviceId).toSet();
      final priority = classifyDevice(
        device,
        nearbyIds: nearbyIds,
        myDeviceIds: myIds,
      );
      final selectedId = ref.read(selectedDeviceIdProvider);
      if (priority == ProbePriority.lazy && selectedId != deviceId) return;
    }
    _dirtyProbeDeviceIds.add(deviceId);
    _dirtyProbeDebounce?.cancel();
    _dirtyProbeDebounce = Timer(_dirtyProbeDebounceWindow, () {
      final ids = List<String>.from(_dirtyProbeDeviceIds);
      _dirtyProbeDeviceIds.clear();
      for (final id in ids) {
        unawaited(_probeSingleDevice(id));
      }
    });
  }

  Future<void> _refreshCloudDeviceRosterSnapshot() async {
    await ref.read(cloudDeviceRosterProvider.notifier).refreshSnapshot();
  }

  Future<void> _markPresenceOnline(String reason) async {
    if (!mounted || _deviceId.isEmpty || _effectiveOffline) return;
    try {
      final dto = await updateDevicePresence(
        _deviceId,
        sessionId: _presenceSessionId,
        status: 'online',
        platform: Platform.operatingSystem,
      );
      ref.read(cloudDeviceRosterProvider.notifier).applyUpsert(dto);
      logChat.fine('presence online reason=$reason');
    } catch (e) {
      logChat.warning('presence online failed reason=$reason: $e');
    }
  }

  Future<void> _markPresenceOffline(String reason) async {
    if (_deviceId.isEmpty || _isOffline) return;
    try {
      final dto = await updateDevicePresence(
        _deviceId,
        sessionId: _presenceSessionId,
        status: 'offline',
        platform: Platform.operatingSystem,
      );
      if (mounted) {
        ref.read(cloudDeviceRosterProvider.notifier).applyUpsert(dto);
      }
      logChat.fine('presence offline reason=$reason');
    } catch (e) {
      logChat.warning('presence offline failed reason=$reason: $e');
    }
  }

  void _cancelPresenceRefreshTimer() {
    _presenceRefreshTimer?.cancel();
    _presenceRefreshTimer = null;
  }

  void _schedulePresenceRefresh() {
    _cancelPresenceRefreshTimer();
    if (!mounted) return;
    if (_presencePausedByLifecycle) return;
    _presenceRefreshTimer = Timer.periodic(
      _rosterFallbackRefreshInterval,
      (_) => unawaited(_onPresenceRefreshTick()),
    );
  }

  /// Low-frequency fallback for missed realtime roster/discovery events.
  Future<void> _onPresenceRefreshTick() async {
    if (!mounted) return;
    if (_presencePausedByLifecycle) return;

    final probing = ref.read(devicesProbingProvider);
    final loggedIn = ref.read(authProvider).isLoggedIn;
    final cloudActive = ref.read(isCloudSessionActiveProvider);
    final shouldRefreshCloud = loggedIn && cloudActive;

    if (shouldRefreshCloud) {
      await _refreshCloudDeviceRosterSnapshot();
    }

    if (probing) {
      logChat.fine('roster.fallback skip probe (already probing)');
      return;
    }

    await _probeAllDevices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _presencePausedByLifecycle = false;
        _schedulePresenceRefresh();
        unawaited(_markPresenceOnline('app_resumed'));
        unawaited(_refreshRosterAndProbeSelected('app_resumed'));
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _presencePausedByLifecycle = true;
        _cancelPresenceRefreshTimer();
        unawaited(_markPresenceOffline('app_${state.name}'));
        break;
    }
  }

  Future<void> _refreshRosterAndProbeSelected(String reason) async {
    if (!mounted) return;
    final loggedIn = ref.read(authProvider).isLoggedIn;
    final cloudActive = ref.read(isCloudSessionActiveProvider);
    if (loggedIn && cloudActive) {
      logChat.fine('roster snapshot refresh reason=$reason');
      await _refreshCloudDeviceRosterSnapshot();
    }
    if (!mounted || ref.read(devicesProbingProvider)) return;
    final selected = ref.read(selectedDeviceIdProvider);
    if (selected != null && selected != s3VirtualDeviceId) {
      await _probeSingleDevice(selected);
    }
  }

  void _reconcileSendModeWithAvailability(ConnectionOrchestratorState orchestrator) {
    final peerId = ref.read(selectedDeviceIdProvider);
    if (peerId == null || peerId == s3VirtualDeviceId) return;

    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    final isRegisteredPeer = ref
        .read(myDevicesProvider)
        .any((d) => d.deviceId == peerId);
    final auto = ref.read(chatSendModeAutoProvider);
    final preferred = ref.read(selectedSendModeProvider);
    final resolved = auto
        ? resolveSendModeAutoPreferHttp(
            candidates: orchestrator.candidates,
            isLoggedIn: isLoggedIn,
            isRegisteredPeer: isRegisteredPeer,
            fallback: preferred,
          )
        : resolveSendModeWithMemory(
            preferred: preferred,
            candidates: orchestrator.candidates,
            isLoggedIn: isLoggedIn,
            isRegisteredPeer: isRegisteredPeer,
          );
    if (resolved != preferred) {
      logChat.info(
        'send mode ${auto ? 'auto' : 'manual'} ${preferred.name} -> ${resolved.name}',
      );
      ref
          .read(selectedSendModeProvider.notifier)
          .select(resolved, persist: !auto);
    }
  }

  Future<void> _confirmAndSwitchMode(SendMode mode) async {
    if (_manualSwitchBusy || !mounted) return;
    final peerId = ref.read(selectedDeviceIdProvider);
    if (peerId == null || peerId == s3VirtualDeviceId) return;

    setState(() => _manualSwitchBusy = true);
    try {
      ref.read(chatSendModeAutoProvider.notifier).state = false;
      ref.read(connectionManualOverrideProvider.notifier).state = true;
      ref.read(connectionManualModeProvider.notifier).state = mode;
      ref.read(selectedSendModeProvider.notifier).select(mode);
      await _probeSelectedModeAfterSwitch(peerId, mode);
    } finally {
      if (mounted) setState(() => _manualSwitchBusy = false);
    }
  }

  Future<void> _probeSelectedModeAfterSwitch(
    String peerId,
    SendMode mode,
  ) async {
    final device = _findKnownDeviceById(peerId);
    if (device == null) return;
    final l10n = AppLocalizations.of(context);
    ref
        .read(connectionSwitchProbeProvider.notifier)
        .state = ConnectionSwitchProbeState(
      peerId: peerId,
      mode: mode,
      hint: l10n.chatProbeDetecting(connectionModeLabel(mode, l10n: l10n)),
    );
    final ok = await _enqueueProbeRequest(
      device,
      mode: mode,
      source: 'manual_switch',
    );
    ref
        .read(connectionSwitchProbeProvider.notifier)
        .state = ConnectionSwitchProbeState(
      peerId: peerId,
      mode: mode,
      hint: ok == true
          ? l10n.chatProbeAvailable(connectionModeLabel(mode, l10n: l10n))
          : ok == false
          ? (mode == SendMode.lan || mode == SendMode.nearby)
              ? l10n.chatProbeUnverifiedAttemptable(
                  connectionModeLabel(mode, l10n: l10n),
                )
              : l10n.chatProbeUnavailable(connectionModeLabel(mode, l10n: l10n))
          : l10n.chatProbeTriggered(connectionModeLabel(mode, l10n: l10n)),
    );
  }

  bool _isProbeRequestCurrent(String peerId, int requestId) {
    return (_probeRequestSeqByPeer[peerId] ?? 0) == requestId;
  }

  String _probeRequestKey(String peerId, SendMode? mode) {
    final modeKey = mode?.name ?? 'all';
    return '$peerId|$modeKey';
  }

  Future<bool?> _enqueueProbeRequest(
    DeviceDto device, {
    SendMode? mode,
    required String source,
    bool force = false,
    ConnectionDiagnosticReporter? reporter,
  }) async {
    final peerId = device.deviceId;
    final key = _probeRequestKey(peerId, mode);
    final now = DateTime.now();
    final last = _lastProbeRequestAt[key];
    if (!force && last != null && now.difference(last) < _probeDedupeWindow) {
      logChat.fine(
        'probe.skip dedupe source=$source peer=$peerId mode=${mode?.name ?? 'all'}',
      );
      if (mounted) {
        ref
            .read(deviceReachabilityProvider.notifier)
            .mergeDetail(peerId, checking: false);
      }
      return null;
    }
    _lastProbeRequestAt[key] = now;
    final requestId = (_probeRequestSeqByPeer[peerId] ?? 0) + 1;
    _probeRequestSeqByPeer[peerId] = requestId;
    final request = _QueuedProbeRequest(
      device: device,
      requestId: requestId,
      mode: mode,
      source: source,
      reporter: reporter,
    );

    if (_probeRunningPeers.contains(peerId)) {
      final replaced = _pendingProbeByPeer[peerId];
      if (replaced != null && !replaced.completer.isCompleted) {
        replaced.completer.complete(null);
      }
      _pendingProbeByPeer[peerId] = request;
      return request.completer.future;
    }

    _probeRunningPeers.add(peerId);
    try {
      _QueuedProbeRequest? current = request;
      while (current != null) {
        final result = await _executeProbeRequest(current);
        if (!current.completer.isCompleted) {
          current.completer.complete(result);
        }
        current = _pendingProbeByPeer.remove(peerId);
      }
    } finally {
      _probeRunningPeers.remove(peerId);
    }
    return request.completer.future;
  }

  Future<bool?> _executeProbeRequest(_QueuedProbeRequest request) async {
    final peerId = request.device.deviceId;
    logChat.fine(
      'probe.run source=${request.source} peer=$peerId mode=${request.mode?.name ?? 'all'}',
    );
    final reach = ref.read(deviceReachabilityProvider.notifier);
    if (_isProbeRequestCurrent(peerId, request.requestId)) {
      reach.mergeDetail(peerId, checking: true);
    }
    if (request.mode != null) {
      return _probeSingleModeForDevice(
        request.device,
        request.mode!,
        requestId: request.requestId,
      );
    }
    if (request.reporter != null) {
      final orderedStepIds = ref
          .read(connectionDiagnosticProvider)
          .steps
          .map((step) => step.id)
          .toList(growable: false);
      await _runConnectionDiagnostic(
        request.device,
        requestId: request.requestId,
        reporter: request.reporter!,
        orderedStepIds: orderedStepIds,
      );
      return null;
    }
    await _probeDeviceAllMethods(
      request.device,
      requestId: request.requestId,
    );
    return null;
  }

  Future<bool> _probeSingleModeForDevice(
    DeviceDto device,
    SendMode mode, {
    required int requestId,
  }) async {
    final peerId = device.deviceId;
    final reach = ref.read(deviceReachabilityProvider.notifier);
    bool isCurrent() => _isProbeRequestCurrent(peerId, requestId);

    bool directHttp = false;
    bool peerHttpHealthy = false;
    bool pullReachable = false;
    bool webrtc = false;

    switch (mode) {
      case SendMode.nearby:
      case SendMode.lan:
        if (device.lanHttpUrl != null && device.lanHttpUrl!.isNotEmpty) {
          try {
            directHttp = await probeHttp(
              device.lanHttpUrl!,
              timeout: const Duration(seconds: 3),
            );
          } catch (_) {}
        }
        if (mounted && isCurrent()) {
          reach.mergeDetail(peerId, directHttp: directHttp);
        }
        final lanReach = await _resolveLanReachFromProbes(
          device,
          directHttp: directHttp,
        );
        peerHttpHealthy = lanReach.peerHttpHealthy;
        pullReachable = lanReach.pullReachable;
        if (mounted && isCurrent()) {
          reach.mergeDetail(
            peerId,
            peerHttpHealthy: peerHttpHealthy,
            pullReachable: pullReachable,
          );
        }
        break;
      case SendMode.webrtc:
        if (!_effectiveOffline) {
          try {
            final c = await _sendWebRTCProbe(peerId);
            webrtc = c == 'online' || c == 'connectable';
          } catch (_) {}
        }
        if (mounted && isCurrent()) {
          reach.mergeDetail(peerId, webrtc: webrtc);
        }
        break;
      case SendMode.s3:
        if (mounted && isCurrent()) {
          reach.mergeDetail(peerId);
        }
        break;
    }

    if (mounted && isCurrent()) {
      reach.mergeDetail(peerId, checking: false, provisionalOnline: false);
    }
    if (!isCurrent()) return false;
    final detail = ref.read(deviceReachabilityProvider)[peerId];
    final s3Online = ref.read(s3OnlineProvider);
    return _modeReachable(
      mode,
      detail ?? DeviceReachDetail.offlineDetail,
      s3Online: s3Online,
    );
  }

  bool _modeReachable(
    SendMode mode,
    DeviceReachDetail detail, {
    required bool s3Online,
  }) {
    switch (mode) {
      case SendMode.nearby:
      case SendMode.lan:
        return httpTransferAvailable(detail);
      case SendMode.webrtc:
        return detail.webrtc == true;
      case SendMode.s3:
        return s3Online;
    }
  }

  void _applyProbeLanHttpUrl(String deviceId, String? lanHttpUrl) {
    final url = lanHttpUrl?.trim();
    if (url == null || url.isEmpty) return;
    final device = _findKnownDeviceById(deviceId);
    _lanDiscovery?.addManualDevice(
      DeviceDto(
        deviceId: deviceId,
        name: device?.name ?? deviceId,
        platform: device?.platform,
        lanHttpUrl: url,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        presenceStatus: device?.presenceStatus,
        presenceUpdatedAt: device?.presenceUpdatedAt,
        displayCode: device?.displayCode,
      ),
    );
  }

  Future<({bool peerHttpHealthy, bool pullReachable})> _resolveLanReachFromProbes(
    DeviceDto device, {
    required bool directHttp,
    Duration signalingTimeout = const Duration(seconds: 5),
  }) async {
    var peerHttpHealthy = false;
    var pullReachable = false;

    if (!_effectiveOffline) {
      try {
        final r = await _sendLanHttpProbe(
          device.deviceId,
          responseTimeout: signalingTimeout,
        );
        peerHttpHealthy = r.success;
        pullReachable = r.senderReachable;
        _applyProbeLanHttpUrl(device.deviceId, r.lanHttpUrl);
      } catch (_) {}
    }

    if (!directHttp && !pullReachable && !_effectiveOffline) {
      try {
        pullReachable = await _sendPullProbe(device.deviceId);
      } catch (_) {}
    }

    return (peerHttpHealthy: peerHttpHealthy, pullReachable: pullReachable);
  }

  DeviceDto? _findKnownDeviceById(String deviceId) {
    for (final d in ref.read(myDevicesProvider)) {
      if (d.deviceId == deviceId) return d;
    }
    for (final d in ref.read(nearbyDevicesProvider)) {
      if (d.deviceId == deviceId) return d;
    }
    return null;
  }

  void _seedSelectedPeerReachabilitySnapshot(String peerId) {
    final device = _findKnownDeviceById(peerId);
    _selectedPeerPresenceSnapshot = device?.presenceStatus;
    _selectedPeerLanUrlSnapshot = device?.lanHttpUrl?.trim();
  }

  void _clearSelectedPeerReachabilitySnapshot() {
    _selectedPeerPresenceSnapshot = null;
    _selectedPeerLanUrlSnapshot = null;
  }

  /// Re-probes the selected peer when presence goes online or [lanHttpUrl] arrives.
  void _checkSelectedPeerReachabilitySignal() {
    if (!mounted) return;
    final peerId = ref.read(selectedDeviceIdProvider);
    if (peerId == null || peerId == s3VirtualDeviceId) return;
    final device = _findKnownDeviceById(peerId);
    if (device == null) return;

    final presence = device.presenceStatus;
    final lanUrl = device.lanHttpUrl?.trim() ?? '';
    final prevPresence = _selectedPeerPresenceSnapshot;
    final prevLanUrl = _selectedPeerLanUrlSnapshot;

    if (prevPresence == null && prevLanUrl == null) {
      _selectedPeerPresenceSnapshot = presence;
      _selectedPeerLanUrlSnapshot = lanUrl.isEmpty ? null : lanUrl;
      return;
    }

    var shouldProbe = false;
    if (prevPresence == 'offline' && presence != 'offline' && presence != null) {
      shouldProbe = true;
    }
    if (lanUrl.isNotEmpty && lanUrl != (prevLanUrl ?? '')) {
      shouldProbe = true;
    }

    _selectedPeerPresenceSnapshot = presence;
    _selectedPeerLanUrlSnapshot = lanUrl.isEmpty ? null : lanUrl;

    if (shouldProbe) {
      logChat.info(
        'selected peer reachability signal peer=$peerId presence=$presence lanUrl=${lanUrl.isNotEmpty}',
      );
      unawaited(_probeSingleDevice(peerId, force: true));
    }
  }

  void _applyPendingFilesFromShare() {
    if (!mounted) return;
    final files = ShareReceiveService.instance.takePendingFromShare();
    if (files != null && files.isNotEmpty) {
      _addPendingFiles(files);
    }
  }

  void _onPendingShareReady() {
    _applyPendingFilesFromShare();
  }

  void _onReceiveDirChanged() {
    Future.microtask(() async {
      await _refreshReceiveDir();
      await _lanReceiver?.stop();
      if (mounted) await _startLanReceiver();
      if (mounted) setState(() {});
    });
  }

  bool _initStillCurrent(int generation) =>
      mounted && generation == _initGeneration;

  Future<void> _init() async {
    final generation = ++_initGeneration;
    _cancelPresenceRefreshTimer();
    await _lanLostPeerSub?.cancel();
    _lanLostPeerSub = null;
    _newPeerProbeDebounce?.cancel();
    _newPeerProbeDebounce = null;
    _knownPeerIdsForQuickProbe.clear();
    _deviceId = await getOrCreateDeviceId();
    if (!_initStillCurrent(generation)) return;
    _deviceName = await getDeviceName();
    if (!_initStillCurrent(generation)) return;
    logChat.info('chat_screen init deviceId=$_deviceId offline=$_isOffline');

    if (mounted) setState(() => _statusCheckDone = false);

    // 阶段一：先加载本地消息和 LAN，服务器状态保持“检查中”直到探测完成。

    _lanDiscovery = LanDiscoveryService.ensureInstance(
      deviceId: _deviceId,
      deviceName: _deviceName,
      platform: Platform.operatingSystem,
    );

    await _refreshReceiveDir();
    if (!_initStillCurrent(generation)) return;
    // Make sure pre-existing files in the receive root are indexed before
    // history load runs the backfill — otherwise old chats won't preview
    // until the user pulls to refresh the file manager. Bounded by the
    // number of subdirectories, so it stays fast even with many files.
    try {
      final root = await FileStore.getCacheDir();
      await ReceivedFileDao.instance.reconcileWithRoot(root);
    } catch (e) {
      logChat.warning('startup reconcileWithRoot failed: $e');
    }
    if (!_initStillCurrent(generation)) return;
    await TransferStateManager.instance.cleanExpired();
    if (!_initStillCurrent(generation)) return;
    await _restoreResumableLanTransfers();
    if (!_initStillCurrent(generation)) return;
    await _loadHistory();
    if (!_initStillCurrent(generation)) return;
    await _lanReceiver?.stop();
    await _lanDiscovery?.stopDiscovery();
    if (!_initStillCurrent(generation)) return;
    await _startLanReceiver();
    if (!_initStillCurrent(generation)) return;
    if (_lanDiscovery != null) {
      _lanLostPeerSub = _lanDiscovery!.lostDiscoveredDeviceIds.listen((
        deviceId,
      ) {
        if (!mounted) return;
        logChat.fine(
          'LanDiscovery peer lost id=$deviceId → reachability offline',
        );
        ref
            .read(deviceReachabilityProvider.notifier)
            .setDetail(deviceId, DeviceReachDetail.offlineDetail);
      });
      _lanDiscovery!.startDiscovery();
    }

    // iOS: the initial Bonjour operations may silently fail while
    // the local-network permission dialog is on screen.  Schedule
    // a retry so that once the user taps "Allow", we restart.
    _scheduleIosLanRetry();

    // Check S3 configuration
    _checkS3Config();

    // 阶段二：后台检测服务器（不阻塞 UI）
    if (!_initStillCurrent(generation)) return;
    _checkServerConnection();
    if (!_initStillCurrent(generation)) return;
    _schedulePresenceRefresh();
  }

  void _scheduleIosLanRetry() {
    _iosLanRetryTimer?.cancel();
    if (!Platform.isIOS) return;
    _iosLanRetryTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _lanDiscovery == null) return;
      unawaited(_lanDiscovery!.restartLanDiscovery());
    });
  }

  /// Sidebar / connection-bar refresh: restart mDNS browse + broadcast, then probe.
  /// [_probeAllDevices] alone cannot recover if Bonsoir missed announcements.
  Future<void> _manualRefreshDevices() async {
    if (!mounted) return;
    if (ref.read(devicesProbingProvider)) return;

    final loggedIn = ref.read(authProvider).isLoggedIn;
    final cloudActive = ref.read(isCloudSessionActiveProvider);
    final shouldRefreshCloud = loggedIn && cloudActive;

    if (shouldRefreshCloud) {
      await _checkS3Config();
      if (!mounted) return;
      await _refreshCloudDeviceRosterSnapshot();
      if (!mounted) return;
    }

    if (_lanDiscovery != null) {
      await _lanDiscovery!.restartLanDiscovery();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    await _probeAllDevices(force: true);
  }

  /// Connection bar refresh: re-probe only the open conversation peer (+ S3).
  Future<void> _refreshSelectedSessionReach() async {
    if (!mounted) return;
    final selected = ref.read(selectedDeviceIdProvider);
    if (selected == null || selected == s3VirtualDeviceId) {
      if (ref.read(authProvider).isLoggedIn) {
        await _checkS3Config();
      }
      return;
    }

    final checking =
        ref.read(deviceReachabilityProvider)[selected]?.checking ?? false;
    if (checking) return;

    final device = _findKnownDeviceById(selected);
    if (device == null) return;

    final l10n = AppLocalizations.of(context);
    final peerLabel = connectionPeerLabel(selected, device: device);
    final nearbyIds = ref
        .read(nearbyDevicesProvider)
        .map((d) => d.deviceId)
        .toSet();
    final myDeviceIds = ref
        .read(myDevicesProvider)
        .map((d) => d.deviceId)
        .toSet();
    final priority = classifyDevice(
      device,
      nearbyIds: nearbyIds,
      myDeviceIds: myDeviceIds,
    );
    final orderedIds = diagnosticStepOrder(devicePriority: priority);
    final steps = orderedIds
        .map(
          (id) => ConnectionDiagnosticStep(
            id: id,
            title: diagnosticStepTitle(l10n, id),
          ),
        )
        .toList(growable: false);

    final diagnosticNotifier = ref.read(connectionDiagnosticProvider.notifier);
    diagnosticNotifier.startSession(
      peerId: selected,
      peerLabel: peerLabel,
      steps: steps,
    );
    final reporter = ConnectionDiagnosticReporter(diagnosticNotifier);

    unawaited(showConnectionDiagnosticSheet(context));

    try {
      await _enqueueProbeRequest(
        device,
        source: 'session_reach_refresh',
        force: true,
        reporter: reporter,
      );

      if (mounted) {
        reporter.setSummary(_buildConnectionDiagnosticSummary(selected, l10n));
      }
    } catch (e) {
      logChat.warning('_refreshSelectedSessionReach diagnostic failed: $e');
      if (mounted) {
        reporter.setSummary(l10n.connectionDiagSummaryNoRoute);
      }
    }
  }

  Future<void> _runConnectionDiagnostic(
    DeviceDto device, {
    required int requestId,
    required ConnectionDiagnosticReporter reporter,
    required List<ConnectionDiagnosticStepId> orderedStepIds,
  }) async {
    final peerId = device.deviceId;
    bool isCurrent() => _isProbeRequestCurrent(peerId, requestId);
    final l10n = lookupAppLocalizations(ref.read(appLocaleProvider));

    var directHttp = false;
    var peerHttpHealthy = false;
    var pullReachable = false;
    bool? webrtcResult;

    for (final stepId in orderedStepIds) {
      if (!isCurrent()) return;

      switch (stepId) {
        case ConnectionDiagnosticStepId.httpDirect:
          reporter.beginStep(stepId);
          final lanUrl = device.lanHttpUrl?.trim();
          if (lanUrl == null || lanUrl.isEmpty) {
            reporter.finishFailure(
              stepId,
              reason: l10n.connectionDiagReasonHttpDirectNoUrl,
            );
          } else {
            try {
              directHttp = await probeHttp(
                lanUrl,
                timeout: _probeQuickDirectHttp,
              );
            } catch (_) {}
            if (directHttp) {
              reporter.finishSuccess(
                stepId,
                reason: l10n.connectionDiagReasonHttpDirectOk,
              );
            } else {
              reporter.finishFailure(
                stepId,
                reason: l10n.connectionDiagReasonHttpDirectFail,
              );
            }
          }
        case ConnectionDiagnosticStepId.httpSignaling:
          reporter.beginStep(stepId);
          if (_effectiveOffline) {
            reporter.finishFailure(
              stepId,
              reason: l10n.connectionDiagReasonOfflineCloud,
            );
          } else {
            try {
              final r = await _sendLanHttpProbe(
                peerId,
                responseTimeout: _probeQuickLanSignaling,
              );
              peerHttpHealthy = r.success;
              if (r.senderReachable) pullReachable = true;
              _applyProbeLanHttpUrl(peerId, r.lanHttpUrl);
              if (peerHttpHealthy) {
                reporter.finishSuccess(
                  stepId,
                  reason: l10n.connectionDiagReasonHttpSignalingOk,
                );
              } else {
                reporter.finishFailure(
                  stepId,
                  reason: l10n.connectionDiagReasonHttpSignalingFail,
                );
              }
            } catch (_) {
              reporter.finishFailure(
                stepId,
                reason: l10n.connectionDiagReasonHttpSignalingFail,
              );
            }
          }
        case ConnectionDiagnosticStepId.httpPull:
          reporter.beginStep(stepId);
          if (_effectiveOffline) {
            reporter.finishFailure(
              stepId,
              reason: l10n.connectionDiagReasonOfflineCloud,
            );
          } else {
            try {
              final ok = await _sendPullProbe(peerId);
              if (ok) pullReachable = true;
              if (ok) {
                reporter.finishSuccess(
                  stepId,
                  reason: l10n.connectionDiagReasonHttpPullOk,
                );
              } else {
                reporter.finishFailure(
                  stepId,
                  reason: l10n.connectionDiagReasonHttpPullFail,
                );
              }
            } catch (_) {
              reporter.finishFailure(
                stepId,
                reason: l10n.connectionDiagReasonHttpPullFail,
              );
            }
          }
        case ConnectionDiagnosticStepId.webrtc:
          reporter.beginStep(stepId);
          if (_effectiveOffline) {
            reporter.finishFailure(
              stepId,
              reason: l10n.connectionDiagReasonOfflineCloud,
            );
          } else {
            try {
              final connectivity = await _sendWebRTCProbe(
                peerId,
                responseTimeout: _probeQuickWebRTC,
              );
              final ok =
                  connectivity == 'online' || connectivity == 'connectable';
              webrtcResult = ok;
              if (ok) {
                final reason = connectivity == 'online'
                    ? l10n.connectionDiagReasonWebrtcOnline
                    : l10n.connectionDiagReasonWebrtcConnectable;
                reporter.finishSuccess(stepId, reason: reason);
              } else {
                reporter.finishFailure(
                  stepId,
                  reason: l10n.connectionDiagReasonWebrtcFail,
                );
              }
            } catch (_) {
              webrtcResult = false;
              reporter.finishFailure(
                stepId,
                reason: l10n.connectionDiagReasonWebrtcFail,
              );
            }
          }
        case ConnectionDiagnosticStepId.s3:
          reporter.beginStep(stepId);
          if (!ref.read(authProvider).isLoggedIn) {
            reporter.finishFailure(
              stepId,
              reason: l10n.connectionDiagReasonS3LoginRequired,
            );
          } else {
            await _checkS3Config();
            if (!mounted || !isCurrent()) return;
            final s3Configured = ref.read(s3ConfiguredProvider);
            final s3Online = ref.read(s3OnlineProvider);
            if (!s3Configured) {
              reporter.finishFailure(
                stepId,
                reason: l10n.connectionDiagReasonS3NotConfigured,
              );
            } else if (s3Online) {
              reporter.finishSuccess(
                stepId,
                reason: l10n.connectionDiagReasonS3Online,
              );
            } else {
              reporter.finishFailure(
                stepId,
                reason: l10n.connectionDiagReasonS3Unavailable,
              );
            }
          }
      }
    }

    if (!mounted || !isCurrent()) return;
    ref.read(deviceReachabilityProvider.notifier).mergeDetail(
      peerId,
      directHttp: directHttp,
      peerHttpHealthy: peerHttpHealthy,
      pullReachable: pullReachable,
      webrtc: webrtcResult,
      checking: false,
      provisionalOnline: false,
    );
  }

  String _buildConnectionDiagnosticSummary(String peerId, AppLocalizations l10n) {
    final orchestrator = ref.read(connectionOrchestratorProvider);
    ConnectionCandidate? best;
    for (final c in orchestrator.candidates) {
      if (c.available) {
        best = c;
        break;
      }
    }
    if (best == null) {
      return l10n.connectionDiagSummaryNoRoute;
    }
    final modeLabel = transferModeBarLabel(best.mode, l10n: l10n);
    return l10n.connectionDiagSummaryRecommend(modeLabel, best.reason);
  }

  Future<void> _confirmDeleteThisDevice() async {
    final ok = await AppConfirmDialog.show(
      context,
      title: _l10n.chatScreenDeleteThisDeviceTitle,
      content: _l10n.chatScreenDeleteThisDeviceBody,
      confirmLabel: _l10n.chatScreenConfirmDeleteLabel,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!ok || !mounted) return;
    final deviceId = await getOrCreateDeviceId();
    try {
      await deleteDevice(deviceId);
      if (!mounted) return;
      ref.read(cloudDeviceRosterProvider.notifier).applyRemove(deviceId);
      await ref.read(authProvider.notifier).clearAuth();
      if (!mounted) return;
      AppToast.show(context, message: _l10n.chatScreenToastDeletedThisDevice);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      logChat.warning('deleteThisDevice failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: _l10n.chatScreenToastDeleteDeviceFailed('$e'),
        );
      }
    }
  }

  Future<void> _confirmRemovePeerDevice(String peerDeviceId) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: _l10n.chatScreenRemovePeerTitle,
      content: _l10n.chatScreenRemovePeerBody,
      confirmLabel: _l10n.chatScreenConfirmRemoveLabel,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!ok || !mounted) return;
    try {
      await deleteDevice(peerDeviceId);
      if (!mounted) return;
      ref.read(cloudDeviceRosterProvider.notifier).applyRemove(peerDeviceId);
      ref.read(selectedDeviceIdProvider.notifier).select(null);
      AppToast.show(context, message: _l10n.chatScreenToastRemovedPeer);
    } catch (e) {
      logChat.warning('removePeerDevice failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: _l10n.chatScreenToastRemovePeerFailed('$e'),
        );
      }
    }
  }

  Future<void> _openSessionDeviceSettings() async {
    _composerKey.currentState?.unfocus();
    final selectedId = ref.read(selectedDeviceIdProvider);
    if (selectedId == null || selectedId == s3VirtualDeviceId) return;

    final currentId =
        ref.read(deviceInfoProvider).valueOrNull?.id ??
        await getOrCreateDeviceId();
    if (!mounted) return;
    final isSelf = selectedId == currentId;

    final colors = context.appColors;
    final theme = Theme.of(context);

    final action = await showModalBottomSheet<_SessionSettingsAction>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    sheetL10n.chatScreenSessionSettingsTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    LucideIcons.pencil,
                    size: 22,
                    color: colors.textSecondary,
                  ),
                  title: Text(sheetL10n.chatScreenTileRenameDevice),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
                  onTap: () => Navigator.pop(ctx, _SessionSettingsAction.rename),
                ),
                ListTile(
                  leading: Icon(
                    LucideIcons.messageSquareX,
                    size: 22,
                    color: colors.warning,
                  ),
                  title: Text(sheetL10n.chatScreenTileClearMessages),
                  subtitle: Text(
                    sheetL10n.chatScreenSubtitleClearMessages,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
                  onTap: () =>
                      Navigator.pop(ctx, _SessionSettingsAction.clearMessages),
                ),
                ListTile(
                  leading: Icon(
                    LucideIcons.trash2,
                    size: 22,
                    color: colors.danger,
                  ),
                  title: Text(
                    isSelf
                        ? sheetL10n.chatScreenTileRemoveThisDevice
                        : sheetL10n.chatScreenTileRemovePeer,
                  ),
                  subtitle: Text(
                    isSelf
                        ? sheetL10n.chatScreenSubtitleRemoveThisDevice
                        : sheetL10n.chatScreenSubtitleRemovePeer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
                  onTap: () => Navigator.pop(ctx, _SessionSettingsAction.remove),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _SessionSettingsAction.rename:
        await _renameSessionDevice(selectedId, currentId);
      case _SessionSettingsAction.clearMessages:
        await _confirmClearSessionMessages();
      case _SessionSettingsAction.remove:
        if (isSelf) {
          await _confirmDeleteThisDevice();
        } else {
          await _confirmRemovePeerDevice(selectedId);
        }
    }
  }

  Future<void> _renameSessionDevice(
    String deviceId,
    String currentDeviceId,
  ) async {
    final device = _findKnownDeviceById(deviceId);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final nameController = TextEditingController(text: device?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          titlePadding: AppDialog.titlePadding,
          contentPadding: AppDialog.confirmContentPadding,
          actionsPadding: AppDialog.actionsPadding,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  loc.devicesRenameTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  foregroundColor: colors.textTertiary,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(hintText: loc.devicesNameHint),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(loc.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, nameController.text.trim()),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(loc.commonSave),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      await updateDevice(deviceId, name: result);
      if (deviceId == currentDeviceId) await setDeviceName(result);
      if (!mounted) return;
      await ref.read(cloudDeviceRosterProvider.notifier).refreshSnapshot();
      AppToast.show(
        context,
        message: AppLocalizations.of(context).devicesSavedToast,
      );
    } catch (e) {
      logChat.warning('session rename failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).devicesSaveFailed('$e'),
        );
      }
    }
  }

  Future<void> _confirmClearSessionMessages() async {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    var deleteCache = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
              titlePadding: AppDialog.titlePadding,
              contentPadding: AppDialog.confirmContentPadding,
              actionsPadding: AppDialog.actionsPadding,
              title: Text(
                loc.chatScreenClearMessagesTitle,
                style: theme.textTheme.titleMedium,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.chatScreenClearMessagesConfirm,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: deleteCache,
                    onChanged: (v) =>
                        setState(() => deleteCache = v ?? false),
                    title: Text(
                      loc.chatScreenClearMessagesDeleteCache,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: Text(loc.cancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: colors.danger,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(loc.chatScreenTileClearMessages),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final threadKey = await _threadKeyForCurrentSelection();
    if (threadKey == null || !mounted) return;

    try {
      final queryUserIds = await _getQueryUserIds();
      await ChatMessageDao.instance.deleteAllForThread(
        userIds: queryUserIds,
        threadKey: threadKey,
      );
      if (!_isOffline) {
        await deleteThreadMessages(threadKey);
      }
      await _clearChatTimeline();
      _fileMetaByMessageId.clear();
      if (deleteCache) {
        await ReceivedFileDao.instance.clearCacheForThread(threadKey);
      }
      if (!mounted) return;
      AppToast.show(context, message: l10n.chatScreenClearMessagesDone);
    } catch (e) {
      logChat.warning('clear session messages failed: $e');
      if (mounted) {
        AppToast.show(context, message: l10n.chatScreenClearMessagesFailed);
      }
    }
  }

  Future<void> _refreshReceiveDir() async {
    final dir = await FileStore.getReceiveDir();
    _webrtcManager.saveDirPath = dir;
  }

  Future<void> _checkS3Config() async {
    if (!mounted) return;
    ref.read(s3CheckingProvider.notifier).state = true;
    try {
      final ok = await hasS3Config();
      if (!mounted) return;
      ref.read(s3ConfiguredProvider.notifier).state = ok;
      var online = false;
      if (ok && ref.read(authProvider).isLoggedIn) {
        try {
          await testS3Config();
          online = true;
        } catch (_) {
          online = false;
        }
      }
      if (mounted) {
        ref.read(s3OnlineProvider.notifier).state = online;
        ref.read(s3CheckingProvider.notifier).state = false;
      }
    } catch (_) {
      if (mounted) {
        ref.read(s3ConfiguredProvider.notifier).state = false;
        ref.read(s3OnlineProvider.notifier).state = false;
        ref.read(s3CheckingProvider.notifier).state = false;
      }
    }
  }

  /// Probes direct HTTP + LAN signaling first; skips WebRTC when either succeeds
  /// and marks WebRTC as unknown (`null`) to avoid extra ICE cost.
  Future<void> _probeDeviceAllMethods(
    DeviceDto device, {
    int? requestId,
  }) async {
    bool isCurrent() =>
        requestId == null || _isProbeRequestCurrent(device.deviceId, requestId);

    final nearbyIds = ref
        .read(nearbyDevicesProvider)
        .map((d) => d.deviceId)
        .toSet();
    if (shouldSkipAutoProbe(device, nearbyIds: nearbyIds)) {
      if (!mounted || !isCurrent()) return;
      ref.read(deviceReachabilityProvider.notifier).setDetail(
        device.deviceId,
        DeviceReachDetail.offlineDetail,
      );
      return;
    }

    bool directHttp = false;

    if (device.lanHttpUrl != null && device.lanHttpUrl!.isNotEmpty) {
      try {
        directHttp = await probeHttp(
          device.lanHttpUrl!,
          timeout: _probeQuickDirectHttp,
        );
      } catch (_) {}
    }

    if (!isCurrent()) return;

    if (directHttp) {
      if (!mounted || !isCurrent()) return;
      ref.read(deviceReachabilityProvider.notifier).mergeDetail(
        device.deviceId,
        directHttp: true,
        webrtc: kDeviceReachMergeUnset,
        checking: false,
        provisionalOnline: false,
      );
      return;
    }

    final lanReach = await _resolveLanReachFromProbes(
      device,
      directHttp: directHttp,
      signalingTimeout: _probeQuickLanSignaling,
    );
    if (!isCurrent()) return;

    Object? webrtcUpdate = kDeviceReachMergeUnset;
    if (!_effectiveOffline) {
      final lanReachable =
          directHttp ||
          lanReach.pullReachable ||
          lanReach.peerHttpHealthy;
      if (!lanReachable) {
        try {
          final connectivity = await _sendWebRTCProbe(
            device.deviceId,
            responseTimeout: _probeQuickWebRTC,
          );
          final ok =
              connectivity == 'online' || connectivity == 'connectable';
          webrtcUpdate = ok;
        } catch (_) {
          webrtcUpdate = false;
        }
      } else {
        webrtcUpdate = null;
      }
    }

    if (!mounted || !isCurrent()) return;
    ref.read(deviceReachabilityProvider.notifier).mergeDetail(
      device.deviceId,
      directHttp: directHttp,
      peerHttpHealthy: lanReach.peerHttpHealthy,
      pullReachable: lanReach.pullReachable,
      webrtc: webrtcUpdate,
      checking: false,
      provisionalOnline: false,
    );
  }

  List<DeviceDto> _collectPeerDevices() {
    final currentId = _deviceId;
    final myDevices = ref.read(myDevicesProvider);
    final nearbyDevices = ref.read(nearbyDevicesProvider);
    final myIds = myDevices.map((d) => d.deviceId).toSet();
    final allDevices = [
      ...myDevices,
      ...nearbyDevices.where((d) => !myIds.contains(d.deviceId)),
    ];
    return allDevices
        .where((d) => d.deviceId != currentId && d.deviceId.isNotEmpty)
        .toList();
  }

  Future<void> _runProbeWave(
    List<DeviceDto> devices, {
    required int concurrency,
    required bool force,
    required void Function() onProbeFinished,
  }) async {
    if (devices.isEmpty) return;

    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < devices.length) {
        final index = nextIndex++;
        try {
          await _enqueueProbeRequest(
            devices[index],
            source: 'probe_all',
            force: force,
          );
        } finally {
          onProbeFinished();
        }
      }
    }

    final workers = concurrency < devices.length ? concurrency : devices.length;
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  Future<void> _probeAllDevices({bool force = false}) async {
    if (!mounted) return;
    final devices = _collectPeerDevices();
    if (devices.isEmpty) return;

    final nearbyIds = ref
        .read(nearbyDevicesProvider)
        .map((d) => d.deviceId)
        .toSet();
    final myIds = ref.read(myDevicesProvider).map((d) => d.deviceId).toSet();
    final partition = partitionForProbe(
      devices,
      nearbyIds: nearbyIds,
      myDeviceIds: myIds,
    );

    final toProbe = force
        ? devices
        : [...partition.lanDiscovered, ...partition.presenceOnline];
    if (toProbe.isEmpty && partition.lazy.isEmpty) return;

    ref.read(devicesProbingProvider.notifier).state = true;
    final reach = ref.read(deviceReachabilityProvider.notifier);

    if (force) {
      reach.setAllChecking(toProbe.map((d) => d.deviceId).toList());
    } else {
      if (toProbe.isNotEmpty) {
        reach.setAllChecking(toProbe.map((d) => d.deviceId).toList());
      }
      for (final d in partition.lazy) {
        reach.setDetail(d.deviceId, DeviceReachDetail.offlineDetail);
      }
    }

    var pending = toProbe.length;
    void onProbeFinished() {
      pending--;
      if (pending <= 0 && mounted) {
        ref.read(devicesProbingProvider.notifier).state = false;
      }
    }

    if (pending == 0) {
      ref.read(devicesProbingProvider.notifier).state = false;
      return;
    }

    if (force) {
      await _runProbeWave(
        toProbe,
        concurrency: _signalingProbeConcurrency,
        force: force,
        onProbeFinished: onProbeFinished,
      );
      return;
    }

    await _runProbeWave(
      partition.lanDiscovered,
      concurrency: _lanProbeConcurrency,
      force: force,
      onProbeFinished: onProbeFinished,
    );
    if (!mounted) return;
    await _runProbeWave(
      partition.presenceOnline,
      concurrency: _signalingProbeConcurrency,
      force: force,
      onProbeFinished: onProbeFinished,
    );
  }

  Future<void> _probeSingleDevice(String deviceId, {bool force = false}) async {
    if (!mounted) return;
    final myDevices = ref.read(myDevicesProvider);
    DeviceDto? device = myDevices
        .where((d) => d.deviceId == deviceId)
        .firstOrNull;
    device ??= ref
        .read(nearbyDevicesProvider)
        .where((d) => d.deviceId == deviceId)
        .firstOrNull;
    if (device == null) return;

    ref.read(deviceReachabilityProvider.notifier).setChecking(deviceId);
    await _enqueueProbeRequest(
      device,
      source: 'single_device',
      force: force,
    );
  }

  String _networkSignature(List<ConnectivityResult> results) {
    final values =
        results
            .where((r) => r != ConnectivityResult.none)
            .map((r) => r.name)
            .toList()
          ..sort();
    return values.join('|');
  }

  Future<void> _handleConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    if (!mounted) return;
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork && _statusCheckDone && _effectiveOffline && !_isOffline) {
      if (mounted) setState(() => _statusCheckDone = false);
      await _checkServerConnection();
    }

    final signature = _networkSignature(results);
    if (_lastNetworkSignature == signature) return;
    final previous = _lastNetworkSignature;
    _lastNetworkSignature = signature;

    if (!hasNetwork || previous == null) return;
    await _repairLanReceiver('connectivity_changed');
  }

  Future<void> _repairLanReceiver(String reason) async {
    if (_lanRepairInProgress || !mounted) return;
    _lanRepairInProgress = true;
    try {
      logChat.info('_repairLanReceiver reason=$reason');
      await _lanReceiver?.stop();
      await _lanDiscovery?.stopBroadcast();
      await _lanDiscovery?.stopDiscovery();
      await _startLanReceiver();
      _lanDiscovery?.startDiscovery();

      final lanUrl = _lanReceiver?.lanHttpUrl;
      if (!_effectiveOffline && lanUrl != null && lanUrl.isNotEmpty) {
        try {
          await updateDevice(_deviceId, lanHttpUrl: lanUrl);
        } catch (e) {
          logChat.warning('_repairLanReceiver updateDevice failed: $e');
        }
      }
      if (mounted) setState(() {});
    } finally {
      _lanRepairInProgress = false;
    }
  }

  Future<String?> _ensureHealthyLanHttpUrl() async {
    String? lanUrl = _lanReceiver?.lanHttpUrl;
    if (lanUrl != null && lanUrl.isNotEmpty) {
      final ok = await probeHttp(lanUrl, timeout: const Duration(seconds: 2));
      if (ok) return lanUrl;
    }

    await _repairLanReceiver('lan_http_probe');
    lanUrl = _lanReceiver?.lanHttpUrl;
    if (lanUrl != null && lanUrl.isNotEmpty) {
      final ok = await probeHttp(lanUrl, timeout: const Duration(seconds: 2));
      if (ok) return lanUrl;
    }
    return null;
  }

  Future<void> _checkServerConnection() async {
    if (!mounted) return;
    final checkGeneration = ++_serverConnectionCheckGeneration;
    bool isCurrentCheck() =>
        mounted && checkGeneration == _serverConnectionCheckGeneration;
    void probeDevicesIfCurrent() {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (isCurrentCheck()) _probeAllDevices();
      });
    }

    final isOfflineMode = ref.read(isOfflineModeProvider);
    if (isOfflineMode) {
      if (!isCurrentCheck()) return;
      setState(() => _statusCheckDone = true);
      _showStatusCheckToast();
      probeDevicesIfCurrent();
      return;
    }

    final session = ref.read(authSessionControllerProvider.notifier);

    try {
      await fetchUserProfile().timeout(const Duration(seconds: 8));
      if (!isCurrentCheck()) return;
      session.markServerReachable();
      if (!isCurrentCheck()) return;
      setState(() => _statusCheckDone = true);
      _showStatusCheckToast();
      unawaited(
        _runPostServerConnectSetup(
          checkGeneration: checkGeneration,
          probeDevicesIfCurrent: probeDevicesIfCurrent,
        ),
      );
    } on SessionUnavailableException catch (e) {
      if (!isCurrentCheck()) return;
      logChat.warning(
        '_checkServerConnection session unavailable kind=${e.kind}: $e',
      );
      if (e.isTransient) {
        session.markNetworkUnavailable();
      }
      setState(() => _statusCheckDone = true);
      _showStatusCheckToast();
      probeDevicesIfCurrent();
    } on TimeoutException catch (e) {
      if (!isCurrentCheck()) return;
      logChat.warning(
        '_checkServerConnection timeout, fallback to offline: $e',
      );
      session.markNetworkUnavailable();
      setState(() => _statusCheckDone = true);
      _showStatusCheckToast();
      probeDevicesIfCurrent();
    } catch (e) {
      if (!isCurrentCheck()) return;
      logChat.warning('_checkServerConnection failed, fallback to offline: $e');
      session.markNetworkUnavailable();
      setState(() => _statusCheckDone = true);
      _showStatusCheckToast();
      probeDevicesIfCurrent();
    }
  }

  Future<void> _runPostServerConnectSetup({
    required int checkGeneration,
    required void Function() probeDevicesIfCurrent,
  }) async {
    bool isCurrentCheck() =>
        mounted && checkGeneration == _serverConnectionCheckGeneration;

    try {
      await registerDevice(
        _deviceId,
        _deviceName,
        platform: Platform.operatingSystem,
        sessionId: _presenceSessionId,
      );
    } catch (e) {
      logChat.warning(
        '_runPostServerConnectSetup registerDevice failed (non-blocking): $e',
      );
    }
    if (!isCurrentCheck()) return;

    _hasNoMoreHistory = false;
    try {
      await _refreshCloudDeviceRosterSnapshot();
    } catch (e) {
      logChat.warning(
        '_runPostServerConnectSetup refresh roster failed: $e',
      );
    }
    if (!isCurrentCheck()) return;

    try {
      await _restoreResumableS3Transfers();
    } catch (e) {
      logChat.warning(
        '_runPostServerConnectSetup restore S3 transfers failed: $e',
      );
    }
    if (!isCurrentCheck()) return;

    try {
      await _restoreResumableWebRTCTransfers();
    } catch (e) {
      logChat.warning(
        '_runPostServerConnectSetup restore WebRTC transfers failed: $e',
      );
    }
    if (!isCurrentCheck()) return;

    _connectCentrifuge();
    try {
      await _loadHistory();
    } catch (e) {
      logChat.warning('_runPostServerConnectSetup loadHistory failed: $e');
    }
    if (!isCurrentCheck()) return;
    probeDevicesIfCurrent();
  }

  void _showStatusCheckToast() {
    if (!mounted) return;
    final String message;
    final offline = ref.read(isOfflineModeProvider);
    final phase = ref.read(authSessionPhaseProvider);
    if (offline) {
      message = _l10n.chatScreenConnNotLoggedInHttp;
    } else if (phase == AuthSessionPhase.networkUnavailable) {
      message = _l10n.chatScreenConnOffline;
    } else if (phase == AuthSessionPhase.authenticated) {
      message = _l10n.chatScreenConnServerOk;
    } else {
      return;
    }
    AppToast.show(
      context,
      message: message,
      duration: const Duration(seconds: 2),
    );
  }

  static const _ephemeralTypes = {
    'lan_file_offer',
    'lan_pull_probe',
    'lan_pull_probe_result',
    'lan_http_probe',
    'lan_http_probe_result',
    'webrtc_probe',
    'webrtc_probe_result',
    'webrtc_offer',
    'webrtc_answer',
    'webrtc_ice_candidate',
    'webrtc_transfer_cancel',
  };

  static const _renderableTypes = {'text', 'file'};

  bool _isRenderableChatType(String type) => _renderableTypes.contains(type);

  bool _shouldSkipInTimeline(String type) {
    if (_ephemeralTypes.contains(type)) return true;
    if (isWebRTCSignalType(type)) return true;
    return !_isRenderableChatType(type);
  }

  Future<String> _accountPartForThreadKey() async {
    if (_isOffline) {
      return accountPartOffline(await getOrCreateOfflineUserId());
    }
    final uid = await getStoredUserId();
    if (uid != null && uid.isNotEmpty) {
      return accountPartLoggedIn(uid);
    }
    return accountPartOffline(await getOrCreateOfflineUserId());
  }

  Future<String?> _threadKeyForCurrentSelection() async {
    if (!mounted) return null;
    final peer = ref.read(selectedDeviceIdProvider);
    if (peer == null) return null;
    final ap = await _accountPartForThreadKey();
    return threadKeyForPeerSelection(
      accountPart: ap,
      myDeviceId: _deviceId,
      selectedPeerId: peer,
    );
  }

  Future<String> _threadKeyForMessageEnvelope(
    MessageEnvelope msg, {
    Map<String, dynamic>? raw,
  }) async {
    final ap = await _accountPartForThreadKey();
    final map =
        raw ??
        <String, dynamic>{
          if (msg.toDeviceId != null) 'toDeviceId': msg.toDeviceId,
          if (msg.threadKey != null) 'threadKey': msg.threadKey,
        };
    return deriveThreadKeyForStoredMessage(
      accountPart: ap,
      fromDeviceId: msg.fromDeviceId,
      toDeviceId: map['toDeviceId'] as String? ?? msg.toDeviceId,
      myDeviceId: _deviceId,
      explicitThreadKey: map['threadKey'] as String? ?? msg.threadKey,
    );
  }

  Future<({String threadKey, String? toDeviceId})>
  _outboundThreadKeyForSelection() async {
    final ap = await _accountPartForThreadKey();
    final conv = ref.read(selectedDeviceIdProvider);
    if (conv == s3VirtualDeviceId) {
      return (threadKey: threadKeyS3Cloud(ap), toDeviceId: null);
    }
    if (conv != null && conv != _deviceId) {
      return (
        threadKey: threadKeyOneToOne(ap, _deviceId, conv),
        toDeviceId: conv,
      );
    }
    return (threadKey: threadKeyLegacyBroadcast(ap), toDeviceId: null);
  }

  Future<String> _threadKeyForS3Persist(String? toDeviceId) async {
    final ap = await _accountPartForThreadKey();
    if (toDeviceId != null && toDeviceId.isNotEmpty) {
      return threadKeyOneToOne(ap, _deviceId, toDeviceId);
    }
    return threadKeyS3Cloud(ap);
  }

  Future<void> _clearChatTimeline() async {
    final msgs = List<Message>.from(_chatController.messages);
    for (final m in msgs) {
      await _chatController.removeMessage(m);
    }
    _loadedMessageIds.clear();
    _serverIdByMessageId.clear();
    _oldestServerMessageId = null;
    _hasNoMoreHistory = false;
  }

  Future<void> _reloadThreadForSelectionChange() async {
    if (!mounted) return;
    await _clearChatTimeline();
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final userId = await _getCurrentUserId();
      if (!mounted) return;
      if (!_isOffline && (userId == null || userId.isEmpty)) return;
      final queryUserIds = await _getQueryUserIds();
      if (!mounted) return;
      final threadKey = await _threadKeyForCurrentSelection();
      if (threadKey == null) {
        await _clearChatTimeline();
        return;
      }

      final seenIds = <String>{};
      final allMessages = <Message>[];

      final localList = await ChatMessageDao.instance.getMessages(
        userIds: queryUserIds,
        threadKey: threadKey,
        limit: kChatPageSize,
      );
      if (mounted && localList.isNotEmpty) {
        for (final m in localList) {
          if (_shouldSkipInTimeline(m.type)) {
            await ChatMessageDao.instance.deleteById(m.id);
            continue;
          }
          if (m.id.startsWith('local_')) {
            final localId = m.id.substring(6);
            if (m.status != null && m.status!.isNotEmpty) {
              final s = m.status!;
              if (s == 'sending' || s == 'uploading' || s == 'downloading') {
                _localMessageStatus[localId] = 'failed';
              } else {
                _localMessageStatus[localId] = s;
              }
            } else if (!m.synced) {
              _localMessageStatus[localId] = 'failed';
            }
          }
          final envelope = MessageEnvelope(
            type: m.type,
            payload: m.payload,
            fromDeviceId: m.fromDeviceId,
            ts: m.ts,
            threadKey: m.threadKey,
          );
          var message = envelopeToMessage(envelope, overrideId: m.id);
          seenIds.add(m.id);
          _registerFileMetaFromPayload(message, m.type, m.payload);
          message = _maybeOverrideStatusText(message);
          allMessages.add(message);
        }
      }

      List<MessageEnvelope> serverList = [];
      if (!_effectiveOffline) {
        try {
          serverList = await getMessageHistory(
            limit: kChatPageSize,
            threadKey: threadKey,
          );
        } catch (e) {
          logChat.warning('_loadHistory server fetch failed: $e');
        }
      }
      if (!mounted) return;
      int? batchMinServerId;
      for (final e in serverList) {
        if (e.id != null &&
            (batchMinServerId == null || e.id! < batchMinServerId)) {
          batchMinServerId = e.id!;
        }
      }
      for (final envelope in serverList) {
        if (_shouldSkipInTimeline(envelope.type)) continue;
        final id = '${envelope.ts}_${envelope.fromDeviceId}';
        if (envelope.id != null) {
          _serverIdByMessageId[id] = envelope.id!;
        }
        if (seenIds.contains(id)) continue;
        final p = envelope.payload is Map ? envelope.payload as Map : null;
        final localId = p?['localId']?.toString();
        final rowTk = await _threadKeyForMessageEnvelope(envelope);
        if (localId != null && seenIds.contains('local_$localId')) {
          final localMessageId = 'local_$localId';
          seenIds.add(id);
          if (envelope.type == 'text') {
            var message = envelopeToMessage(envelope, overrideId: id);
            _replaceQueuedMessageById(allMessages, localMessageId, message);
            _upgradeLocalBubbleToServerMessage(localMessageId, message);
          }
          await ChatMessageDao.instance.deleteById('local_$localId');
          await ChatMessageDao.instance.insertMessage(
            userId: userId!,
            id: id,
            type: envelope.type,
            payload: envelope.payload,
            fromDeviceId: envelope.fromDeviceId,
            ts: envelope.ts,
            threadKey: rowTk,
            synced: true,
          );
          continue;
        }
        seenIds.add(id);
        var message = envelopeToMessage(envelope, overrideId: id);
        _registerFileMetaFromPayload(message, envelope.type, envelope.payload);
        message = _maybeOverrideStatusText(message);
        allMessages.add(message);
        await ChatMessageDao.instance.insertMessage(
          userId: userId!,
          id: id,
          type: envelope.type,
          payload: envelope.payload,
          fromDeviceId: envelope.fromDeviceId,
          ts: envelope.ts,
          threadKey: rowTk,
          synced: true,
        );
      }
      allMessages.sort((a, b) {
        final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aTs.compareTo(bTs);
      });

      // Backfill localPath for file bubbles by joining against the
      // received_files index. This is what makes a chat bubble previewable
      // immediately after reopening the screen.
      await _backfillLocalPathsFromIndex(allMessages);

      final controllerIds = _chatController.messages.map((m) => m.id).toSet();
      int insertedCount = 0;

      for (final message in allMessages) {
        if (controllerIds.contains(message.id)) continue;

        final messages = _chatController.messages;
        final ts = message.createdAt?.millisecondsSinceEpoch ?? 0;
        int insertIdx = messages.length;
        for (int i = messages.length - 1; i >= 0; i--) {
          final existingTs = messages[i].createdAt?.millisecondsSinceEpoch ?? 0;
          if (existingTs <= ts) {
            insertIdx = i + 1;
            break;
          }
          if (i == 0) insertIdx = 0;
        }

        _chatController.insertMessage(message, index: insertIdx);
        controllerIds.add(message.id);
        _loadedMessageIds.add(message.id);
        insertedCount++;
      }

      _updateOldestServerId();
      if (_oldestServerMessageId == null && batchMinServerId != null) {
        _oldestServerMessageId = batchMinServerId;
      }

      final totalFetched = localList.length + serverList.length;
      if (totalFetched < kChatPageSize) {
        _hasNoMoreHistory = true;
      }

      if (insertedCount == 0 &&
          !_hasNoMoreHistory &&
          _oldestServerMessageId != null &&
          !_effectiveOffline) {
        _loadingMore = false;
        await _loadMoreHistory();
      }
    } catch (e) {
      logChat.warning('_loadHistory failed: $e');
    }
  }

  void _updateOldestServerId() {
    final messages = _chatController.messages;
    if (messages.isEmpty) return;
    int? oldestTs;
    String? oldestMsgId;
    for (final m in messages) {
      final ts = m.createdAt?.millisecondsSinceEpoch ?? 0;
      if (oldestTs == null || ts < oldestTs) {
        oldestTs = ts;
        oldestMsgId = m.id;
      }
    }
    if (oldestMsgId != null && _serverIdByMessageId.containsKey(oldestMsgId)) {
      _oldestServerMessageId = _serverIdByMessageId[oldestMsgId];
    } else {
      final allServerIds = _serverIdByMessageId.values.toList();
      if (allServerIds.isNotEmpty) {
        allServerIds.sort();
        _oldestServerMessageId = allServerIds.first;
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_loadingMore || _hasNoMoreHistory) return;
    final userId = await _getCurrentUserId();
    if (!_isOffline && (userId == null || userId.isEmpty)) return;
    final queryUserIds = await _getQueryUserIds();
    final threadKey = await _threadKeyForCurrentSelection();
    if (threadKey == null) {
      return;
    }
    _loadingMore = true;
    try {
      final messages = _chatController.messages;
      if (messages.isEmpty) {
        _loadingMore = false;
        return;
      }

      int? oldestTs;
      for (final m in messages) {
        final ts = m.createdAt?.millisecondsSinceEpoch ?? 0;
        if (oldestTs == null || ts < oldestTs) {
          oldestTs = ts;
        }
      }

      final localFuture = ChatMessageDao.instance.getMessages(
        userIds: queryUserIds,
        threadKey: threadKey,
        limit: kChatPageSize,
        beforeTs: oldestTs,
      );
      final serverFuture = !_effectiveOffline && _oldestServerMessageId != null
          ? getMessageHistory(
              limit: kChatPageSize,
              before: _oldestServerMessageId,
              threadKey: threadKey,
            )
          : Future.value(<MessageEnvelope>[]);

      final results = await Future.wait([localFuture, serverFuture]);
      if (!mounted) {
        _loadingMore = false;
        return;
      }

      final localList = results[0] as List<LocalChatMessage>;
      final serverList = results[1] as List<MessageEnvelope>;

      int? batchMinServerId;
      for (final e in serverList) {
        if (e.id != null &&
            (batchMinServerId == null || e.id! < batchMinServerId)) {
          batchMinServerId = e.id!;
        }
      }

      final newMessages = <Message>[];
      final seenIds = <String>{..._loadedMessageIds};

      for (final m in localList) {
        if (_shouldSkipInTimeline(m.type)) {
          await ChatMessageDao.instance.deleteById(m.id);
          continue;
        }
        if (seenIds.contains(m.id)) continue;
        seenIds.add(m.id);
        final envelope = MessageEnvelope(
          type: m.type,
          payload: m.payload,
          fromDeviceId: m.fromDeviceId,
          ts: m.ts,
          threadKey: m.threadKey,
        );
        var message = envelopeToMessage(envelope, overrideId: m.id);
        _registerFileMetaFromPayload(message, m.type, m.payload);
        message = _maybeOverrideStatusText(message);
        newMessages.add(message);
      }

      for (final envelope in serverList) {
        if (_shouldSkipInTimeline(envelope.type)) continue;
        final id = '${envelope.ts}_${envelope.fromDeviceId}';
        if (envelope.id != null) {
          _serverIdByMessageId[id] = envelope.id!;
        }
        if (seenIds.contains(id)) continue;
        final p = envelope.payload is Map ? envelope.payload as Map : null;
        final localId = p?['localId']?.toString();
        final rowTk = await _threadKeyForMessageEnvelope(envelope);
        if (localId != null && seenIds.contains('local_$localId')) {
          final localMessageId = 'local_$localId';
          seenIds.add(id);
          if (envelope.type == 'text') {
            var message = envelopeToMessage(envelope, overrideId: id);
            _replaceQueuedMessageById(newMessages, localMessageId, message);
            _upgradeLocalBubbleToServerMessage(localMessageId, message);
          }
          await ChatMessageDao.instance.deleteById('local_$localId');
          await ChatMessageDao.instance.insertMessage(
            userId: userId!,
            id: id,
            type: envelope.type,
            payload: envelope.payload,
            fromDeviceId: envelope.fromDeviceId,
            ts: envelope.ts,
            threadKey: rowTk,
            synced: true,
          );
          continue;
        }
        seenIds.add(id);
        var message = envelopeToMessage(envelope, overrideId: id);
        _registerFileMetaFromPayload(message, envelope.type, envelope.payload);
        message = _maybeOverrideStatusText(message);
        newMessages.add(message);
        await ChatMessageDao.instance.insertMessage(
          userId: userId!,
          id: id,
          type: envelope.type,
          payload: envelope.payload,
          fromDeviceId: envelope.fromDeviceId,
          ts: envelope.ts,
          threadKey: rowTk,
          synced: true,
        );
      }

      newMessages.sort((a, b) {
        final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aTs.compareTo(bTs);
      });

      await _backfillLocalPathsFromIndex(newMessages);

      if (newMessages.isNotEmpty) {
        await _chatController.insertAllMessages(
          newMessages,
          index: 0,
          animated: false,
        );
        for (final message in newMessages) {
          _loadedMessageIds.add(message.id);
        }
      }

      _updateOldestServerId();
      if (_oldestServerMessageId == null && batchMinServerId != null) {
        _oldestServerMessageId = batchMinServerId;
      }

      final totalFetched = localList.length + serverList.length;
      if (totalFetched < kChatPageSize) {
        _hasNoMoreHistory = true;
      }
    } catch (e) {
      logChat.warning('_loadMoreHistory failed: $e');
    } finally {
      _loadingMore = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Pulls `localPath` / `size` / `s3_key` for any file-typed messages whose
  /// metadata isn't already populated from the payload, by querying the
  /// `received_files` index. Lets reopened chats jump straight into preview.
  ///
  /// Two-stage lookup:
  ///   1. Direct hit by `message.id` (fast path).
  ///   2. Fallback by `(fileName, size)` for messages whose server-assigned
  ///      id differs from the locally-derived receive-side id (e.g. an
  ///      online LAN file whose chat bubble id is the server snowflake but
  ///      whose actual file lives at `lan_recv_<hash>/...`).
  Future<void> _backfillLocalPathsFromIndex(List<Message> messages) async {
    final ids = <String>[];
    for (final m in messages) {
      final meta = _fileMetaByMessageId[m.id];
      if (meta == null) continue;
      if (meta.localPath != null && meta.localPath!.isNotEmpty) continue;
      ids.add(m.id);
    }
    if (ids.isEmpty) return;
    try {
      final found = await ReceivedFileDao.instance.getByMessageIds(ids);
      for (final entry in found.entries) {
        final meta = _fileMetaByMessageId[entry.key];
        if (meta == null) continue;
        meta.localPath = entry.value.absPath;
        if (meta.size == null || meta.size == 0) {
          meta.size = entry.value.size;
        }
      }
      for (final m in messages) {
        final meta = _fileMetaByMessageId[m.id];
        if (meta == null) continue;
        if (meta.localPath != null && meta.localPath!.isNotEmpty) continue;
        if (meta.fileName.isEmpty) continue;
        final hits = await ReceivedFileDao.instance.findByNameAndSize(
          fileName: meta.fileName,
          size: meta.size,
        );
        if (hits.isEmpty) continue;
        final hit = hits.first;
        if (!File(hit.absPath).existsSync()) continue;
        meta.localPath = hit.absPath;
        if (meta.size == null || meta.size == 0) {
          meta.size = hit.size;
        }
      }
    } catch (e) {
      logChat.warning('_backfillLocalPathsFromIndex failed: $e');
    }
  }

  void _registerFileMetaFromPayload(
    Message message,
    String type,
    dynamic rawPayload,
  ) {
    if (type != 'file' || rawPayload is! Map) return;
    final payload = rawPayload;
    final key = payload['key']?.toString();
    if (key != null && key.isNotEmpty) {
      _fileKeyByMessageId[message.id] = key;
    }
    final fileName = payload['fileName']?.toString();
    if (fileName != null && fileName.isNotEmpty) {
      _fileFileNameByMessageId[message.id] = fileName;
    }
    final prev = _fileMetaByMessageId[message.id];
    final incomingType = transferTypeFromFilePayload(payload);
    String? tt = incomingType ?? prev?.transferType;
    if (tt == null && message is TextMessage) {
      tt = inferTransferTypeFromFileBubbleText(message.text);
    }
    final sizeVal = (payload['size'] as num?)?.toInt();
    final mtimeMs = parseMtimeMs(payload['lastModifiedMs']);
    _fileMetaByMessageId[message.id] = _FileMeta(
      fileName: fileName ?? prev?.fileName ?? _l10n.chatScreenGenericFile,
      size: sizeVal ?? prev?.size,
      s3Key: (key != null && key.isNotEmpty) ? key : prev?.s3Key,
      transferType: tt,
      localPath: payload['localPath']?.toString() ?? prev?.localPath,
      lastModifiedMs: mtimeMs ?? prev?.lastModifiedMs,
    );
  }

  /// Override message text based on persisted status so that history shows the
  /// correct visual state (failed / cancelled) without needing updateMessage.
  Message _maybeOverrideStatusText(Message message) {
    if (!message.id.startsWith('local_')) return message;
    final localId = message.id.substring(6);
    final status = _localMessageStatus[localId];
    if (status == 'cancelled') {
      final info = _retryInfoByLocalId[localId];
      final meta = _fileMetaByMessageId[message.id];
      final fn = info?.fileName ?? meta?.fileName ?? '';
      return Message.text(
        id: message.id,
        authorId: message.authorId,
        createdAt: message.createdAt,
        text: fn.isNotEmpty
            ? _l10n.chatTransferCancelledNamed(fn)
            : _l10n.chatTransferCancelledBare,
      );
    }
    if (status == 'failed') {
      final info = _retryInfoByLocalId[localId];
      if (info != null) {
        return Message.text(
          id: message.id,
          authorId: message.authorId,
          createdAt: message.createdAt,
          text: _l10n.chatTransferSendFailedNamed(info.fileName),
        );
      }
      final meta = _fileMetaByMessageId[message.id];
      if (meta != null) {
        return Message.text(
          id: message.id,
          authorId: message.authorId,
          createdAt: message.createdAt,
          text: _l10n.chatTransferSendFailedNamed(meta.fileName),
        );
      }
    }
    return message;
  }

  /// After inline export: show saved-to-folder or export-failed in chat + toast.
  void _notifyReceiveSavedToFolder({
    required String messageId,
    required String fileName,
    required bool exportOk,
    Message? chatMessage,
  }) {
    if (!mounted) return;
    final text = exportOk
        ? _l10n.chatHttpReceivedBracket(fileName)
        : '${_l10n.fileExportFailed}: $fileName';
    if (chatMessage != null) {
      _chatController.updateMessage(
        chatMessage,
        Message.text(
          id: messageId,
          authorId: chatMessage.authorId,
          createdAt: chatMessage.createdAt,
          text: text,
        ),
      );
    }
    AppToast.show(
      context,
      message: exportOk
          ? _l10n.fileExportSavedToDownloads(fileName)
          : _l10n.fileExportFailed,
    );
  }

  Future<void> _startLanReceiver() async {
    if (_deviceId.isEmpty) return;
    try {
      _lanReceiver = LanReceiver(
        deviceId: _deviceId,
        deviceName: _deviceName,
        platform: Platform.operatingSystem,
        onFileReceived:
            (
              filePath,
              fileName,
              fromDeviceId, {
              messageId,
              senderLocalId,
              lastModifiedMs,
            }) async {
              if (!mounted) return;
              final msgId = messageId ?? 'lan_recv_${const Uuid().v4()}';
              // The cancel-vs-completion race can land here when the last
              // chunk arrives before the worker checks the cancel flag.
              // Respect the user's explicit cancel — discard the just-saved
              // file and leave the bubble as "已取消".
              if (_isLanReceiveCancelled(msgId)) {
                _cancelledLanReceives.remove(msgId);
                try {
                  File(filePath).deleteSync();
                } catch (_) {}
                return;
              }
              await applyReceivedFileTimestamps(filePath, lastModifiedMs);
              if (senderLocalId != null && senderLocalId.isNotEmpty) {
                _lanRecvLocalIds.add(senderLocalId);
                _lanLocalIdToMessageId[senderLocalId] = msgId;
              }
              _activeLanReceives.remove(msgId);
              _lanRecvFileIdByMsgId.remove(msgId);
              _speedTrackers.remove(msgId);
              _transferStartTimes.remove(msgId);
              int? sz;
              try {
                sz = File(filePath).lengthSync();
              } catch (_) {}
              _fileMetaByMessageId[msgId] = _FileMeta(
                fileName: fileName,
                size: sz,
                transferType: 'lan',
                localPath: filePath,
              );
              await _persistLanHttpReceiveIfOffline(
                filePath,
                fileName,
                fromDeviceId,
                messageId: msgId,
              );
              // Persist to received_files index so file manager and reopened
              // chats can resolve this file without re-scanning the disk.
              var exportOk = false;
              try {
                final uid = await _getCurrentUserId();
                final tk = await _threadKeyForCurrentSelection();
                exportOk =
                    await ReceivedFileIndexPipeline.instance
                        .upsertAndExportInline(
                  messageId: msgId,
                  upsert: () => ReceivedFileDao.instance.upsert(
                    messageId: msgId,
                    absPath: filePath,
                    cachePath: filePath,
                    exportStatus: ExportStatus.pending,
                    userId: uid,
                    threadKey: tk,
                    protocol: 'lan',
                    size: sz,
                    fromDeviceId: fromDeviceId,
                  ),
                );
              } catch (e) {
                logChat.warning('LAN receive finalize failed: $e');
              }
              _notifyReceiveSavedToFolder(
                messageId: msgId,
                fileName: fileName,
                exportOk: exportOk,
                chatMessage: _findMessageById(msgId),
              );
            },
        onReceiveProgress:
            (fileName, received, total, {messageId, senderLocalId, fileId}) {
              if (!mounted) return;
              final msgId = messageId ?? 'lan_recv_${const Uuid().v4()}';
              // Drop stale progress events that arrive after the user already
              // cancelled this receive — otherwise the bubble briefly shows
              // "已取消" and then flips back to "正在接收 X%", which looks
              // exactly like a transfer that auto-resumed itself.
              if (_isLanReceiveCancelled(msgId)) return;
              if (senderLocalId != null && senderLocalId.isNotEmpty) {
                _lanRecvLocalIds.add(senderLocalId);
                _lanLocalIdToMessageId[senderLocalId] = msgId;
              }
              _activeLanReceives[msgId] = fileName;
              if (fileId != null && fileId.isNotEmpty) {
                _lanRecvFileIdByMsgId[msgId] = fileId;
              }
              final prevMeta = _fileMetaByMessageId[msgId];
              _fileMetaByMessageId[msgId] = _FileMeta(
                fileName: fileName,
                size: total > 0 ? total : prevMeta?.size,
                transferType: 'lan',
                localPath: prevMeta?.localPath,
              );
              final tracker = _speedTrackers.putIfAbsent(
                msgId,
                () => SpeedTracker(),
              );
              tracker.update(received);
              _transferStartTimes.putIfAbsent(msgId, () => DateTime.now());
              final pct = total > 0
                  ? (received * 100 / total).round().clamp(0, 100)
                  : 0;
              final existingMsg = _findMessageById(msgId);
              if (existingMsg != null) {
                final newMsg = Message.text(
                  id: msgId,
                  authorId: 'system',
                  createdAt: existingMsg.createdAt,
                  text: _l10n.chatTransferReceivingPct(fileName, pct),
                );
                _chatController.updateMessage(existingMsg, newMsg);
              } else {
                final newMsg = Message.text(
                  id: msgId,
                  authorId: 'system',
                  createdAt: DateTime.now(),
                  text: _l10n.chatTransferReceivingPct(fileName, pct),
                );
                _chatController.insertMessage(newMsg);
                _scrollToBottom();
              }
            },
        onReceiveError: (fileName, error, {messageId, senderLocalId, fileId}) {
          if (!mounted) return;
          logChat.warning('LAN receive error: $fileName $error');
          final msgId = messageId ?? 'lan_recv_${const Uuid().v4()}';
          _activeLanReceives.remove(msgId);
          _lanRecvFileIdByMsgId.remove(msgId);
          _speedTrackers.remove(msgId);
          _transferStartTimes.remove(msgId);
          // The receive truly ended (cancel ack or genuine failure) — drop
          // the cancellation marker so a future receive that happens to
          // reuse the same msgId is not silently suppressed.
          _cancelledLanReceives.remove(msgId);
          final isCancelled = error == 'cancelled';
          final existingMsg = _findMessageById(msgId);
          if (existingMsg != null) {
            final failMsg = Message.text(
              id: msgId,
              authorId: 'system',
              createdAt: existingMsg.createdAt,
              text: isCancelled
                  ? _l10n.chatTransferCancelledNamed(fileName)
                  : _l10n.chatTransferReceiveFailedNamed(fileName),
            );
            _chatController.updateMessage(existingMsg, failMsg);
          }
        },
        onMessageReceived: _onLanMessageReceived,
        onPeerRegistered:
            (peerDeviceId, peerName, peerLanHttpUrl, peerPlatform) {
              if (peerDeviceId == _deviceId) return;
              final dto = DeviceDto(
                deviceId: peerDeviceId,
                name: peerName,
                platform: peerPlatform,
                lanHttpUrl: peerLanHttpUrl,
                lastSeen: DateTime.now().millisecondsSinceEpoch,
              );
              _lanDiscovery?.addManualDevice(dto);
            },
        onRegisterLanHttpUrl: (url) async {
          if (!mounted) return;
          _lanDiscovery?.setMyLanHttpUrl(url);
          if (_lanDiscovery != null) {
            await _lanDiscovery!.startBroadcast(url);
          }
          if (!mounted) return;
          if (!_effectiveOffline) {
            await updateDevice(_deviceId, lanHttpUrl: url);
          }
        },
      );
      final url = await _lanReceiver!.start();
      if (mounted && url != null) setState(() {});
    } catch (e) {
      logChat.warning('_startLanReceiver failed: $e');
    }
  }

  /// Older builds generated a fresh localId on every retry, so an interrupted
  /// transfer that was retried multiple times could leave several
  /// `transfer_records` rows (and matching `chat_messages` rows) for the same
  /// underlying file. Keep only the latest-updated row per (channel,
  /// direction, fileName, fileSize) and delete the orphans together with their
  /// chat bubble so the UI shows a single retry/continue affordance.
  Future<List<TransferRecord>> _dedupeOrphanRecords(
    List<TransferRecord> records,
  ) async {
    if (records.length <= 1) return records;
    final groups = <String, List<TransferRecord>>{};
    for (final r in records) {
      final key = '${r.channel}|${r.direction}|${r.fileName}|${r.fileSize}';
      (groups[key] ??= []).add(r);
    }
    final kept = <TransferRecord>[];
    for (final entry in groups.entries) {
      final group = entry.value;
      if (group.length == 1) {
        kept.add(group.single);
        continue;
      }
      group.sort((a, b) {
        // Prefer the row with the most progress, fall back to most recent.
        final byBytes = b.transferredBytes.compareTo(a.transferredBytes);
        if (byBytes != 0) return byBytes;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      kept.add(group.first);
      for (final orphan in group.skip(1)) {
        logChat.info(
          '_dedupeOrphanRecords: dropping orphan transferId=${orphan.transferId} '
          'file=${orphan.fileName} status=${orphan.status}',
        );
        await TransferStateManager.instance.removeRecord(orphan.transferId);
        try {
          await ChatMessageDao.instance.deleteById(
            'local_${orphan.transferId}',
          );
        } catch (e) {
          logChat.warning(
            '_dedupeOrphanRecords: deleteById failed for ${orphan.transferId}: $e',
          );
        }
      }
    }
    return kept;
  }

  Future<void> _restoreResumableLanTransfers() async {
    try {
      final allRecords = await TransferStateManager.instance
          .getResumableTransfers();
      logChat.info(
        '_restoreResumableLan: total resumable=${allRecords.length} records=${allRecords.map((r) => '${r.channel}/${r.direction}/${r.status}/${r.fileName}').toList()}',
      );
      final lanRecords = await _dedupeOrphanRecords(
        allRecords
            .where((r) => r.channel == 'lan' && r.direction == 'upload')
            .toList(),
      );
      logChat.info('_restoreResumableLan: lanRecords=${lanRecords.length}');
      if (lanRecords.isEmpty || !mounted) return;

      final lanDevices = _lanDiscovery?.currentDiscovered ?? [];
      List<DeviceDto> cloudDevices = [];
      if (!_effectiveOffline) {
        try {
          cloudDevices = await listDevices();
        } catch (_) {}
      }
      final devices = _mergeLanAndCloudDevices(
        lanDevices,
        cloudDevices.isEmpty ? null : cloudDevices,
      );
      logChat.info('_restoreResumableLan: devices=${devices.length}');

      for (final record in lanRecords) {
        logChat.info(
          '_restoreResumableLan: checking record id=${record.transferId} file=${record.fileName} path=${record.filePath} status=${record.status} targetDeviceIds=${record.lanTargetDeviceIds}',
        );
        if (record.filePath == null) {
          logChat.info('_restoreResumableLan: filePath is null, removing');
          TransferStateManager.instance.removeRecord(record.transferId);
          continue;
        }
        final fileExists = File(record.filePath!).existsSync();
        if (!fileExists) {
          logChat.info(
            '_restoreResumableLan: file does not exist at ${record.filePath}, removing',
          );
          TransferStateManager.instance.removeRecord(record.transferId);
          continue;
        }
        final localId = record.transferId;
        List<DeviceDto>? targets;
        if (record.lanTargetDeviceIds != null && devices.isNotEmpty) {
          targets = devices
              .where((d) => record.lanTargetDeviceIds!.contains(d.deviceId))
              .toList();
          if (targets.isEmpty) targets = null;
        }
        logChat.info(
          '_restoreResumableLan: restoring retry for ${record.fileName}, localId=$localId, targets=${targets?.length}',
        );
        _retryInfoByLocalId[localId] = _RetryInfo(
          fileName: record.fileName,
          fileSize: record.fileSize,
          filePath: record.filePath,
          channel: 'lan',
          lanTargets: targets,
        );
        final restoreStatus =
            (record.status == 'paused' || record.status == 'cancelled')
            ? 'cancelled'
            : 'failed';
        if (mounted) {
          setState(() => _localMessageStatus[localId] = restoreStatus);
        }
        logChat.info(
          '_restoreResumableLan: set retry state for ${record.fileName} '
          'status=$restoreStatus',
        );
      }
    } catch (e, st) {
      logChat.warning('_restoreResumableLanTransfers failed: $e\n$st');
    }
  }

  Future<void> _restoreResumableS3Transfers() async {
    try {
      final allRecords = await TransferStateManager.instance
          .getResumableTransfers();
      final s3Records = await _dedupeOrphanRecords(
        allRecords
            .where((r) => r.channel == 's3' && r.direction == 'upload')
            .toList(),
      );
      if (s3Records.isEmpty || !mounted) return;

      for (final record in s3Records) {
        if (record.filePath == null) {
          logChat.info(
            '_restoreResumableS3: filePath null, removing record ${record.transferId}',
          );
          TransferStateManager.instance.removeRecord(record.transferId);
          continue;
        }
        if (!File(record.filePath!).existsSync()) {
          logChat.info(
            '_restoreResumableS3: file not found ${record.filePath}, removing record',
          );
          TransferStateManager.instance.removeRecord(record.transferId);
          continue;
        }
        final localId = record.transferId;
        _retryInfoByLocalId[localId] = _RetryInfo(
          fileName: record.fileName,
          fileSize: record.fileSize,
          filePath: record.filePath,
          channel: 's3',
        );
        final restoreStatus =
            (record.status == 'paused' || record.status == 'cancelled')
            ? 'cancelled'
            : 'failed';
        if (mounted) {
          setState(() => _localMessageStatus[localId] = restoreStatus);
        }
        logChat.info(
          '_restoreResumableS3: set retry state for ${record.fileName} '
          'status=$restoreStatus',
        );
      }
    } catch (e, st) {
      logChat.warning('_restoreResumableS3Transfers failed: $e\n$st');
    }
  }

  Future<void> _restoreResumableWebRTCTransfers() async {
    try {
      final allRecords = await TransferStateManager.instance
          .getResumableTransfers();
      final webrtcRecords = await _dedupeOrphanRecords(
        allRecords
            .where((r) => r.channel == 'webrtc' && r.direction == 'upload')
            .toList(),
      );
      logChat.info(
        '_restoreResumableWebRTC: webrtcRecords=${webrtcRecords.length}',
      );
      if (webrtcRecords.isEmpty || !mounted) return;

      for (final record in webrtcRecords) {
        if (record.filePath == null) {
          logChat.info(
            '_restoreResumableWebRTC: filePath null, removing record ${record.transferId}',
          );
          TransferStateManager.instance.removeRecord(record.transferId);
          continue;
        }
        if (!File(record.filePath!).existsSync()) {
          logChat.info(
            '_restoreResumableWebRTC: file not found ${record.filePath}, removing record',
          );
          TransferStateManager.instance.removeRecord(record.transferId);
          continue;
        }
        final localId = record.transferId;
        _retryInfoByLocalId[localId] = _RetryInfo(
          fileName: record.fileName,
          fileSize: record.fileSize,
          filePath: record.filePath,
          channel: 'webrtc',
          webrtcTargetDeviceId: record.webrtcTargetDeviceId,
          webrtcFileId: record.webrtcFileId,
        );
        _fileMetaByMessageId['local_$localId'] = _FileMeta(
          fileName: record.fileName,
          size: record.fileSize,
          transferType: 'webrtc',
        );
        final restoreStatus =
            (record.status == 'paused' || record.status == 'cancelled')
            ? 'cancelled'
            : 'failed';
        if (mounted) {
          setState(() => _localMessageStatus[localId] = restoreStatus);
        }
        logChat.info(
          '_restoreResumableWebRTC: set retry state for ${record.fileName} '
          'status=$restoreStatus',
        );
      }
    } catch (e, st) {
      logChat.warning('_restoreResumableWebRTCTransfers failed: $e\n$st');
    }
  }

  void _handleDeviceRosterPatch(Map<String, dynamic> map) {
    final action = map['action']?.toString();
    final deviceId = map['deviceId']?.toString();
    final roster = ref.read(cloudDeviceRosterProvider.notifier);
    if (action == 'remove') {
      if (deviceId == null || deviceId.isEmpty) return;
      roster.applyRemove(deviceId);
      ref
          .read(deviceReachabilityProvider.notifier)
          .setDetail(deviceId, DeviceReachDetail.offlineDetail);
      return;
    }

    if (action != 'upsert') return;
    final rawDevice = map['device'];
    if (rawDevice is! Map) return;
    final device = DeviceDto.fromJson(Map<String, dynamic>.from(rawDevice));
    roster.applyUpsert(device);
    if (device.deviceId != _deviceId) {
      if (device.presenceStatus == 'offline') {
        ref
            .read(deviceReachabilityProvider.notifier)
            .setDetail(device.deviceId, DeviceReachDetail.offlineDetail);
        return;
      }
      ref
          .read(deviceReachabilityProvider.notifier)
          .setDetail(device.deviceId, DeviceReachDetail.offlineDetail);
      _enqueueDirtyProbe(device.deviceId);
      final selectedId = ref.read(selectedDeviceIdProvider);
      if (selectedId == device.deviceId) {
        _seedSelectedPeerReachabilitySnapshot(device.deviceId);
        unawaited(_probeSingleDevice(device.deviceId, force: true));
      }
    }
  }

  Future<void> _connectCentrifuge() async {
    logChat.info('chat_screen connectCentrifuge');
    try {
      final tokens = await getCentrifugoToken();
      final client = centrifuge.createClient(
        Env.centrifugoWs,
        centrifuge.ClientConfig(
          token: tokens.connectionToken,
          data: utf8.encode(
            jsonEncode({
              'deviceId': _deviceId,
              'name': _deviceName,
              'platform': Platform.operatingSystem,
              'sessionId': _presenceSessionId,
            }),
          ),
          getData: () async => utf8.encode(
            jsonEncode({
              'deviceId': _deviceId,
              'name': _deviceName,
              'platform': Platform.operatingSystem,
              'sessionId': _presenceSessionId,
            }),
          ),
          getToken: (_) async {
            final r = await getCentrifugoToken();
            return r.connectionToken;
          },
        ),
      );
      client.connect();
      client.connected.listen((_) {
        logChat.info('chat_screen Centrifugo connected');
        if (mounted) {
          setState(() => _connected = true);
          unawaited(_markPresenceOnline('centrifugo_connected'));
          unawaited(_refreshRosterAndProbeSelected('centrifugo_connected'));
        }
      });
      client.disconnected.listen((e) {
        logChat.info('chat_screen Centrifugo disconnected: ${e.reason}');
        if (mounted) setState(() => _connected = false);
      });
      final sub = client.newSubscription(
        tokens.channel,
        centrifuge.SubscriptionConfig(
          token: tokens.subscriptionToken,
          getToken: (_) async {
            final r = await getCentrifugoToken();
            return r.subscriptionToken;
          },
        ),
      );
      sub.publication.listen((e) async {
        try {
          final raw = e.data;
          if (raw.isEmpty) return;
          final map =
              jsonDecode(utf8.decode(Uint8List.fromList(raw)))
                  as Map<String, dynamic>;
          final msg = MessageEnvelope.fromJson(map);
          if (msg.type == 'device_roster_patch') {
            _handleDeviceRosterPatch(map);
            return;
          }
          // toDeviceId filtering: skip messages targeted at a different device.
          // We keep messages FROM this device (echo for local status update).
          final toDeviceId = map['toDeviceId'] as String?;
          if (toDeviceId != null &&
              toDeviceId != _deviceId &&
              msg.fromDeviceId != _deviceId) {
            return;
          }
          final signalPayload = msg.payload is Map
              ? Map<String, dynamic>.from(msg.payload as Map)
              : null;
          final publicationSid = signalPayload?['sessionId']?.toString();
          logChat.fine(
            'chat_screen publication type=${msg.type} from=${msg.fromDeviceId} '
            'to=${toDeviceId ?? '-'} sid=${publicationSid ?? '-'}',
          );
          if (!mounted) return;
          if (msg.type == 'lan_file_offer' && msg.payload is Map) {
            if (msg.fromDeviceId == _deviceId) {
              logChat.fine('drop lan_file_offer echo from self');
              return;
            }
            final payload = msg.payload as Map;
            final targetIds = payload['targetDeviceIds'];
            if (targetIds is List && targetIds.contains(_deviceId)) {
              final pullUrl = payload['pullUrl']?.toString();
              final pullSize = (payload['size'] as num?)?.toInt() ?? 0;
              final offerLocalId = payload['localId']?.toString();
              if (offerLocalId != null &&
                  offerLocalId.isNotEmpty &&
                  _isSenderLocalIdRecentlyCancelled(offerLocalId)) {
                logChat.info(
                  'drop lan_file_offer for senderLocalId=$offerLocalId '
                  '— receiver recently cancelled this transfer',
                );
                return;
              }
              if (pullUrl != null && pullUrl.isNotEmpty) {
                _pullFileFromOffer(
                  pullUrl,
                  payload['fileName']?.toString() ??
                      _l10n.chatScreenGenericFile,
                  fileSize: pullSize,
                  senderLocalId:
                      (offerLocalId != null && offerLocalId.isNotEmpty)
                      ? offerLocalId
                      : null,
                  senderDeviceId: msg.fromDeviceId,
                );
              }
            }
            return;
          }
          if (msg.type == 'lan_pull_cancelled' && msg.payload is Map) {
            if (msg.fromDeviceId == _deviceId) return;
            if (msg.toDeviceId != null &&
                msg.toDeviceId!.isNotEmpty &&
                msg.toDeviceId != _deviceId) {
              return;
            }
            final payload = msg.payload as Map;
            final localId = payload['localId']?.toString();
            if (localId == null || localId.isEmpty) return;
            unawaited(_onPeerCancelledReversePull(localId));
            return;
          }
          if (msg.type == 'lan_pull_probe' && msg.payload is Map) {
            final payload = msg.payload as Map;
            final targetDeviceId = payload['targetDeviceId']?.toString();
            if (targetDeviceId == _deviceId) {
              final probeUrl = payload['probeUrl']?.toString();
              final probeId = payload['probeId']?.toString();
              if (probeUrl != null && probeId != null) {
                _handlePullProbe(probeUrl, probeId);
              }
            }
            return;
          }
          if (msg.type == 'lan_pull_probe_result' && msg.payload is Map) {
            final payload = msg.payload as Map;
            final probeId = payload['probeId']?.toString();
            final success = payload['success'] == true;
            if (probeId != null) {
              final completer = _pendingPullProbes.remove(probeId);
              if (completer != null && !completer.isCompleted) {
                completer.complete(success);
              }
            }
            return;
          }
          if (msg.type == 'lan_http_probe' && msg.payload is Map) {
            final payload = msg.payload as Map;
            final targetDeviceId = payload['targetDeviceId']?.toString();
            if (targetDeviceId == _deviceId) {
              final probeId = payload['probeId']?.toString();
              final senderLanHttpUrl = payload['senderLanHttpUrl']?.toString();
              if (probeId != null) {
                _handleLanHttpProbe(probeId, senderLanHttpUrl);
              }
            }
            return;
          }
          if (msg.type == 'lan_http_probe_result' && msg.payload is Map) {
            final payload = msg.payload as Map;
            final probeId = payload['probeId']?.toString();
            final success = payload['success'] == true;
            final lanHttpUrl = payload['lanHttpUrl']?.toString();
            final senderReachable = payload['senderReachable'] == true;
            if (probeId != null) {
              final completer = _pendingLanHttpProbes.remove(probeId);
              if (completer != null && !completer.isCompleted) {
                completer.complete((
                  success: success,
                  lanHttpUrl: lanHttpUrl,
                  senderReachable: senderReachable,
                ));
              }
            }
            return;
          }
          if (msg.type == 'webrtc_probe' && msg.payload is Map) {
            final payload = msg.payload as Map;
            final targetDeviceId = payload['targetDeviceId']?.toString();
            if (targetDeviceId == _deviceId) {
              final probeId = payload['probeId']?.toString();
              final iceSummary = payload['iceSummary'] is Map<String, dynamic>
                  ? payload['iceSummary'] as Map<String, dynamic>
                  : null;
              if (probeId != null) {
                _handleWebRTCProbe(probeId, msg.fromDeviceId, iceSummary);
              }
            }
            return;
          }
          if (msg.type == 'webrtc_probe_result' && msg.payload is Map) {
            final payload = msg.payload as Map;
            final probeId = payload['probeId']?.toString();
            final success = payload['success'] == true;
            final connectivity = payload['connectivity']?.toString();
            if (probeId != null) {
              final completer = _pendingWebRTCProbes.remove(probeId);
              if (completer != null && !completer.isCompleted) {
                completer.complete(
                  success ? (connectivity ?? 'online') : 'offline',
                );
              }
            }
            return;
          }
          if (isWebRTCSignalType(msg.type) && msg.payload is Map) {
            final signal = Map<String, dynamic>.from(msg.payload as Map);
            if (msg.type == 'webrtc_offer') {
              _handleWebRTCOffer(signal, msg.fromDeviceId);
            }
            _webrtcManager.handleSignal(signal, _deviceId);
            return;
          }
          if (!_isRenderableChatType(msg.type)) {
            logChat.fine('skip non-renderable publication type=${msg.type}');
            return;
          }
          final payload = msg.payload is Map ? msg.payload as Map : null;
          final incomingLocalId = payload?['localId']?.toString();
          final incomingLocalMessageId = incomingLocalId != null
              ? 'local_$incomingLocalId'
              : null;
          final hasLocalTextBubble =
              msg.type == 'text' &&
              incomingLocalMessageId != null &&
              _findMessageById(incomingLocalMessageId) != null;
          if (incomingLocalId != null &&
              (_localMessageStatus.containsKey(incomingLocalId) ||
                  hasLocalTextBubble)) {
            final serverId = '${msg.ts}_${msg.fromDeviceId}';
            if (msg.type == 'text' && incomingLocalMessageId != null) {
              final serverMessage = envelopeToMessage(
                msg,
                overrideId: serverId,
              );
              _upgradeLocalBubbleToServerMessage(
                incomingLocalMessageId,
                serverMessage,
              );
            }
            if (mounted) {
              setState(() => _setMessageStatus(incomingLocalId, 'sent'));
            }
            final userId = await _getCurrentUserId();
            if (userId != null) {
              final rowTk = await _threadKeyForMessageEnvelope(msg, raw: map);
              await ChatMessageDao.instance.deleteById(
                'local_$incomingLocalId',
              );
              await ChatMessageDao.instance.insertMessage(
                userId: userId,
                id: serverId,
                type: msg.type,
                payload: msg.payload,
                fromDeviceId: msg.fromDeviceId,
                ts: msg.ts,
                threadKey: rowTk,
                synced: true,
              );
            }
            return;
          }
          final message = envelopeToMessage(msg);
          var skipUiForLanOrWebrtcDup = false;
          // When the inbound `file` matches a local LAN/WebRTC receiver bubble
          // we've already shown, "upgrade" that bubble's id to the server-side
          // ${ts}_${fromDeviceId} so future updates target it instead of
          // inserting a duplicate. Identity is always per-transfer localId,
          // never fileName — so re-sending a same-named file still creates a
          // fresh bubble + received_files row.
          String? upgradeFromMsgId;
          if (msg.type == 'file' && msg.payload is Map) {
            final payload = msg.payload as Map;
            _registerFileMetaFromPayload(message, 'file', payload);
            final senderLocalId = payload['localId']?.toString();
            final isLan = chatPayloadBoolTrue(payload['lan']);
            // Suppress publications for reverse-pulls this receiver just
            // cancelled. Sender's `addStream` may have finished writing all
            // bytes BEFORE our socket closed, so it publishes `file` thinking
            // the transfer succeeded; without this short-circuit our "已取消"
            // bubble would be silently upgraded to "已传输完成" and any
            // ChatMessageDao replay on cold-start would do the same.
            if (isLan &&
                senderLocalId != null &&
                senderLocalId.isNotEmpty &&
                _isRecvCancelledSenderLocalId(senderLocalId)) {
              logChat.info(
                'drop file publication for senderLocalId=$senderLocalId '
                '— receiver cancelled this reverse-pull',
              );
              unawaited(_dropCancelledPullDbRows(senderLocalId));
              return;
            }
            if (isLan) {
              if (msg.fromDeviceId == _deviceId) return;
              final targetIds = payload['targetDeviceIds'];
              if (targetIds is List && !targetIds.contains(_deviceId)) return;
              if (senderLocalId != null &&
                  senderLocalId.isNotEmpty &&
                  _lanRecvLocalIds.contains(senderLocalId)) {
                skipUiForLanOrWebrtcDup = true;
                upgradeFromMsgId = _lanLocalIdToMessageId[senderLocalId];
              }
            }
            final isWebrtc = chatPayloadBoolTrue(payload['webrtc']);
            if (isWebrtc) {
              if (msg.fromDeviceId == _deviceId) return;
              final targetDeviceId = payload['targetDeviceId']?.toString();
              if (targetDeviceId != null && targetDeviceId != _deviceId) return;
              if (senderLocalId != null &&
                  senderLocalId.isNotEmpty &&
                  _webrtcRecvLocalIds.contains(senderLocalId)) {
                skipUiForLanOrWebrtcDup = true;
                upgradeFromMsgId = _lanLocalIdToMessageId[senderLocalId];
              }
            }
          }
          final rowTk = await _threadKeyForMessageEnvelope(msg, raw: map);
          final viewTk = await _threadKeyForCurrentSelection();
          if (skipUiForLanOrWebrtcDup &&
              upgradeFromMsgId != null &&
              viewTk != null &&
              rowTk == viewTk) {
            final existing = _findMessageById(upgradeFromMsgId);
            if (existing != null) {
              _chatController.updateMessage(existing, message);
              _loadedMessageIds.remove(upgradeFromMsgId);
              _loadedMessageIds.add(message.id);
            }
          } else if (!skipUiForLanOrWebrtcDup &&
              viewTk != null &&
              rowTk == viewTk) {
            _chatController.insertMessage(message);
            _loadedMessageIds.add(message.id);
            _scrollToBottom();
          }
          final userId = await _getCurrentUserId();
          if (userId != null) {
            // If we just upgraded a local LAN/WebRTC bubble to the server id,
            // drop the receiver's local-only chat row so it doesn't show up
            // as a duplicate next time the chat is reopened, and re-key the
            // matching received_files row to the server id so taps via the
            // server id also resolve to this transfer's on-disk file (and
            // not some same-named older file).
            if (upgradeFromMsgId != null && upgradeFromMsgId != message.id) {
              try {
                await ChatMessageDao.instance.deleteById(upgradeFromMsgId);
              } catch (e) {
                logChat.warning(
                  'chat_screen failed to delete upgraded local row '
                  '$upgradeFromMsgId: $e',
                );
              }
              try {
                final oldRow = await ReceivedFileDao.instance.getByMessageId(
                  upgradeFromMsgId,
                );
                if (oldRow != null) {
                  await ReceivedFileDao.instance.upsert(
                    messageId: message.id,
                    absPath: oldRow.absPath,
                    userId: oldRow.userId ?? userId,
                    threadKey: oldRow.threadKey ?? rowTk,
                    protocol: oldRow.protocol,
                    s3Key: oldRow.s3Key,
                    fromDeviceId: oldRow.fromDeviceId ?? msg.fromDeviceId,
                    size: oldRow.size,
                  );
                  await ReceivedFileDao.instance.removeByMessageId(
                    upgradeFromMsgId,
                  );
                }
              } catch (e) {
                logChat.warning(
                  'chat_screen failed to re-key received_files from '
                  '$upgradeFromMsgId to ${message.id}: $e',
                );
              }
              // Carry over in-memory meta + cached deps to the server id.
              final meta = _fileMetaByMessageId.remove(upgradeFromMsgId);
              if (meta != null) {
                _fileMetaByMessageId[message.id] = meta;
              }
              final tracker = _speedTrackers.remove(upgradeFromMsgId);
              if (tracker != null) {
                _speedTrackers[message.id] = tracker;
              }
              final startTime = _transferStartTimes.remove(upgradeFromMsgId);
              if (startTime != null) {
                _transferStartTimes[message.id] = startTime;
              }
            }
            await ChatMessageDao.instance.insertMessage(
              userId: userId,
              id: message.id,
              type: msg.type,
              payload: msg.payload,
              fromDeviceId: msg.fromDeviceId,
              ts: msg.ts,
              threadKey: rowTk,
              synced: true,
            );
          }
          if (msg.type == 'file' && msg.payload is Map) {
            _maybeAutoDownloadIncomingS3File(
              message: message,
              payload: msg.payload as Map,
              fromDeviceId: msg.fromDeviceId,
            );
          }
        } catch (e, st) {
          logChat.warning('chat_screen Centrifugo publication failed: $e\n$st');
        }
      });
      sub.subscribe();
      _client = client;
      logChat.info(
        'chat_screen Centrifugo subscribe channel=${tokens.channel}',
      );
    } catch (e) {
      logChat.warning('chat_screen connectCentrifuge failed: $e');
      if (mounted) setState(() => _connected = false);
    }
  }

  void _onLanMessageReceived(String text, String fromDeviceId, String? _) {
    if (!mounted) return;
    unawaited(_persistLanTextMessage(text, fromDeviceId));
  }

  Future<void> _persistLanTextMessage(String text, String fromDeviceId) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final id = 'lan_msg_${fromDeviceId}_$ts';
    final ap = await _accountPartForThreadKey();
    final tk = threadKeyOneToOne(ap, fromDeviceId, _deviceId);
    final viewTk = await _threadKeyForCurrentSelection();
    if (!mounted) return;
    if (viewTk != null && tk == viewTk) {
      final message = Message.text(
        id: id,
        authorId: fromDeviceId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(ts),
        text: text,
      );
      _chatController.insertMessage(message);
      _loadedMessageIds.add(message.id);
      _scrollToBottom();
    }
    final userId = await _getCurrentUserId();
    if (userId != null) {
      await ChatMessageDao.instance.insertMessage(
        userId: userId,
        id: id,
        type: 'text',
        payload: {'text': text},
        fromDeviceId: fromDeviceId,
        ts: ts,
        threadKey: tk,
        synced: false,
      );
    }
  }

  /// 纯 LAN HTTP 收文件在离线时不会走 Centrifugo；与文本不同，文本有独立 /message 落库。此处在无实时通道时补写本地库。
  Future<void> _persistLanHttpReceiveIfOffline(
    String filePath,
    String fileName,
    String? senderFromHeader, {
    required String messageId,
  }) async {
    // 未登录时始终需要本地持久化；已登录且 Centrifugo 在线时由推送写库。
    if (!_effectiveOffline && _connected) return;
    final userId = await _getCurrentUserId();
    if (userId == null) return;
    String? peer = senderFromHeader;
    peer ??= ref.read(selectedDeviceIdProvider);
    if ((peer == null || peer.isEmpty) && _effectiveOffline) {
      final targets = ref.read(effectiveSelectedTargetsProvider);
      if (targets.length == 1) {
        peer = targets.single;
      }
    }
    if (peer == null ||
        peer.isEmpty ||
        peer == s3VirtualDeviceId ||
        peer == _deviceId) {
      return;
    }
    final ap = await _accountPartForThreadKey();
    final tk = threadKeyOneToOne(ap, peer, _deviceId);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{'fileName': fileName, 'lan': true};
    try {
      final f = File(filePath);
      if (f.existsSync()) {
        payload['size'] = f.lengthSync();
        payload['localPath'] = filePath;
      }
    } catch (_) {}
    await ChatMessageDao.instance.insertMessage(
      userId: userId,
      id: messageId,
      type: 'file',
      payload: payload,
      fromDeviceId: peer,
      ts: ts,
      threadKey: tk,
      synced: false,
    );
  }

  Future<void> _sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final localId = const Uuid().v4();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final convDeviceId = ref.read(selectedDeviceIdProvider);
    final outbound = await _outboundThreadKeyForSelection();
    final threadKeyForRow = outbound.threadKey;
    final toDeviceIdArg = outbound.toDeviceId;
    final envelope = MessageEnvelope(
      type: 'text',
      payload: {'text': trimmed, 'localId': localId},
      fromDeviceId: _deviceId,
      ts: ts,
      toDeviceId: toDeviceIdArg,
      threadKey: threadKeyForRow,
    );
    final message = envelopeToMessage(envelope, overrideId: 'local_$localId');
    _chatController.insertMessage(message);
    _scrollToBottom();
    final userId = await _getCurrentUserId();
    if (userId != null) {
      await ChatMessageDao.instance.insertMessage(
        userId: userId,
        id: 'local_$localId',
        type: 'text',
        payload: {'text': trimmed, 'localId': localId},
        fromDeviceId: _deviceId,
        ts: ts,
        threadKey: threadKeyForRow,
        synced: false,
        status: 'sending',
      );
    }
    if (mounted) setState(() => _localMessageStatus[localId] = 'sending');
    logChat.info(
      'chat_screen sendText fromDeviceId=$_deviceId offline=$_isOffline',
    );
    var selectedTargets = ref.read(effectiveSelectedTargetsProvider);
    // In 1:1 conversation mode, always restrict to the conversation device only,
    // ignoring any stale multi-select state from effectiveSelectedTargets.
    if (convDeviceId != null &&
        convDeviceId != s3VirtualDeviceId &&
        convDeviceId != _deviceId) {
      selectedTargets = {convDeviceId};
    }
    if (_effectiveOffline) {
      if (selectedTargets.isEmpty) {
        _composerKey.currentState?.expandDevicePanel();
        if (mounted) {
          AppToast.show(context, message: _l10n.chatScreenSelectTargetFirst);
          setState(() => _setMessageStatus(localId, 'failed'));
        }
        Analytics.track(AnalyticsEvents.chatTextSend, {
          'result': 'failed',
          'offline': true,
          'channel': 'lan',
          'length_bucket': Analytics.lengthBucket(trimmed.length),
          'reason': 'no_targets',
        });
        return;
      }
      await _sendTextViaLan(trimmed, localId, selectedTargets);
    } else {
      try {
        await sendMessage({
          'type': 'text',
          'payload': {'text': trimmed, 'localId': localId},
          'fromDeviceId': _deviceId,
          if (toDeviceIdArg != null) 'toDeviceId': toDeviceIdArg,
          'threadKey': threadKeyForRow,
          'ts': ts,
        });
        logChat.fine('chat_screen sendText ok');
        await ChatMessageDao.instance.markSynced('local_$localId');
        if (mounted) setState(() => _setMessageStatus(localId, 'sent'));
        Analytics.track(AnalyticsEvents.chatTextSend, {
          'result': 'sent',
          'offline': false,
          'channel': 'api',
          'length_bucket': Analytics.lengthBucket(trimmed.length),
        });
      } catch (e) {
        logChat.warning('chat_screen sendText failed: $e');
        if (mounted) setState(() => _setMessageStatus(localId, 'failed'));
        Analytics.track(AnalyticsEvents.chatTextSend, {
          'result': 'failed',
          'offline': false,
          'channel': 'api',
          'length_bucket': Analytics.lengthBucket(trimmed.length),
        });
      }
    }
  }

  Future<void> _sendTextViaLan(
    String text,
    String localId,
    Set<String> targetIds, {
    bool forRetry = false,
  }) async {
    final allDevices = _lanDiscovery?.currentDiscovered ?? [];
    final devices = allDevices
        .where((d) => targetIds.contains(d.deviceId))
        .toList();
    if (devices.isEmpty) {
      if (mounted) setState(() => _setMessageStatus(localId, 'sent'));
      Analytics.track(
        forRetry ? AnalyticsEvents.chatTextRetry : AnalyticsEvents.chatTextSend,
        {
          'result': 'sent',
          'offline': true,
          'channel': 'lan',
          'length_bucket': Analytics.lengthBucket(text.length),
          'reason': 'no_lan_devices',
        },
      );
      return;
    }
    int sentCount = 0;
    for (final d in devices) {
      if (d.lanHttpUrl == null || d.lanHttpUrl!.isEmpty) continue;
      try {
        final uri = Uri.parse('${d.lanHttpUrl!}/message');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': text,
                'fromDeviceId': _deviceId,
                'fromDeviceName': _deviceName,
                'toDeviceId': d.deviceId,
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          sentCount++;
        } else {
          logChat.warning(
            '_sendTextViaLan HTTP ${response.statusCode} to ${d.deviceId}',
          );
        }
      } catch (e) {
        logChat.warning('_sendTextViaLan to ${d.deviceId} failed: $e');
      }
    }
    if (mounted) {
      setState(
        () => _setMessageStatus(localId, sentCount > 0 ? 'sent' : 'failed'),
      );
      Analytics.track(
        forRetry ? AnalyticsEvents.chatTextRetry : AnalyticsEvents.chatTextSend,
        {
          'result': sentCount > 0 ? 'sent' : 'failed',
          'offline': true,
          'channel': 'lan',
          'length_bucket': Analytics.lengthBucket(text.length),
        },
      );
    }
  }

  Future<void> _retryTextSend(String localId) async {
    final msgId = 'local_$localId';
    final existing = _findMessageById(msgId);
    if (existing == null) return;
    final textContent = (existing is TextMessage) ? existing.text : null;
    if (textContent == null || textContent.isEmpty) return;
    if (mounted) setState(() => _setMessageStatus(localId, 'sending'));
    var selectedTargets = ref.read(effectiveSelectedTargetsProvider);
    if (_effectiveOffline) {
      if (selectedTargets.isEmpty) {
        _composerKey.currentState?.expandDevicePanel();
        if (mounted) {
          AppToast.show(context, message: _l10n.chatScreenSelectTargetFirst);
          setState(() => _setMessageStatus(localId, 'failed'));
        }
        Analytics.track(AnalyticsEvents.chatTextRetry, {
          'result': 'failed',
          'offline': true,
          'channel': 'lan',
          'reason': 'no_targets',
        });
        return;
      }
      await _sendTextViaLan(
        textContent,
        localId,
        selectedTargets,
        forRetry: true,
      );
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outbound = await _outboundThreadKeyForSelection();
    try {
      await sendMessage({
        'type': 'text',
        'payload': {'text': textContent, 'localId': localId},
        'fromDeviceId': _deviceId,
        'threadKey': outbound.threadKey,
        if (outbound.toDeviceId != null) 'toDeviceId': outbound.toDeviceId,
        'ts': ts,
      });
      await ChatMessageDao.instance.markSynced(msgId);
      if (mounted) setState(() => _setMessageStatus(localId, 'sent'));
      Analytics.track(AnalyticsEvents.chatTextRetry, {
        'result': 'sent',
        'offline': false,
        'channel': 'api',
        'length_bucket': Analytics.lengthBucket(textContent.length),
      });
    } catch (e) {
      logChat.warning('chat_screen retryTextSend failed: $e');
      if (mounted) setState(() => _setMessageStatus(localId, 'failed'));
      Analytics.track(AnalyticsEvents.chatTextRetry, {
        'result': 'failed',
        'offline': false,
        'channel': 'api',
        'length_bucket': Analytics.lengthBucket(textContent.length),
      });
    }
  }

  Future<void> _handleAttachmentChoice(AttachmentPickerChoice choice) async {
    List<PlatformFile> picked = [];
    switch (choice) {
      case AttachmentPickerChoice.imageVideo:
        picked = await _pickImageVideo();
      case AttachmentPickerChoice.file:
        picked = await _pickFiles();
      case AttachmentPickerChoice.folder:
        picked = await _pickFolder();
      case AttachmentPickerChoice.apk:
        picked = await _pickApk();
    }
    Analytics.track(AnalyticsEvents.attachmentPick, {
      'choice': choice.name,
      'picked_count': picked.length,
    });
    if (picked.isEmpty || !mounted) return;
    _addPendingFiles(picked);
  }

  Future<void> _handleDesktopDropFiles(List<PlatformFile> files) async {
    if (!_isDesktopPlatform || files.isEmpty || !mounted) return;
    _addPendingFiles(files);
  }

  Future<void> _onAttachmentTap() async {
    _composerKey.currentState?.unfocus();
    final colors = ChatColors.of(context);
    final choice = await showModalBottomSheet<AttachmentPickerChoice>(
      context: context,
      backgroundColor: colors.surface,
      builder: (ctx) => const AttachmentPickerSheet(),
    );
    if (choice == null || !mounted) return;
    await _handleAttachmentChoice(choice);
  }

  Future<List<PlatformFile>> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return [];
    return result.files
        .where((f) => f.size > 0 && (f.bytes != null || f.path != null))
        .toList();
  }

  Future<({bool proceed, bool hideLimitedOverlay})> _ensureGalleryReadForPicker() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return (proceed: true, hideLimitedOverlay: false);
    }
    if (!mounted) return (proceed: false, hideLimitedOverlay: false);
    final l10n = AppLocalizations.of(context);

    var state = await getGalleryReadPermissionState();
    if (!mounted) return (proceed: false, hideLimitedOverlay: false);
    state = await repairGalleryReadPermissionIfNeeded(state);
    if (!mounted) return (proceed: false, hideLimitedOverlay: false);
    if (isGalleryReadFullyAuthorized(state)) {
      return (proceed: true, hideLimitedOverlay: false);
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.chatGalleryReadPermissionTitle,
      content: l10n.chatGalleryReadPermissionBody,
      confirmLabel: l10n.chatGalleryReadPermissionConfirm,
      icon: LucideIcons.images,
    );
    if (!confirmed || !mounted) return (proceed: false, hideLimitedOverlay: false);

    state = await requestGalleryReadPermission();
    if (!mounted) return (proceed: false, hideLimitedOverlay: false);

    if (isGalleryReadFullyAuthorized(state)) {
      return (proceed: true, hideLimitedOverlay: false);
    }

    if (state == PermissionState.limited) {
      final openSettings = await AppConfirmDialog.show(
        context,
        title: l10n.chatGalleryReadPermissionTitle,
        content: l10n.chatGalleryReadPermissionLimited,
        confirmLabel: l10n.qrScannerOpenSettings,
        cancelLabel: l10n.chatGalleryReadPermissionContinuePartial,
        icon: LucideIcons.images,
      );
      if (!mounted) return (proceed: false, hideLimitedOverlay: false);
      if (openSettings) {
        await openAppSettings();
        return (proceed: false, hideLimitedOverlay: false);
      }
      return (proceed: true, hideLimitedOverlay: true);
    }

    if (!mounted) return (proceed: false, hideLimitedOverlay: false);
    AppToast.show(context, message: l10n.chatGalleryReadPermissionDenied);
    return (proceed: false, hideLimitedOverlay: false);
  }

  Future<List<PlatformFile>> _pickAssetsFromGallery({
    bool hideLimitedOverlay = false,
  }) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        requestType: RequestType.common,
        maxAssets: 999,
        limitedPermissionOverlayPredicate:
            hideLimitedOverlay ? (_) => false : null,
        textDelegate: assetPickerTextDelegateFromLocale(
          const Locale('zh', 'CN'),
        ),
      ),
    );
    if (assets == null || assets.isEmpty) return [];

    final result = <PlatformFile>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      final stat = await file.stat();
      if (stat.size <= 0) continue;
      result.add(
        PlatformFile(
          name: await asset.titleAsync,
          path: file.path,
          size: stat.size,
        ),
      );
    }
    return result;
  }

  Future<List<PlatformFile>> _pickImageVideo() async {
    if (!mounted) return [];
    try {
      final access = await _ensureGalleryReadForPicker();
      if (!access.proceed) return [];
      return await _pickAssetsFromGallery(
        hideLimitedOverlay: access.hideLimitedOverlay,
      );
    } catch (e) {
      logChat.warning('_pickImageVideo failed: $e');
      return [];
    }
  }

  Future<List<PlatformFile>> _pickFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return [];

    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final result = <PlatformFile>[];
    var listFailed = false;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.size <= 0) continue;
            result.add(
              PlatformFile(
                name: entity.path.split(Platform.pathSeparator).last,
                path: entity.path,
                size: stat.size,
              ),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      listFailed = true;
      logChat.warning('_pickFolder list failed: $e');
    }

    if (result.isEmpty && mounted) {
      final message = Platform.isAndroid && listFailed
          ? _l10n.chatScreenFolderSafTryFiles
          : _l10n.chatScreenFolderEmpty;
      AppToast.show(context, message: message);
    }
    return result;
  }

  Future<List<PlatformFile>> _pickApk() async {
    _composerKey.currentState?.unfocus();
    final picks = await Navigator.push<List<ApkPickResult>>(
      context,
      MaterialPageRoute(builder: (_) => const ApkPickerScreen()),
    );
    if (picks == null || picks.isEmpty) return [];

    final result = <PlatformFile>[];
    for (final pick in picks) {
      final file = File(pick.path);
      if (!await file.exists()) continue;
      final stat = await file.stat();
      if (stat.size <= 0) continue;
      result.add(
        PlatformFile(name: pick.displayName, path: pick.path, size: stat.size),
      );
    }
    return result;
  }

  void _addPendingFiles(List<PlatformFile> files) {
    var toAdd = files;
    if (Env.androidPlayDistribution) {
      toAdd = files
          .where((f) => !looksLikeApkInstallerFileName(f.name))
          .toList();
    }
    if (toAdd.isEmpty) return;
    var changed = false;
    setState(() {
      final existingPaths = _pendingFiles
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toSet();
      final existingFiles = _pendingFiles
          .where((f) => f.path == null)
          .map((f) => '${f.name}_${f.size}')
          .toSet();

      final newFiles = toAdd.where((file) {
        if (file.path != null) {
          return !existingPaths.contains(file.path);
        } else {
          return !existingFiles.contains('${file.name}_${file.size}');
        }
      }).toList();

      if (newFiles.isNotEmpty) {
        _pendingFiles = [...newFiles, ..._pendingFiles];
        changed = true;
      }
    });
    if (changed) _persistPendingFiles();
  }

  Future<void> _handleDesktopPasteFromClipboard(
    List<PlatformFile> files,
  ) async {
    if (!_isDesktopPlatform || files.isEmpty) return;
    _addPendingFiles(files);
  }

  Future<void> _copyChatFileToClipboard(String path) async {
    final loc = AppLocalizations.of(context);
    final ok = await DesktopFileClipboard.writeFilesToClipboard([path]);
    if (!mounted) return;
    AppToast.show(
      context,
      message: ok ? loc.fileClipboardCopied(1) : loc.fileClipboardCopyFailed,
    );
  }

  void _addFileMessageToPending(_FileMeta fileMeta, String localPath) {
    _addPendingFiles([
      PlatformFile(
        name: fileMeta.fileName,
        size: fileMeta.size ?? 0,
        path: localPath,
      ),
    ]);
    if (!mounted) return;
    AppToast.show(
      context,
      message: AppLocalizations.of(
        context,
      ).fmPendingAddedOne(fileMeta.fileName),
    );
  }

  void _removePendingFileRef(PlatformFile file) {
    unawaited(SharePendingCache.deleteStagingFile(file.path));
    setState(() {
      _pendingFiles = List.from(_pendingFiles)..remove(file);
    });
    _persistPendingFiles();
  }

  void _clearPendingFiles() {
    final files = List<PlatformFile>.from(_pendingFiles);
    unawaited(SharePendingCache.deleteStagingFiles(files));
    setState(() {
      _pendingFiles = [];
    });
    _persistPendingFiles();
  }

  Message? _findMessageById(String id) {
    for (final m in _chatController.messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Idempotent insert: if a bubble with the same id is already in the
  /// controller (e.g. because retry flipped it in-place before the per-channel
  /// sender re-ran), update it rather than appending a second copy.
  /// `InMemoryChatController.insertMessage` only asserts on duplicates in
  /// debug builds — in release it silently adds a second entry with the same
  /// id, which then breaks `_findMessageById` based updates because they only
  /// hit the first occurrence.
  void _insertOrUpdateMessage(Message message) {
    final existing = _findMessageById(message.id);
    if (existing != null) {
      _chatController.updateMessage(existing, message);
    } else {
      _chatController.insertMessage(message);
    }
  }

  void _upgradeLocalBubbleToServerMessage(
    String localMessageId,
    Message serverMessage,
  ) {
    final existing = _findMessageById(localMessageId);
    if (existing == null) return;
    _chatController.updateMessage(existing, serverMessage);
    _loadedMessageIds.remove(localMessageId);
    _loadedMessageIds.add(serverMessage.id);
  }

  void _replaceQueuedMessageById(
    List<Message> messages,
    String oldMessageId,
    Message newMessage,
  ) {
    final index = messages.indexWhere((m) => m.id == oldMessageId);
    if (index >= 0) {
      messages[index] = newMessage;
    } else {
      messages.add(newMessage);
    }
  }

  void _cancelTransfer(String localId) {
    final meta = _fileMetaByMessageId['local_$localId'];
    final fileName = meta?.fileName ?? '';
    Analytics.track(AnalyticsEvents.fileSendCancel, {
      'channel': meta?.transferType ?? 'unknown',
    });
    final cancelText = fileName.isNotEmpty
        ? _l10n.chatTransferCancelledNamed(fileName)
        : _l10n.chatTransferCancelledBare;

    final token = _activeTransfers.remove(localId);
    if (token != null) {
      token.cancel();
      _updateSendingMessage(localId, cancelText);
      if (mounted) {
        setState(() {
          _setMessageStatus(localId, 'cancelled');
          _localMessageProgress.remove(localId);
        });
      }
      // pause_resume semantics: the user-initiated cancel becomes a paused
      // record (resumable) rather than a terminal cancellation.
      TransferStateManager.instance.markStatus(localId, 'paused');
      return;
    }
    final fileId = _webrtcLocalIdToFileIdMap.remove(localId);
    if (fileId != null) {
      // Per-file cancel: leaves the parent session alone so other in-flight
      // WebRTC files in the same session keep streaming.
      _webrtcManager.cancelTransferByFileId(fileId);
      _webrtcFileLocalIdMap.remove(fileId);
      _webrtcFileNameMap.remove(fileId);
      _webrtcFileSizeMap.remove(fileId);
      _webrtcFileMtimeMsMap.remove(fileId);
      final transferId = _webrtcTransferIdMap.remove(fileId);
      if (transferId != null) {
        TransferStateManager.instance.markStatus(transferId, 'paused');
      }
      _updateSendingMessage(localId, cancelText);
      _speedTrackers.remove('local_$localId');
      _transferStartTimes.remove('local_$localId');
      if (mounted) {
        setState(() {
          _setMessageStatus(localId, 'cancelled');
          _localMessageProgress.remove(localId);
        });
      }
    }
  }

  /// Triggered when the receiver tells us via `lan_pull_cancelled` Centrifugo
  /// signal that they cancelled the reverse-pull bubble for [localId].
  /// Two branches:
  ///  A) In-flight on this side → re-use `_cancelTransfer` so all the
  ///     normal UI/state/retry plumbing fires.
  ///  B) Already success-completed (sender's `addStream` finished writing
  ///     before the receiver socket closed): rebuild the retry context from
  ///     whatever persisted breadcrumbs are still around (TransferRecord may
  ///     already be gone because `markStatus('completed')` deletes it) and
  ///     demote the bubble + DB row from a completed FileMessage back to a
  ///     cancelled TextMessage so the UI mirrors what the receiver sees.
  Future<void> _onPeerCancelledReversePull(String localId) async {
    if (_activeTransfers.containsKey(localId)) {
      logChat.info(
        '_onPeerCancelledReversePull in-flight localId=$localId → _cancelTransfer',
      );
      _cancelTransfer(localId);
      return;
    }
    final msgRowId = 'local_$localId';
    final record = await TransferStateManager.instance.getRecord(localId);
    final dbRow = await ChatMessageDao.instance.getById(msgRowId);
    final meta = _fileMetaByMessageId[msgRowId];
    Map? payloadMap;
    if (dbRow?.payload is Map) {
      payloadMap = dbRow!.payload as Map;
    }

    if (record == null && dbRow == null && meta == null) {
      logChat.info(
        '_onPeerCancelledReversePull no breadcrumbs for $localId — '
        'nothing to roll back',
      );
      return;
    }

    // Channel resolution: TransferRecord is authoritative when present, else
    // infer from the persisted payload, else from the in-memory meta.
    String channel = record?.channel ?? meta?.transferType ?? 'lan';
    if (record == null && payloadMap != null) {
      if (chatPayloadBoolTrue(payloadMap['lan'])) {
        channel = 'lan';
      } else if (chatPayloadBoolTrue(payloadMap['webrtc'])) {
        channel = 'webrtc';
      } else if (payloadMap['key'] != null) {
        channel = 's3';
      }
    }

    final fileName =
        record?.fileName ??
        meta?.fileName ??
        payloadMap?['fileName']?.toString() ??
        '';
    final fileSize =
        record?.fileSize ??
        meta?.size ??
        (payloadMap?['size'] as num?)?.toInt() ??
        0;
    final filePath =
        record?.filePath ??
        meta?.localPath ??
        payloadMap?['localPath']?.toString();

    List<String>? lanTargetIds = record?.lanTargetDeviceIds;
    if ((lanTargetIds == null || lanTargetIds.isEmpty) &&
        payloadMap?['targetDeviceIds'] is List) {
      lanTargetIds = (payloadMap!['targetDeviceIds'] as List)
          .map((e) => e.toString())
          .toList();
    }
    List<DeviceDto>? lanTargets;
    if (channel == 'lan' && lanTargetIds != null && lanTargetIds.isNotEmpty) {
      final discovered =
          _lanDiscovery?.currentDiscovered ?? const <DeviceDto>[];
      final byId = {for (final d in discovered) d.deviceId: d};
      lanTargets = lanTargetIds
          .map((id) => byId[id])
          .whereType<DeviceDto>()
          .toList();
    }

    logChat.info(
      '_onPeerCancelledReversePull rolling back localId=$localId '
      'channel=$channel fileName=$fileName recordPresent=${record != null} '
      'dbRowPresent=${dbRow != null} lanTargetIds=${lanTargetIds?.length ?? 0}',
    );

    final retryInfo = _RetryInfo(
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      channel: channel,
      lanTargets: lanTargets,
      webrtcTargetDeviceId:
          record?.webrtcTargetDeviceId ??
          payloadMap?['targetDeviceId']?.toString(),
      webrtcFileId: record?.webrtcFileId,
    );
    _retryInfoByLocalId[localId] = retryInfo;

    final cancelText = fileName.isNotEmpty
        ? _l10n.chatTransferCancelledNamed(fileName)
        : _l10n.chatTransferCancelledBare;
    _updateSendingMessage(localId, cancelText);

    try {
      await ChatMessageDao.instance.rewriteMessagePayload(
        id: msgRowId,
        type: 'text',
        payload: {'text': cancelText, 'localId': localId},
        status: 'cancelled',
      );
    } catch (e) {
      logChat.warning(
        '_onPeerCancelledReversePull rewriteMessagePayload failed: $e',
      );
    }
    // markStatus is a no-op when the record has already been deleted at
    // success time; harmless to call either way.
    await TransferStateManager.instance.markStatus(localId, 'paused');
    if (mounted) {
      setState(() {
        _setMessageStatus(localId, 'cancelled');
        _localMessageProgress.remove(localId);
      });
    }
  }

  void _markLanReceiveCancelled(String msgId) {
    _cancelledLanReceives[msgId] = DateTime.now().add(
      _cancelledReceiveSuppressionWindow,
    );
    final now = DateTime.now();
    _cancelledLanReceives.removeWhere((_, ttl) => ttl.isBefore(now));
  }

  bool _isLanReceiveCancelled(String msgId) {
    final ttl = _cancelledLanReceives[msgId];
    if (ttl == null) return false;
    if (ttl.isBefore(DateTime.now())) {
      _cancelledLanReceives.remove(msgId);
      return false;
    }
    return true;
  }

  void _rememberCancelledSenderLocalId(String senderLocalId) {
    _lanRecentlyCancelledSenderLocalIds[senderLocalId] = DateTime.now().add(
      _lanCancelSuppressionWindow,
    );
    // Drop expired entries opportunistically so the map doesn't grow
    // unbounded across long sessions.
    final now = DateTime.now();
    _lanRecentlyCancelledSenderLocalIds.removeWhere(
      (_, ttl) => ttl.isBefore(now),
    );
  }

  bool _isSenderLocalIdRecentlyCancelled(String senderLocalId) {
    final ttl = _lanRecentlyCancelledSenderLocalIds[senderLocalId];
    if (ttl == null) return false;
    if (ttl.isBefore(DateTime.now())) {
      _lanRecentlyCancelledSenderLocalIds.remove(senderLocalId);
      return false;
    }
    return true;
  }

  void _rememberRecvCancelledSenderLocalId(String senderLocalId) {
    _lanRecvCancelledSenderLocalIds[senderLocalId] = DateTime.now().add(
      _lanCancelSuppressionWindow,
    );
    final now = DateTime.now();
    _lanRecvCancelledSenderLocalIds.removeWhere((_, ttl) => ttl.isBefore(now));
  }

  bool _isRecvCancelledSenderLocalId(String senderLocalId) {
    final ttl = _lanRecvCancelledSenderLocalIds[senderLocalId];
    if (ttl == null) return false;
    if (ttl.isBefore(DateTime.now())) {
      _lanRecvCancelledSenderLocalIds.remove(senderLocalId);
      return false;
    }
    return true;
  }

  void _cancelLanReceive(String msgId, String fileName) {
    final fileId = _lanRecvFileIdByMsgId.remove(msgId);
    _lanReceiver?.cancelReceive(fileName, fileId: fileId);
    _activeLanReceives.remove(msgId);
    _speedTrackers.remove(msgId);
    _transferStartTimes.remove(msgId);
    // Worker isolates may have already queued a few _ReceiveProgress events
    // before they see the cancel flag — mark this msgId so those late events
    // are dropped instead of resurrecting the "正在接收 X%" bubble.
    _markLanReceiveCancelled(msgId);
    // Suppress any imminent `lan_file_offer` reverse-pull from the same
    // sender for this transfer — without this the sender's automatic push →
    // pull fallback would spawn a fresh receive bubble seconds after the
    // user already cancelled.
    const prefix = 'lan_recv_';
    if (msgId.startsWith(prefix)) {
      final senderLocalId = msgId.substring(prefix.length);
      if (senderLocalId.isNotEmpty) {
        _rememberCancelledSenderLocalId(senderLocalId);
      }
    }
    final existingMsg = _findMessageById(msgId);
    if (existingMsg != null) {
      final cancelMsg = Message.text(
        id: msgId,
        authorId: 'system',
        createdAt: existingMsg.createdAt,
        text: _l10n.chatTransferCancelledNamed(fileName),
      );
      _chatController.updateMessage(existingMsg, cancelMsg);
    }
  }

  /// Cancel an in-flight download (S3 or LAN reverse-pull) keyed by chat
  /// message id. The actual record-status bookkeeping is done inside the
  /// transfer service (S3) so cold-start resume picks up where we left off.
  void _cancelDownload(String msgId, String fileName) {
    final token = _activeDownloads.remove(msgId);
    if (token != null) {
      token.cancel();
    }
    _speedTrackers.remove(msgId);
    _transferStartTimes.remove(msgId);
    final existingMsg = _findMessageById(msgId);
    if (existingMsg != null) {
      final cancelMsg = Message.text(
        id: msgId,
        authorId: existingMsg.authorId,
        createdAt: existingMsg.createdAt,
        text: _l10n.chatTransferCancelledNamed(fileName),
      );
      _chatController.updateMessage(existingMsg, cancelMsg);
    }
    // Reverse-pull cancel needs extra plumbing:
    //   1) Drop our local id→bubble mapping so the upcoming Centrifugo `file`
    //      publication can't "upgrade" the cancelled bubble back into a
    //      FileMessage (sender's `addStream` may have finished writing the
    //      last bytes BEFORE we closed our end, in which case sender thinks
    //      the pull succeeded and publishes `file`).
    //   2) Park the senderLocalId in a suppression set the publication
    //      handler consults — covers any `file` already on the wire when
    //      step 1 ran.
    //   3) Tell the sender to roll back via a new `lan_pull_cancelled`
    //      signal so its own bubble doesn't sit on "已传输完成".
    const prefix = 'lan_recv_pull_';
    if (!msgId.startsWith(prefix)) return;
    final senderLocalId = msgId.substring(prefix.length);
    if (senderLocalId.isEmpty) return;
    _lanRecvLocalIds.remove(senderLocalId);
    _lanLocalIdToMessageId.remove(senderLocalId);
    _rememberRecvCancelledSenderLocalId(senderLocalId);
    final senderDeviceId = _lanPullSenderDeviceIdByLocalId.remove(
      senderLocalId,
    );
    if (senderDeviceId != null && senderDeviceId.isNotEmpty) {
      unawaited(
        _notifyPeerPullCancelled(
          senderLocalId: senderLocalId,
          senderDeviceId: senderDeviceId,
          fileName: fileName,
        ),
      );
    }
  }

  /// Drop the receiver-side bubble row that was just cancelled so a cold
  /// start replay doesn't surface the locally-cancelled bubble as a file
  /// again. The publication handler short-circuits before persisting the
  /// server-id row, so we only need to scrub the local one here.
  Future<void> _dropCancelledPullDbRows(String senderLocalId) async {
    try {
      await ChatMessageDao.instance.deleteById('lan_recv_pull_$senderLocalId');
    } catch (e) {
      logChat.warning(
        '_dropCancelledPullDbRows failed senderLocalId=$senderLocalId: $e',
      );
    }
  }

  /// Best-effort Centrifugo notice that this receiver cancelled a reverse
  /// pull. Sender handles it via `_onPeerCancelledReversePull`.
  Future<void> _notifyPeerPullCancelled({
    required String senderLocalId,
    required String senderDeviceId,
    required String fileName,
  }) async {
    if (_effectiveOffline) return;
    try {
      await sendMessage({
        'type': 'lan_pull_cancelled',
        'payload': {'localId': senderLocalId, 'fileName': fileName},
        'fromDeviceId': _deviceId,
        'toDeviceId': senderDeviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      logChat.warning(
        '_notifyPeerPullCancelled failed senderLocalId=$senderLocalId: $e',
      );
    }
  }

  Future<void> _retryFileSend(String localId) async {
    final info = _retryInfoByLocalId.remove(localId);
    if (info == null || info.filePath == null) return;

    if (_effectiveOffline &&
        (info.channel == 's3' || info.channel == 'webrtc')) {
      _retryInfoByLocalId[localId] = info;
      if (mounted) {
        AppToast.show(context, message: _l10n.chatScreenRetryCloudOffline);
      }
      return;
    }

    // For LAN channel, ALWAYS re-resolve targets from current discovery so
    // that a cold-start retry doesn't talk to a stale `lanHttpUrl` (the peer
    // app may have rebound to a different ephemeral port). The stored
    // targets are only used as a fallback when discovery hasn't caught up.
    var effectiveInfo = info;
    if (info.channel == 'lan') {
      final record = await TransferStateManager.instance.getRecord(localId);
      final targetIds =
          record?.lanTargetDeviceIds ??
          info.lanTargets?.map((d) => d.deviceId).toList();
      if (targetIds != null && targetIds.isNotEmpty) {
        final allDevices = _lanDiscovery?.currentDiscovered ?? [];
        final resolved = allDevices
            .where((d) => targetIds.contains(d.deviceId))
            .toList();
        if (resolved.isNotEmpty) {
          effectiveInfo = _RetryInfo(
            fileName: info.fileName,
            fileSize: info.fileSize,
            filePath: info.filePath,
            channel: 'lan',
            lanTargets: resolved,
          );
        } else if (info.lanTargets != null && info.lanTargets!.isNotEmpty) {
          // Discovery hasn't seen anything yet — keep the stored targets so
          // `canProceed` doesn't bail out, even if the URL is stale.
          effectiveInfo = info;
        }
      }
    }

    // Validate channel-specific conditions before removing the message.
    bool canProceed = false;
    switch (effectiveInfo.channel) {
      case 's3':
        canProceed = true;
        break;
      case 'lan':
        canProceed =
            effectiveInfo.lanTargets != null &&
            effectiveInfo.lanTargets!.isNotEmpty;
        break;
      case 'webrtc':
        canProceed = effectiveInfo.webrtcTargetDeviceId != null;
        break;
    }

    if (!canProceed) {
      _retryInfoByLocalId[localId] = info;
      if (mounted) {
        AppToast.show(context, message: _l10n.chatScreenNoDeviceFound);
      }
      return;
    }

    Analytics.track(AnalyticsEvents.fileSendRetry, {
      'channel': effectiveInfo.channel,
      'size_bucket': Analytics.sizeBucket(effectiveInfo.fileSize),
    });

    // Re-register retry info immediately so the bubble's retry button doesn't
    // disappear mid-await. `_sendSingleFileViaLan` (and siblings) will
    // overwrite this entry with a fresh `_RetryInfo` shortly.
    _retryInfoByLocalId[localId] = effectiveInfo;

    // Flip the existing "已取消" bubble to "正在发送 0%" in the same frame so
    // the user gets instant feedback. Without this the bubble would linger on
    // "Cancelled" for hundreds of ms (or seconds when oldFuture stalls) while
    // we wait for the previous send to terminate and the new send to reach
    // its first insertMessage. We keep using `updateMessage` so the chat
    // controller's id-keyed list stays a singleton — `insertMessage` with a
    // duplicate id silently appends a second bubble in release builds (the
    // InMemoryChatController only asserts in debug).
    final placeholder = _findMessageById('local_$localId');
    if (placeholder != null) {
      final progressMsg = Message.text(
        id: placeholder.id,
        authorId: placeholder.authorId,
        createdAt: placeholder.createdAt,
        text: _l10n.chatTransferSendingPct(effectiveInfo.fileName, 0),
      );
      _chatController.updateMessage(placeholder, progressMsg);
    }
    if (mounted) {
      setState(() {
        _localMessageStatus[localId] = 'uploading';
        _localMessageProgress.remove(localId);
      });
    }

    // Wait briefly for any previous send on this localId to fully terminate
    // before starting a new one, preventing concurrent writes to the same
    // file. The previous 5s timeout was a safety net that mostly hurt UX:
    // sendCompleter is normally resolved within a handful of ms after the
    // cancel propagates through `finally`. 1.5s is plenty even when the
    // network teardown stalls, and any leftover after that is the worst case
    // a fresh send already tolerates.
    final oldFuture = _activeTransferFutures.remove(localId);
    if (oldFuture != null) {
      try {
        await oldFuture.timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    // Intentionally do NOT remove the prior record here. `saveRecord` inside
    // each per-channel sender uses `ConflictAlgorithm.replace`, so the row
    // will be overwritten with fresh metadata; meanwhile any receiver-side
    // partial file keyed by sender fileId stays valid for resume.

    final file = PlatformFile(
      name: effectiveInfo.fileName,
      path: effectiveInfo.filePath,
      size: effectiveInfo.fileSize,
    );

    switch (effectiveInfo.channel) {
      case 's3':
        _sendSingleFileViaS3(
          file,
          toDeviceId: effectiveInfo.toDeviceId,
          reuseLocalId: localId,
        );
        break;
      case 'lan':
        _sendSingleFileViaLan(
          file,
          effectiveInfo.lanTargets!,
          reuseLocalId: localId,
        );
        break;
      case 'webrtc':
        _sendFilesViaWebRTC(
          [file],
          effectiveInfo.webrtcTargetDeviceId!,
          reuseFileId: effectiveInfo.webrtcFileId,
          reuseLocalId: localId,
        );
        break;
    }
  }

  Future<void> _switchToS3(String localId) async {
    final info = _retryInfoByLocalId[localId];
    if (info == null || info.filePath == null) return;

    if (_effectiveOffline) {
      if (mounted) {
        AppToast.show(context, message: _l10n.chatScreenOfflineNoS3);
      }
      return;
    }

    if (!ref.read(s3ConfiguredProvider)) {
      if (!mounted) return;
      final goConfig = await AppConfirmDialog.show(
        context,
        title: _l10n.chatScreenS3NotConfiguredTitle,
        content: _l10n.chatScreenS3NotConfiguredBody,
        confirmLabel: _l10n.chatScreenS3GoConfigure,
        icon: LucideIcons.cloud,
      );
      if (goConfig && mounted) {
        Navigator.pushNamed(context, '/settings/s3');
      }
      return;
    }
    if (!ref.read(s3OnlineProvider)) {
      if (!mounted) return;
      final goConfig = await AppConfirmDialog.show(
        context,
        title: _l10n.chatScreenS3UnavailableTitle,
        content: _l10n.chatScreenS3UnavailableBody,
        confirmLabel: _l10n.chatScreenS3GoSettings,
        icon: LucideIcons.cloud,
      );
      if (goConfig && mounted) {
        Navigator.pushNamed(context, '/settings/s3');
      }
      return;
    }

    // 只有在S3配置检查通过后才移除重试信息
    _retryInfoByLocalId.remove(localId);

    // 等待之前的传输完成
    final oldFuture = _activeTransferFutures.remove(localId);
    if (oldFuture != null) {
      try {
        await oldFuture.timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    // 清理状态
    TransferStateManager.instance.removeRecord(localId);
    final oldMsg = _findMessageById('local_$localId');
    if (oldMsg != null) _chatController.removeMessage(oldMsg);
    setState(() {
      _localMessageStatus.remove(localId);
      _localMessageProgress.remove(localId);
    });

    // 使用S3发送
    final file = PlatformFile(
      name: info.fileName,
      path: info.filePath,
      size: info.fileSize,
    );
    _sendSingleFileViaS3(file, toDeviceId: info.toDeviceId);
  }

  Future<void> _showFileSendModal() async {
    if (_pendingFiles.isEmpty || !mounted) return;

    var selectedTargets = ref.read(effectiveSelectedTargetsProvider);
    // When the S3 virtual device conversation is active, always use S3 mode
    // regardless of the global send mode setting.
    final convDeviceIdForMode = ref.read(selectedDeviceIdProvider);
    var sendMode = convDeviceIdForMode == s3VirtualDeviceId
        ? SendMode.s3
        : ref.read(selectedSendModeProvider);
    final peerIsRegistered =
        convDeviceIdForMode != null &&
        ref
            .read(myDevicesProvider)
            .any((d) => d.deviceId == convDeviceIdForMode);
    if (!ref.read(authProvider).isLoggedIn &&
        convDeviceIdForMode != s3VirtualDeviceId) {
      sendMode = SendMode.nearby;
    } else if (convDeviceIdForMode != s3VirtualDeviceId &&
        !peerIsRegistered &&
        (sendMode == SendMode.s3 || sendMode == SendMode.webrtc)) {
      sendMode = SendMode.nearby;
    }
    // In 1:1 conversation mode, always restrict to the conversation device only,
    // ignoring any stale multi-select state from effectiveSelectedTargets.
    if (sendMode != SendMode.s3 &&
        convDeviceIdForMode != null &&
        convDeviceIdForMode != _deviceId) {
      selectedTargets = {convDeviceIdForMode};
    }
    logChat.info(
      '_showFileSendModal sendMode=${sendMode.name} '
      'selectedTargets=$selectedTargets '
      'count=${selectedTargets.length}',
    );

    if (sendMode != SendMode.s3 && selectedTargets.isEmpty) {
      _composerKey.currentState?.expandDevicePanel();
      if (mounted) {
        AppToast.show(context, message: _l10n.chatScreenSelectTargetFirst);
      }
      return;
    }

    if (sendMode == SendMode.s3) {
      if (!ref.read(s3ConfiguredProvider)) {
        if (!mounted) return;
        final goConfig = await AppConfirmDialog.show(
          context,
          title: _l10n.chatScreenS3NotConfiguredTitle,
          content: _l10n.chatScreenS3NotConfiguredBody,
          confirmLabel: _l10n.chatScreenS3GoConfigure,
          icon: LucideIcons.cloud,
        );
        if (goConfig && mounted) {
          _composerKey.currentState?.unfocus();
          Navigator.pushNamed(context, '/settings/s3');
        }
        return;
      }
      if (!ref.read(s3OnlineProvider)) {
        if (!mounted) return;
        final goConfig = await AppConfirmDialog.show(
          context,
          title: _l10n.chatScreenS3UnavailableTitle,
          content: _l10n.chatScreenS3UnavailableBody,
          confirmLabel: _l10n.chatScreenS3GoSettings,
          icon: LucideIcons.cloud,
        );
        if (goConfig && mounted) {
          _composerKey.currentState?.unfocus();
          Navigator.pushNamed(context, '/settings/s3');
        }
        return;
      }
      final filesToSend = List<PlatformFile>.from(_pendingFiles);
      setState(() => _pendingFiles = []);
      _persistPendingFiles();
      // S3 virtual device conversation is a broadcast to all own devices (no toDeviceId).
      // A real device conversation uses toDeviceId so only that device gets the notification.
      final s3ToDeviceId =
          (convDeviceIdForMode != null &&
              convDeviceIdForMode != s3VirtualDeviceId &&
              convDeviceIdForMode != _deviceId)
          ? convDeviceIdForMode
          : null;
      final s3Bytes = filesToSend.fold<int>(0, (a, f) => a + f.size);
      Analytics.track(AnalyticsEvents.fileSendIntent, {
        'channel': 's3',
        'file_count': filesToSend.length,
        'total_size_bucket': Analytics.sizeBucket(s3Bytes),
        'target_count': selectedTargets.length,
      });
      _sendFilesConcurrently(
        filesToSend,
        (f) => _sendSingleFileViaS3(f, toDeviceId: s3ToDeviceId),
      );
      return;
    }

    final lanDevices = _lanDiscovery?.currentDiscovered ?? [];
    List<DeviceDto> cloudDevices = [];
    if (!_effectiveOffline) {
      try {
        cloudDevices = await listDevices();
      } catch (_) {}
    }
    if (!mounted) return;

    final mergedById = <String, DeviceDto>{};
    for (final d in lanDevices) {
      mergedById[d.deviceId] = d;
    }
    for (final d in cloudDevices) {
      final existing = mergedById[d.deviceId];
      if (existing != null) {
        mergedById[d.deviceId] = DeviceDto(
          deviceId: d.deviceId,
          name: d.name,
          platform: d.platform,
          lanHttpUrl: existing.lanHttpUrl ?? d.lanHttpUrl,
          lastSeen: d.lastSeen,
          presenceStatus: d.presenceStatus,
          presenceUpdatedAt: d.presenceUpdatedAt,
          displayCode: d.displayCode,
        );
      } else {
        mergedById[d.deviceId] = d;
      }
    }
    final allDevices = mergedById.values
        .where((d) => d.deviceId != _deviceId)
        .toList();

    switch (sendMode) {
      case SendMode.nearby:
        final targets = allDevices
            .where(
              (d) =>
                  selectedTargets.contains(d.deviceId) &&
                  d.lanHttpUrl != null &&
                  d.lanHttpUrl!.isNotEmpty,
            )
            .toList();
        if (targets.isEmpty) {
          _composerKey.currentState?.expandDevicePanel();
          if (mounted) {
            AppToast.show(context, message: _l10n.chatScreenNoNearbyDevice);
          }
          return;
        }
        final nearbyFiles = List<PlatformFile>.from(_pendingFiles);
        setState(() => _pendingFiles = []);
        _persistPendingFiles();
        final nbBytes = nearbyFiles.fold<int>(0, (a, f) => a + f.size);
        Analytics.track(AnalyticsEvents.fileSendIntent, {
          'channel': 'nearby',
          'file_count': nearbyFiles.length,
          'total_size_bucket': Analytics.sizeBucket(nbBytes),
          'target_count': targets.length,
        });
        _sendFilesConcurrently(
          nearbyFiles,
          (file) => _sendSingleFileViaLan(file, targets),
        );
      case SendMode.lan:
        final lanReachMap = ref.read(deviceReachabilityProvider);
        final manualHttpLocked =
            ref.read(connectionManualOverrideProvider) &&
            ref.read(connectionManualModeProvider) == SendMode.lan;
        final lanDiscoveredIds = (_lanDiscovery?.currentDiscovered ?? [])
            .where((d) => d.lanHttpUrl != null && d.lanHttpUrl!.isNotEmpty)
            .map((d) => d.deviceId)
            .toSet();
        final targets = allDevices
            .where(
              (d) =>
                  selectedTargets.contains(d.deviceId) &&
                  (manualHttpLocked ||
                      lanReachMap[d.deviceId]?.directHttp == true ||
                      lanReachMap[d.deviceId]?.pullReachable == true ||
                      lanReachMap[d.deviceId]?.peerHttpHealthy == true ||
                      lanDiscoveredIds.contains(d.deviceId)),
            )
            .toList();
        if (targets.isEmpty) {
          _composerKey.currentState?.expandDevicePanel();
          if (mounted) {
            AppToast.show(context, message: _l10n.chatScreenDeviceUnavailable);
          }
          return;
        }
        final filesToSend = List<PlatformFile>.from(_pendingFiles);
        setState(() => _pendingFiles = []);
        _persistPendingFiles();
        final lanBytes = filesToSend.fold<int>(0, (a, f) => a + f.size);
        Analytics.track(AnalyticsEvents.fileSendIntent, {
          'channel': 'lan',
          'file_count': filesToSend.length,
          'total_size_bucket': Analytics.sizeBucket(lanBytes),
          'target_count': targets.length,
        });
        _sendFilesConcurrently(
          filesToSend,
          (file) => _sendSingleFileViaLan(file, targets),
        );
      case SendMode.webrtc:
        final unsupportedFiles = _pendingFiles
            .where((f) => f.path == null || f.path!.isEmpty)
            .toList();
        if (unsupportedFiles.isNotEmpty) {
          if (mounted) {
            AppToast.show(
              context,
              message: _l10n.chatScreenWebRtcUnsupportedSource,
            );
          }
          return;
        }
        final reachMap = ref.read(deviceReachabilityProvider);
        final reachableTargets = selectedTargets
            .where(
              (id) =>
                  allDevices.any((d) => d.deviceId == id) &&
                  (reachMap[id]?.isConfirmedOnline ?? false),
            )
            .toList();
        if (reachableTargets.isEmpty) {
          _composerKey.currentState?.expandDevicePanel();
          if (mounted) {
            AppToast.show(context, message: _l10n.chatScreenDeviceUnavailable);
          }
          return;
        }
        final rtcFiles = List<PlatformFile>.from(_pendingFiles);
        setState(() => _pendingFiles = []);
        _persistPendingFiles();
        final rtcBytes = rtcFiles.fold<int>(0, (a, f) => a + f.size);
        Analytics.track(AnalyticsEvents.fileSendIntent, {
          'channel': 'webrtc',
          'file_count': rtcFiles.length,
          'total_size_bucket': Analytics.sizeBucket(rtcBytes),
          'target_count': reachableTargets.length,
        });
        for (final targetId in reachableTargets) {
          _sendFilesViaWebRTC(rtcFiles, targetId);
        }
      case SendMode.s3:
        break;
    }
  }

  void _sendFilesConcurrently(
    List<PlatformFile> files,
    Future<void> Function(PlatformFile) sendOne,
  ) {
    final maxConcurrent = TransferProtocol.maxConcurrentFiles;
    var running = 0;
    var index = 0;
    final waiters = <Completer<void>>[];

    void startNext() {
      while (running < maxConcurrent && index < files.length) {
        final file = files[index++];
        running++;
        sendOne(file).whenComplete(() {
          running--;
          if (waiters.isNotEmpty) {
            waiters.removeAt(0).complete();
          }
          startNext();
        });
      }
    }

    startNext();
  }

  Future<void> _sendFilesViaWebRTC(
    List<PlatformFile> files,
    String targetDeviceId, {
    String? reuseFileId,
    String? reuseLocalId,
  }) async {
    // reuseLocalId only makes sense for a single-file retry; callers passing
    // multiple files must rely on freshly-minted ids.
    assert(
      reuseLocalId == null || files.length == 1,
      'reuseLocalId requires a single-file batch',
    );
    final ap = await _accountPartForThreadKey();
    final webrtcThreadKey = threadKeyOneToOne(ap, _deviceId, targetDeviceId);
    final filesWithMeta = <({String filePath, WebRTCFileMeta meta})>[];
    final fileLocalIds = <String, String>{};

    for (final file in files) {
      if (file.path == null) continue;
      final fileId = reuseFileId ?? const Uuid().v4();
      final localId = reuseLocalId ?? const Uuid().v4();
      final meta = WebRTCFileMeta(
        fileId: fileId,
        fileName: file.name,
        fileSize: file.size,
        mimeType: 'application/octet-stream',
        lastModifiedMs: readMtimeMs(file.path),
        senderLocalId: localId,
      );
      filesWithMeta.add((filePath: file.path!, meta: meta));
      fileLocalIds[fileId] = localId;
      _webrtcFileLocalIdMap[fileId] = localId;
      _webrtcLocalIdToFileIdMap[localId] = fileId;
      _webrtcFileNameMap[fileId] = file.name;
      _webrtcFileSizeMap[fileId] = file.size;
      if (meta.lastModifiedMs != null) {
        _webrtcFileMtimeMsMap[fileId] = meta.lastModifiedMs!;
      }
      _webrtcTransferIdMap[fileId] = localId;
      _retryInfoByLocalId[localId] = _RetryInfo(
        fileName: file.name,
        fileSize: file.size,
        filePath: file.path,
        channel: 'webrtc',
        webrtcTargetDeviceId: targetDeviceId,
        webrtcFileId: fileId,
      );

      final transferRecord = TransferRecord(
        transferId: localId,
        fileName: file.name,
        fileSize: file.size,
        filePath: file.path,
        channel: 'webrtc',
        direction: 'upload',
        webrtcFileId: fileId,
        webrtcTargetDeviceId: targetDeviceId,
      );
      TransferStateManager.instance.saveRecord(transferRecord);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final sendingMsg = Message.text(
        id: 'local_$localId',
        authorId: _deviceId,
        createdAt: DateTime.now(),
        text: _l10n.chatTransferSendingPct(file.name, 0),
      );
      _insertOrUpdateMessage(sendingMsg);
      _scrollToBottom();
      final userId = await _getCurrentUserId();
      final webrtcMtimeMs = readMtimeMs(file.path);
      if (userId != null) {
        await ChatMessageDao.instance.insertMessage(
          userId: userId,
          id: 'local_$localId',
          type: 'file',
          payload: {
            'fileName': file.name,
            'size': file.size,
            'webrtc': true,
            'localId': localId,
            if (webrtcMtimeMs != null) 'lastModifiedMs': webrtcMtimeMs,
          },
          fromDeviceId: _deviceId,
          ts: ts,
          threadKey: webrtcThreadKey,
          synced: false,
          status: 'uploading',
        );
      }
      _fileMetaByMessageId['local_$localId'] = _FileMeta(
        fileName: file.name,
        size: file.size,
        transferType: 'webrtc',
      );
      setState(() {
        _localMessageStatus[localId] = 'uploading';
        _localMessageProgress[localId] = 0;
      });
      _speedTrackers['local_$localId'] = SpeedTracker();
      _transferStartTimes['local_$localId'] = DateTime.now();
    }

    try {
      final session = await _webrtcManager.initiateTransfer(
        targetDeviceId: targetDeviceId,
        localDeviceId: _deviceId,
        files: filesWithMeta,
      );
      await session.connected;
      logChat.info('WebRTC transfer initiated to $targetDeviceId');
    } catch (e) {
      logChat.warning('WebRTC failed: $e');
      // Try LAN reverse-pull fallback per file before surfacing failure.
      // We intentionally do NOT show the "webrtc failed, try http" toast yet
      // — if the fallback succeeds the user shouldn't see a failure message.
      bool anyFallbackSucceeded = false;
      bool anyFallbackAttempted = false;
      for (final fileWithMeta in filesWithMeta) {
        final fileId = fileWithMeta.meta.fileId;
        final localId = fileLocalIds[fileId];
        if (localId == null) continue;
        final fileName = fileWithMeta.meta.fileName;
        final fileSize = fileWithMeta.meta.fileSize;
        final mtimeMs = fileWithMeta.meta.lastModifiedMs;
        final pulled = await _tryWebRTCToLanReversePullFallback(
          fileId: fileId,
          localId: localId,
          fileName: fileName,
          fileSize: fileSize,
          filePath: fileWithMeta.filePath,
          lastModifiedMs: mtimeMs,
          targetDeviceId: targetDeviceId,
        );
        anyFallbackAttempted = true;
        if (pulled) {
          anyFallbackSucceeded = true;
          // Maps are cleared by _onWebRTCFileSent — remove from fileLocalIds
          // so the failure loop below skips this entry.
          fileLocalIds.remove(fileId);
        }
      }
      // Only show the "WebRTC failed" toast if at least one file truly failed
      // (fallback didn't recover it). Avoids a misleading toast when every
      // file was rescued by reverse-pull.
      if (mounted &&
          fileLocalIds.isNotEmpty &&
          (!anyFallbackAttempted || !anyFallbackSucceeded)) {
        AppToast.show(context, message: _l10n.chatScreenWebRtcFailedTryHttp);
      }
      for (final entry in fileLocalIds.entries) {
        final fileName =
            _webrtcFileNameMap[entry.key] ?? _l10n.chatScreenGenericFile;
        final localId = entry.value;
        _webrtcFileLocalIdMap.remove(entry.key);
        _webrtcLocalIdToFileIdMap.remove(localId);
        _webrtcFileNameMap.remove(entry.key);
        final rtcFailSize = _webrtcFileSizeMap.remove(entry.key);
        _webrtcFileMtimeMsMap.remove(entry.key);
        _webrtcTransferIdMap.remove(entry.key);
        await TransferStateManager.instance.markStatus(localId, 'failed');
        Analytics.track(AnalyticsEvents.fileSendOutcome, {
          'channel': 'webrtc',
          'status': 'failed',
          'size_bucket': Analytics.sizeBucket(rtcFailSize ?? 0),
        });
        _speedTrackers.remove('local_$localId');
        _transferStartTimes.remove('local_$localId');
        if (mounted) {
          _updateSendingMessage(
            localId,
            _l10n.chatTransferSendFailedNamed(fileName),
          );
          setState(() {
            _setMessageStatus(localId, 'failed');
            _localMessageProgress.remove(localId);
          });
        }
      }
    }
  }

  /// Resolve a device id to a [DeviceDto] with a usable `lanHttpUrl`, used
  /// by the WebRTC → LAN reverse-pull fallback. Prefers the LAN discovery
  /// cache (fast, accurate), falls back to the cloud device list when not
  /// offline.
  Future<DeviceDto?> _resolveDeviceForLan(String deviceId) async {
    if (deviceId.isEmpty || deviceId == _deviceId) return null;
    final lanDiscovered =
        _lanDiscovery?.currentDiscovered ?? const <DeviceDto>[];
    for (final d in lanDiscovered) {
      if (d.deviceId == deviceId &&
          d.lanHttpUrl != null &&
          d.lanHttpUrl!.isNotEmpty) {
        return d;
      }
    }
    if (_effectiveOffline) return null;
    try {
      final cloudDevices = await listDevices();
      for (final d in cloudDevices) {
        if (d.deviceId == deviceId &&
            d.lanHttpUrl != null &&
            d.lanHttpUrl!.isNotEmpty) {
          return d;
        }
      }
    } catch (e) {
      logChat.fine('_resolveDeviceForLan listDevices failed: $e');
    }
    return null;
  }

  /// Run the WebRTC → LAN reverse-pull fallback for a single file. Called
  /// from both `_sendFilesViaWebRTC` catch (initiateTransfer failure) and
  /// `_onWebRTCFileFailed` (mid-stream failure). On success, runs the same
  /// post-send bookkeeping as a normal WebRTC completion (routes through
  /// `_onWebRTCFileSent`); on failure, returns false so the caller can fall
  /// through to its existing failure path.
  ///
  /// IMPORTANT: caller must NOT have torn down the per-file WebRTC bookkeeping
  /// maps before calling this — they are needed by `_onWebRTCFileSent` on the
  /// success path.
  Future<bool> _tryWebRTCToLanReversePullFallback({
    required String fileId,
    required String localId,
    required String fileName,
    required int fileSize,
    required String? filePath,
    required int? lastModifiedMs,
    required String targetDeviceId,
  }) async {
    if (!mounted) return false;
    if (_lanReceiver?.lanHttpUrl == null) return false;
    if (filePath == null || filePath.isEmpty) return false;
    if (fileSize <= 0) return false;
    if (targetDeviceId.isEmpty) return false;

    final target = await _resolveDeviceForLan(targetDeviceId);
    if (target == null || !mounted) return false;

    // Register a CancelToken so the user's "cancel" tap during the
    // reverse-pull wait still routes through _cancelTransfer.
    final fallbackToken = CancelToken();
    _activeTransfers[localId] = fallbackToken;
    final tracker = _speedTrackers['local_$localId'] ?? SpeedTracker();
    _speedTrackers['local_$localId'] = tracker;
    try {
      final pulled = await _tryLanReversePullFallback(
        localId: localId,
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        bytes: null,
        targetDeviceIds: [targetDeviceId],
        targetsForProbe: [target],
        lastModifiedMs: lastModifiedMs,
        tracker: tracker,
        cancelToken: fallbackToken,
      );
      if (fallbackToken.isCancelled || !mounted) {
        if (fallbackToken.isCancelled) {
          await TransferStateManager.instance.markStatus(localId, 'paused');
        }
        return false;
      }
      if (!pulled) return false;
      // Route through the standard WebRTC "sent" path so the chat bubble,
      // TransferRecord, analytics event and `file` echo all match a normal
      // completion. The fileId-keyed maps were still populated when we got
      // here (caller hasn't torn them down yet), which is what
      // `_onWebRTCFileSent` expects.
      _onWebRTCFileSent(fileId, fileName);
      return true;
    } finally {
      // Clear our fallback token from _activeTransfers if it's still ours;
      // if the caller's success path replaces it later, leave that alone.
      final current = _activeTransfers[localId];
      if (identical(current, fallbackToken)) {
        _activeTransfers.remove(localId);
      }
    }
  }

  /// Publish a `lan_file_offer` so the receiver can pull this file out-of-band
  /// when the primary push (LAN POST or WebRTC) failed.
  ///
  /// Returns `true` iff the peer completed the pull within [pullTimeout].
  /// Returns `false` for any of: missing local LAN server, no probable target,
  /// peer never pulled in time, [cancelToken] tripped, or no payload to
  /// publish. Callers are responsible for the post-success bookkeeping
  /// (sending the `file` echo, persisting status, updating bubble to "sent").
  ///
  /// [targetsForProbe] is the list of devices whose `lanHttpUrl` we probe to
  /// confirm at least one is reachable before publishing the offer. Pass an
  /// empty list to skip the probe (treated as reachable). This is important
  /// for asymmetric LANs: direct HTTP from sender to receiver may fail while
  /// cloud signaling still lets the receiver learn the sender's pull URL.
  ///
  /// [pullTimeout] caps how long we wait for the receiver to actually pull
  /// the offer before giving up. Default is 60s. Callers that already know
  /// the peer was reachable but rejected mid-stream (e.g. LAN push opened a
  /// socket then failed) should pass a shorter timeout — if the receiver
  /// explicitly cancelled it will silently drop the offer (via the
  /// `_lanRecentlyCancelledSenderLocalIds` suppression window) and the wait
  /// just delays the user-visible failure.
  Future<bool> _tryLanReversePullFallback({
    required String localId,
    required String fileName,
    required int fileSize,
    required String? filePath,
    required Uint8List? bytes,
    required List<String> targetDeviceIds,
    required List<DeviceDto> targetsForProbe,
    required int? lastModifiedMs,
    required SpeedTracker tracker,
    required CancelToken? cancelToken,
    Duration pullTimeout = const Duration(seconds: 60),
  }) async {
    if (!mounted) return false;
    if (_lanReceiver?.lanHttpUrl == null) return false;
    if (cancelToken?.isCancelled == true) return false;
    if (filePath == null && bytes == null) return false;
    if (targetDeviceIds.isEmpty) return false;

    // Probe failed devices to check if any are still alive before trying
    // reverse pull. Empty `targetsForProbe` means the caller already vetted
    // reachability (e.g. the LAN push succeeded for some siblings) and just
    // wants to publish the offer to no-lanHttpUrl peers.
    bool anyReachable = false;
    if (targetsForProbe.isNotEmpty) {
      for (final d in targetsForProbe) {
        if (d.lanHttpUrl != null && d.lanHttpUrl!.isNotEmpty) {
          final alive = await probeHttp(
            d.lanHttpUrl!,
            timeout: const Duration(seconds: 3),
          );
          if (alive) {
            anyReachable = true;
            break;
          }
        }
      }
    } else {
      anyReachable = true;
    }
    if (!anyReachable || !mounted || cancelToken?.isCancelled == true) {
      logChat.fine(
        'skip lan reverse-pull offer for $fileName '
        'reachable=$anyReachable mounted=$mounted '
        'cancelled=${cancelToken?.isCancelled == true}',
      );
      return false;
    }

    final offerId = const Uuid().v4();
    _updateSendingMessage(localId, _l10n.chatTransferWaitingPeerLine(fileName));
    final (pullUrl, pullFuture) = _lanReceiver!.offerFileForPull(
      offerId,
      fileName,
      fileSize,
      filePath: filePath,
      bytes: bytes,
      cancelToken: cancelToken,
      onPullStarted: () {
        if (!mounted) return;
        tracker.reset();
        _updateSendingMessage(
          localId,
          _l10n.chatTransferSendingPct(fileName, 0),
        );
      },
      onSendProgress: (sent, total) {
        if (!mounted || cancelToken?.isCancelled == true) return;
        tracker.update(sent);
        final pct = total > 0 ? (sent * 100 / total).round().clamp(0, 100) : 0;
        _updateSendingMessage(
          localId,
          _l10n.chatTransferSendingPct(fileName, pct),
        );
      },
      onPullCompleted: () {
        if (!mounted) return;
        logChat.info('chat_screen reverse pull completed for $fileName');
      },
    );
    if (pullUrl == null || !mounted) return false;

    if (!_effectiveOffline) {
      logChat.info(
        'publish lan_file_offer file=$fileName targets=$targetDeviceIds '
        'pullUrl=$pullUrl timeout=${pullTimeout.inSeconds}s',
      );
      await sendMessage({
        'type': 'lan_file_offer',
        'payload': <String, dynamic>{
          'fileName': fileName,
          'size': fileSize,
          'pullUrl': pullUrl,
          'offerId': offerId,
          'targetDeviceIds': targetDeviceIds,
          'localId': localId,
          if (lastModifiedMs != null) 'lastModifiedMs': lastModifiedMs,
        },
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }
    if (mounted) {
      _updateSendingMessage(
        localId,
        _l10n.chatTransferWaitingPeerLine(fileName),
      );
    }
    if (pullFuture == null) return false;
    final pullOk = await pullFuture.timeout(
      pullTimeout,
      onTimeout: () => false,
    );
    if (cancelToken?.isCancelled == true) return false;
    return pullOk;
  }

  Future<void> _sendSingleFileViaLan(
    PlatformFile file,
    List<DeviceDto> targets, {
    String? reuseLocalId,
  }) async {
    // Reusing the original localId on retry keeps the chat bubble id, the
    // TransferRecord transferId and the receiver-side messageId stable across
    // cold-start retries. Without this, every retry leaves orphan rows in
    // `transfer_records` / `chat_messages` and the cancel button bound to the
    // visible bubble may not match the active CancelToken key.
    final localId = reuseLocalId ?? const Uuid().v4();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final cancelToken = CancelToken();
    _activeTransfers[localId] = cancelToken;
    final sendCompleter = Completer<void>();
    _activeTransferFutures[localId] = sendCompleter.future;

    _retryInfoByLocalId[localId] = _RetryInfo(
      fileName: file.name,
      fileSize: file.size,
      filePath: file.path,
      channel: 'lan',
      lanTargets: targets,
    );

    final transferRecord = TransferRecord(
      transferId: localId,
      fileName: file.name,
      fileSize: file.size,
      filePath: file.path,
      channel: 'lan',
      direction: 'upload',
      lanTargetDeviceIds: targets.map((d) => d.deviceId).toList(),
    );
    await TransferStateManager.instance.saveRecord(transferRecord);

    final outbound = await _outboundThreadKeyForSelection();
    final lanMtimeMs = readMtimeMs(file.path);
    final lanPayload = <String, dynamic>{
      'fileName': file.name,
      'size': file.size,
      'lan': true,
      'targetDeviceIds': targets.map((d) => d.deviceId).toList(),
      'localId': localId,
      if (lanMtimeMs != null) 'lastModifiedMs': lanMtimeMs,
    };
    final envelope = MessageEnvelope(
      type: 'file',
      payload: lanPayload,
      fromDeviceId: _deviceId,
      ts: ts,
      toDeviceId: outbound.toDeviceId,
      threadKey: outbound.threadKey,
    );
    final placeholderMsg = envelopeToMessage(
      envelope,
      overrideId: 'local_$localId',
    );
    final sendingMessage = Message.text(
      id: placeholderMsg.id,
      authorId: placeholderMsg.authorId,
      createdAt: placeholderMsg.createdAt,
      text: _l10n.chatTransferSendingPct(file.name, 0),
    );
    _insertOrUpdateMessage(sendingMessage);
    _scrollToBottom();
    final userId = await _getCurrentUserId();
    if (userId != null) {
      await ChatMessageDao.instance.insertMessage(
        userId: userId,
        id: 'local_$localId',
        type: 'file',
        payload: lanPayload,
        fromDeviceId: _deviceId,
        ts: ts,
        threadKey: outbound.threadKey,
        synced: false,
        status: 'uploading',
      );
    }
    _fileMetaByMessageId['local_$localId'] = _FileMeta(
      fileName: file.name,
      size: file.size,
      transferType: 'lan',
    );
    if (mounted) setState(() => _localMessageStatus[localId] = 'uploading');
    final tracker = SpeedTracker();
    _speedTrackers['local_$localId'] = tracker;
    _transferStartTimes['local_$localId'] = DateTime.now();

    int lastLanProgressPersistAtPct = 0;
    bool anyPushConnected = false;
    try {
      final pushTargets = targets
          .where((d) => d.lanHttpUrl != null && d.lanHttpUrl!.isNotEmpty)
          .toList();
      final (
        bool anyPushed,
        List<DeviceDto> pushFailed,
      ) = await trySendFileViaLan(
        file,
        pushTargets,
        fromDeviceId: _deviceId,
        localId: localId,
        cancelToken: cancelToken,
        onConnected: () => anyPushConnected = true,
        onProgress: (sent, total) {
          if (!mounted || cancelToken.isCancelled) return;
          tracker.update(sent);
          final pct = total > 0
              ? (sent * 100 / total).round().clamp(0, 100)
              : 0;
          _updateSendingMessage(
            localId,
            _l10n.chatTransferSendingPct(file.name, pct),
          );
          // Persist progress every 5% so a cold-start can show the right
          // resume offset in the UI even before the receiver reports back.
          if (pct - lastLanProgressPersistAtPct >= 5 || pct >= 100) {
            lastLanProgressPersistAtPct = pct;
            TransferStateManager.instance.updateLanOffset(localId, sent);
          }
        },
      );
      if (cancelToken.isCancelled) {
        await TransferStateManager.instance.markStatus(localId, 'paused');
        return;
      }

      final needOfferIds = <String>[
        ...pushFailed.map((d) => d.deviceId),
        ...targets
            .where((d) => d.lanHttpUrl == null || d.lanHttpUrl!.isEmpty)
            .map((d) => d.deviceId),
      ];
      bool didSendFile = false;
      if (anyPushed && mounted) {
        if (!_effectiveOffline) {
          await sendMessage({
            'type': 'file',
            'payload': Map<String, dynamic>.from(lanPayload),
            'fromDeviceId': _deviceId,
            'threadKey': outbound.threadKey,
            if (outbound.toDeviceId != null) 'toDeviceId': outbound.toDeviceId,
            'ts': DateTime.now().millisecondsSinceEpoch,
          });
        }
        didSendFile = true;
      }
      // Always attempt the reverse-pull fallback when the direct push didn't
      // cover every target — even when the push had already reached the
      // receiver. f67384d originally short-circuited this branch on the
      // theory that "POST handshake succeeded → subsequent failure must be
      // an active reject", but that heuristic misclassifies transient
      // network/system failures (Android backgrounding, kernel killing the
      // socket, etc.) as rejections and leaves the user stranded with no
      // recovery path. When the receiver *did* explicitly cancel, its
      // `_lanRecentlyCancelledSenderLocalIds` suppression window drops the
      // offer silently, so the worst case is the short [pullTimeout] wait
      // selected below.
      if (needOfferIds.isNotEmpty && mounted && !cancelToken.isCancelled) {
        final noPushDevices = targets
            .where((d) => d.lanHttpUrl == null || d.lanHttpUrl!.isEmpty)
            .toList();
        if (noPushDevices.isNotEmpty) {
          logChat.fine(
            'Skipping ${noPushDevices.length} device(s) without lanHttpUrl',
          );
        }
        // Tight timeout when the peer was already reachable but rejected the
        // upload — receiver-side suppression will drop the offer immediately
        // and a long wait would just stall the UI. Full 60s timeout for
        // never-connected pushes so a slow remote still has a chance.
        final pullTimeout = anyPushConnected
            ? const Duration(seconds: 10)
            : const Duration(seconds: 60);
        final pulled = await _tryLanReversePullFallback(
          localId: localId,
          fileName: file.name,
          fileSize: file.size,
          filePath: file.path,
          bytes: file.bytes,
          targetDeviceIds: needOfferIds,
          // Do not re-probe the failed direct-HTTP direction here. The whole
          // point of reverse pull is to recover asymmetric links where
          // Windows -> Android HTTP breaks but cloud signaling still reaches
          // Android and Android can pull from Windows.
          targetsForProbe: const <DeviceDto>[],
          lastModifiedMs: lanMtimeMs,
          tracker: tracker,
          cancelToken: cancelToken,
          pullTimeout: pullTimeout,
        );
        if (cancelToken.isCancelled) {
          await TransferStateManager.instance.markStatus(localId, 'paused');
          return;
        }
        if (pulled) {
          if (!anyPushed && !_effectiveOffline) {
            await sendMessage({
              'type': 'file',
              'payload': Map<String, dynamic>.from(lanPayload),
              'fromDeviceId': _deviceId,
              'threadKey': outbound.threadKey,
              if (outbound.toDeviceId != null)
                'toDeviceId': outbound.toDeviceId,
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
          }
          didSendFile = true;
        }
      }
      if (mounted && (didSendFile || anyPushed)) {
        final doneEnvelope = MessageEnvelope(
          type: 'file',
          payload: lanPayload,
          fromDeviceId: _deviceId,
          ts: ts,
          toDeviceId: outbound.toDeviceId,
          threadKey: outbound.threadKey,
        );
        final doneMessage = envelopeToMessage(
          doneEnvelope,
          overrideId: 'local_$localId',
        );
        final toUpdate = _findMessageById('local_$localId');
        if (toUpdate != null) {
          await _chatController.updateMessage(toUpdate, doneMessage);
        }
        _fileMetaByMessageId['local_$localId'] = _FileMeta(
          fileName: file.name,
          size: file.size,
          transferType: 'lan',
          localPath: file.path,
        );
        _retryInfoByLocalId.remove(localId);
        final uid = await _getCurrentUserId();
        if (uid != null) {
          final donePayload = Map<String, dynamic>.from(lanPayload);
          if (file.path != null) donePayload['localPath'] = file.path!;
          await ChatMessageDao.instance.insertMessage(
            userId: uid,
            id: 'local_$localId',
            type: 'file',
            payload: donePayload,
            fromDeviceId: _deviceId,
            ts: ts,
            threadKey: outbound.threadKey,
            synced: true,
            status: 'sent',
          );
        }
        if (mounted) setState(() => _localMessageStatus[localId] = 'sent');
        await TransferStateManager.instance.markStatus(localId, 'completed');
        Analytics.track(AnalyticsEvents.fileSendOutcome, {
          'channel': 'lan',
          'status': 'completed',
          'size_bucket': Analytics.sizeBucket(file.size),
        });
        unawaited(SharePendingCache.deleteStagingFile(file.path));
      }
      if (mounted && !didSendFile && !anyPushed) {
        _updateSendingMessage(
          localId,
          _l10n.chatTransferSendFailedNamed(file.name),
        );
        setState(() => _setMessageStatus(localId, 'failed'));
        await TransferStateManager.instance.markStatus(localId, 'failed');
        Analytics.track(AnalyticsEvents.fileSendOutcome, {
          'channel': 'lan',
          'status': 'failed',
          'size_bucket': Analytics.sizeBucket(file.size),
        });
      }
    } catch (e) {
      // Distinguish user cancel (paused, resumable) from genuine failure.
      if (cancelToken.isCancelled) {
        await TransferStateManager.instance.markStatus(localId, 'paused');
      } else {
        if (mounted) {
          _updateSendingMessage(
            localId,
            _l10n.chatTransferSendFailedNamed(file.name),
          );
          setState(() => _setMessageStatus(localId, 'failed'));
        }
        await TransferStateManager.instance.markStatus(localId, 'failed');
        Analytics.track(AnalyticsEvents.fileSendOutcome, {
          'channel': 'lan',
          'status': 'failed',
          'size_bucket': Analytics.sizeBucket(file.size),
        });
      }
    } finally {
      _activeTransfers.remove(localId);
      _activeTransferFutures.remove(localId);
      _speedTrackers.remove('local_$localId');
      _transferStartTimes.remove('local_$localId');
      if (!sendCompleter.isCompleted) sendCompleter.complete();
    }
  }

  Future<void> _sendSingleFileViaS3(
    PlatformFile file, {
    String? toDeviceId,
    String? reuseLocalId,
  }) async {
    // See `_sendSingleFileViaLan` for why reusing localId on retry matters.
    final localId = reuseLocalId ?? const Uuid().v4();
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Register the cancel token before any await so the cancel button (which
    // becomes visible as soon as the placeholder bubble is inserted) is never
    // racing against an unset `_activeTransfers` slot.
    final cancelToken = CancelToken();
    _activeTransfers[localId] = cancelToken;
    final s3ThreadKey = await _threadKeyForS3Persist(toDeviceId);

    _retryInfoByLocalId[localId] = _RetryInfo(
      fileName: file.name,
      fileSize: file.size,
      filePath: file.path,
      channel: 's3',
      toDeviceId: toDeviceId,
    );

    logChat.info('chat_screen sendFileViaS3 fileName=${file.name}');
    try {
      if (!mounted) return;
      if (!ref.read(s3ConfiguredProvider)) {
        logChat.warning('chat_screen sendFileViaS3 hasS3Config=false');
        if (mounted) {
          AppToast.show(
            context,
            message: _l10n.chatScreenConfigureS3FirstToast,
          );
        }
        _activeTransfers.remove(localId);
        return;
      }
      if (!ref.read(s3OnlineProvider)) {
        logChat.warning('chat_screen sendFileViaS3 s3Offline');
        if (mounted) {
          AppToast.show(context, message: _l10n.chatScreenS3UnavailableToast);
        }
        _activeTransfers.remove(localId);
        return;
      }
      final contentType = file.extension != null
          ? mimeFromExtension(file.extension!)
          : null;
      final s3MtimeMs = readMtimeMs(file.path);
      final envelope = MessageEnvelope(
        type: 'file',
        payload: {
          'fileName': file.name,
          'size': file.size,
          'localId': localId,
          if (s3MtimeMs != null) 'lastModifiedMs': s3MtimeMs,
        },
        fromDeviceId: _deviceId,
        ts: ts,
        toDeviceId: toDeviceId,
        threadKey: s3ThreadKey,
      );
      final progressMsg = envelopeToMessage(
        envelope,
        overrideId: 'local_$localId',
      );
      final initialMessage = Message.text(
        id: progressMsg.id,
        authorId: progressMsg.authorId,
        createdAt: progressMsg.createdAt,
        text: _l10n.chatTransferSendingPct(file.name, 0),
      );
      _insertOrUpdateMessage(initialMessage);
      _scrollToBottom();
      final userId = await _getCurrentUserId();
      if (userId != null) {
        await ChatMessageDao.instance.insertMessage(
          userId: userId,
          id: 'local_$localId',
          type: 'file',
          payload: {
            'fileName': file.name,
            'size': file.size,
            'localId': localId,
            if (s3MtimeMs != null) 'lastModifiedMs': s3MtimeMs,
          },
          fromDeviceId: _deviceId,
          ts: ts,
          threadKey: s3ThreadKey,
          synced: false,
          status: 'uploading',
        );
      }
      _fileMetaByMessageId['local_$localId'] = _FileMeta(
        fileName: file.name,
        size: file.size,
        transferType: 's3',
      );
      if (mounted) {
        setState(() {
          _localMessageStatus[localId] = 'uploading';
          _localMessageProgress[localId] = 0;
        });
      }

      final s3Tracker = SpeedTracker();
      _speedTrackers['local_$localId'] = s3Tracker;
      _transferStartTimes['local_$localId'] = DateTime.now();
      Message currentMessage = initialMessage;
      int lastLoggedPct = -1;

      final result = await _cloudTransfer.upload(
        fileName: file.name,
        fileSize: file.size,
        filePath: file.path,
        bytes: file.bytes,
        contentType: contentType,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          s3Tracker.update(sent);
          final pct = total > 0
              ? (sent * 100 / total).round().clamp(0, 100)
              : 0;
          if (pct >= lastLoggedPct + 10) {
            lastLoggedPct = pct;
            logChat.info(
              'S3 upload progress ${file.name} $pct% ($sent/$total bytes)',
            );
          }
          if (mounted) {
            setState(() {
              _localMessageProgress[localId] = pct;
            });
            final newMsg = Message.text(
              id: currentMessage.id,
              authorId: currentMessage.authorId,
              createdAt: currentMessage.createdAt,
              text: _l10n.chatTransferSendingPct(file.name, pct),
            );
            _chatController.updateMessage(currentMessage, newMsg);
            currentMessage = newMsg;
          }
        },
      );

      await sendMessage({
        'type': 'file',
        'payload': <String, dynamic>{
          'key': result.key,
          'fileName': file.name,
          'size': file.size,
          'localId': localId,
          if (s3MtimeMs != null) 'lastModifiedMs': s3MtimeMs,
        },
        'fromDeviceId': _deviceId,
        'threadKey': s3ThreadKey,
        if (toDeviceId != null) 'toDeviceId': toDeviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      final envelopeDone = MessageEnvelope(
        type: 'file',
        payload: {
          'key': result.key,
          'fileName': file.name,
          'size': file.size,
          'localId': localId,
          if (s3MtimeMs != null) 'lastModifiedMs': s3MtimeMs,
        },
        fromDeviceId: _deviceId,
        ts: ts,
        toDeviceId: toDeviceId,
        threadKey: s3ThreadKey,
      );
      final doneMessage = envelopeToMessage(
        envelopeDone,
        overrideId: 'local_$localId',
      );
      _fileKeyByMessageId[doneMessage.id] = result.key;
      _fileFileNameByMessageId[doneMessage.id] = file.name;
      _fileMetaByMessageId[doneMessage.id] = _FileMeta(
        fileName: file.name,
        size: file.size,
        s3Key: result.key,
        transferType: 's3',
        localPath: file.path,
      );
      final lastMsg = _findMessageById('local_$localId');
      if (lastMsg != null) {
        await _chatController.updateMessage(lastMsg, doneMessage);
      }
      _retryInfoByLocalId.remove(localId);
      await ChatMessageDao.instance.markSynced('local_$localId');
      if (mounted) {
        setState(() {
          _setMessageStatus(localId, 'sent');
          _localMessageProgress.remove(localId);
        });
      }
      logChat.info('chat_screen sendFileViaS3 ok key=${result.key}');
      Analytics.track(AnalyticsEvents.fileSendOutcome, {
        'channel': 's3',
        'status': 'completed',
        'size_bucket': Analytics.sizeBucket(file.size),
      });
      unawaited(SharePendingCache.deleteStagingFile(file.path));
    } catch (e) {
      if (cancelToken.isCancelled) return;
      logChat.warning('chat_screen sendFileViaS3 failed: $e');
      if (mounted) {
        _updateSendingMessage(
          localId,
          _l10n.chatTransferSendFailedNamed(file.name),
        );
        setState(() {
          _setMessageStatus(localId, 'failed');
          _localMessageProgress.remove(localId);
        });
        AppToast.show(
          context,
          message: _l10n.chatScreenSendFailedWithError('$e'),
        );
      }
      Analytics.track(AnalyticsEvents.fileSendOutcome, {
        'channel': 's3',
        'status': 'failed',
        'size_bucket': Analytics.sizeBucket(file.size),
      });
    } finally {
      _activeTransfers.remove(localId);
      _speedTrackers.remove('local_$localId');
      _transferStartTimes.remove('local_$localId');
    }
  }

  Future<void> _handlePullProbe(String probeUrl, String probeId) async {
    final success = await probeHttp(
      probeUrl,
      timeout: const Duration(seconds: 3),
    );
    logChat.info('_handlePullProbe probeId=$probeId success=$success');
    try {
      await sendMessage({
        'type': 'lan_pull_probe_result',
        'payload': {'probeId': probeId, 'success': success},
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      logChat.warning('_handlePullProbe sendResult failed: $e');
    }
  }

  Future<bool> _sendPullProbe(String targetDeviceId) async {
    if (_lanReceiver?.lanHttpUrl == null) return false;
    final probeId = const Uuid().v4();
    final completer = Completer<bool>();
    _pendingPullProbes[probeId] = completer;
    final probeUrl = _lanReceiver!.lanHttpUrl!;
    try {
      await sendMessage({
        'type': 'lan_pull_probe',
        'payload': {
          'probeId': probeId,
          'probeUrl': probeUrl,
          'targetDeviceId': targetDeviceId,
        },
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          _pendingPullProbes.remove(probeId);
          return false;
        },
      );
    } catch (e) {
      _pendingPullProbes.remove(probeId);
      logChat.warning('_sendPullProbe failed: $e');
      return false;
    }
  }

  /// Returns a connectivity status string:
  /// 'online' (same network), 'connectable' (might work), 'offline' (unreachable).
  Future<String> _sendWebRTCProbe(
    String targetDeviceId, {
    Duration responseTimeout = const Duration(seconds: 10),
  }) async {
    final probeId = const Uuid().v4();
    final completer = Completer<String>();
    _pendingWebRTCProbes[probeId] = completer;
    try {
      final localSummary = await gatherIceCandidates();
      await sendMessage({
        'type': 'webrtc_probe',
        'payload': {
          'probeId': probeId,
          'targetDeviceId': targetDeviceId,
          'iceSummary': localSummary.toJson(),
        },
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      return await completer.future.timeout(
        responseTimeout,
        onTimeout: () {
          _pendingWebRTCProbes.remove(probeId);
          return 'offline';
        },
      );
    } catch (e) {
      _pendingWebRTCProbes.remove(probeId);
      logChat.warning('_sendWebRTCProbe failed: $e');
      return 'offline';
    }
  }

  Future<void> _handleWebRTCProbe(
    String probeId,
    String fromDeviceId,
    Map<String, dynamic>? senderIceSummary,
  ) async {
    logChat.info('_handleWebRTCProbe probeId=$probeId from=$fromDeviceId');
    try {
      final localSummary = await gatherIceCandidates();
      final remoteSummary = senderIceSummary != null
          ? IceCandidateSummary.fromJson(senderIceSummary)
          : IceCandidateSummary.empty();
      final connectivity = IceCandidateSummary.analyzeConnectivity(
        localSummary,
        remoteSummary,
      );
      logChat.info(
        '_handleWebRTCProbe result=$connectivity '
        'local=${localSummary.toJson()} remote=${remoteSummary.toJson()}',
      );
      await sendMessage({
        'type': 'webrtc_probe_result',
        'payload': {
          'probeId': probeId,
          'success': true,
          'connectivity': connectivity,
        },
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      logChat.warning('_handleWebRTCProbe sendResult failed: $e');
    }
  }

  Future<void> _handleLanHttpProbe(
    String probeId,
    String? senderLanHttpUrl,
  ) async {
    final lanUrl = await _ensureHealthyLanHttpUrl();
    final success = lanUrl != null && lanUrl.isNotEmpty;
    bool senderReachable = false;
    if (senderLanHttpUrl != null && senderLanHttpUrl.isNotEmpty) {
      senderReachable = await probeHttp(
        senderLanHttpUrl,
        timeout: const Duration(seconds: 3),
      );
    }
    logChat.info(
      '_handleLanHttpProbe probeId=$probeId success=$success lanUrl=$lanUrl senderReachable=$senderReachable',
    );
    try {
      await sendMessage({
        'type': 'lan_http_probe_result',
        'payload': {
          'probeId': probeId,
          'success': success,
          'lanHttpUrl': lanUrl,
          'senderReachable': senderReachable,
        },
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      logChat.warning('_handleLanHttpProbe sendResult failed: $e');
    }
  }

  Future<({bool success, String? lanHttpUrl, bool senderReachable})>
  _sendLanHttpProbe(
    String targetDeviceId, {
    Duration responseTimeout = const Duration(seconds: 5),
  }) async {
    final probeId = const Uuid().v4();
    final completer =
        Completer<({bool success, String? lanHttpUrl, bool senderReachable})>();
    _pendingLanHttpProbes[probeId] = completer;
    try {
      await sendMessage({
        'type': 'lan_http_probe',
        'payload': {
          'probeId': probeId,
          'targetDeviceId': targetDeviceId,
          'senderLanHttpUrl': _lanReceiver?.lanHttpUrl,
        },
        'fromDeviceId': _deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      return await completer.future.timeout(
        responseTimeout,
        onTimeout: () {
          _pendingLanHttpProbes.remove(probeId);
          return (success: false, lanHttpUrl: null, senderReachable: false);
        },
      );
    } catch (e) {
      _pendingLanHttpProbes.remove(probeId);
      logChat.warning('_sendLanHttpProbe failed: $e');
      return (success: false, lanHttpUrl: null, senderReachable: false);
    }
  }

  void _handleWebRTCOffer(Map<String, dynamic> signal, String fromDeviceId) {
    final senderDeviceId = signal['senderDeviceId']?.toString() ?? '';
    if (senderDeviceId == _deviceId) return;
    final targetDeviceId = signal['targetDeviceId']?.toString() ?? '';
    if (targetDeviceId != _deviceId) return;

    final filesRaw = signal['files'] as List? ?? [];
    for (final f in filesRaw) {
      if (f is Map<String, dynamic>) {
        final fileId = f['fileId']?.toString() ?? '';
        final fileName = f['fileName']?.toString() ?? 'unknown';
        final fileSize = (f['fileSize'] as num?)?.toInt();
        final rawSenderLocalId = f['localId'];
        final senderLocalId =
            (rawSenderLocalId is String && rawSenderLocalId.isNotEmpty)
            ? rawSenderLocalId
            : null;

        final existingLocalId = _webrtcFileLocalIdMap[fileId];
        if (existingLocalId != null) {
          _speedTrackers.putIfAbsent(
            'local_$existingLocalId',
            () => SpeedTracker(),
          );
          _transferStartTimes['local_$existingLocalId'] = DateTime.now();
          setState(() {
            _setMessageStatus(existingLocalId, 'downloading');
            _localMessageProgress[existingLocalId] = 0;
          });
          final existingMsg = _findMessageById('local_$existingLocalId');
          if (existingMsg != null) {
            final updMsg = Message.text(
              id: existingMsg.id,
              authorId: existingMsg.authorId,
              createdAt: existingMsg.createdAt,
              text: _l10n.chatTransferReceivingPct(fileName, 0),
            );
            _chatController.updateMessage(existingMsg, updMsg);
          }
          continue;
        }

        final localId = const Uuid().v4();
        _webrtcFileLocalIdMap[fileId] = localId;
        _webrtcLocalIdToFileIdMap[localId] = fileId;
        _webrtcFileNameMap[fileId] = fileName;
        if (fileSize != null && fileSize > 0) {
          _webrtcFileSizeMap[fileId] = fileSize;
        }
        _speedTrackers['local_$localId'] = SpeedTracker();
        _transferStartTimes['local_$localId'] = DateTime.now();
        // Remember the sender's localId so we can dedup the eventual
        // Centrifugo `file` publication against this local receiver bubble.
        if (senderLocalId != null) {
          _webrtcRecvLocalIds.add(senderLocalId);
          _lanLocalIdToMessageId[senderLocalId] = 'local_$localId';
        }

        final msg = Message.text(
          id: 'local_$localId',
          authorId: fromDeviceId,
          createdAt: DateTime.now(),
          text: _l10n.chatTransferReceivingPct(fileName, 0),
        );
        setState(() {
          _localMessageStatus[localId] = 'downloading';
          _localMessageProgress[localId] = 0;
        });
        _chatController.insertMessage(msg);
        _scrollToBottom();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final payload = <String, dynamic>{'fileName': fileName, 'webrtc': true};
        if (fileSize != null && fileSize > 0) payload['size'] = fileSize;
        _getCurrentUserId().then((userId) async {
          if (userId == null) return;
          final ap = await _accountPartForThreadKey();
          final rtk = threadKeyOneToOne(ap, fromDeviceId, _deviceId);
          await ChatMessageDao.instance.insertMessage(
            userId: userId,
            id: 'local_$localId',
            type: 'file',
            payload: payload,
            fromDeviceId: fromDeviceId,
            ts: ts,
            threadKey: rtk,
            synced: false,
            status: 'downloading',
          );
        });
      }
    }
  }

  int _lastWebRTCProgressUpdate = 0;

  void _onWebRTCProgress(String fileId, int received, int total) {
    final localId = _webrtcFileLocalIdMap[fileId];
    if (localId == null || !mounted) return;
    final pct = total > 0 ? (received * 100 / total).round().clamp(0, 100) : 0;
    final tracker = _speedTrackers['local_$localId'];
    tracker?.update(received);
    setState(() {
      _localMessageProgress[localId] = pct;
    });
    final fileName = _webrtcFileNameMap[fileId];
    if (fileName != null) {
      final status = _localMessageStatus[localId];
      final progressLine = status == 'uploading'
          ? _l10n.chatTransferSendingPct(fileName, pct)
          : _l10n.chatTransferReceivingPct(fileName, pct);
      _updateSendingMessage(localId, progressLine);
    }

    final transferId = _webrtcTransferIdMap[fileId];
    if (transferId != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastWebRTCProgressUpdate > 2000) {
        _lastWebRTCProgressUpdate = now;
        TransferStateManager.instance.updateWebrtcOffset(transferId, received);
      }
    }
  }

  void _onWebRTCFileSent(String fileId, String fileName) {
    final localId = _webrtcFileLocalIdMap.remove(fileId);
    if (localId != null) _webrtcLocalIdToFileIdMap.remove(localId);
    _webrtcFileNameMap.remove(fileId);
    final fileSize = _webrtcFileSizeMap.remove(fileId);
    final webrtcSentMtimeMs = _webrtcFileMtimeMsMap.remove(fileId);
    final transferId = _webrtcTransferIdMap.remove(fileId);
    final retryInfo = localId != null ? _retryInfoByLocalId[localId] : null;
    if (transferId != null) {
      TransferStateManager.instance.markStatus(transferId, 'completed');
    }
    if (localId == null || !mounted) return;
    Analytics.track(AnalyticsEvents.fileSendOutcome, {
      'channel': 'webrtc',
      'status': 'completed',
      'size_bucket': Analytics.sizeBucket(fileSize ?? 0),
    });
    _speedTrackers.remove('local_$localId');
    _transferStartTimes.remove('local_$localId');
    final targetDeviceId = retryInfo?.webrtcTargetDeviceId;
    _retryInfoByLocalId.remove(localId);
    unawaited(SharePendingCache.deleteStagingFile(retryInfo?.filePath));
    setState(() {
      _setMessageStatus(localId, 'sent');
      _localMessageProgress.remove(localId);
    });
    _fileMetaByMessageId['local_$localId'] = _FileMeta(
      fileName: fileName,
      size: fileSize,
      transferType: 'webrtc',
    );
    _updateSendingMessage(localId, _l10n.chatWebRtcSentParen(fileName));
    final payload = <String, dynamic>{
      'fileName': fileName,
      'webrtc': true,
      'localId': localId,
    };
    if (fileSize != null && fileSize > 0) payload['size'] = fileSize;
    if (targetDeviceId != null) payload['targetDeviceId'] = targetDeviceId;
    if (webrtcSentMtimeMs != null) {
      payload['lastModifiedMs'] = webrtcSentMtimeMs;
    }
    unawaited(() async {
      try {
        final ap = await _accountPartForThreadKey();
        final wtk = targetDeviceId != null && targetDeviceId.isNotEmpty
            ? threadKeyOneToOne(ap, _deviceId, targetDeviceId)
            : (await _outboundThreadKeyForSelection()).threadKey;
        await sendMessage({
          'type': 'file',
          'payload': payload,
          'fromDeviceId': _deviceId,
          'threadKey': wtk,
          if (targetDeviceId != null) 'toDeviceId': targetDeviceId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        logChat.warning('WebRTC sendMessage persist failed: $e');
      }
    }());
    ChatMessageDao.instance.markSynced('local_$localId');
    logChat.info('WebRTC file sent: $fileName');
  }

  void _onWebRTCFileFailed(String fileId, String fileName, String error) {
    // Wrap the async impl so any unexpected throw doesn't vanish into the
    // microtask queue — the original sync handler couldn't throw.
    unawaited(
      _onWebRTCFileFailedAsync(fileId, fileName, error).catchError((
        Object e,
        StackTrace st,
      ) {
        logChat.warning(
          '_onWebRTCFileFailedAsync unhandled: $fileName error=$error: $e\n$st',
        );
      }),
    );
  }

  Future<void> _onWebRTCFileFailedAsync(
    String fileId,
    String fileName,
    String error,
  ) async {
    // Peek (don't remove yet) so the LAN reverse-pull fallback can route a
    // recovery through _onWebRTCFileSent, which expects the per-file maps
    // to still be populated.
    final localId = _webrtcFileLocalIdMap[fileId];
    final wasDownloading = localId == null
        ? false
        : _localMessageStatus[localId] == 'downloading';

    // Reverse-pull fallback only makes sense on the SEND side. If this was
    // an inbound transfer that failed (`downloading` state), skip the
    // fallback and go straight to failure handling.
    if (localId != null && mounted && !wasDownloading) {
      final retry = _retryInfoByLocalId[localId];
      final targetDeviceId = retry?.webrtcTargetDeviceId ?? '';
      final filePath = retry?.filePath;
      final fileSize = _webrtcFileSizeMap[fileId] ?? retry?.fileSize ?? 0;
      final mtimeMs = _webrtcFileMtimeMsMap[fileId];
      if (targetDeviceId.isNotEmpty &&
          filePath != null &&
          filePath.isNotEmpty &&
          fileSize > 0) {
        try {
          final pulled = await _tryWebRTCToLanReversePullFallback(
            fileId: fileId,
            localId: localId,
            fileName: fileName,
            fileSize: fileSize,
            filePath: filePath,
            lastModifiedMs: mtimeMs,
            targetDeviceId: targetDeviceId,
          );
          if (pulled) {
            // _onWebRTCFileSent already cleaned everything up and emitted
            // the success-side analytics + `file` echo. Done.
            logChat.info(
              'WebRTC file recovered via LAN reverse-pull: $fileName',
            );
            return;
          }
        } catch (e, st) {
          logChat.warning(
            'WebRTC → LAN reverse-pull fallback threw for $fileName: $e\n$st',
          );
        }
      }
    }

    // Original failure path: tear down per-file bookkeeping and surface the
    // failure to the user.
    _webrtcFileLocalIdMap.remove(fileId);
    if (localId != null) _webrtcLocalIdToFileIdMap.remove(localId);
    _webrtcFileNameMap.remove(fileId);
    final rtcFailSize = _webrtcFileSizeMap.remove(fileId);
    _webrtcFileMtimeMsMap.remove(fileId);
    final transferId = _webrtcTransferIdMap.remove(fileId);
    if (transferId != null) {
      TransferStateManager.instance.markStatus(transferId, 'failed');
      Analytics.track(AnalyticsEvents.fileSendOutcome, {
        'channel': 'webrtc',
        'status': 'failed',
        'size_bucket': Analytics.sizeBucket(rtcFailSize ?? 0),
      });
    }
    if (localId == null || !mounted) return;
    final failText = wasDownloading
        ? _l10n.chatTransferReceiveFailedNamed(fileName)
        : _l10n.chatTransferSendFailedNamed(fileName);
    _speedTrackers.remove('local_$localId');
    _transferStartTimes.remove('local_$localId');
    _updateSendingMessage(localId, failText);
    setState(() {
      _setMessageStatus(localId, 'failed');
      _localMessageProgress.remove(localId);
    });
    logChat.warning('WebRTC file failed: $fileName error=$error');
  }

  void _onWebRTCFileCancelled(String fileId, String fileName) {
    final localId = _webrtcFileLocalIdMap.remove(fileId);
    if (localId != null) _webrtcLocalIdToFileIdMap.remove(localId);
    _webrtcFileNameMap.remove(fileId);
    _webrtcFileSizeMap.remove(fileId);
    _webrtcFileMtimeMsMap.remove(fileId);
    final transferId = _webrtcTransferIdMap.remove(fileId);
    if (transferId != null) {
      // Mark `paused` so cold-start resume restores a "Continue" affordance
      // instead of treating the cancel as terminal.
      TransferStateManager.instance.markStatus(transferId, 'paused');
    }
    if (localId == null || !mounted) return;
    _speedTrackers.remove('local_$localId');
    _transferStartTimes.remove('local_$localId');
    _updateSendingMessage(localId, _l10n.chatTransferCancelledNamed(fileName));
    setState(() {
      _setMessageStatus(localId, 'cancelled');
      _localMessageProgress.remove(localId);
    });
    logChat.info('WebRTC file cancelled: $fileName');
  }

  void _onWebRTCFileReceived(String fileId, String fileName, String filePath) {
    final localId = _webrtcFileLocalIdMap.remove(fileId);
    if (localId != null) _webrtcLocalIdToFileIdMap.remove(localId);
    _webrtcFileNameMap.remove(fileId);
    final fileSize = _webrtcFileSizeMap.remove(fileId);
    _webrtcFileMtimeMsMap.remove(fileId);
    // The file is stored under <root>/webrtc_recv_<fileId>/ on the receiver
    // side. Persist that to the index even if there's no matching local
    // outbound message (e.g. the receiver has no `local_<localId>` row).
    final receiverMsgId = 'webrtc_recv_$fileId';
    unawaited(() async {
      try {
        final uid = await _getCurrentUserId();
        final tk = await _threadKeyForCurrentSelection();
        final exportOk =
            await ReceivedFileIndexPipeline.instance.upsertAndExportInline(
          messageId: receiverMsgId,
          upsert: () => ReceivedFileDao.instance.upsert(
            messageId: receiverMsgId,
            absPath: filePath,
            cachePath: filePath,
            exportStatus: ExportStatus.pending,
            userId: uid,
            threadKey: tk,
            protocol: 'webrtc',
            size: fileSize,
          ),
        );
        if (!exportOk) {
          logChat.warning(
            'WebRTC receive export failed for $fileName ($receiverMsgId)',
          );
        }
      } catch (e) {
        logChat.warning('WebRTC receive finalize failed: $e');
      }
    }());
    if (localId == null || !mounted) return;
    _speedTrackers.remove('local_$localId');
    _transferStartTimes.remove('local_$localId');

    _fileFileNameByMessageId['local_$localId'] = fileName;
    _fileMetaByMessageId['local_$localId'] = _FileMeta(
      fileName: fileName,
      size: fileSize,
      transferType: 'webrtc',
      localPath: filePath,
    );
    setState(() {
      _setMessageStatus(localId, 'sent');
      _localMessageProgress.remove(localId);
    });
    _updateSendingMessage(localId, '$fileName (WebRTC)');
    ChatMessageDao.instance.markSynced('local_$localId');
    logChat.info('WebRTC file received: $fileName -> $filePath');
  }

  void _updateSendingMessage(String localId, String text) {
    final msgId = 'local_$localId';
    final existing = _findMessageById(msgId);
    if (existing != null) {
      final newMsg = Message.text(
        id: msgId,
        authorId: existing.authorId,
        createdAt: existing.createdAt,
        text: text,
      );
      _chatController.updateMessage(existing, newMsg);
    }
  }

  Future<void> _pullFileFromOffer(
    String pullUrl,
    String fileName, {
    int fileSize = 0,
    String? senderLocalId,
    String? senderDeviceId,
  }) async {
    logChat.info(
      '_pullFileFromOffer pullUrl=$pullUrl fileName=$fileName fileSize=$fileSize',
    );
    // Use the sender's localId as the stable per-transfer id when available
    // (matches what the worker will write into received_files + the
    // Centrifugo `file` publication's payload.localId). Fall back to a fresh
    // UUID so same-named pulls without localId still get distinct ids.
    final msgId = (senderLocalId != null && senderLocalId.isNotEmpty)
        ? 'lan_recv_pull_$senderLocalId'
        : 'lan_recv_pull_${const Uuid().v4()}';
    if (senderLocalId != null && senderLocalId.isNotEmpty) {
      _lanRecvLocalIds.add(senderLocalId);
      _lanLocalIdToMessageId[senderLocalId] = msgId;
      if (senderDeviceId != null && senderDeviceId.isNotEmpty) {
        _lanPullSenderDeviceIdByLocalId[senderLocalId] = senderDeviceId;
      }
    }
    final recvTracker = SpeedTracker();
    _speedTrackers[msgId] = recvTracker;
    _transferStartTimes[msgId] = DateTime.now();
    final cancelToken = CancelToken();
    _activeDownloads[msgId] = cancelToken;
    final receiveDir = await FileStore.getReceiveDir();
    final now = DateTime.now();
    final initialText = _l10n.chatTransferReceivingPct(fileName, 0);
    // On retry (same senderLocalId) the bubble may already exist with a
    // "paused" / "已取消" text from the previous attempt. Reuse it instead of
    // calling `_chatController.insertMessage` which would silently append a
    // duplicate in release builds (InMemoryChatController only asserts in
    // debug). Either way `currentMsg` ends up pointing at the live entry.
    Message currentMsg;
    final existing = _findMessageById(msgId);
    if (existing != null) {
      currentMsg = Message.text(
        id: msgId,
        authorId: existing.authorId,
        createdAt: existing.createdAt,
        text: initialText,
      );
      _chatController.updateMessage(existing, currentMsg);
    } else {
      currentMsg = Message.text(
        id: msgId,
        authorId: 'system',
        createdAt: now,
        text: initialText,
      );
      _chatController.insertMessage(currentMsg);
      _scrollToBottom();
    }
    _fileMetaByMessageId[msgId] = _FileMeta(
      fileName: fileName,
      size: fileSize > 0 ? fileSize : null,
      transferType: 'lan',
    );

    // Path tracking for session-local resume. If a previous attempt for the
    // same senderLocalId was interrupted, reuse its partial path so the next
    // pull issues a Range request and appends. Otherwise we'll learn the
    // chosen path from `onFilePathReady` and remember it for future retries.
    String? trackedPath;
    if (senderLocalId != null && senderLocalId.isNotEmpty) {
      trackedPath = _lanPullPartialBySenderLocalId[senderLocalId]?.path;
    }

    try {
      final pullResult = await pullFileHttp(
        downloadUrl: pullUrl,
        savePath: receiveDir,
        senderLocalId: senderLocalId,
        cancelToken: cancelToken,
        existingFilePath: trackedPath,
        onFilePathReady: (p) {
          trackedPath = p;
          if (senderLocalId != null && senderLocalId.isNotEmpty) {
            _lanPullPartialBySenderLocalId[senderLocalId] = _PullPartial(
              path: p,
              size: fileSize > 0 ? fileSize : null,
            );
          }
        },
        onProgress: (name, received, total) {
          if (cancelToken.isCancelled) return;
          if (!mounted) return;
          recvTracker.update(received);
          final pct = total > 0
              ? (received * 100 / total).round().clamp(0, 100)
              : 0;
          final newMsg = Message.text(
            id: msgId,
            authorId: 'system',
            createdAt: now,
            text: _l10n.chatTransferReceivingPct(name, pct),
          );
          _chatController.updateMessage(currentMsg, newMsg);
          currentMsg = newMsg;
        },
      );
      final finalPath = pullResult.filePath;
      if (cancelToken.isCancelled) {
        // Receiver-side user cancel: drop the partial file AND forget the
        // partial path so a follow-up "send again" from the peer doesn't
        // accidentally resume from stale bytes.
        try {
          final cancelledFile = File(finalPath);
          if (cancelledFile.existsSync()) {
            cancelledFile.deleteSync();
          }
        } catch (e) {
          logChat.fine('_pullFileFromOffer delete cancelled file failed: $e');
        }
        if (senderLocalId != null && senderLocalId.isNotEmpty) {
          _lanPullPartialBySenderLocalId.remove(senderLocalId);
        }
        return;
      }
      await applyReceivedFileTimestamps(finalPath, pullResult.lastModifiedMs);
      if (senderLocalId != null && senderLocalId.isNotEmpty) {
        _lanPullPartialBySenderLocalId.remove(senderLocalId);
      }

      _speedTrackers.remove(msgId);
      _transferStartTimes.remove(msgId);
      if (!mounted) return;
      final file = File(finalPath);
      logChat.info('_pullFileFromOffer saved ${file.path}');
      _fileMetaByMessageId[msgId] = _FileMeta(
        fileName: fileName,
        size: fileSize > 0 ? fileSize : null,
        transferType: 'lan',
        localPath: finalPath,
      );
      var exportOk = false;
      try {
        final uid = await _getCurrentUserId();
        final tk = await _threadKeyForCurrentSelection();
        exportOk = await ReceivedFileIndexPipeline.instance.upsertAndExportInline(
          messageId: msgId,
          upsert: () => ReceivedFileDao.instance.upsert(
            messageId: msgId,
            absPath: finalPath,
            cachePath: finalPath,
            exportStatus: ExportStatus.pending,
            userId: uid,
            threadKey: tk,
            protocol: 'lan',
            size: fileSize > 0 ? fileSize : null,
          ),
        );
      } catch (e) {
        logChat.warning('_pullFileFromOffer finalize failed: $e');
      }
      if (!mounted) return;
      _notifyReceiveSavedToFolder(
        messageId: msgId,
        fileName: fileName,
        exportOk: exportOk,
        chatMessage: currentMsg,
      );
    } catch (e) {
      logChat.warning('_pullFileFromOffer failed: $e');
      _speedTrackers.remove(msgId);
      _transferStartTimes.remove(msgId);
      final wasReceiverCancel = cancelToken.isCancelled;
      // Keep the partial file on disk for sender-cancel / network drops so a
      // retry can Range-resume from `_lanPullPartialBySenderLocalId`. On
      // explicit receiver-side cancel we drop both the partial bytes and the
      // map entry — see comment in the success path above.
      if (wasReceiverCancel) {
        if (trackedPath != null) {
          try {
            final f = File(trackedPath!);
            if (f.existsSync()) f.deleteSync();
          } catch (err) {
            logChat.fine(
              '_pullFileFromOffer delete receiver-cancelled partial failed: $err',
            );
          }
        }
        if (senderLocalId != null && senderLocalId.isNotEmpty) {
          _lanPullPartialBySenderLocalId.remove(senderLocalId);
        }
      }
      if (mounted) {
        // Reuse the "已取消 / Cancelled" copy regardless of who tore the stream
        // down. For a receiver-side cancel it's literally correct; for a
        // sender-side cancel or a transient network drop we leave the partial
        // bytes on disk and let the sender's retry resume via Range, so the
        // bubble's "paused" framing matches the actual semantic better than
        // "接收失败" (which would suggest the data is gone).
        final failMsg = Message.text(
          id: msgId,
          authorId: 'system',
          createdAt: now,
          text: _l10n.chatTransferCancelledNamed(fileName),
        );
        _chatController.updateMessage(currentMsg, failMsg);
      }
    } finally {
      _activeDownloads.remove(msgId);
    }
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Resolve the actual on-disk path for a chat file message, with a
  /// four-tier fallback so `localPath`-stale or "the user changed/moved the
  /// receive root" cases still find the file:
  ///
  ///   1. [candidate] (typically `fileMeta.localPath`) if it exists.
  ///   2. Direct hit by [messageId] in the `received_files` index.
  ///   3. Index lookup by `(fileName, size)` — recovers the case where the
  ///      server-pushed message id differs from the locally-derived
  ///      `lan_recv_*` / `webrtc_recv_*` id.
  ///   4. Scan `<receiveRoot>/<messageId>/` directly (covers freshly-moved
  ///      directories that the index hasn't reconciled yet).
  ///
  /// On a successful match that is **not** the [candidate], the index is
  /// upserted so the next lookup is a one-step hit.
  Future<String?> _resolveLocalPathForOpen(
    String messageId,
    _FileMeta meta, {
    String? candidate,
  }) async {
    if (candidate != null &&
        candidate.isNotEmpty &&
        File(candidate).existsSync()) {
      return candidate;
    }

    try {
      final hit = await ReceivedFileDao.instance.getByMessageId(messageId);
      if (hit != null) {
        final readable = hit.readablePath;
        if (File(readable).existsSync()) {
          return readable;
        }
      }

      if (meta.fileName.isNotEmpty) {
        // Read-only fallback: locate a same-named (and same-sized) file from
        // the index just for display. We intentionally do NOT upsert that
        // path under `messageId` — every received message must point at its
        // own on-disk copy, otherwise re-sending a same-named file would
        // make all such messages collapse onto the most recent file.
        final hits = await ReceivedFileDao.instance.findByNameAndSize(
          fileName: meta.fileName,
          size: meta.size,
        );
        for (final r in hits) {
          final readable = r.readablePath;
          if (File(readable).existsSync()) {
            return readable;
          }
        }
      }

      final root = await FileStore.getCacheDir();
      final dir = Directory(p.join(root, messageId));
      if (await dir.exists()) {
        for (final e in dir.listSync(followLinks: false)) {
          if (e is File && !p.basename(e.path).startsWith('.')) {
            try {
              await ReceivedFileDao.instance.upsert(
                messageId: messageId,
                absPath: e.path,
                protocol: inferProtocolFromMessageId(messageId),
              );
            } catch (_) {}
            return e.path;
          }
        }
      }
    } catch (e) {
      logChat.warning('_resolveLocalPathForOpen failed: $e');
    }
    return null;
  }

  /// Build a [ReceivedFileInfo] from the local meta + resolved path. Pulls
  /// `protocol` / `s3Key` / `threadKey` / `fromDeviceId` from the index when
  /// available, and falls back to message-id heuristics otherwise.
  Future<ReceivedFileInfo> _buildReceivedFileInfo(
    String messageId,
    _FileMeta meta,
    String resolvedPath,
  ) async {
    ReceivedFileRecord? indexHit;
    try {
      indexHit = await ReceivedFileDao.instance.getByMessageId(messageId);
    } catch (_) {}
    final f = File(resolvedPath);
    final size =
        meta.size ?? indexHit?.size ?? (f.existsSync() ? f.lengthSync() : 0);
    final modified =
        indexHit?.mtime ??
        (f.existsSync() ? f.lastModifiedSync() : DateTime.now());
    final createdAt = indexHit?.createdAt ?? modified;
    return ReceivedFileInfo(
      messageId: messageId,
      path: resolvedPath,
      displayName: meta.fileName,
      protocol: indexHit?.protocol ?? inferProtocolFromMessageId(messageId),
      size: size,
      modified: modified,
      createdAt: createdAt,
      category: getFileCategory(meta.fileName),
      threadKey: indexHit?.threadKey,
      s3Key: meta.s3Key ?? indexHit?.s3Key,
      fromDeviceId: indexHit?.fromDeviceId,
    );
  }

  ReceivedFilePreviewCallbacks _previewCallbacksFor(String messageId) {
    return ReceivedFilePreviewCallbacks(
      onEnterMultiSelect: () {
        setState(() {
          _isSelectionMode = true;
          _selectedMessages.add(messageId);
        });
      },
      onAddToPending: (file) => _addPendingFiles([file]),
    );
  }

  /// Tap-to-open entry shared by chat bubbles and their hover/long-press
  /// menus. Resolves a local path with [_resolveLocalPathForOpen], hands off
  /// to [openReceivedFile] (the same code path as the file manager) on a
  /// hit. Cloud-only files must be downloaded first (no download-and-open).
  Future<void> _openFileFromBubble({
    required String messageId,
    required _FileMeta meta,
    String? fallbackKey,
  }) async {
    final resolved = await _resolveLocalPathForOpen(
      messageId,
      meta,
      candidate: meta.localPath,
    );
    if (resolved != null) {
      meta.localPath = resolved;
      if (!mounted) return;
      final info = await _buildReceivedFileInfo(messageId, meta, resolved);
      if (!mounted) return;
      await openReceivedFile(
        context,
        info,
        callbacks: _previewCallbacksFor(messageId),
      );
      return;
    }
    if (fallbackKey != null && fallbackKey.isNotEmpty) {
      logChat.info('chat_screen file tap fallback download key=$fallbackKey');
      await _downloadS3File(
        fallbackKey,
        messageId: messageId,
        fileName: meta.fileName,
      );
      return;
    }
    if (mounted) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).chatFileMissingDeleted,
      );
    }
  }

  /// Convenience used by hover/menu actions that only have a `_FileMeta` to
  /// hand. Prefer [_openFileFromBubble] when a fallback s3 key is available.
  Future<void> _tryOpenLocalFilePath(
    String path, {
    String? messageId,
    _FileMeta? meta,
  }) async {
    if (messageId != null && meta != null) {
      await _openFileFromBubble(messageId: messageId, meta: meta);
      return;
    }
    final f = File(path);
    if (!f.existsSync()) {
      if (mounted) {
        AppToast.show(context, message: _l10n.chatScreenFileMissing);
      }
      return;
    }
    final fakeMeta = _FileMeta(fileName: p.basename(path), localPath: path);
    final info = await _buildReceivedFileInfo(
      messageId ?? path,
      fakeMeta,
      path,
    );
    if (!mounted) return;
    await openReceivedFile(
      context,
      info,
      callbacks: _previewCallbacksFor(messageId ?? path),
    );
  }

  void _onMessageTap(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    if (message is! TextMessage) return;
    final localId = message.id.startsWith('local_')
        ? message.id.substring(6)
        : null;
    if (localId != null && _activeTransfers.containsKey(localId)) {
      // Don't cancel on tap — the cancel button in the progress bubble
      // is the intended way to cancel. Tapping the message should be a no-op
      // while a transfer is in progress.
      return;
    }
    if (_activeLanReceives.containsKey(message.id)) {
      return;
    }
    final fileMeta = _fileMetaByMessageId[message.id];
    final key = _fileKeyByMessageId[message.id];
    final fileName = _fileFileNameByMessageId[message.id];

    if (fileMeta != null) {
      final localPath = fileMeta.localPath;
      final fileExists = localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();
      if (fileExists) {
        unawaited(
          _openFileFromBubble(
            messageId: message.id,
            meta: fileMeta,
            fallbackKey: key,
          ),
        );
      } else if (key != null && key.isNotEmpty) {
        unawaited(
          _downloadS3File(key, messageId: message.id, fileName: fileName),
        );
      } else {
        unawaited(
          _openFileFromBubble(
            messageId: message.id,
            meta: fileMeta,
            fallbackKey: key,
          ),
        );
      }
      return;
    }
    if (key == null || key.isEmpty) return;
    logChat.info('chat_screen download tap key=$key');
    unawaited(_downloadS3File(key, messageId: message.id, fileName: fileName));
  }

  Future<void> _exportChatFile(String path, String fileName) async {
    await runSaveFileAs(
      context: context,
      l10n: AppLocalizations.of(context),
      sourcePath: path,
      fileName: fileName,
    );
  }

  String _exportActionLabel(AppLocalizations loc) => saveAsActionLabel(loc);

  void _showMessageActions(TextMessage message, bool isSentByMe) {
    _composerKey.currentState?.unfocus();
    final colors = context.appColors;
    final fileMeta = _fileMetaByMessageId[message.id];
    final localPath = fileMeta?.localPath;
    final fileExists = localPath != null && File(localPath).existsSync();
    final isFileMessage = fileMeta != null;
    final s3Key = _fileKeyByMessageId[message.id];
    final category = isFileMessage ? getFileCategory(fileMeta.fileName) : null;
    final canSaveToGallery =
        _isMobile &&
        fileExists &&
        category != null &&
        (category == FileCategory.image || category == FileCategory.video);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx);
        return SafeArea(
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
              ListTile(
                leading: const Icon(LucideIcons.squareCheck),
                title: Text(loc.chatMenuMultiSelect),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectionMode = true;
                    _selectedMessages.add(message.id);
                  });
                },
              ),
              Divider(height: 1, color: colors.border),
              if (isFileMessage &&
                  localPath != null &&
                  localPath.isNotEmpty &&
                  !fileExists) ...[
                ListTile(
                  leading: Icon(LucideIcons.fileX, color: colors.textTertiary),
                  title: Text(loc.chatMenuLocalFileUnavailable),
                  subtitle: Text(loc.chatMenuLocalFileUnavailableSubtitle),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
              if (isFileMessage && fileExists) ...[
                ListTile(
                  leading: const Icon(LucideIcons.externalLink),
                  title: Text(loc.chatMenuOpen),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(
                      _openFileFromBubble(
                        messageId: message.id,
                        meta: fileMeta,
                        fallbackKey: s3Key,
                      ),
                    );
                  },
                ),
                if (_isDesktopPlatform)
                  ListTile(
                    leading: const Icon(LucideIcons.folderOpen),
                    title: Text(loc.fmRevealInFolder),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(revealFileInFolder(localPath));
                    },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.plus),
                  title: Text(loc.chatMenuAddToPending),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addFileMessageToPending(fileMeta, localPath);
                  },
                ),
                if (_isDesktopPlatform)
                  ListTile(
                    leading: const Icon(LucideIcons.copy),
                    title: Text(loc.chatMenuCopyFile),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(_copyChatFileToClipboard(localPath));
                    },
                  ),
                if (_isMobile)
                  ListTile(
                    leading: const Icon(LucideIcons.share2),
                    title: Text(loc.chatMenuShare),
                    onTap: () {
                      Navigator.pop(ctx);
                      Share.shareXFiles([XFile(localPath)]);
                    },
                  ),
                if (FileExportService.isSupported)
                  ListTile(
                    leading: const Icon(LucideIcons.download),
                    title: Text(_exportActionLabel(loc)),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(_exportChatFile(localPath, fileMeta.fileName));
                    },
                  ),
                if (canSaveToGallery)
                  ListTile(
                    leading: const Icon(LucideIcons.download),
                    title: Text(loc.chatMenuSaveToGallery),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        final result = await SaverGallery.saveFile(
                          filePath: localPath,
                          fileName: fileMeta.fileName,
                          androidRelativePath:
                              'Pictures/${loc.appGallerySubfolder}',
                          skipIfExists: false,
                        );
                        if (!mounted) return;
                        AppToast.show(
                          context,
                          message: result.isSuccess
                              ? loc.chatGallerySaved
                              : loc.chatGallerySaveFailed,
                        );
                      } catch (_) {
                        if (!mounted) return;
                        AppToast.show(
                          context,
                          message: loc.chatGallerySaveFailed,
                        );
                      }
                    },
                  ),
              ],
              if (isFileMessage &&
                  !fileExists &&
                  s3Key != null &&
                  s3Key.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(LucideIcons.download),
                  title: Text(loc.chatMenuDownloadFromCloud),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(
                      _downloadS3File(
                        s3Key,
                        messageId: message.id,
                        fileName: _fileFileNameByMessageId[message.id],
                      ),
                    );
                  },
                ),
              ],
              if (!isFileMessage) ...[
                ListTile(
                  leading: const Icon(LucideIcons.copy),
                  title: Text(loc.chatMenuCopyText),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: message.text));
                    AppToast.show(context, message: loc.chatCopied);
                  },
                ),
                if (_isMobile)
                  ListTile(
                    leading: const Icon(LucideIcons.textCursorInput),
                    title: Text(loc.chatMenuSelectText),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSelectableTextDialog(message.text);
                    },
                  ),
              ],
              ListTile(
                leading: Icon(LucideIcons.trash2, color: colors.danger),
                title: Text(
                  loc.chatMenuDeleteMessage,
                  style: TextStyle(color: colors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(message);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        );
      },
    );
  }

  void _showSelectableTextDialog(String text) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        titlePadding: AppDialog.titlePadding,
        contentPadding: AppDialog.contentPadding,
        constraints: AppDialog.contentConstraints,
        title: Row(
          children: [
            Expanded(
              child: Text(
                loc.chatSelectTextTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => Navigator.pop(ctx),
              style: IconButton.styleFrom(
                foregroundColor: colors.textTertiary,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        content: SelectableText(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(TextMessage message) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: loc.chatDeleteMessageTitle,
      content: loc.chatDeleteMessageBody,
      confirmLabel: loc.chatDeleteMessageConfirm,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;

    // Delete associated disk file and partial cache.
    final meta = _fileMetaByMessageId[message.id];
    if (meta != null) {
      if (meta.localPath != null) {
        try {
          final f = File(meta.localPath!);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      // Also remove the partial cache file for this specific transfer.
      if (meta.size != null && meta.size! > 0) {
        try {
          final fileId = makeFileId(
            meta.fileName,
            meta.size!,
            localId: senderLocalIdFromRecvMessageId(message.id),
          );
          final receiveDir = await FileStore.getReceiveDir();
          final partialFile = File('$receiveDir/.lan_partial_$fileId');
          if (await partialFile.exists()) await partialFile.delete();
        } catch (_) {}
      }
    }
    _fileMetaByMessageId.remove(message.id);

    final existing = _findMessageById(message.id);
    if (existing != null) {
      _chatController.removeMessage(existing);
    }

    await ChatMessageDao.instance.deleteById(message.id);

    final serverId = _serverIdByMessageId[message.id];
    if (serverId != null) {
      try {
        await deleteMessage(serverId);
      } catch (e) {
        logChat.warning('deleteMessage from server failed: $e');
      }
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessages.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final allMessageIds = _chatController.messages.map((m) => m.id).toSet();
      if (_selectedMessages.length == allMessageIds.length) {
        _selectedMessages.clear();
      } else {
        _selectedMessages.clear();
        _selectedMessages.addAll(allMessageIds);
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;

    final count = _selectedMessages.length;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: _l10n.chatScreenDeleteMessagesTitle,
      content: _l10n.chatScreenDeleteMessagesBody(count),
      confirmLabel: _l10n.chatScreenConfirmDeleteLabel,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;

    final messagesToDelete = List<String>.from(_selectedMessages);

    for (final messageId in messagesToDelete) {
      final message = _findMessageById(messageId);
      if (message == null || message is! TextMessage) continue;

      // Delete associated disk file and partial cache.
      final meta = _fileMetaByMessageId[messageId];
      if (meta != null) {
        if (meta.localPath != null) {
          try {
            final f = File(meta.localPath!);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
        // Also remove the partial cache file for this specific transfer.
        if (meta.size != null && meta.size! > 0) {
          try {
            final fileId = makeFileId(
              meta.fileName,
              meta.size!,
              localId: senderLocalIdFromRecvMessageId(messageId),
            );
            final receiveDir = await FileStore.getReceiveDir();
            final partialFile = File('$receiveDir/.lan_partial_$fileId');
            if (await partialFile.exists()) await partialFile.delete();
          } catch (_) {}
        }
      }
      _fileMetaByMessageId.remove(messageId);

      final existing = _findMessageById(messageId);
      if (existing != null) {
        _chatController.removeMessage(existing);
      }

      await ChatMessageDao.instance.deleteById(messageId);

      final serverId = _serverIdByMessageId[messageId];
      if (serverId != null) {
        try {
          await deleteMessage(serverId);
        } catch (e) {
          logChat.warning('deleteMessage from server failed: $e');
        }
      }
    }

    // Clear selection and exit selection mode
    _exitSelectionMode();
  }

  /// Downloads an inbound S3 object to the receive directory. Never opens the
  /// file afterward — use [_openFileFromBubble] when the user explicitly opens.
  void _maybeAutoDownloadIncomingS3File({
    required Message message,
    required Map payload,
    required String fromDeviceId,
  }) {
    if (fromDeviceId == _deviceId) return;
    if (transferTypeFromFilePayload(payload) != 's3') return;
    final key = payload['key']?.toString();
    if (key == null || key.isEmpty) return;
    if (_activeDownloads.containsKey(message.id)) return;
    final meta = _fileMetaByMessageId[message.id];
    final localPath = meta?.localPath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return;
    }
    final fileName =
        payload['fileName']?.toString() ??
        _fileFileNameByMessageId[message.id] ??
        meta?.fileName;
    final mtimeMs = parseMtimeMs(payload['lastModifiedMs']);
    unawaited(
      _downloadS3File(
        key,
        messageId: message.id,
        fileName: fileName,
        lastModifiedMs: mtimeMs ?? meta?.lastModifiedMs,
      ),
    );
  }

  Future<void> _downloadS3File(
    String key, {
    required String messageId,
    String? fileName,
    int? lastModifiedMs,
  }) async {
    logChat.info('chat_screen _downloadS3File start key=$key');
    final displayName = fileName ?? 'download';
    Message? currentMsg = _findMessageById(messageId);
    if (currentMsg != null && mounted) {
      final updMsg = Message.text(
        id: messageId,
        authorId: currentMsg.authorId,
        createdAt: currentMsg.createdAt,
        text: _l10n.chatTransferReceivingPct(displayName, 0),
      );
      _chatController.updateMessage(currentMsg, updMsg);
      currentMsg = updMsg;
    }
    final cancelToken = CancelToken();
    _activeDownloads[messageId] = cancelToken;
    try {
      final savePath = await FileStore.buildReceivePath(messageId, displayName);
      final dlTracker = SpeedTracker();
      _speedTrackers[messageId] = dlTracker;
      _transferStartTimes[messageId] = DateTime.now();

      final result = await _cloudTransfer.download(
        key: key,
        savePath: savePath,
        cancelToken: cancelToken,
        lastModifiedMs:
            lastModifiedMs ?? _fileMetaByMessageId[messageId]?.lastModifiedMs,
        onProgress: (received, total) {
          dlTracker.update(received);
          final cur = currentMsg;
          if (mounted && total > 0 && cur != null) {
            final pct = (received * 100 / total).round().clamp(0, 100);
            final newMsg = Message.text(
              id: messageId,
              authorId: cur.authorId,
              createdAt: cur.createdAt,
              text: _l10n.chatTransferReceivingPct(displayName, pct),
            );
            _chatController.updateMessage(cur, newMsg);
            currentMsg = newMsg;
          }
        },
      );

      _speedTrackers.remove(messageId);
      _transferStartTimes.remove(messageId);
      logChat.info(
        'chat_screen _downloadS3File wrote file path=${result.filePath} bytes=${result.totalBytes}',
      );
      final existingMeta = _fileMetaByMessageId[messageId];
      if (existingMeta != null) {
        existingMeta.localPath = result.filePath;
        if (existingMeta.size == null || existingMeta.size == 0) {
          existingMeta.size = result.totalBytes;
        }
      }
      // Persist to received_files index so reopening the chat resolves a
      // local path without round-tripping through S3 again.
      var exportOk = false;
      try {
        final uid = await _getCurrentUserId();
        final tk = await _threadKeyForCurrentSelection();
        exportOk =
            await ReceivedFileIndexPipeline.instance.upsertAndExportInline(
          messageId: messageId,
          upsert: () => ReceivedFileDao.instance.upsert(
            messageId: messageId,
            absPath: result.filePath,
            cachePath: result.filePath,
            exportStatus: ExportStatus.pending,
            userId: uid,
            threadKey: tk,
            protocol: 's3',
            s3Key: key,
            size: result.totalBytes,
          ),
        );
      } catch (e) {
        logChat.warning('chat_screen _downloadS3File finalize failed: $e');
      }
      final curDone = currentMsg;
      if (curDone != null && mounted) {
        final doneMsg = Message.text(
          id: messageId,
          authorId: curDone.authorId,
          createdAt: curDone.createdAt,
          text: exportOk
              ? '$displayName (${formatSize(result.totalBytes)})'
              : '${_l10n.fileExportFailed}: $displayName',
        );
        _chatController.updateMessage(curDone, doneMsg);
      }
      if (!mounted) return;
      AppToast.show(
        context,
        message: exportOk
            ? _l10n.fileExportSavedToDownloads(displayName)
            : _l10n.fileExportFailed,
      );
    } catch (e, st) {
      logChat.warning('chat_screen _downloadS3File error: $e');
      logChat.info('chat_screen _downloadS3File stackTrace: $st');
      final curErr = currentMsg;
      // Distinguish user cancel from genuine failure so the bubble text and
      // toast match the user's intent.
      final wasCancelled = cancelToken.isCancelled;
      if (curErr != null && mounted) {
        final errMsg = Message.text(
          id: messageId,
          authorId: curErr.authorId,
          createdAt: curErr.createdAt,
          text: wasCancelled
              ? _l10n.chatTransferCancelledNamed(displayName)
              : _l10n.chatTransferReceiveFailedNamed(displayName),
        );
        _chatController.updateMessage(curErr, errMsg);
      }
      if (mounted && !wasCancelled) {
        AppToast.show(
          context,
          message: _l10n.chatScreenReceiveFailedWithError('$e'),
        );
      }
    } finally {
      _activeDownloads.remove(messageId);
      _speedTrackers.remove(messageId);
      _transferStartTimes.remove(messageId);
    }
  }

  @override
  void dispose() {
    _initGeneration++;
    unawaited(_markPresenceOffline('dispose'));
    WidgetsBinding.instance.removeObserver(this);
    _cancelPresenceRefreshTimer();
    _newPeerProbeDebounce?.cancel();
    _dirtyProbeDebounce?.cancel();
    _lanLostPeerSub?.cancel();
    _myDevicesListSub?.close();
    _nearbyDevicesListSub?.close();
    _pendingProbeByPeer.clear();
    _dirtyProbeDeviceIds.clear();
    _probeRunningPeers.clear();
    _lastProbeRequestAt.clear();
    _probeRequestSeqByPeer.clear();
    _iosLanRetryTimer?.cancel();
    FileStore.removeReceiveDirChangedListener(_onReceiveDirChanged);
    for (final token in _activeTransfers.values) {
      token.cancel();
    }
    _activeTransfers.clear();
    _activeLanReceives.clear();
    _webrtcManager.closeAll();
    _lanReceiver?.stop();
    _connectivitySub?.cancel();
    _authSub?.close();
    _selectedDeviceSub?.close();
    _connectionOrchestratorSub?.close();
    _chatController.dispose();
    _chatScrollController.dispose();
    _client?.disconnect();
    if (_isDesktopPlatform) {
      DesktopFileDropDispatcher.instance.unregister(this);
    }
    if (ShareReceiveService.instance.onPendingShareReady == _onPendingShareReady) {
      ShareReceiveService.instance.onPendingShareReady = null;
    }
    super.dispose();
  }

  Widget _buildMainLayout({
    required bool isOffline,
    required bool isAuthOffline,
    required bool mobileHomeTabs,
    required ChatColors colors,
    required bool isDark,
  }) {
    return MainLayout(
      connected: _connected,
      deviceName: _deviceName,
      myDeviceId: _deviceId.isEmpty ? null : _deviceId,
      statusCheckDone: _statusCheckDone,
      isLoggedIn: !isAuthOffline,
      compactDeviceListChrome: mobileHomeTabs,
      authSessionPhase: ref.watch(authSessionPhaseProvider),
      onLoginTap: () {
        _composerKey.currentState?.unfocus();
        Navigator.pushNamed(context, '/login');
      },
      onRefresh: _manualRefreshDevices,
      onShowSettings: () async {
        _composerKey.currentState?.unfocus();
        if (mobileHomeTabs) {
          setState(() => _mobileMainTabIndex = 2);
        } else {
          await Navigator.pushNamed(context, '/settings');
        }
        await _refreshReceiveDir();
        _checkS3Config();
      },
      onSessionDeviceSettings: !isOffline && ref.watch(authProvider).isLoggedIn
          ? _openSessionDeviceSettings
          : null,
      onSearch: () {
        _composerKey.currentState?.unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessageSearchScreen()),
        );
      },
      onScanQr: !isOffline && RuntimePlatform.isMobile
          ? () {
              _composerKey.currentState?.unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            }
          : null,
      onFileManager: () {
        _composerKey.currentState?.unfocus();
        if (mobileHomeTabs) {
          setState(() {
            _mobileMainTabIndex = 1;
            _embeddedFileTabActivation++;
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FileManagerScreen(
                onAddToPending: (file) {
                  if (mounted) _addPendingFiles([file]);
                },
              ),
            ),
          );
        }
      },
      onOpenS3Settings: () async {
        _composerKey.currentState?.unfocus();
        await Navigator.pushNamed(context, '/settings/s3');
        if (mounted) await _checkS3Config();
      },
      isSelectionMode: _isSelectionMode,
      selectedCount: _selectedMessages.length,
      totalCount: _chatController.messages.length,
      onExitSelection: _exitSelectionMode,
      onToggleSelectAll: _toggleSelectAll,
      onDeleteSelected: _selectedMessages.isEmpty
          ? null
          : _deleteSelectedMessages,
      chatContent: _buildChatContent(
        context,
        colors,
        isDark,
        ref.watch(authProvider).isLoggedIn,
      ),
    );
  }

  Widget _buildPlainMobileBottomBar({
    required BuildContext context,
    required ChatColors colors,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    Widget tab({
      required int index,
      required String label,
      required IconData icon,
    }) {
      final selected = _mobileMainTabIndex == index;
      final color = selected ? theme.colorScheme.primary : colors.muted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _mobileMainTabIndex = index;
                if (index == 1) _embeddedFileTabActivation++;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final appColors = context.appColors;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          appColors.surface.withValues(alpha: 0.94),
          colors.background,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: appColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.xs),
          tab(
            index: 0,
            label: l10n.mobileHomeTabConnect,
            icon: LucideIcons.smartphone,
          ),
          tab(
            index: 1,
            label: l10n.mobileHomeTabFiles,
            icon: LucideIcons.folderOpen,
          ),
          tab(
            index: 2,
            label: l10n.mobileHomeTabSettings,
            icon: LucideIcons.settings,
          ),
          const SizedBox(width: _kMobileGlassBarExtraSpacing),
          Semantics(
            button: true,
            label: l10n.mobileHomePendingOutbox,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                showPendingFilesManageSheet(
                  context,
                  files: List.of(_pendingFiles),
                  onRemove: _removePendingFileRef,
                  onClearAll: _clearPendingFiles,
                );
              },
              child: SizedBox(
                width: _kMobileGlassBarExtraSize,
                height: _kMobileGlassBarExtraSize,
                child: Center(
                  child: Badge(
                    isLabelVisible: _pendingFiles.isNotEmpty,
                    label: Text(
                      _pendingFiles.length > 99
                          ? '99+'
                          : '${_pendingFiles.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.package,
                      color: colors.muted,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(effectiveOfflineModeProvider);
    final isAuthOffline = ref.watch(isOfflineModeProvider);

    final colors = ChatColors.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final mobileChatSession =
        !_isDesktopPlatform && selectedDeviceId != null;
    final mobileHomeFloatingBar =
        !_isDesktopPlatform &&
        selectedDeviceId == null &&
        MediaQuery.sizeOf(context).width < kChatNarrowLayoutBreakpoint;

    return PopScope(
      canPop: !_isSelectionMode && selectedDeviceId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isSelectionMode) {
            _exitSelectionMode();
          } else if (selectedDeviceId != null) {
            ref.read(selectedDeviceIdProvider.notifier).select(null);
          }
        }
      },
      child: Scaffold(
        backgroundColor:
            mobileChatSession ? colors.surface : colors.background,
        body: _initError != null
            ? ChatInitErrorView(
                message: _initError!,
                colors: colors,
                onRetry: () {
                  setState(() => _initError = null);
                  _init();
                },
              )
            : SafeArea(
                bottom: !mobileHomeFloatingBar,
                child: _isDesktopPlatform
                    ? DesktopPasteShortcuts(
                        onPasteFiles: _handleDesktopPasteFromClipboard,
                        child: _buildChatBodyStack(
                          isOffline: isOffline,
                          isAuthOffline: isAuthOffline,
                          colors: colors,
                          isDark: isDark,
                          selectedDeviceId: selectedDeviceId,
                        ),
                      )
                    : _buildMobileChatBody(
                        isOffline: isOffline,
                        isAuthOffline: isAuthOffline,
                        colors: colors,
                        isDark: isDark,
                        selectedDeviceId: selectedDeviceId,
                      ),
              ),
      ),
    );
  }

  Widget _buildMobileChatBody({
    required bool isOffline,
    required bool isAuthOffline,
    required ChatColors colors,
    required bool isDark,
    required String? selectedDeviceId,
  }) {
    return _buildChatBodyStack(
      isOffline: isOffline,
      isAuthOffline: isAuthOffline,
      colors: colors,
      isDark: isDark,
      selectedDeviceId: selectedDeviceId,
    );
  }

  Widget _buildChatBodyStack({
    required bool isOffline,
    required bool isAuthOffline,
    required ChatColors colors,
    required bool isDark,
    required String? selectedDeviceId,
  }) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow =
                      constraints.maxWidth < kChatNarrowLayoutBreakpoint;
                  if (!isNarrow || selectedDeviceId != null) {
                    return _buildMainLayout(
                      isOffline: isOffline,
                      isAuthOffline: isAuthOffline,
                      mobileHomeTabs: false,
                      colors: colors,
                      isDark: isDark,
                    );
                  }
                  return Scaffold(
                    backgroundColor: colors.background,
                    extendBody: true,
                    body: _PlatformGlassBackdrop(
                      child: Stack(
                        clipBehavior: Clip.none,
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: IndexedStack(
                              index: _mobileMainTabIndex,
                              children: [
                                _buildMainLayout(
                                  isOffline: isOffline,
                                  isAuthOffline: isAuthOffline,
                                  mobileHomeTabs: true,
                                  colors: colors,
                                  isDark: isDark,
                                ),
                                FileManagerScreen(
                                  embedded: true,
                                  embeddedFileTabActivation:
                                      _embeddedFileTabActivation,
                                  onAddToPending: (file) {
                                    if (mounted) {
                                      _addPendingFiles([file]);
                                    }
                                  },
                                ),
                                const SettingsScreen(embedded: true),
                              ],
                            ),
                          ),
                          // Floating glass bar: content scrolls underneath;
                          // stronger glass tint + no tab glow reduces ghost pill on light BG.
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: SafeArea(
                              top: false,
                              minimum: const EdgeInsets.only(
                                left: _kMobileFloatingBarEdge,
                                right: _kMobileFloatingBarEdge,
                                bottom: _kMobileFloatingBarBottomGap,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final l10n = AppLocalizations.of(context);
                                  final barW = math.min(
                                    constraints.maxWidth,
                                    _kMobileGlassBarOuterWidth,
                                  );
                                  return Align(
                                    alignment: Alignment.bottomCenter,
                                    child: SizedBox(
                                      width: barW,
                                      child:
                                          AppPlatformPerformance
                                              .preferPlainNarrowNavigation
                                          ? _buildPlainMobileBottomBar(
                                              context: context,
                                              colors: colors,
                                              theme: theme,
                                              l10n: l10n,
                                            )
                                          : GlassBottomBar(
                                              tabs: [
                                                GlassBottomBarTab(
                                                  label:
                                                      l10n.mobileHomeTabConnect,
                                                  icon: const Icon(
                                                    LucideIcons.smartphone,
                                                  ),
                                                ),
                                                GlassBottomBarTab(
                                                  label:
                                                      l10n.mobileHomeTabFiles,
                                                  icon: const Icon(
                                                    LucideIcons.folderOpen,
                                                  ),
                                                ),
                                                GlassBottomBarTab(
                                                  label: l10n
                                                      .mobileHomeTabSettings,
                                                  icon: const Icon(
                                                    LucideIcons.settings,
                                                  ),
                                                ),
                                              ],
                                              selectedIndex:
                                                  _mobileMainTabIndex,
                                              onTabSelected: (i) {
                                                setState(() {
                                                  _mobileMainTabIndex = i;
                                                  if (i == 1) {
                                                    _embeddedFileTabActivation++;
                                                  }
                                                });
                                              },
                                              spacing:
                                                  _kMobileGlassBarExtraSpacing,
                                              extraButton: GlassBottomBarExtraButton(
                                                label: l10n
                                                    .mobileHomePendingOutbox,
                                                size: _kMobileGlassBarExtraSize,
                                                iconColor: colors.muted,
                                                icon: Badge(
                                                  isLabelVisible:
                                                      _pendingFiles.isNotEmpty,
                                                  label: Text(
                                                    _pendingFiles.length > 99
                                                        ? '99+'
                                                        : '${_pendingFiles.length}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    LucideIcons.package,
                                                    color: colors.muted,
                                                    size: 24,
                                                  ),
                                                ),
                                                onTap: () {
                                                  showPendingFilesManageSheet(
                                                    context,
                                                    files: List.of(
                                                      _pendingFiles,
                                                    ),
                                                    onRemove:
                                                        _removePendingFileRef,
                                                    onClearAll:
                                                        _clearPendingFiles,
                                                  );
                                                },
                                              ),
                                              selectedIconColor:
                                                  theme.colorScheme.primary,
                                              unselectedIconColor: colors.muted,
                                              horizontalPadding:
                                                  _kMobileGlassBarHPadding,
                                              verticalPadding: 0,
                                              barHeight: 64,
                                              barBorderRadius: 45,
                                              tabWidth:
                                                  _kMobileGlassBarTabWidth,
                                              iconSize: 24,
                                              labelFontSize: 12,
                                              iconLabelSpacing: 3,
                                              tabPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 4,
                                                  ),
                                              blendAmount: 6,
                                              indicatorExpansion: 14,
                                              glowOpacity: 0,
                                              glowBlurRadius: 0,
                                              glowSpreadRadius: 0,
                                              // Dynamic tab indicator + IndexedStack: prefer standard
                                              // over default premium to avoid Impeller/texture artifacts
                                              // after repeated tab switches (package docs).
                                              quality: GlassQuality.standard,
                                              interactionBehavior:
                                                  GlassInteractionBehavior.none,
                                              interactionGlowColor:
                                                  Colors.transparent,
                                              glassSettings: LiquidGlassSettings(
                                                thickness: 26,
                                                blur: 5,
                                                // Softer rim + less fringe: reads as
                                                // frosted float against shell bg, not a stroke.
                                                chromaticAberration: 0.08,
                                                specularSharpness:
                                                    GlassSpecularSharpness.soft,
                                                lightIntensity: 0.58,
                                                refractiveIndex: 1.55,
                                                saturation: 0.72,
                                                ambientStrength: 1,
                                                lightAngle: 0.75 * math.pi,
                                                glassColor: isDark
                                                    ? const Color(0x59000000)
                                                    : const Color(0x72FFFFFF),
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_isDesktopPlatform)
          ValueListenableBuilder<bool>(
            valueListenable: DesktopFileDropDispatcher.instance.isHovering,
            builder: (context, hovering, _) {
              if (!hovering) return const SizedBox.shrink();
              return ChatDropOverlay(colors: colors);
            },
          ),
      ],
    );
  }

  Widget _buildChatContent(
    BuildContext context,
    ChatColors colors,
    bool isDark,
    bool isLoggedIn,
  ) {
    return ChatSessionBody(
      onRefresh: _refreshSelectedSessionReach,
      onModeSelected: isLoggedIn ? _confirmAndSwitchMode : null,
      currentUserId: _deviceId,
      deviceName: _deviceName,
      chatController: _chatController,
      onMessageSend: _sendText,
      onAttachmentTap: _onAttachmentTap,
      onMessageTap: _onMessageTap,
      textMessageBuilder: _buildTextMessage,
      onChatTap: () {
        _composerKey.currentState?.unfocus();
        _composerKey.currentState?.dismissPanel();
      },
      scrollController: _chatScrollController,
      onEndReached: _loadMoreHistory,
      composerBuilder: (context) => _buildComposerWidget(context, colors),
      colors: colors,
      isDark: isDark,
    );
  }

  Widget _buildComposerWidget(BuildContext context, ChatColors colors) {
    return ChatComposer(
      key: _composerKey,
      onSend: _sendText,
      onAttachmentChoice: _handleAttachmentChoice,
      pendingFiles: _pendingFiles,
      onSendPendingFiles: _showFileSendModal,
      onRemovePendingFile: _removePendingFileRef,
      onClearPendingFiles: _clearPendingFiles,
      onPasteFiles: _isDesktopPlatform
          ? (files) {
              _addPendingFiles(files);
            }
          : null,
      onToggleDesktopSidebar: _isDesktopPlatform
          ? () {
              setState(
                () => _desktopDevicePanelVisible = !_desktopDevicePanelVisible,
              );
              _saveDevicePanelState(_desktopDevicePanelVisible);
            }
          : null,
      onExpandDesktopSidebar: _isDesktopPlatform
          ? () {
              if (!_desktopDevicePanelVisible) {
                setState(() => _desktopDevicePanelVisible = true);
                _saveDevicePanelState(true);
              }
            }
          : null,
      onToggleDevicePanel: !_isDesktopPlatform
          ? _toggleMobileDevicePanel
          : null,
      onExpandDevicePanel: !_isDesktopPlatform ? _openMobileDevicePanel : null,
      onDismissDevicePanel: !_isDesktopPlatform
          ? _closeMobileDevicePanel
          : null,
      isDevicePanelOpen: _isDesktopPlatform
          ? _desktopDevicePanelVisible
          : _mobileDevicePanelVisible,
      onHeightChanged: null,
      lanReceiverUrl: _lanReceiver?.lanHttpUrl,
      onProbePull: _effectiveOffline ? null : _sendPullProbe,
      onWebRTCProbe: _effectiveOffline ? null : _sendWebRTCProbe,
      onLanHttpProbe: _effectiveOffline ? null : _sendLanHttpProbe,
    );
  }

  static String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$h:$m:$s';
    }
    return '${dt.month}/${dt.day} $h:$m:$s';
  }

  static final _progressReZh = RegExp(r'^(.+?) (发送中|接收中) (\d+)%$');
  static final _progressReEn = RegExp(r'^(.+?) (Sending|Receiving) (\d+)%$');
  static final _waitingReZh = RegExp(r'^(.+?) 等待接收方连接…$');
  static final _waitingReEn = RegExp(r'^(.+?) Waiting for peer…$');

  RegExpMatch? _matchProgress(String text) =>
      _progressReZh.firstMatch(text) ?? _progressReEn.firstMatch(text);

  RegExpMatch? _matchWaiting(String text) =>
      _waitingReZh.firstMatch(text) ?? _waitingReEn.firstMatch(text);

  bool _isCancelledTransferLine(String text) {
    return text.endsWith('已取消') ||
        text.endsWith('Cancelled') ||
        text.endsWith('cancelled');
  }

  bool _isFailedTransferLine(String text) {
    return text.endsWith('发送失败') ||
        text.endsWith('接收失败') ||
        text.endsWith('send failed') ||
        text.endsWith('receive failed');
  }

  /// When payload omits flags (older rows), infer LAN/WebRTC/S3 from bubble copy or key.
  String? _effectiveFileTransferTypeForCard(
    String messageId,
    String text,
    _FileMeta meta,
  ) {
    if (meta.transferType != null && meta.transferType!.isNotEmpty) {
      return meta.transferType;
    }
    final fromText = inferTransferTypeFromFileBubbleText(text);
    if (fromText != null) return fromText;
    final key = _fileKeyByMessageId[messageId];
    if (key != null && key.isNotEmpty) return 's3';
    // Legacy [envelopeToMessage] fallback when payload lost lan/targetDeviceIds:
    // `文件: name.jpg` — treat as HTTP/LAN direct file row (not S3).
    if ((text.startsWith('文件:') || text.startsWith('File:')) &&
        (meta.s3Key == null || meta.s3Key!.isEmpty)) {
      return 'lan';
    }
    return null;
  }

  int? _effectiveFileSizeForCard(String text, _FileMeta meta) {
    if (meta.size != null && meta.size! > 0) return meta.size;
    return tryParseTrailingParenFileSize(text);
  }

  Widget _buildTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final colors = ChatColors.of(context);
    final text = message.text;
    final timeStr = message.createdAt != null
        ? _formatMessageTime(message.createdAt!)
        : '';

    Widget bubble;

    final progressMatch = _matchProgress(text);
    if (progressMatch != null) {
      final fileName = progressMatch.group(1)!;
      final direction = progressMatch.group(2)!;
      final pct = int.parse(progressMatch.group(3)!);
      String? localId;
      if (message.id.startsWith('local_')) {
        localId = message.id.substring(6);
      }
      final isActiveReceive = _activeLanReceives.containsKey(message.id);
      final isActiveDownload = _activeDownloads.containsKey(message.id);
      final canCancel =
          isActiveReceive ||
          isActiveDownload ||
          (localId != null &&
              (_activeTransfers.containsKey(localId) ||
                  _webrtcLocalIdToFileIdMap.containsKey(localId)));
      final speedStr = _speedTrackers[message.id]?.formatted;
      final speedBps = _speedTrackers[message.id]?.bytesPerSecond;
      final startTime = _transferStartTimes[message.id];
      final elapsed = startTime != null
          ? DateTime.now().difference(startTime)
          : null;
      final progressMeta = _fileMetaByMessageId[message.id];
      bubble = TransferProgressBubble(
        colors: colors,
        fileName: fileName,
        progress: pct / 100.0,
        isUploading: direction == '发送中' || direction == 'Sending',
        speed: speedStr,
        speedBytesPerSecond: speedBps,
        elapsed: elapsed,
        canCancel: canCancel,
        onCancel: canCancel
            ? () {
                if (isActiveReceive) {
                  _cancelLanReceive(message.id, fileName);
                } else if (isActiveDownload) {
                  _cancelDownload(message.id, fileName);
                } else {
                  _cancelTransfer(localId!);
                }
              }
            : null,
        isSentByMe: isSentByMe,
        transferLabel: transferTypeLabel(progressMeta?.transferType),
        transferType: progressMeta?.transferType,
        fileSize: progressMeta?.size,
      );
    } else if (_matchWaiting(text) case final waitingMatch?) {
      final fileName = waitingMatch.group(1)!;
      String? localId;
      if (message.id.startsWith('local_')) {
        localId = message.id.substring(6);
      }
      final canCancel =
          localId != null &&
          (_activeTransfers.containsKey(localId) ||
              _webrtcLocalIdToFileIdMap.containsKey(localId));
      final waitMeta = _fileMetaByMessageId[message.id];
      bubble = TransferProgressBubble(
        colors: colors,
        fileName: fileName,
        progress: null,
        isUploading: true,
        statusText: AppLocalizations.of(context).chatTransferWaitingPeerShort,
        canCancel: canCancel,
        onCancel: canCancel ? () => _cancelTransfer(localId!) : null,
        isSentByMe: isSentByMe,
        transferLabel: transferTypeLabel(waitMeta?.transferType),
        transferType: waitMeta?.transferType,
        fileSize: waitMeta?.size,
      );
    } else if (_isCancelledTransferLine(text)) {
      String? localId;
      VoidCallback? onRetry;
      String? cancelSubtitle;
      if (message.id.startsWith('local_')) {
        localId = message.id.substring(6);
        if (isSentByMe && _retryInfoByLocalId.containsKey(localId)) {
          onRetry = () => _retryFileSend(localId!);
        }
      }
      String? cancelTransferType;
      final cancelMeta = _fileMetaByMessageId[message.id];
      if (cancelMeta != null) {
        cancelTransferType = cancelMeta.transferType;
        final sizeStr = formatFileSize(cancelMeta.size);
        if (cancelMeta.transferType != null) {
          cancelSubtitle = sizeStr.isNotEmpty ? sizeStr : null;
        } else {
          final parts = <String>[];
          final label = transferTypeLabel(cancelMeta.transferType);
          if (label.isNotEmpty) parts.add(label);
          if (sizeStr.isNotEmpty) parts.add(sizeStr);
          if (parts.isNotEmpty) cancelSubtitle = parts.join(' · ');
        }
      } else if (localId != null) {
        final retryInfo = _retryInfoByLocalId[localId];
        if (retryInfo != null) {
          cancelTransferType = retryInfo.channel;
          final sizeStr = formatFileSize(retryInfo.fileSize);
          cancelSubtitle = sizeStr.isNotEmpty ? sizeStr : null;
        }
      }
      bubble = TransferStatusBubble(
        colors: colors,
        text: text,
        color: colors.bubbleAccent(isSentByMe, colors.warning),
        icon: LucideIcons.circleX,
        isSentByMe: isSentByMe,
        onRetry: onRetry,
        subtitle: cancelSubtitle,
        transferType: cancelTransferType,
      );
    } else if (_isFailedTransferLine(text)) {
      String? localId;
      VoidCallback? onRetry;
      VoidCallback? onSwitchToS3;
      String? failSubtitle;
      String? failTransferType;
      if (message.id.startsWith('local_')) {
        localId = message.id.substring(6);
        if (_retryInfoByLocalId.containsKey(localId)) {
          onRetry = () => _retryFileSend(localId!);
          final retryInfo = _retryInfoByLocalId[localId]!;
          failTransferType = retryInfo.channel;
          final sizeStr = formatFileSize(retryInfo.fileSize);
          failSubtitle = sizeStr.isNotEmpty ? sizeStr : null;
          // 如果原传输方式不是S3，显示切换到S3按钮
          if (retryInfo.channel != 's3' && isSentByMe) {
            onSwitchToS3 = () => _switchToS3(localId!);
          }
        }
      }
      if (failSubtitle == null) {
        final failMeta = _fileMetaByMessageId[message.id];
        if (failMeta != null) {
          failTransferType = failMeta.transferType ?? failTransferType;
          final sizeStr = formatFileSize(failMeta.size);
          if (failMeta.transferType != null) {
            failSubtitle = sizeStr.isNotEmpty ? sizeStr : null;
          } else {
            final parts = <String>[];
            final label = transferTypeLabel(failMeta.transferType);
            if (label.isNotEmpty) parts.add(label);
            if (sizeStr.isNotEmpty) parts.add(sizeStr);
            if (parts.isNotEmpty) failSubtitle = parts.join(' · ');
          }
          // 如果原传输方式不是S3，显示切换到S3按钮
          if (failMeta.transferType != 's3' && isSentByMe && localId != null) {
            onSwitchToS3 = () => _switchToS3(localId!);
          }
        }
      }
      bubble = TransferStatusBubble(
        colors: colors,
        text: text,
        color: colors.bubbleAccent(isSentByMe, colors.danger),
        icon: LucideIcons.circleAlert,
        isSentByMe: isSentByMe,
        onRetry: onRetry,
        onSwitchToS3: onSwitchToS3,
        subtitle: failSubtitle,
        transferType: failTransferType,
      );
    } else {
      final fileMeta = _fileMetaByMessageId[message.id];
      if (fileMeta != null) {
        final card = FileCardBubble(
          fileName: fileMeta.fileName,
          size: _effectiveFileSizeForCard(text, fileMeta),
          transferType: _effectiveFileTransferTypeForCard(
            message.id,
            text,
            fileMeta,
          ),
          hasDownload: fileMeta.s3Key != null,
          isSentByMe: isSentByMe,
          filePath: fileMeta.localPath,
        );
        Widget fileCard = card;
        if (_isDesktopPlatform) {
          fileCard = MouseRegion(
            cursor: SystemMouseCursors.click,
            child: fileCard,
          );
          final localPath = fileMeta.localPath;
          if (localPath != null &&
              localPath.isNotEmpty &&
              File(localPath).existsSync()) {
            fileCard = DesktopFileDragSource(
              paths: [localPath],
              child: fileCard,
            );
          }
        }
        bubble = fileCard;
      } else {
        final isLocalText = isSentByMe && message.id.startsWith('local_');
        if (isLocalText) {
          final localId = message.id.substring(6);
          final status = _localMessageStatus[localId];
          if (status == 'failed') {
            bubble = FailedTextBubble(
              colors: colors,
              message: message,
              index: index,
              onRetry: () => _retryTextSend(localId),
            );
          } else {
            bubble = PlainTextBubble(
              colors: colors,
              message: message,
              isSentByMe: isSentByMe,
            );
          }
        } else {
          bubble = PlainTextBubble(
            colors: colors,
            message: message,
            isSentByMe: isSentByMe,
          );
        }
      }
    }

    Widget? statusIcon;
    if (message.id.startsWith('local_')) {
      final localId = message.id.substring(6);
      final status = _localMessageStatus[localId];
      statusIcon = switch (status) {
        'sending' || 'uploading' || 'downloading' => SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.bubbleMuted(isSentByMe),
          ),
        ),
        'sent' => Icon(LucideIcons.check, size: 12, color: colors.upload),
        'failed' => Icon(
          LucideIcons.circleAlert,
          size: 12,
          color: colors.danger,
        ),
        'cancelled' => Icon(
          LucideIcons.circleX,
          size: 12,
          color: colors.warning,
        ),
        _ => null,
      };
    }

    final isTransferring = progressMatch != null || _matchWaiting(text) != null;

    final isFileMessage = _fileMetaByMessageId[message.id] != null;
    final isSelected = _selectedMessages.contains(message.id);

    final timeRow = Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxs,
        left: AppSpacing.xxs,
        right: AppSpacing.xxs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              color: colors.bubbleSubtle(isSentByMe),
              fontSize: 10,
            ),
          ),
          if (statusIcon != null) ...[const SizedBox(width: 4), statusIcon],
        ],
      ),
    );

    // Wrap bubble with selection UI
    Widget messageContent = bubble;
    if (_isSelectionMode) {
      final theme = Theme.of(context);
      messageContent = Container(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.xs,
              ),
              child: Icon(
                isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
                color: isSelected
                    ? theme.colorScheme.primary
                    : context.appColors.textSecondary,
                size: 24,
              ),
            ),
            // Use loose flex so bubbles keep intrinsic width. `Expanded` forces
            // tight max width and stretches bubbles across the row in selection mode.
            Flexible(fit: FlexFit.loose, child: bubble),
          ],
        ),
      );
    }

    if (_isMobile) {
      return GestureDetector(
        onTap: _isSelectionMode && !isTransferring
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedMessages.remove(message.id);
                  } else {
                    _selectedMessages.add(message.id);
                  }
                });
              }
            : null,
        onLongPress: _isSelectionMode || isTransferring
            ? null
            : () => _showMessageActions(message, isSentByMe),
        child: Column(
          crossAxisAlignment: isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [messageContent, timeRow],
        ),
      );
    }

    final isHovered = _hoveredMessageId == message.id;
    final bubbleWithActions = MouseRegion(
      onEnter: (_) {
        if (!_isSelectionMode) {
          setState(() => _hoveredMessageId = message.id);
        }
      },
      onExit: (_) {
        if (_hoveredMessageId == message.id) {
          setState(() => _hoveredMessageId = null);
        }
      },
      child: GestureDetector(
        onTap: _isSelectionMode && !isTransferring
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedMessages.remove(message.id);
                  } else {
                    _selectedMessages.add(message.id);
                  }
                });
              }
            : null,
        onSecondaryTapUp: isFileMessage && !isTransferring && !_isSelectionMode
            ? (details) =>
                  _showFileMessageContextMenu(message, details.globalPosition)
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            messageContent,
            if (isHovered && !isTransferring && !_isSelectionMode)
              Positioned(
                right: AppSpacing.xxs,
                bottom: AppSpacing.xxs,
                child: _buildMessageHoverActions(
                  message,
                  isSentByMe,
                  isFileMessage,
                  context.appColors,
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: isSentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [bubbleWithActions, timeRow],
    );
  }

  Widget _buildMessageHoverActions(
    TextMessage message,
    bool isSentByMe,
    bool isFileMessage,
    AppThemeColors appColors,
  ) {
    final fileMeta = _fileMetaByMessageId[message.id];
    final localPath = fileMeta?.localPath;
    final fileExists = localPath != null && File(localPath).existsSync();
    final s3Key = _fileKeyByMessageId[message.id];
    final canS3Download = s3Key != null && s3Key.isNotEmpty && !fileExists;
    final existingLocalPath = fileExists ? localPath : null;

    return Container(
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: appColors.border),
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
          _msgHoverBtn(LucideIcons.squareCheck, appColors.textSecondary, () {
            setState(() {
              _isSelectionMode = true;
              _selectedMessages.add(message.id);
            });
          }),
          if (!isFileMessage)
            _msgHoverBtn(LucideIcons.copy, appColors.textSecondary, () {
              Clipboard.setData(ClipboardData(text: message.text));
              AppToast.show(
                context,
                message: AppLocalizations.of(context).chatCopied,
              );
            }),
          if (isFileMessage && existingLocalPath != null) ...[
            _msgHoverBtn(LucideIcons.copy, appColors.textSecondary, () {
              unawaited(_copyChatFileToClipboard(existingLocalPath));
            }),
            _msgHoverBtn(LucideIcons.externalLink, appColors.textSecondary, () {
              final meta = _fileMetaByMessageId[message.id];
              if (meta == null) {
                unawaited(_tryOpenLocalFilePath(existingLocalPath));
              } else {
                unawaited(
                  _openFileFromBubble(
                    messageId: message.id,
                    meta: meta,
                    fallbackKey: s3Key,
                  ),
                );
              }
            }),
            _msgHoverBtn(LucideIcons.folderOpen, appColors.textSecondary, () {
              unawaited(revealFileInFolder(existingLocalPath));
            }),
            if (FileExportService.isSupported)
              _msgHoverBtn(LucideIcons.download, appColors.textSecondary, () {
                final meta = _fileMetaByMessageId[message.id];
                if (meta != null) {
                  unawaited(_exportChatFile(existingLocalPath, meta.fileName));
                }
              }),
            _msgHoverBtn(LucideIcons.plus, appColors.textSecondary, () {
              final meta = _fileMetaByMessageId[message.id];
              if (meta != null) {
                _addFileMessageToPending(meta, existingLocalPath);
              }
            }),
          ],
          if (isFileMessage && canS3Download)
            _msgHoverBtn(LucideIcons.download, appColors.textSecondary, () {
              unawaited(
                _downloadS3File(
                  s3Key,
                  messageId: message.id,
                  fileName: _fileFileNameByMessageId[message.id],
                ),
              );
            }),
          _msgHoverBtn(
            LucideIcons.trash2,
            appColors.danger,
            () => _confirmDeleteMessage(message),
          ),
        ],
      ),
    );
  }

  Widget _msgHoverBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _showFileMessageContextMenu(TextMessage message, Offset globalPosition) {
    final fileMeta = _fileMetaByMessageId[message.id];
    if (fileMeta == null) return;

    final localPath = fileMeta.localPath;
    final fileExists =
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();
    final s3Key = _fileKeyByMessageId[message.id];
    final canS3Download = !fileExists && s3Key != null && s3Key.isNotEmpty;

    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final items = <PopupMenuEntry<void>>[];
    if (fileExists) {
      items.addAll([
        PopupMenuItem<void>(
          onTap: () => unawaited(_copyChatFileToClipboard(localPath)),
          child: Text(l10n.fileClipboardCopy),
        ),
        PopupMenuItem<void>(
          onTap: () {
            unawaited(
              _openFileFromBubble(
                messageId: message.id,
                meta: fileMeta,
                fallbackKey: s3Key,
              ),
            );
          },
          child: Text(l10n.chatMenuOpen),
        ),
        PopupMenuItem<void>(
          onTap: () => unawaited(revealFileInFolder(localPath)),
          child: Text(l10n.fmRevealInFolder),
        ),
        if (FileExportService.isSupported)
          PopupMenuItem<void>(
            onTap: () =>
                unawaited(_exportChatFile(localPath, fileMeta.fileName)),
            child: Text(_exportActionLabel(l10n)),
          ),
        PopupMenuItem<void>(
          onTap: () => _addFileMessageToPending(fileMeta, localPath),
          child: Text(l10n.chatMenuAddToPending),
        ),
      ]);
    } else if (canS3Download) {
      items.add(
        PopupMenuItem<void>(
          onTap: () {
            unawaited(
              _downloadS3File(
                s3Key,
                messageId: message.id,
                fileName: _fileFileNameByMessageId[message.id],
              ),
            );
          },
          child: Text(l10n.chatMenuDownloadFromCloud),
        ),
      );
    }
    items.add(
      PopupMenuItem<void>(
        onTap: () => _confirmDeleteMessage(message),
        child: Text(
          l10n.chatMenuDeleteMessage,
          style: TextStyle(color: colors.danger),
        ),
      ),
    );

    showMenu<void>(context: context, position: position, items: items);
  }
}
