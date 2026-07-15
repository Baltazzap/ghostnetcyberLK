# Исправление названия и иконки Windows

Что исправлено:

- Windows EXE теперь собирается как `GhostNetCyberVPN.exe`, без подчёркиваний.
- Заголовок окна приложения: `GhostNet Cyber VPN`.
- Название в свойствах файла Windows: `GhostNet Cyber VPN`.
- Иконка Windows генерируется из `assets/images/logo.png`, то есть такая же, как в Android-приложении.
- Android label дополнительно патчится на `GhostNet Cyber VPN`.

Важно: в `pubspec.yaml` поле `name: ghostnet_cyber_vpn` оставлено как есть. Это техническое имя Flutter-проекта, там пробелы нельзя. Пользователь его не видит.

После загрузки файлов на GitHub:

1. Сделай Commit.
2. Push origin.
3. Запусти Actions → Build Windows EXE.
4. Скачай artifact `GhostNet-Cyber-VPN-Windows`.

Внутри архива будет приложение с нормальным названием окна и иконкой.
