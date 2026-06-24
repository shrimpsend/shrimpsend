import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pending_dispatch_bridge.dart';
import '../services/pending_files_path_stabilizer.dart';
import '../services/pending_files_store.dart';
import '../services/share_receive_service.dart';
import '../utils/pending_files_merge.dart';
import 'pending_add_result.dart';
import 'pending_dispatch_result.dart';

final pendingFilesProvider =
    NotifierProvider<PendingFilesNotifier, List<PlatformFile>>(
  PendingFilesNotifier.new,
);

final class PendingFilesNotifier extends Notifier<List<PlatformFile>> {
  final Map<String, PlatformFile> _heldForDispatch = {};

  @override
  List<PlatformFile> build() {
    PendingDispatchBridge.register(
      (localPath, {required success}) =>
          onDeliverySettled(localPath, success: success),
    );
    ref.onDispose(PendingDispatchBridge.unregister);
    return [];
  }

  Future<int> bootstrap({bool consumeSharePending = true}) async {
    final loaded = await PendingFilesStore.load();
    var files = loaded.files;
    files = mergePendingFiles(files, state);

    if (consumeSharePending) {
      final fromShare = ShareReceiveService.instance.takePendingFromShare();
      if (fromShare != null && fromShare.isNotEmpty) {
        files = mergePendingFiles(files, fromShare);
      }
    }

    state = files;
    await PendingFilesStore.save(files);
    return loaded.droppedMissing;
  }

  Future<PendingAddResult> add(List<PlatformFile> incoming) async {
    if (incoming.isEmpty) return (added: 0, skipped: 0);

    final stabilized = await PendingFilesPathStabilizer.stabilizeAll(incoming);
    final skipped = incoming.length - stabilized.length;
    if (stabilized.isEmpty) return (added: 0, skipped: skipped);

    final prevLen = state.length;
    final merged = mergePendingFiles(state, stabilized);
    final added = merged.length - prevLen;
    if (added == 0) return (added: 0, skipped: skipped);

    state = merged;
    await PendingFilesStore.save(state);
    return (added: added, skipped: skipped);
  }

  Future<PendingDispatchResult> beginDispatch(List<PlatformFile> files) async {
    if (files.isEmpty) {
      return (queued: <PlatformFile>[], skipped: 0);
    }

    final queued = <PlatformFile>[];
    var skipped = 0;
    var nextState = List<PlatformFile>.from(state);

    for (final file in files) {
      final stabilized = await PendingFilesPathStabilizer.stabilizeOne(
        file,
        logSource: 'pending_dispatch',
      );
      if (stabilized == null) {
        skipped++;
        continue;
      }
      final path = stabilized.path;
      if (path == null || path.isEmpty) {
        skipped++;
        continue;
      }
      final local = File(path);
      if (!await local.exists()) {
        skipped++;
        continue;
      }
      final diskSize = await local.length();
      if (diskSize <= 0) {
        skipped++;
        continue;
      }

      final ready = PlatformFile(
        name: stabilized.name,
        path: path,
        size: diskSize,
      );
      final removed = _removeFirstMatching(nextState, file, readyPath: path);
      if (!removed) {
        skipped++;
        continue;
      }
      _heldForDispatch[path] = ready;
      queued.add(ready);
    }

    if (queued.isNotEmpty) {
      state = nextState;
      await PendingFilesStore.save(state);
    }

    return (queued: queued, skipped: skipped);
  }

  void onDeliverySettled(String localPath, {required bool success}) {
    final held = _heldForDispatch.remove(localPath);
    if (held == null) return;

    if (success) {
      unawaited(PendingFilesPathStabilizer.deletePendingCacheFile(localPath));
      return;
    }

    state = mergePendingFiles(state, [held]);
    unawaited(PendingFilesStore.save(state));
  }

  void remove(PlatformFile file) {
    unawaited(PendingFilesPathStabilizer.deletePendingCacheFile(file.path));
    state = List<PlatformFile>.from(state)..remove(file);
    unawaited(PendingFilesStore.save(state));
  }

  void clear() {
    final files = List<PlatformFile>.from(state);
    unawaited(PendingFilesPathStabilizer.deletePendingCacheFiles(files));
    state = [];
    unawaited(PendingFilesStore.save(state));
  }

  Future<int> reloadFromStore() async {
    final loaded = await PendingFilesStore.load();
    state = loaded.files;
    if (loaded.droppedMissing > 0) {
      await PendingFilesStore.save(state);
    }
    return loaded.droppedMissing;
  }

  bool _removeFirstMatching(
    List<PlatformFile> files,
    PlatformFile target, {
    required String readyPath,
  }) {
    final targetPath = target.path;
    for (var i = 0; i < files.length; i++) {
      final candidate = files[i];
      if (candidate.path == targetPath || candidate.path == readyPath) {
        files.removeAt(i);
        return true;
      }
    }
    return false;
  }
}
