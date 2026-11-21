param([string]$VcVarsPath)
$ErrorActionPreference = 'Stop'
if (-not $VcVarsPath) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $VcVarsPath = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
}
if (-not (Test-Path -LiteralPath $VcVarsPath)) { throw 'MSVC x64 compiler environment not found' }
$output = Join-Path $env:TEMP ('simplelive-native-recorder-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$runner = Split-Path $PSScriptRoot
$fixture = Join-Path $PSScriptRoot 'native_crash_recorder_test.cpp'
$source = Join-Path $runner 'native_crash_recorder.cpp'
$build = Join-Path $output 'build.cmd'
@"
@echo off
call "$VcVarsPath" >nul
if errorlevel 1 exit /b 1
cd /d "$output"
cl /nologo /std:c++17 /EHsc /W4 /WX /utf-8 "$fixture" "$source" /link dbghelp.lib shell32.lib ole32.lib /out:test.exe
exit /b %errorlevel%
"@ | Set-Content -LiteralPath $build
& $build
if ($LASTEXITCODE -ne 0) { throw 'Native test compilation failed' }
foreach ($mode in @('capture', 'normal', 'full', 'invalid')) {
    $folder = Join-Path $output $mode
    if ($mode -eq 'invalid') {
        'blocked' | Set-Content -LiteralPath $folder
    } else {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
    if ($mode -eq 'full') {
        1..5 | ForEach-Object { 'existing-evidence' | Set-Content -LiteralPath (Join-Path $folder "$_.dmp") }
    }
    & (Join-Path $output 'test.exe') $folder $mode
    if ($LASTEXITCODE -ne 0) { throw "$mode failed: $LASTEXITCODE" }
    if ($mode -eq 'full') {
        Get-ChildItem -LiteralPath $folder -Filter '*.dmp' | ForEach-Object {
            if ((Get-Content -LiteralPath $_.FullName -Raw).Trim() -ne 'existing-evidence') {
                throw 'Existing dump was changed'
            }
        }
    }
    Write-Output "PASS: $mode"
}
Write-Output "Fixture artifacts (not user crash evidence): $output"
