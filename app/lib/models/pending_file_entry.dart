import 'package:file_picker/file_picker.dart';

/// Pending outbox item with optional folder-pick relative path (POSIX `/`).
final class PendingFileEntry {
  const PendingFileEntry({
    required this.file,
    this.relativeSubPath,
  });

  final PlatformFile file;
  final String? relativeSubPath;

  bool get hasFolderStructure =>
      relativeSubPath != null && relativeSubPath!.contains('/');

  PendingFileEntry copyWith({
    PlatformFile? file,
    String? relativeSubPath,
    bool clearRelativeSubPath = false,
  }) {
    return PendingFileEntry(
      file: file ?? this.file,
      relativeSubPath:
          clearRelativeSubPath ? null : (relativeSubPath ?? this.relativeSubPath),
    );
  }

  static PendingFileEntry fromPlatformFile(
    PlatformFile file, {
    String? relativeSubPath,
  }) {
    return PendingFileEntry(
      file: file,
      relativeSubPath: relativeSubPath?.replaceAll('\\', '/'),
    );
  }
}
