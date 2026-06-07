#Requires -Version 5.1
<#
  统一输出到 app/dist/<四段版本号>/：
    Shrimpsend-windows-<cn|intl>-<ver>.zip
    Shrimpsend-<cn|intl>-<ver>.msix
    ShrimpsendSetup-<cn|intl>-<ver>.exe

  Usage（仓库根目录）:
    .\app\scripts\package_windows.ps1
    .\app\scripts\package_windows.ps1 -Overseas
    .\app\scripts\package_windows.ps1 -All
    .\app\scripts\package_windows.ps1 -All -SkipMsix

  -All：一次性打出国内（cn）与出海（intl）全套产物；不可与 -Overseas、-ZipOnly 同用。
  默认国内；加 -Overseas 仅打出海单包。
#>
param(
    [switch] $SkipMsix,
    [switch] $SkipInno,
    [switch] $ZipOnly,
    [switch] $SkipClean,
    [switch] $Overseas,
    [switch] $All
)

$ErrorActionPreference = 'Stop'
$AppDir = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $AppDir
$ReleaseDir = Join-Path $AppDir 'build\windows\x64\runner\Release'
$VcRuntimeDir = Join-Path $AppDir 'windows\vc_redist\x64'
$InnoIss = Join-Path $RepoRoot 'scripts\shrimpsend_windows_inno.iss'
$VcRuntimeDlls = @(
    'msvcp140.dll',
    'vcruntime140.dll',
    'vcruntime140_1.dll'
)
$MinimumVcRuntimeVersion = [version]'14.40.0.0'

if ($All -and $Overseas) {
    Write-Error '-All cannot be used with -Overseas'
}
if ($All -and $ZipOnly) {
    Write-Error '-All cannot be used with -ZipOnly'
}

function Ensure-Flutter {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Error 'flutter not found on PATH'
    }
}

function Find-Iscc {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Get-PubspecVersionLine {
    $yamlRaw = Get-Content (Join-Path $AppDir 'pubspec.yaml') -Raw
    if ($yamlRaw -match '(?m)^version:\s*(\S+)') { return $Matches[1] }
    return $null
}

function Remove-ReleaseMsixArtifacts([string] $Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return }
    Get-ChildItem -LiteralPath $Dir -Filter '*.msix' -Recurse -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Assert-VcRuntimeDll([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "VC runtime DLL missing: $Path"
    }
    try {
        $versionText = (Get-Item -LiteralPath $Path).VersionInfo.FileVersion
        $version = [version]$versionText
    } catch {
        Write-Error "Unable to read VC runtime DLL version: $Path"
    }
    if ($version -lt $MinimumVcRuntimeVersion) {
        Write-Error "VC runtime DLL too old: $Path version=$version minimum=$MinimumVcRuntimeVersion."
    }
    return $version
}

function Copy-VcRuntimeDlls([string] $SourceDir, [string] $TargetDir) {
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-Error "VC runtime source missing: $SourceDir"
    }
    foreach ($dll in $VcRuntimeDlls) {
        $source = Join-Path $SourceDir $dll
        [void](Assert-VcRuntimeDll $source)
    }
    Write-Host "VC runtime -> $TargetDir"
    foreach ($dll in $VcRuntimeDlls) {
        Copy-Item -LiteralPath (Join-Path $SourceDir $dll) -Destination (Join-Path $TargetDir $dll) -Force
    }
}

function ConvertTo-FourPartVersion([string] $versionLine) {
    if ([string]::IsNullOrWhiteSpace($versionLine)) { return '1.0.0.0' }
    if ($versionLine -match '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
        return "$($Matches[1]).$($Matches[2]).$($Matches[3]).$($Matches[4])"
    }
    if ($versionLine -match '^(\d+\.\d+\.\d+(?:\.\d+)?)$') {
        return $Matches[1]
    }
    return '1.0.0.0'
}

function Clear-WindowsCmakeStaleCache {
    $windowsBuild = Join-Path $AppDir 'build\windows'
    if (-not (Test-Path -LiteralPath $windowsBuild)) { return }
    Get-ChildItem -LiteralPath $windowsBuild -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'CMakeCache.txt' -or $_.Name -eq 'CMakeFiles' } |
        ForEach-Object {
            Write-Host "Remove stale CMake: $($_.FullName)"
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
}

