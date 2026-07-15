# Исправление названия окна Windows

Проблема: после сборки Windows окно могло называться техническим именем проекта:

```text
ghostnet_cyber_vpn
```

Теперь в workflow после `flutter create` запускается:

```bash
python tools/patch_windows_title.py
```

Скрипт меняет:

- заголовок окна на `GhostNet Cyber VPN`
- имя EXE на `GhostNetCyberVPN.exe`
- свойства файла Windows на `GhostNet Cyber VPN`

Важно: `pubspec.yaml -> name: ghostnet_cyber_vpn` может оставаться таким. Это техническое имя Flutter-проекта.
