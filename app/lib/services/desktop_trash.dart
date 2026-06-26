import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import '../logger.dart';

/// Moves files into the operating system recycle bin / trash on desktop
/// platforms so users can recover them from the system file manager.
///
/// Only Windows / macOS / Linux are supported; on mobile [isSupported] is
/// false and callers fall back to a permanent delete.
class DesktopTrash {
  DesktopTrash._();

  static const _channel = MethodChannel('dev.ultrasend/desktop_trash');

  static bool get isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Attempts to move [path] to the system trash. Returns true on success.
  /// Returns false (without throwing) when unsupported or the OS call fails,
  /// letting the caller decide whether to fall back to a permanent delete.
  static Future<bool> moveToTrash(String path) async {
    if (path.isEmpty) return false;
    try {
      if (Platform.isMacOS) return await _moveToTrashMac(path);
      if (Platform.isWindows) return _moveToTrashWindows(path);
      if (Platform.isLinux) return await _moveToTrashLinux(path);
    } catch (e) {
      logChat.warning('DesktopTrash.moveToTrash failed for $path: $e');
    }
    return false;
  }

  static Future<bool> _moveToTrashMac(String path) async {
    final ok = await _channel.invokeMethod<bool>('moveToTrash', {'path': path});
    return ok ?? false;
  }

  static bool _moveToTrashWindows(String path) {
    // SHFileOperationW requires the source list to be double-null terminated.
    final fileOp = calloc<SHFILEOPSTRUCT>();
    final from = '$path\u0000'.toPwstr(allocator: calloc);
    try {
      fileOp.ref
        ..wFunc = FO_DELETE
        ..pFrom = from
        ..fFlags = FOF_ALLOWUNDO |
            FOF_NOCONFIRMATION |
            FOF_SILENT |
            FOF_NOERRORUI;
      final Win32Result(value: result, :error) = SHFileOperation(fileOp);
      return !error.isError &&
          result == 0 &&
          !fileOp.ref.fAnyOperationsAborted;
    } finally {
      calloc.free(from);
      calloc.free(fileOp);
    }
  }

  static Future<bool> _moveToTrashLinux(String path) async {
    // Prefer `gio trash` (GLib) which respects the freedesktop trash spec.
    try {
      final result = await Process.run('gio', ['trash', '--', path]);
      if (result.exitCode == 0) return true;
    } catch (_) {
      // gio not installed; fall through to manual implementation.
    }
    return _moveToTrashXdg(path);
  }

  /// Minimal freedesktop.org trash spec implementation as a fallback when
  /// `gio` is unavailable. Only handles the home trash directory.
  static Future<bool> _moveToTrashXdg(String path) async {
    final source = File(path);
    if (!await source.exists()) return false;

    final dataHome = Platform.environment['XDG_DATA_HOME'];
    final home = Platform.environment['HOME'];
    final base = (dataHome != null && dataHome.isNotEmpty)
        ? dataHome
        : (home != null && home.isNotEmpty ? p.join(home, '.local', 'share') : null);
    if (base == null) return false;

    final trashDir = Directory(p.join(base, 'Trash'));
    final filesDir = Directory(p.join(trashDir.path, 'files'));
    final infoDir = Directory(p.join(trashDir.path, 'info'));
    await filesDir.create(recursive: true);
    await infoDir.create(recursive: true);

    final baseName = p.basename(path);
    var targetName = baseName;
    var counter = 1;
    while (await File(p.join(filesDir.path, targetName)).exists() ||
        await File(p.join(infoDir.path, '$targetName.trashinfo')).exists()) {
      final ext = p.extension(baseName);
      final stem = p.basenameWithoutExtension(baseName);
      targetName = '$stem.$counter$ext';
      counter++;
    }

    final infoFile = File(p.join(infoDir.path, '$targetName.trashinfo'));
    final deletionDate = DateTime.now().toIso8601String().split('.').first;
    await infoFile.writeAsString(
      '[Trash Info]\nPath=${_encodeTrashPath(p.absolute(path))}\n'
      'DeletionDate=$deletionDate\n',
    );
    try {
      await source.rename(p.join(filesDir.path, targetName));
    } catch (_) {
      // Cross-device rename: copy then delete.
      await source.copy(p.join(filesDir.path, targetName));
      await source.delete();
    }
    return true;
  }

  static String _encodeTrashPath(String absPath) {
    return absPath
        .split('/')
        .map((seg) => Uri.encodeComponent(seg))
        .join('/');
  }
}
