import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Show [absolutePath] in Windows Explorer with the item selected.
///
/// Uses the Win32 Shell APIs `SHParseDisplayName` + `SHOpenFolderAndSelectItems`
/// instead of `explorer.exe /select,...` so that paths containing spaces,
/// quotes, or non-ASCII characters work without command-line escaping issues.
///
/// Returns `true` when the shell call succeeded, `false` otherwise. The call
/// is a no-op (returns `false`) on non-Windows platforms.
bool windowsRevealInExplorer(String absolutePath) {
  if (!Platform.isWindows) return false;

  final shell32 = _loadShell32();
  final shParse =
      shell32
          .lookupFunction<_SHParseDisplayNameNative, _SHParseDisplayNameDart>(
            'SHParseDisplayName',
          );
  final shOpen = shell32
      .lookupFunction<
        _SHOpenFolderAndSelectItemsNative,
        _SHOpenFolderAndSelectItemsDart
      >('SHOpenFolderAndSelectItems');

  final coHr = CoInitializeEx(COINIT_APARTMENTTHREADED);
  // S_OK / S_FALSE require a balancing CoUninitialize. RPC_E_CHANGED_MODE
  // means another threading model was already chosen on this thread; we must
  // not call CoUninitialize in that case.
  final shouldUninit = coHr == S_OK || coHr == S_FALSE;

  final wPath = absolutePath.toPcwstr(allocator: calloc);
  final ppidl = calloc<IntPtr>();
  try {
    final hr = shParse(wPath, nullptr, ppidl, 0, nullptr);
    if (hr != S_OK || ppidl.value == 0) {
      return false;
    }
    try {
      // cidl = 0 with a single PIDL tells the shell to open the parent folder
      // and select that item — exactly the "show in folder" UX.
      final hr2 = shOpen(ppidl.value, 0, nullptr, 0);
      return hr2 == S_OK;
    } finally {
      CoTaskMemFree(Pointer.fromAddress(ppidl.value));
    }
  } finally {
    calloc.free(wPath);
    calloc.free(ppidl);
    if (shouldUninit) CoUninitialize();
  }
}

DynamicLibrary? _shell32Cache;

DynamicLibrary _loadShell32() =>
    _shell32Cache ??= DynamicLibrary.open('shell32.dll');

typedef _SHParseDisplayNameNative =
    Int32 Function(
      Pointer<Utf16> pszName,
      Pointer pbc,
      Pointer<IntPtr> ppidl,
      Uint32 sfgaoIn,
      Pointer<Uint32> psfgaoOut,
    );

typedef _SHParseDisplayNameDart =
    int Function(
      Pointer<Utf16> pszName,
      Pointer pbc,
      Pointer<IntPtr> ppidl,
      int sfgaoIn,
      Pointer<Uint32> psfgaoOut,
    );

typedef _SHOpenFolderAndSelectItemsNative =
    Int32 Function(
      IntPtr pidlFolder,
      Uint32 cidl,
      Pointer<IntPtr> apidl,
      Uint32 dwFlags,
    );

typedef _SHOpenFolderAndSelectItemsDart =
    int Function(
      int pidlFolder,
      int cidl,
      Pointer<IntPtr> apidl,
      int dwFlags,
    );
