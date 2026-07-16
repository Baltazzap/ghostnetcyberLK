# Исправление проверки versioned URL

Ошибка:

```text
Updater check failed: Windows URL must point to installer
```

Причина: проверочный скрипт всё ещё ожидал старое имя:

```text
GhostNet-Cyber-VPN-Setup.exe
```

Но после исправления кэширования релизы имеют уникальные имена:

```text
GhostNet-Cyber-VPN-Setup-1.0.6-7.exe
GhostNet-Cyber-VPN-1.0.6-7.apk
```

Теперь `tools/update_system_check.py`:

- принимает версионные имена Windows EXE;
- принимает версионные имена Android APK;
- проверяет совпадение старых и новых полей `version.json`;
- продолжает проверять HTTPS-ссылки и соответствие версии `pubspec.yaml`.

Версию приложения менять не требуется: это исправление только CI-проверки.
