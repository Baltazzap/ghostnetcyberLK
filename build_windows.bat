@echo off
cd /d %~dp0
echo Creating Android/Windows platform files if missing...
flutter create --platforms=android,windows --org ru.ghostnet .
echo Installing dependencies...
flutter pub get
echo Generating launcher icons...
dart run flutter_launcher_icons
echo Building Windows app...
flutter build windows --release
echo.
echo Windows Release folder:
echo build\windows\x64\runner\Release
pause
