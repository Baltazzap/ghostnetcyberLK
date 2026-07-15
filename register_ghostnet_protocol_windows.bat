@echo off
set "EXE=%~dp0GhostNetCyberVPN.exe"
reg add "HKCU\Software\Classes\ghostnet" /ve /d "URL:GhostNet Payment Return" /f
reg add "HKCU\Software\Classes\ghostnet" /v "URL Protocol" /d "" /f
reg add "HKCU\Software\Classes\ghostnet\shell\open\command" /ve /d "\"%EXE%\" \"%%1\"" /f
echo.
echo GhostNet protocol registered: ghostnet://
echo EXE: %EXE%
pause
