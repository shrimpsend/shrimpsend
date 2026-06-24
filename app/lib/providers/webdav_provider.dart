import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../services/webdav_credential_store.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_recent_dao.dart';
import '../services/webdav_transfer_service.dart';
import 'auth_provider.dart';

class WebDavConnectionsNotifier
    extends AsyncNotifier<List<WebDavConnectionSummary>> {
  @override
  Future<List<WebDavConnectionSummary>> build() async {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.isLoggedIn == true && !next.isLoggedIn) {
        WebDavCredentialStore.instance.wipeAll();
      }
      if (next.isLoggedIn) {
        ref.invalidateSelf();
      }
    });
    if (!ref.watch(authProvider).isLoggedIn) return [];
    try {
      return await listWebDavConnections();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (!ref.read(authProvider).isLoggedIn) return [];
      return listWebDavConnections();
    });
  }
}

final webDavConnectionsProvider =
    AsyncNotifierProvider<WebDavConnectionsNotifier, List<WebDavConnectionSummary>>(
  WebDavConnectionsNotifier.new,
);

class WebDavFavoritesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<WebDavFavoriteRecord>, int> {
  @override
  Future<List<WebDavFavoriteRecord>> build(int connectionId) {
    return WebDavFavoriteDao.instance.listForConnection(
      webDavConnectionKey(connectionId),
    );
  }

  Future<void> refresh() async {
    final connectionId = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => WebDavFavoriteDao.instance.listForConnection(
        webDavConnectionKey(connectionId),
      ),
    );
  }
}

final webDavFavoritesProvider = AutoDisposeAsyncNotifierProvider.family<
    WebDavFavoritesNotifier,
    List<WebDavFavoriteRecord>,
    int>(WebDavFavoritesNotifier.new);

class WebDavRecentNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<WebDavRecentRecord>, int> {
  @override
  Future<List<WebDavRecentRecord>> build(int connectionId) {
    return WebDavRecentDao.instance.listForConnection(
      webDavConnectionKey(connectionId),
    );
  }

  Future<void> refresh() async {
    final connectionId = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => WebDavRecentDao.instance.listForConnection(
        webDavConnectionKey(connectionId),
      ),
    );
  }
}

final webDavRecentProvider = AutoDisposeAsyncNotifierProvider.family<
    WebDavRecentNotifier,
    List<WebDavRecentRecord>,
    int>(WebDavRecentNotifier.new);

class WebDavTransferUiState {
  final int activeCount;

  const WebDavTransferUiState({required this.activeCount});
}

class WebDavTransferUiNotifier
    extends AutoDisposeFamilyNotifier<WebDavTransferUiState, int> {
  @override
  WebDavTransferUiState build(int connectionId) {
    void sync() {
      state = WebDavTransferUiState(
        activeCount: WebDavTransferService.instance.activeCountFor(connectionId),
      );
    }

    sync();
    void listener() => sync();
    WebDavTransferService.instance.addListener(listener);
    ref.onDispose(
      () => WebDavTransferService.instance.removeListener(listener),
    );
    return state;
  }
}

final webDavTransferUiProvider = AutoDisposeNotifierProvider.family<
    WebDavTransferUiNotifier,
    WebDavTransferUiState,
    int>(WebDavTransferUiNotifier.new);

Future<WebDavCredentials> resolveWebDavCredentials(
  int connectionId, {
  bool forceRefresh = false,
}) async {
  if (!forceRefresh) {
    final cached = await WebDavCredentialStore.instance.read(connectionId);
    if (cached != null) return cached;
  }
  final creds = await fetchWebDavCredentials(connectionId);
  await WebDavCredentialStore.instance.write(connectionId, creds);
  return creds;
}
