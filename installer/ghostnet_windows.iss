#ifndef AppVersion
  #define AppVersion "1.0.4"
#endif

#ifndef AppBuild
  #define AppBuild "5"
#endif

#define AppName "GhostNet Cyber VPN"
#define AppExeName "GhostNetCyberVPN.exe"
#define AppPublisher "GhostNet Cyber VPN"
#define AppUrl "https://ghostnetcyber.ru"
#define AppSupportUrl "https://t.me/baltazzap"
#define AppFullVersion AppVersion + "." + AppBuild

[Setup]
AppId={{C78E1F60-8DB7-4C6F-AF72-E2381D6EAA21}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppSupportUrl}
AppUpdatesURL={#AppUrl}/downloads/
AppComments=Безопасный доступ к интернету без лишних настроек
VersionInfoVersion={#AppFullVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\GhostNet Cyber VPN
DefaultGroupName=GhostNet Cyber VPN
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\release
OutputBaseFilename=GhostNet-Cyber-VPN-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
WizardResizable=no
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes
AllowNoIcons=yes
UsePreviousAppDir=yes
SetupLogging=yes
MinVersion=10.0.17763

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные ярлыки:"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\GhostNet Cyber VPN"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\GhostNet Cyber VPN"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\ghostnet"; ValueType: string; ValueName: ""; ValueData: "URL:GhostNet Cyber VPN"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\ghostnet"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\ghostnet\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKCU; Subkey: "Software\Classes\ghostnet\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Запустить GhostNet Cyber VPN"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data\flutter_assets\NOTICES.Z"
