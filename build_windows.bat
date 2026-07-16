@echo off
setlocal
cd /d %~dp0

echo Creating Android and Windows platform files if missing...
flutter create --platforms=android,windows --org ru.ghostnet . || goto :error

echo Applying application patches...
python tools\patch_app_name.py || goto :error
python tools\patch_windows_title.py || goto :error

echo Installing dependencies...
flutter pub get || goto :error

echo Running security checks...
python tools\security_check.py || goto :error

echo Formatting and analyzing project...
dart format lib\main.dart || goto :error
flutter analyze --no-fatal-infos --no-fatal-warnings || goto :error

echo Generating launcher icons...
dart run flutter_launcher_icons || goto :error

echo Building Windows app...
flutter build windows --release || goto :error

echo Building Windows installer...
python tools\build_windows_installer.py || goto :error

echo Creating update manifest...
python tools\create_update_manifest.py --output release\version.json || goto :error

echo.
echo Windows installer:
echo release\GhostNet-Cyber-VPN-Setup.exe
echo.
echo Update manifest:
echo release\version.json
pause
exit /b 0

:error
echo.
echo BUILD FAILED. Error code: %errorlevel%
pause
exit /b %errorlevel%
