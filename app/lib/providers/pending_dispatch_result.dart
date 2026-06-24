import 'package:file_picker/file_picker.dart';

/// Result of dispatching files from the visible pending outbox.
typedef PendingDispatchResult = ({
  List<PlatformFile> queued,
  int skipped,
});
