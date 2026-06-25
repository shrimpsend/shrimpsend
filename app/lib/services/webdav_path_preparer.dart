import 'dart:async';

import 'webdav_session.dart';
import 'webdav_upload_layout.dart';

/// Serializes WebDAV MKCOL per connection and caches ensured directories.
final class WebDavPathPreparer {
  WebDavPathPreparer({
    required this.connectionId,
    required this.client,
  });

  final int connectionId;
  final WebDavClient client;

  static final _ensuredByConnection = <int, Set<String>>{};
  static final _mutexByConnection = <int, _AsyncMutex>{};

  Set<String> get _ensured =>
      _ensuredByConnection.putIfAbsent(connectionId, () => <String>{});

  _AsyncMutex get _mutex =>
      _mutexByConnection.putIfAbsent(connectionId, _AsyncMutex.new);

  /// Ensures all parent directories for [remoteFilePaths] exist (shallow-first).
  Future<void> prepareRemoteDirs(Iterable<String> remoteFilePaths) async {
    for (final dir in collectSortedParentDirs(remoteFilePaths)) {
      if (_ensured.contains(dir)) continue;
      await _mutex.run(() async {
        if (_ensured.contains(dir)) return;
        await client.createDirectory(dir);
        _ensured.add(dir);
      });
    }
  }
}

final class _AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
