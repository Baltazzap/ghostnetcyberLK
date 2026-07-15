# Финальный фикс Android и Windows

## Android сразу закрывался

Причина была в том, что мы поменяли `applicationId` на:

```text
ru.ghostnet.cybervpn
```

но `MainActivity.kt` после `flutter create` оставался в старом пакете проекта. Из-за этого Android мог не находить главный Activity-класс и приложение закрывалось сразу после запуска.

Теперь `tools/patch_app_name.py` исправляет:

- название приложения на `GhostNet Cyber VPN`
- `namespace`
- `applicationId`
- пакет `MainActivity.kt`

## Windows окно называлось ghostnet_cyber_vpn

Причина была в том, что в новых версиях Flutter окно создаётся через:

```cpp
window.Create(L"ghostnet_cyber_vpn", origin, size)
```

а старый фикс искал только `CreateAndShow`.

Теперь `tools/patch_windows_title.py` исправляет оба варианта:

- `window.Create(...)`
- `window.CreateAndShow(...)`

Название окна будет:

```text
GhostNet Cyber VPN
```

EXE будет:

```text
GhostNetCyberVPN.exe
```

## После обновления

1. Скопируй файлы поверх проекта.
2. Commit.
3. Push.
4. Запусти заново Build Android APK и Build Windows EXE.
5. На телефоне удали старое приложение и установи новый APK.
