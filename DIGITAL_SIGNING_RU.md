# Цифровая подпись GhostNet Cyber VPN

Текущая версия проекта:

```text
1.0.5+6
```

## Важно перед началом

### Android

Все будущие APK должны подписываться одним и тем же JKS-ключом. Если ключ
потерять, выпустить обновление поверх установленного приложения будет
невозможно.

Старые APK GhostNet собирались без постоянного собственного ключа. После
перехода на новый постоянный JKS пользователям может потребоваться один раз
удалить старое приложение и установить подписанную версию заново. После
этого следующие версии будут обновляться поверх неё.

### Windows

Для публичной доверенной подписи нужен сертификат Code Signing от
доверенного центра сертификации или облачная служба подписи.

Самоподписанный сертификат не убирает предупреждение SmartScreen у обычных
пользователей.

Этот проект настроен для сертификата в формате PFX. Если поставщик выдаёт
USB-токен или облачный ключ без экспортируемого PFX, понадобится интеграция
конкретного поставщика либо собственный Windows Runner.

---

# 1. Создание постоянного ключа Android

На своём Windows-компьютере, в корне проекта, запустить:

```powershell
powershell -ExecutionPolicy Bypass -File tools\create_android_signing_key.ps1
```

Скрипт попросит придумать пароль и создаст:

```text
signing\ghostnet-release.jks
signing\ANDROID_KEYSTORE_BASE64.txt
```

Сохранить JKS и пароль минимум в двух защищённых местах.

## GitHub Secrets для Android

Открыть:

```text
GitHub → Repository → Settings → Secrets and variables
→ Actions → New repository secret
```

Создать четыре секрета:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Значения:

```text
ANDROID_KEYSTORE_BASE64 = содержимое ANDROID_KEYSTORE_BASE64.txt
ANDROID_KEYSTORE_PASSWORD = придуманный пароль
ANDROID_KEY_ALIAS = ghostnet_release
ANDROID_KEY_PASSWORD = тот же пароль
```

GitHub Actions восстановит JKS только на время сборки, подпишет APK,
проверит его через apksigner и удалит ключ с Runner.

---

# 2. Сертификат Windows Code Signing

Нужен доверенный RSA-сертификат Code Signing.

Для готового PFX создать GitHub Secrets:

```text
WINDOWS_CERTIFICATE_BASE64
WINDOWS_CERTIFICATE_PASSWORD
```

Создать Base64-файл:

```powershell
powershell -ExecutionPolicy Bypass `
  -File tools\encode_signing_file_base64.ps1 `
  -Path "C:\Путь\к\сертификату.pfx"
```

В WINDOWS_CERTIFICATE_BASE64 вставить содержимое файла:

```text
сертификат.pfx.base64.txt
```

В WINDOWS_CERTIFICATE_PASSWORD указать пароль PFX.

GitHub Actions подпишет:

```text
GhostNetCyberVPN.exe
GhostNet-Cyber-VPN-Setup.exe
```

Используются SHA-256 и RFC 3161 timestamp.

---

# 3. Проверка результатов

Android workflow должен пройти шаг:

```text
Verify Android APK signature
```

Windows workflow должен пройти шаги:

```text
Sign Windows application
Sign Windows installer
```

У Windows-установщика откройте:

```text
ПКМ → Свойства → Цифровые подписи
```

---

# 4. Что нельзя загружать в GitHub

```text
*.jks
*.keystore
*.pfx
*.p12
пароли
Base64-файлы ключей
```

Эти форматы уже добавлены в .gitignore.
