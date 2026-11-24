; =====================================================================
; Inno Setup Script: SimpleLive Windows Desktop Installer
; Repository: https://github.com/June6699/dart_simple_live
; =====================================================================

#ifndef MyAppName
#define MyAppName "SimpleLive"
#endif

#ifndef MyAppFullName
#define MyAppFullName "SimpleLive"
#endif

#ifndef MyAppVersion
#define MyAppVersion "1.13.2"
#endif

#ifndef MyAppPublisher
#define MyAppPublisher "June6699"
#endif

#ifndef MyAppURL
#define MyAppURL "https://github.com/June6699/dart_simple_live"
#endif

#ifndef MyAppExeName
#define MyAppExeName "simple_live_app.exe"
#endif

#ifndef MyAppIcoPath
#define MyAppIcoPath "..\..\runner\resources\app_icon.ico"
#endif

#ifndef SourceDir
#define SourceDir "..\..\..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "."
#endif

#ifndef OutputFilename
#define OutputFilename "SimpleLive_v" + MyAppVersion + "_Setup"
#endif

[Setup]
AppId={{A4C89D12-3E6B-4F71-B592-8E304892FA10}
AppName={#MyAppFullName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\app_icon.ico
PrivilegesRequiredOverridesAllowed=dialog
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename={#OutputFilename}
SetupIconFile={#MyAppIcoPath}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyAppIcoPath}"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppFullName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#MyAppFullName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Registry]
; Applications
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#MyAppFullName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\app_icon.ico,0"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletekey

; App Paths (Win+R simplelive or simple_live_app)
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\simplelive.exe"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\simplelive.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}"; Flags: uninsdeletekey

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppFullName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
