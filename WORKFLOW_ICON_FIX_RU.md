# Исправление сборки

Ошибка была из-за того, что `dart run flutter_launcher_icons` запускался до создания папки `android`.

Теперь workflow делает правильно:

1. `flutter create --platforms=android,windows --org ru.ghostnet .`
2. `flutter pub get`
3. `dart run flutter_launcher_icons`
4. сборка APK или Windows EXE

Это исправляет ошибку:

`PathNotFoundException: android/app/src/main/AndroidManifest.xml`
