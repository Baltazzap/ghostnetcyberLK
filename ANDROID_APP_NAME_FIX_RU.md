# Исправление названия приложения на Android

Проблема была в том, что GitHub Actions каждый раз выполняет:

```bash
flutter create --platforms=android --org ru.ghostnet .
```

Flutter заново создаёт AndroidManifest.xml и ставит название из технического имени проекта:

```text
ghostnet_cyber_vpn
```

Теперь после `flutter create` автоматически запускается:

```bash
python tools/patch_app_name.py
```

Скрипт меняет Android label на:

```text
GhostNet Cyber VPN
```

Важно: строка в `pubspec.yaml`

```yaml
name: ghostnet_cyber_vpn
```

может оставаться такой. Это техническое имя проекта Flutter. Пользователь его не должен видеть.