function Invoke-PackageWindowsRegion {
    param(
        [bool] $OverseasRegion,
        [bool] $RunFlutterBuild
    )

    $overseasDefine = if ($OverseasRegion) { 'true' } else { 'false' }
    $region = if ($OverseasRegion) { 'intl' } else { 'cn' }
    # Unicode code points avoid PowerShell source/CLI encoding issues for msix display-name.
    $appDisplayName = if ($OverseasRegion) { 'Shrimpsend' } else { -join ([char]0x867E, [char]0x4F20) }

    Write-Host ''
    Write-Host "==> Windows package: region=$region"

    if ($RunFlutterBuild) {
        Clear-WindowsCmakeStaleCache
        Write-Host 'Enable Windows font assets...'
        & (Join-Path $AppDir 'scripts\windows_font_assets.ps1') enable
        & (Join-Path $AppDir 'scripts\ensure_windows_pdfium.ps1')
        $env:WINDOWS_OVERSEAS_BUILD = if ($OverseasRegion) { '1' } else { '0' }
        Write-Host "flutter build windows --release --dart-define=OVERSEAS_BUILD=$overseasDefine (WINDOWS_OVERSEAS_BUILD=$env:WINDOWS_OVERSEAS_BUILD)"
        flutter build windows --release "--dart-define=OVERSEAS_BUILD=$overseasDefine"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "flutter build windows failed with exit code $LASTEXITCODE"
        }
    }

    if (-not (Test-Path $ReleaseDir)) {
        Write-Error "Release output missing: $ReleaseDir"
    }

    $cnExeName = -join ([char]0x867E, [char]0x4F20) + '.exe'
    $expectedExe = if ($OverseasRegion) { 'Shrimpsend.exe' } else { $cnExeName }
    $staleExe = if ($OverseasRegion) { $cnExeName } else { 'Shrimpsend.exe' }
    $expectedPath = Join-Path $ReleaseDir $expectedExe
    $stalePath = Join-Path $ReleaseDir $staleExe
    if (-not (Test-Path -LiteralPath $expectedPath)) {
        Write-Error "Expected main executable missing: $expectedPath"
    }
    if (Test-Path -LiteralPath $stalePath) {
        Write-Host "Remove stale executable: $stalePath"
        Remove-Item -LiteralPath $stalePath -Force
    }

    Copy-VcRuntimeDlls $VcRuntimeDir $ReleaseDir

    $versionLine = Get-PubspecVersionLine
    $v = ConvertTo-FourPartVersion $versionLine
    $DistDir = Join-Path (Join-Path $AppDir 'dist') $v
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

    $zipName = "Shrimpsend-windows-$region-$v.zip"
    $msixName = "Shrimpsend-$region-$v"
    $setupName = "ShrimpsendSetup-$region-$v.exe"
    $zipPath = Join-Path $DistDir $zipName
    $msixPath = Join-Path $DistDir "$msixName.msix"

    $legacySetupName = "ShrimpsendSetup-$v.exe"
    foreach ($pattern in @($zipName, "$msixName.msix", $setupName, $legacySetupName)) {
        $p = Join-Path $DistDir $pattern
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
    }

    Remove-ReleaseMsixArtifacts $ReleaseDir

    Write-Host "ZIP -> $zipPath"
    Compress-Archive -Path (Join-Path $ReleaseDir '*') -DestinationPath $zipPath -Force

    $iscc = $null
    if (-not $SkipInno -and -not $ZipOnly) {
        Remove-ReleaseMsixArtifacts $ReleaseDir
        $iscc = Find-Iscc
        if (-not $iscc) {
            Write-Warning 'Inno Setup 6 (ISCC.exe) not found — skip Setup.exe.'
        } elseif (-not (Test-Path -LiteralPath $InnoIss)) {
            Write-Warning "Inno script missing: $InnoIss"
        } else {
            Write-Host "Inno -> $(Join-Path $DistDir $setupName)"
            $isccArgs = @(
                "/DReleaseDir=$ReleaseDir",
                "/DOutputDir=$DistDir",
                "/DMyAppVersion=$v",
                "/DRegionSlug=$region"
            )
            if (-not $OverseasRegion) { $isccArgs += '/DIsCnBuild=1' }
            & $iscc @isccArgs $InnoIss
            if ($LASTEXITCODE -ne 0) {
                Write-Error "ISCC failed with exit code $LASTEXITCODE"
            }
        }
    }

    if (-not $SkipMsix -and -not $ZipOnly) {
        # cn 构建磁盘 exe 为 虾传.exe，但 msix 从 CMake BINARY_NAME 推断 Shrimpsend.exe；
        # ZIP/Inno 已完成后复制，避免便携包含双 exe，且满足 MakeAppx manifest 校验。
        $msixExePath = Join-Path $ReleaseDir 'Shrimpsend.exe'
        if (-not $OverseasRegion) {
            Write-Host "MSIX prep: copy $expectedExe -> Shrimpsend.exe"
            Copy-Item -LiteralPath $expectedPath -Destination $msixExePath -Force
        }

        Write-Host "MSIX -> $msixPath"
        # pubspec msix_config.build_windows=false；PowerShell 下请用 =false 单参数，避免 false 被当成布尔量传错
        dart run msix:create "--build-windows=false" --output-path $DistDir --output-name $msixName "--display-name=$appDisplayName"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "msix:create failed with exit code $LASTEXITCODE"
        }

        if (-not $OverseasRegion -and (Test-Path -LiteralPath $msixExePath)) {
            Remove-Item -LiteralPath $msixExePath -Force
        }
    }

    Write-Host "  [1] $zipName"
    if (-not $ZipOnly -and -not $SkipMsix) {
        Write-Host "  [2] $msixName.msix"
    }
    if (-not $ZipOnly -and -not $SkipInno -and $null -ne $iscc) {
        Write-Host "  [3] $setupName"
    }
}

Ensure-Flutter
Push-Location $AppDir
try {
    if (-not $ZipOnly) {
        if (-not $SkipClean) {
            Write-Host 'flutter clean'
            flutter clean
        }
    }

    if ($All) {
        Write-Host 'Windows -All: cn, intl'
        Invoke-PackageWindowsRegion -OverseasRegion $false -RunFlutterBuild (-not $ZipOnly)
        Invoke-PackageWindowsRegion -OverseasRegion $true -RunFlutterBuild (-not $ZipOnly)
        $v = ConvertTo-FourPartVersion (Get-PubspecVersionLine)
        Write-Host ''
        Write-Host "Done. All Windows artifacts (version $v) under: $(Join-Path $AppDir "dist\$v")"
    } else {
        Invoke-PackageWindowsRegion -OverseasRegion $Overseas.IsPresent -RunFlutterBuild (-not $ZipOnly)
        $region = if ($Overseas) { 'intl' } else { 'cn' }
        $v = ConvertTo-FourPartVersion (Get-PubspecVersionLine)
        Write-Host ''
        Write-Host "Done. Artifacts (version $v, region $region) under: $(Join-Path $AppDir "dist\$v")"
    }
}
finally {
    Pop-Location
}
