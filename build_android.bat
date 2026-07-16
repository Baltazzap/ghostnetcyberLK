@echo off
setlocal
cd /d %~dp0

echo Creating Android and Windows platform files if missing...
flutter create --platforms=android,windows --org ru.ghostnet . || goto :error

echo Applying Android security and application patches...
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

echo Building Android APK...
flutter build apk --release || goto :error

echo.
echo APK path:
echo build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0

:error
echo.
echo BUILD FAILED. Error code: %errorlevel%
pause
exit /b %errorlevel%
