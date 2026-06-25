import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pending_file_entry.dart';
import '../services/pending_dispatch_bridge.dart';
import '../services/pending_files_path_stabilizer.dart';
import '../services/pending_files_store.dart';
import '../services/share_receive_service.dart';
import '../utils/pending_files_merge.dart';
import 'pending_add_result.dart';
import 'pending_dispatch_result.dart';

final pendingFilesProvider =
    NotifierProvider<PendingFilesNotifier, List<PendingFileEntry>>(
  PendingFilesNotifier.new,
);

final class PendingFilesNotifier extends Notifier<List<PendingFileEntry>> {
  final Map<String, PendingFileEntry> _heldForDispatch = {};

  @override
  List<PendingFileEntry> build() {
    PendingDispatchBridge.register(
      (localPath, {required success}) =>
          onDeliverySettled(localPath, success: success),
    );
    ref.onDispose(PendingDispatchBridge.unregister);
    return [];
  }

  Future<int> bootstrap({bool consumeSharePending = true}) async {
    final loaded = await PendingFilesStore.load();
    var entries = loaded.entries;
    entries = mergePendingFileEntries(entries, state);

    if (consumeSharePending) {
      final fromShare = ShareReceiveService.instance.takePendingFromShare();
      if (fromShare != null && fromShare.isNotEmpty) {
        entries = mergePendingFileEntries(
          entries,
          fromShare
              .map((f) => PendingFileEntry.fromPlatformFile(f))
              .toList(),
        );
      }
    }

    state = entries;
    await PendingFilesStore.save(entries);
    return loaded.droppedMissing;
  }

  Future<PendingAddResult> add(List<PendingFileEntry> incoming) async {
    if (incoming.isEmpty) return (added: 0, skipped: 0);

    final stabilized = await _stabilizeEntries(incoming);
    final skipped = incoming.length - stabilized.length;
    if (stabilized.isEmpty) return (added: 0, skipped: skipped);

    final prevLen = state.length;
    final merged = mergePendingFileEntries(state, stabilized);
    final added = merged.length - prevLen;
    if (added == 0) return (added: 0, skipped: skipped);

    state = merged;
    await PendingFilesStore.save(state);
    return (added: added, skipped: skipped);
  }

  Future<List<PendingFileEntry>> _stabilizeEntries(
    List<PendingFileEntry> incoming,
  ) async {
    final result = <PendingFileEntry>[];
    for (final entry in incoming) {
      final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
        entry.file,
      );
      if (stabilized == null) continue;
      result.add(
        PendingFileEntry.fromPlatformFile(
          stabilized,
          relativeSubPath: entry.relativeSubPath,
        ),
      );
    }
    return result;
  }

  /// Validates and stabilizes [entries] without mutating outbox state.
  Future<PendingDispatchResult> prepareDispatch(
    List<PendingFileEntry> entries,
  ) async {
    if (entries.isEmpty) {
      return (queued: <PendingFileEntry>[], skipped: 0);
    }

    final queued = <PendingFileEntry>[];
    var skipped = 0;

    for (final entry in entries) {
      final ready = await _stabilizeDispatchEntry(entry);
      if (ready == null) {
        skipped++;
        continue;
      }
      queued.add(ready);
    }

    return (queued: queued, skipped: skipped);
  }

  /// Removes [queued] from outbox and holds them until delivery settles.
  Future<PendingDispatchResult> commitDispatch(
    List<PendingFileEntry> queued,
  ) async {
    if (queued.isEmpty) {
      return (queued: <PendingFileEntry>[], skipped: 0);
    }

    final committed = <PendingFileEntry>[];
    var skipped = 0;
    var nextState = List<PendingFileEntry>.from(state);

    for (final ready in queued) {
      final path = ready.file.path;
      if (path == null || path.isEmpty) {
        skipped++;
        continue;
      }
      final removed = _removeFirstMatching(nextState, ready, readyPath: path);
      if (!removed) {
        skipped++;
        continue;
      }
      _heldForDispatch[path] = ready;
      committed.add(ready);
    }

    if (committed.isNotEmpty) {
      state = nextState;
      await PendingFilesStore.save(state);
    }

    return (queued: committed, skipped: skipped);
  }

  Future<PendingDispatchResult> beginDispatch(
    List<PendingFileEntry> entries,
  ) async {
    final prep = await prepareDispatch(entries);
    if (prep.queued.isEmpty) return prep;
    final committed = await commitDispatch(prep.queued);
    return (queued: committed.queued, skipped: prep.skipped + committed.skipped);
  }

  /// Restores held dispatch entries back into the outbox after a failed enqueue.
  void rollbackHeldDispatch(Iterable<String> localPaths) {
    for (final localPath in localPaths) {
      if (localPath.isEmpty) continue;
      onDeliverySettled(localPath, success: false);
    }
  }

  Future<PendingFileEntry?> _stabilizeDispatchEntry(
    PendingFileEntry entry,
  ) async {
    final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
      entry.file,
      logSource: 'pending_dispatch',
    );
    if (stabilized == null) return null;
    final path = stabilized.path;
    if (path == null || path.isEmpty) return null;
    final local = File(path);
    if (!await local.exists()) return null;
    final diskSize = await local.length();
    if (diskSize <= 0) return null;

    return PendingFileEntry.fromPlatformFile(
      PlatformFile(
        name: stabilized.name,
        path: path,
        size: diskSize,
      ),
      relativeSubPath: entry.relativeSubPath,
    );
  }

  void onDeliverySettled(String localPath, {required bool success}) {
    final held = _heldForDispatch.remove(localPath);
    if (held == null) return;

    if (success) {
      unawaited(PendingFilesPathStabilizer.deletePendingCacheFile(localPath));
      return;
    }

    state = mergePendingFileEntries(state, [held]);
    unawaited(PendingFilesStore.save(state));
  }

  void remove(PendingFileEntry entry) {
    unawaited(PendingFilesPathStabilizer.deletePendingCacheFile(entry.file.path));
    state = List<PendingFileEntry>.from(state)..remove(entry);
    unawaited(PendingFilesStore.save(state));
  }

  void clear() {
    final entries = List<PendingFileEntry>.from(state);
    unawaited(
      PendingFilesPathStabilizer.deletePendingCacheFiles(
        entries.map((e) => e.file),
      ),
    );
    state = [];
    unawaited(PendingFilesStore.save(state));
  }

  Future<int> reloadFromStore() async {
    final loaded = await PendingFilesStore.load();
    state = loaded.entries;
    if (loaded.droppedMissing > 0) {
      await PendingFilesStore.save(state);
    }
    return loaded.droppedMissing;
  }

  bool _removeFirstMatching(
    List<PendingFileEntry> entries,
    PendingFileEntry target, {
    required String readyPath,
  }) {
    final targetPath = target.file.path;
    for (var i = 0; i < entries.length; i++) {
      final candidate = entries[i];
      if (candidate.file.path == targetPath ||
          candidate.file.path == readyPath) {
        entries.removeAt(i);
        return true;
      }
    }
    return false;
  }
}
