param([string]$VcVarsPath)
$ErrorActionPreference = 'Stop'
if (-not $VcVarsPath) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $VcVarsPath = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
}
if (-not (Test-Path -LiteralPath $VcVarsPath)) { throw 'MSVC x64 compiler environment not found' }
$output = Join-Path $env:TEMP ('simplelive-capture-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$source = Join-Path (Split-Path $PSScriptRoot) 'custom_platform_view'
$flutter = (Resolve-Path (Join-Path $PSScriptRoot '../../../../windows/flutter/ephemeral')).Path
$build = Join-Path $output 'build.cmd'
@"
@echo off
call "$VcVarsPath" >nul
if errorlevel 1 exit /b 1
cd /d "$output"
cl /nologo /std:c++17 /EHsc /utf-8 /DLEGACY_CAPTURE_CALLBACK "$PSScriptRoot/capture_event_handler_test.cpp" /link windowsapp.lib /out:legacy.exe
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /utf-8 "$PSScriptRoot/capture_event_handler_test.cpp" /link windowsapp.lib /out:delegate.exe
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /utf-8 /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS /DUNICODE /D_UNICODE /I"$flutter" /I"$flutter/cpp_client_wrapper/include" "$PSScriptRoot/capture_lifecycle_test.cpp" "$source/texture_bridge.cc" "$source/texture_bridge_gpu.cc" "$source/graphics_context.cc" "$source/util/rohelper.cc" "$source/util/direct3d11.interop.cc" /link windowsapp.lib user32.lib d3d11.lib dxgi.lib /out:lifecycle.exe
exit /b %errorlevel%
"@ | Set-Content -LiteralPath $build
& $build
if ($LASTEXITCODE -ne 0) { throw 'Capture test compilation failed' }
$legacyOutput = & (Join-Path $output 'legacy.exe') 2>&1
if ($LASTEXITCODE -ne 1 -or "$legacyOutput" -notmatch '80010012') {
    throw "Legacy negative control did not reproduce expected COM disconnection: $legacyOutput"
}
Write-Output "PASS: negative control reproduced 0x80010012"
foreach ($test in @('delegate', 'lifecycle')) {
    & (Join-Path $output "$test.exe")
    if ($LASTEXITCODE -ne 0) { throw "$test failed: $LASTEXITCODE" }
}
Write-Output "Local test artifacts: $output"
