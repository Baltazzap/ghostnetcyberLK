# GhostNet Cyber VPN — Firebase Push Android Desugar Fix

Исправление сборки Android для `flutter_local_notifications`.

Что исправлено:

- включено `coreLibraryDesugaringEnabled` / `isCoreLibraryDesugaringEnabled`;
- добавлена зависимость `com.android.tools:desugar_jdk_libs`;
- исправление применяется автоматически после `flutter create` через `tools/patch_app_name.py`.

Файл `google-services.json` по-прежнему должен лежать в `app/google-services.json` или рядом с `pubspec.yaml`.
