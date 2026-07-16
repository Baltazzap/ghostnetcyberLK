# Финальная настройка цифровой подписи

## Android

Постоянный Android JKS создан отдельно и не находится в GitHub-архиве.

Приватный архив содержит:

```text
ghostnet-release.jks
ANDROID_KEYSTORE_BASE64.txt
ANDROID_SIGNING_SECRETS.txt
SET_GITHUB_ANDROID_SECRETS.ps1
```

Запустить приватный скрипт после `gh auth login`. Он сам добавит четыре
Android-секрета в GitHub.

После этого Android Action соберёт подписанный APK и проверит его через
`apksigner`.

## Windows

Windows workflow полностью подготовлен к Authenticode-подписи.

Пока доверенный PFX не добавлен:

- Windows-установщик продолжает собираться;
- Action выводит предупреждение;
- установщик остаётся без доверенной подписи.

После получения доверенного PFX запустить:

```powershell
powershell -ExecutionPolicy Bypass `
  -File tools\configure_github_signing.ps1 `
  -WindowsPfxPath "C:\Путь\certificate.pfx" `
  -WindowsPfxPassword "ПАРОЛЬ"
```

После этого GitHub автоматически подпишет:

```text
GhostNetCyberVPN.exe
GhostNet-Cyber-VPN-Setup.exe
```

Самоподписанный PFX не убирает SmartScreen. Поэтому он намеренно не
добавлен в релизный проект.
