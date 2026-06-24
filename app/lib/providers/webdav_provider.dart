import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../services/webdav_credential_store.dart';
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
