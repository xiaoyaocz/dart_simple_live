param(
    [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
    [Parameter(Mandatory = $true)][string]$OutputFile
)
$ErrorActionPreference = 'Stop'
$release = (Resolve-Path -LiteralPath $ReleaseDirectory).Path
foreach ($required in @('simple_live_app.exe', 'flutter_windows.dll', 'data\app.so')) {
    if (-not (Test-Path -LiteralPath (Join-Path $release $required))) { throw "Missing release asset: $required" }
}
# The app's pubspec is the sole source of installer metadata and UI version text.
$pubspec = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../pubspec.yaml')).Path
$versionMatch = [regex]::Match([IO.File]::ReadAllText($pubspec), '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$')
if (-not $versionMatch.Success) { throw 'pubspec.yaml must contain a numeric version: major.minor.patch+build' }
$parts = @(1..4 | ForEach-Object { [int]::Parse($versionMatch.Groups[$_].Value) })
if (@($parts | Where-Object { $_ -gt 65535 }).Count -gt 0) { throw 'Windows assembly version components must not exceed 65535' }
$nameVersion = '{0}.{1}.{2}' -f $parts[0], $parts[1], $parts[2]
$fullVersion = '{0}.{1}.{2}.{3}' -f $parts[0], $parts[1], $parts[2], $parts[3]
$appVersion = $nameVersion + '+' + $parts[3]
$releaseVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $release 'simple_live_app.exe')).FileVersion
if ($releaseVersion -ne $appVersion) { throw "Stale Release payload: expected $appVersion from pubspec, found $releaseVersion. Rebuild Windows first." }
$output = [IO.Path]::GetFullPath($OutputFile)
if (Test-Path -LiteralPath $output) { throw "Output already exists: $output" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
$versionSource = $output + '.version.cs'
$versionText = 'internal static class InstallerVersion { internal const string Name = "' + $nameVersion + '"; internal const string Full = "' + $fullVersion + '"; }'
[IO.File]::WriteAllText($versionSource + '.tmp', $versionText, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath ($versionSource + '.tmp') -Destination $versionSource -Force
$payload = $output + '.payload.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($release, $payload)
$payloadHash = $output + '.payload.sha256'
(Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash | Set-Content -Encoding ascii -LiteralPath $payloadHash
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$icon = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../runner/resources/app_icon.ico')).Path
$manifest = Join-Path $PSScriptRoot 'SimpleLiveInstaller.manifest'
& $compiler /nologo /target:winexe /platform:x64 /codepage:65001 /optimize+ "/out:$output" "/win32icon:$icon" "/win32manifest:$manifest" "/resource:$icon,SimpleLive.Icon" "/resource:$payload,SimpleLive.Payload" "/resource:$payloadHash,SimpleLive.Payload.SHA256" /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll (Join-Path $PSScriptRoot 'SimpleLiveInstaller.cs') $versionSource
if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed: $LASTEXITCODE" }
Get-FileHash -LiteralPath $output -Algorithm SHA256
