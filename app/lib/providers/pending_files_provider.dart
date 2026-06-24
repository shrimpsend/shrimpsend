import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pending_files_path_stabilizer.dart';
import '../services/pending_files_store.dart';
import '../services/share_receive_service.dart';
import '../utils/pending_files_merge.dart';
import 'pending_add_result.dart';

final pendingFilesProvider =
    NotifierProvider<PendingFilesNotifier, List<PlatformFile>>(
  PendingFilesNotifier.new,
);

final class PendingFilesNotifier extends Notifier<List<PlatformFile>> {
  @override
  List<PlatformFile> build() => [];

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
}
