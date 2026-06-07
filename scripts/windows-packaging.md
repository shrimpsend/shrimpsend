# Windows 打包说明（MSIX + 官网 ZIP）

## 前置条件

- Windows、Flutter SDK（启用 Windows 桌面）、Visual Studio 工作负载「使用 C++ 的桌面开发」。
- 可选：`signtool`（Windows SDK）用于自有证书签名 MSIX / exe。

## 一键脚本（推荐）

在仓库根目录执行（**主入口**在 `app/scripts/`）：

```powershell
.\app\scripts\package_windows.ps1
```

兼容旧路径（内部转发到同一脚本）：

```powershell
.\scripts\package_windows.ps1
```

将依次：`flutter clean`（可跳过）→ `flutter build windows --release`（默认 **国内** `OVERSEAS_BUILD=false`）→ 复制项目内置 **VC runtime DLL** → 打 **ZIP** →（若已安装 **Inno Setup 6**）编译 **Setup** → 最后 **`msix:create`**。**产物写在 `app/dist/<四段版本号>/`**（例如 `app/dist/1.1.1.11/`），便于按版本查找；同一目录内含：`Shrimpsend-windows-<cn|intl>-*.zip`、`Shrimpsend-<cn|intl>-*.msix`、`ShrimpsendSetup-<cn|intl>-*.exe`（默认 `cn`；加 `-Overseas` 为 `intl`。版本号与目录名一致，`pubspec` 的 `x.y.z+b` → **`x.y.z.b`**）。

便携 ZIP / Inno 会把 [`app/windows/vc_redist/x64`](../app/windows/vc_redist/x64) 中的 `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll` 复制到 `Release`，并随 `Shrimpsend.exe` 同级打包。用户无需手动安装 Microsoft Visual C++ Redistributable。脚本仍然**先 ZIP/Inno、后 MSIX**，避免后续 MSIX 步骤清理 `Release` 临时文件影响便携包。

这 3 个 DLL 必须来自当前 Visual C++ Redistributable / Visual Studio C++ 工具链，且版本不能低于脚本中的最低门禁（当前为 `14.40.0.0`）。不要从旧 `vclibs` 包复制：旧版本（如 `14.34.x`）会在新工具链构建的 Windows release 中触发 `MSVCP140.dll` 访问冲突闪退。更新项目内 DLL 可在发布机执行：

```powershell
Copy-Item C:\Windows\System32\msvcp140.dll app\windows\vc_redist\x64\ -Force
Copy-Item C:\Windows\System32\vcruntime140.dll app\windows\vc_redist\x64\ -Force
Copy-Item C:\Windows\System32\vcruntime140_1.dll app\windows\vc_redist\x64\ -Force
Get-Item app\windows\vc_redist\x64\*.dll | Select-Object Name,@{Name='FileVersion';Expression={$_.VersionInfo.FileVersion}}
```

单独执行 `dart run msix:create` 且未传 `--output-path` 时，MSIX 可能落在 `Release`（例如 `app.msix`）。脚本会在打 ZIP / Inno 前 **删除 Release 下所有 `.msix`**，且 Inno 的 `[Files]` 使用 **`Excludes: "*.msix"`**，避免把 MSIX 误装进 exe 安装包。

**统一发布请以 [`app/scripts/package_windows.ps1`](../app/scripts/package_windows.ps1) 为准**（MSIX / ZIP / Inno 均输出到 **`app/dist/<版本>/`**）。

参数：

- `-All`：一次性打出国内（`cn`）与出海（`intl`）全套产物；不可与 `-Overseas`、`-ZipOnly` 同用。
- `-Overseas`：仅打出海单包，构建时传入 `OVERSEAS_BUILD=true`（默认国内 `false`）。
- `-SkipMsix`：只构建 exe + ZIP + Inno，不打 MSIX。
- `-SkipInno`：不调用 ISCC（未装 Inno 或 CI 中只要 ZIP/MSIX 时使用）。
- `-ZipOnly`：假设已构建过 Release，仅压缩 ZIP（不打 MSIX、不重新 flutter build、不跑 Inno）。
- `-SkipClean`：不执行 `flutter clean`，在上一次构建基础上增量打包（更快；正式发布建议不带此参数）。

