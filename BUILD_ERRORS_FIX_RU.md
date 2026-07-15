# Исправление ошибок сборки Android и Windows

## Что исправлено

### Android APK

Ошибка была из-за того, что файл `android/app/build.gradle.kts` использует Kotlin-синтаксис:

```kotlin
namespace = "ru.ghostnet.cybervpn"
applicationId = "ru.ghostnet.cybervpn"
```

А старый фикс вставлял Groovy-синтаксис:

```gradle
namespace "ru.ghostnet.cybervpn"
applicationId "ru.ghostnet.cybervpn"
```

Из-за этого Gradle падал с ошибкой `Unexpected tokens`.

Теперь скрипт `tools/patch_app_name.py` правильно различает:

- `build.gradle`
- `build.gradle.kts`

### Windows EXE

Ошибка была из-за изменения `Runner.rc`.

Теперь `tools/patch_windows_title.py` больше не трогает `Runner.rc`, поэтому ошибка:

```text
undefined keyword or key name: FileDescription
```

уйдёт.

Скрипт меняет только:

- заголовок окна в `windows/runner/main.cpp`
- имя EXE в `windows/CMakeLists.txt`

## После обновления

1. Скопируй файлы поверх проекта.
2. Commit.
3. Push.
4. Запусти GitHub Actions заново.
