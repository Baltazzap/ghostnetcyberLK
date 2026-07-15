# GhostNet Cyber VPN — Firebase Push Android

Добавлено в приложение:

- Firebase Core;
- Firebase Messaging;
- регистрация FCM token в API;
- запрос разрешения на уведомления;
- Android notification channel `ghostnet_notifications`;
- foreground-уведомления через локальный notification channel.

Файл `google-services.json` не включён в архив специально. Его нужно положить в корень приложения рядом с `pubspec.yaml` перед сборкой.
