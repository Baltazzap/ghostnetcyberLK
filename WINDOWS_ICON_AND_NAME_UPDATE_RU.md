# Обновление Windows-иконки и названия

Что изменено:

- Windows-иконка берётся из `assets/images/logo.png`, как и на телефоне.
- Видимое название окна и приложения на Windows теперь `GhostNet Cyber VPN`.
- Имя `.exe` в сборке тоже будет `GhostNet Cyber VPN.exe` вместо варианта с `_`.
- Обновлён workflow `.github/workflows/build_windows.yml`.

Что сделать:

1. Залей изменённые файлы в репозиторий.
2. Запусти `Actions -> Build Windows EXE -> Run workflow`.
3. Скачай артефакт `GhostNet-Cyber-VPN-Windows`.
