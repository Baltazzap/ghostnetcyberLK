# Исправление google-services.json

Workflow теперь ищет Firebase Android config в двух местах:

- `google-services.json` рядом с `pubspec.yaml`
- `app/google-services.json`

В логах GitHub Actions будет показан найденный путь.