## MSIX：cn 主程序命名与 ZIP/Inno 的差异

国内（`cn`）构建时，CMake 磁盘输出为 **`虾传.exe`**（见 [`app/windows/CMakeLists.txt`](../app/windows/CMakeLists.txt) 的 `APP_EXECUTABLE_NAME`），而 `dart run msix:create` 会从 **`BINARY_NAME`（固定 `Shrimpsend`）** 推断 manifest 中的 `Executable="Shrimpsend.exe"`，且不会校验 Release 目录内是否真有该文件。若 cn build 后直接打 MSIX，MakeAppx 会报 manifest 校验失败（`Shrimpsend.exe doesn't exist in the package`）。

[`app/scripts/package_windows.ps1`](../app/scripts/package_windows.ps1) 的处理顺序：

1. ZIP / Inno 仍只打包 **`虾传.exe`**（与 OTA 更新、`appExecutableBaseName` 一致）。
2. **MSIX 前**临时复制 `虾传.exe` → `Shrimpsend.exe`，供 MakeAppx 通过校验；MSIX 成功后删除 Release 内临时副本。
3. cn MSIX 包内入口 exe 为 `Shrimpsend.exe`（与 `identity_name`、`execution_alias: shrimpsend` 一致）；开始菜单显示名仍由 `--display-name=虾传` 控制。

**intl**（`-Overseas`）构建本身即为 `Shrimpsend.exe`，无需复制。单独执行 `dart run msix:create` 时：cn build 后须先复制 exe，或始终走统一打包脚本。

## MSIX：安装位置与快捷方式（系统限制说明）

- **不能自选安装目录**是 MSIX 的设计：应用由系统装入受管位置（真实文件多在 `C:\Program Files\WindowsApps\` 下加密/受限目录，不建议用户手动浏览）。
- 安装后请从 **「开始」菜单** 启动 **Shrimpsend**（安装程序会自动钉在开始菜单）；本仓库在 `msix_config` 中配置了 **`execution_alias: shrimpsend`**，可在 **Win+R** 或终端输入 **`shrimpsend`** 启动（系统会在「WindowsApps」下提供别名入口）。
- MSIX **无法在清单里像传统安装包那样指定「必定创建桌面快捷方式」**；用户可从开始菜单将图标 **固定到任务栏** 或 **拖到桌面** 创建快捷方式。若必须「向导可选路径 + 默认桌面图标」，请使用下文 **Inno** 渠道。

## Inno Setup（官网安装包）

- 需安装 [Inno Setup 6](https://jrsoftware.org/isdl.php)，脚本为 [`shrimpsend_windows_inno.iss`](shrimpsend_windows_inno.iss)：向导为 **英文界面**（依赖自带的 `Default.isl`，避免未安装中文语言包时编译失败）；结束页的 [`install_notes_inno.txt`](install_notes_inno.txt) 仍为 **中英双语** 并显示 **`{app}`** 路径。向导中 **可选安装目录**、**默认勾选创建桌面快捷方式**。
- **安装/升级时若应用已在运行**：安装器会通过 Restart Manager 与 `taskkill` 自动强制结束 `Shrimpsend.exe` / `虾传.exe`（与 ZIP 内更新行为一致），无需用户手动关进程。
- **cn / intl 品牌**：`RegionSlug=cn` 时主程序为 **`虾传.exe`**、快捷方式/向导标题为「虾传」，安装目录仍为 `Program Files\Shrimpsend`；`intl` 为 **`Shrimpsend.exe`**。构建前由 `package_windows.ps1` 设置 `WINDOWS_OVERSEAS_BUILD`（与 `OVERSEAS_BUILD` 一致）。
- **中文不乱码**：`shrimpsend_windows_inno.iss` 与 `install_notes_inno.txt` 须 **UTF-8 BOM**；cn 包额外传 `/DIsCnBuild=1`，**勿**用 `/D` 传中文显示名。
- **cn OTA ZIP** 内主程序文件名为 **`虾传.exe`**（与 `app/lib/main.dart` 中 `appExecutableBaseName` 一致）。
- 单独编译示例（`OutputDir` 建议与脚本一致，使用版本子目录；`RegionSlug` 为 `cn` 或 `intl`）：`"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DReleaseDir="...\Release" /DOutputDir="...\app\dist\1.1.1.11" /DMyAppVersion=1.1.1.11 /DRegionSlug=cn scripts\shrimpsend_windows_inno.iss`

