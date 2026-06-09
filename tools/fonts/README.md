# ShrimpSend font assets

Downloads OFL-licensed **WenYuan Sans SC** for **Windows Flutter builds only**.

- `app/assets/fonts/windows/` — bundled when building Windows
- Other Flutter platforms and Web use system fonts (no bundled font file)

## Build

```bash
./tools/fonts/build.sh
# or, for Windows Flutter only:
python3 tools/fonts/build.py --app-windows-only
```

Before `flutter build windows`, enable pubspec registration:

```bash
./app/scripts/windows_font_assets.sh enable
```

Before mobile/macOS/Linux builds, disable it (default in repo):

```bash
./app/scripts/windows_font_assets.sh disable
```

Windows packaging scripts call `enable` automatically via `windows_font_assets.ps1` (PowerShell). On Unix/macOS CI, use `windows_font_assets.sh`.

## Licenses

See `LICENSES/NOTICE.txt`. Bundled on Windows only: WenYuan Sans SC / 文源黑体 (OFL 1.1).
