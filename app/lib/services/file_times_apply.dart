import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:win32/win32.dart';

import 'mtime_util.dart';

final Logger _log = Logger('ultrasend.file_times');

const _channel = MethodChannel('dev.ultrasend/file_times');

/// After a received file is written to disk, set:
/// - **modified** = source file mtime ([modifiedMs])
/// - **created** = transfer completion time (now)
///
/// On Windows, setting only last-write to an older date can cause the OS to
/// align creation time with modification time; we set both explicitly.
Future<void> applyReceivedFileTimestamps(String path, int? modifiedMs) async {
  if (modifiedMs == null || modifiedMs <= 0) return;
  if (!File(path).existsSync()) return;

  final modified = DateTime.fromMillisecondsSinceEpoch(modifiedMs);
  final createdMs = DateTime.now().millisecondsSinceEpoch;

  if (Platform.isWindows) {
    if (_applyWindowsFileTimes(path, modified, DateTime.now())) return;
  } else if (Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
    try {
      final ok = await _channel.invokeMethod<bool>('applyReceived', {
        'path': path,
        'modifiedMs': modifiedMs,
        'createdMs': createdMs,
      });
      if (ok == true) return;
    } catch (e) {
      _log.fine('applyReceived platform channel failed for $path: $e');
    }
  }

  applyMtimeMs(path, modifiedMs);
}

bool _applyWindowsFileTimes(
  String path,
  DateTime modified,
  DateTime created,
) {
  final lpFileName = path.toPcwstr(allocator: calloc);
  try {
    final Win32Result(value: handle, :error) = CreateFile(
      lpFileName,
      FILE_WRITE_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
      nullptr,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      null,
    );
    if (error.isError || handle == INVALID_HANDLE_VALUE) {
      _log.warning(
        'CreateFile for timestamps failed ($error): $path',
      );
      return false;
    }

    final ftCreated = calloc<FILETIME>();
    final ftModified = calloc<FILETIME>();
    try {
      _dateTimeToFileTime(created.toUtc(), ftCreated);
      _dateTimeToFileTime(modified.toUtc(), ftModified);
      final Win32Result(value: ok, :error) = SetFileTime(
        handle,
        ftCreated,
        nullptr,
        ftModified,
      );
      if (error.isError || !ok) {
        _log.warning('SetFileTime failed ($error): $path');
        return false;
      }
      return true;
    } finally {
      calloc.free(ftCreated);
      calloc.free(ftModified);
      CloseHandle(handle);
    }
  } finally {
    calloc.free(lpFileName);
  }
}

/// Windows FILETIME: 100-ns intervals since 1601-01-01 UTC.
void _dateTimeToFileTime(DateTime utc, Pointer<FILETIME> ft) {
  const epoch1601Micros = 116444736000000000; // 100-ns units from 1601 to 1970
  final hundredNanos =
      utc.microsecondsSinceEpoch * 10 + epoch1601Micros;
  ft.ref.dwLowDateTime = hundredNanos & 0xFFFFFFFF;
  ft.ref.dwHighDateTime = (hundredNanos >> 32) & 0xFFFFFFFF;
}