## 仅打 MSIX（在 `app` 目录）

推荐仍使用 `.\app\scripts\package_windows.ps1 -SkipInno`（或 `-SkipMsix` 以外的参数），自动处理 cn exe 复制与输出路径。

若手动在 `app` 目录执行，**国内 cn build** 须在 `msix:create` 前复制主程序（intl 可跳过）：

```powershell
cd app
flutter clean
flutter build windows --release
Copy-Item -LiteralPath 'build\windows\x64\runner\Release\虾传.exe' `
  -Destination 'build\windows\x64\runner\Release\Shrimpsend.exe' -Force
dart run msix:create "--build-windows=false"
Remove-Item -LiteralPath 'build\windows\x64\runner\Release\Shrimpsend.exe' -Force -ErrorAction SilentlyContinue
```

`pubspec.yaml` 的 `msix_config.build_windows` 已为 `false`，与一键脚本一致：先 `flutter build`，再只打包 MSIX。

### CMake `generator platform: x64` 不匹配

**不正常**，多为旧版 Flutter 留下的 `build/windows` CMake 缓存与当前 `x64` 目录结构冲突。处理：

```powershell
cd app
flutter clean
Remove-Item -Recurse -Force build\windows -ErrorAction SilentlyContinue
flutter pub get
flutter build windows --release
dart run msix:create "--build-windows=false"
```

或直接使用 `.\app\scripts\package_windows.ps1`（脚本会在构建前清理陈旧 CMake 缓存）。

### `55 packages have newer versions...`

来自 `flutter pub get` 的**提示**，与 MSIX/CMake 失败无关，可忽略；需要时再执行 `flutter pub outdated`。

微软商店提交可使用：

```powershell
dart run msix:create --store
```

（需在 [`app/pubspec.yaml`](../app/pubspec.yaml) 的 `msix_config` 中填写与 Partner Center 一致的 `publisher`、`identity_name` 等。）

侧载签名：在 `msix_config` 配置 `certificate_path`、`certificate_password`，或设置环境变量后在 CI 注入（勿把密码写入仓库）。

## 分发策略（简要）

- **官网 / 直链**：提供 `app/dist/<版本>/` 下的 ZIP 或 Inno 安装包（与解压目录布局一致）；应用内 ZIP 更新有效。
- **微软商店 / MSIX**：由商店更新；运行时为 MSIX 包时会**自动禁用**内置 ZIP 更新器。

## 签名与 CI

- **微软商店**：Partner Center 提交包；本地可用 `dart run msix:create --store`，在 `msix_config` 填写与仪表盘一致的 `publisher`、`identity_name`。签名常由商店完成，无需在 CI 保管商店专用证书。
- **侧载 MSIX**：在 `msix_config` 配置 `certificate_path`（如 `.pfx`）与 `certificate_password`，或使用 `signtool_options`。勿将 `.pfx` 与密码提交进 Git；CI 用密钥库注入（如 GitHub Secrets + base64 解码）。
- **ZIP / Inno exe**：对 `Shrimpsend.exe` 或安装包做 Authenticode，减轻 SmartScreen。

示例流水线骨架：[`ci-msix-windows.example.yml`](ci-msix-windows.example.yml)。
