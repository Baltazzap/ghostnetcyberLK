# Фикс Windows-сборки Firebase / CMake

Исправляет ошибку GitHub Actions:

```text
Compatibility with CMake < 3.5 has been removed from CMake
Dependency firebase_cpp_sdk_windows/CMakeLists.txt
```

Что сделано:

- в `tools/patch_windows_title.py` добавлена строка `CMAKE_POLICY_VERSION_MINIMUM 3.5`;
- workflow Windows теперь проверяет, что патч попал в `windows/CMakeLists.txt`;
- Android push/Firebase не удалялись.

После замены файлов нужно сделать Commit/Push и снова запустить Windows build.
