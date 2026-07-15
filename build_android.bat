@echo off
cd /d %~dp0
echo Creating Android/Windows platform files if missing...
flutter create --platforms=android,windows --org ru.ghostnet .
echo Installing dependencies...
flutter pub get
echo Generating launcher icons...
dart run flutter_launcher_icons
echo Building Android APK...
flutter build apk --release
echo.
echo APK path:
echo build\app\outputs\flutter-apk\app-release.apk
pause
