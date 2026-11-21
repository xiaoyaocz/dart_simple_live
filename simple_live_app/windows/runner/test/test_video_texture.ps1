$ErrorActionPreference = 'Stop'
$app = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$build = Join-Path $app 'build/windows/x64'
$overlay = (Resolve-Path (Join-Path $build 'simplelive_media_kit_video')).Path
$angle = (Resolve-Path (Join-Path $build 'ANGLE')).Path
$release = (Resolve-Path (Join-Path $build 'runner/Release')).Path
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
$work = Join-Path $env:TEMP ('simplelive-video-texture-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$command = Join-Path $work 'test.cmd'
@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b 1
cd /d "$work"
cl /nologo /std:c++17 /EHsc /DUNICODE /D_UNICODE /I"$overlay" /I"$angle/include" "$PSScriptRoot/video_texture_test.cpp" "$overlay/angle_surface_manager.cc" "$overlay/utils.cc" /link d3d11.lib dxgi.lib user32.lib "$angle/lib/libEGL.dll.lib" "$angle/lib/libGLESv2.dll.lib" /out:video_texture_test.exe
if errorlevel 1 exit /b 1
set "PATH=$release;%PATH%"
video_texture_test.exe
exit /b %errorlevel%
"@ | Set-Content -LiteralPath $command
& $command
exit $LASTEXITCODE
