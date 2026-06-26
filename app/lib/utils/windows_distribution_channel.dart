import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Whether this Windows build runs inside an MSIX package (Microsoft Store or sideload).
///
/// Used to skip [flutter_desktop_updater] ZIP installs — those replace loose files under
/// the install directory and must not run for packaged apps.
bool get isWindowsMsixPackaged {
  if (!Platform.isWindows) return false;

  final lengthPtr = calloc<Uint32>();
  try {
    final rc = GetCurrentPackageFullName(
      lengthPtr,
      null,
    );
    if (rc == APPMODEL_ERROR_NO_PACKAGE) return false;
    if (rc == ERROR_INSUFFICIENT_BUFFER && lengthPtr.value > 0) return true;
    return rc == ERROR_SUCCESS;
  } finally {
    calloc.free(lengthPtr);
  }
}
