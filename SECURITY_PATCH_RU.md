# GhostNet Cyber VPN — Security Patch

В архиве выполнен первый релизный пакет безопасности для распространения приложения через собственный сайт.

## Что изменено

- Bearer-токен перенесён из `SharedPreferences` в `flutter_secure_storage`.
- Добавлен автоматический перенос токена у уже авторизованных пользователей.
- Админские права теперь определяются только полем `is_admin`, которое возвращает API.
- Telegram username больше не отправляется как `telegram_id`.
- Для API-запросов установлен таймаут 15 секунд.
- Добавлены понятные ошибки таймаута, отсутствия интернета и сетевого клиента.
- На Android запрещён cleartext HTTP.
- На Android отключён Auto Backup для защищённого хранилища.
- Минимальная версия Android установлена на API 23.
- Flutter в GitHub Actions закреплён на версии 3.44.0.
- В workflow добавлены `flutter analyze`, форматирование, автоматический security-check и тесты.
- Для Windows workflow добавлена установка Visual C++ ATL, необходимая `flutter_secure_storage`.
- Локальные BAT-файлы теперь автоматически применяют патчи и запускают проверки.

## Что нужно сохранить в GitHub

Для Android Firebase по-прежнему нужен настоящий `google-services.json`.

Поддерживаются два варианта:

1. Положить `google-services.json` рядом с `pubspec.yaml`.
2. Создать GitHub Secret `GOOGLE_SERVICES_JSON_BASE64` с содержимым файла в Base64.

Без настоящей Firebase-конфигурации Android workflow намеренно завершится ошибкой, чтобы не собрать приложение с неработающими уведомлениями.

## Сборка

Android:

```bat
build_android.bat
```

Windows:

```bat
build_windows.bat
```

Либо загрузить проект в GitHub — workflows запустятся автоматически при push в `main` или `master`.

## Версия

Версия приложения обновлена до `1.0.1+2`.
