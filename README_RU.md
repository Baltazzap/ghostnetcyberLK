# GhostNet Cyber VPN — приложение для Windows и Android

Это готовый шаблон Flutter-приложения под бренд **GhostNet Cyber VPN**.

Внутри уже есть:

- главный экран;
- регистрация локального профиля;
- личный кабинет;
- тарифы и цены;
- поле промокода;
- кнопка покупки через Telegram-бота;
- раздел помощи;
- логотип GhostNet;
- чёрно-оранжевый кибер-стиль.

## Тарифы в приложении

| Тариф | Цена | Срок |
|---|---:|---|
| GHOST START | 150 ₽ | 7 дней |
| GHOST NET | 250 ₽ | 30 дней |
| GHOST PLUS | 650 ₽ | 90 дней |
| GHOST PREMIUM | 1200 ₽ | 180 дней |
| GHOST ULTIMATE | 2100 ₽ | 365 дней |

Кнопка покупки ведёт сюда:

```text
https://t.me/GhostNetV_bot?start=pr_WELCOME
```

Если пользователь ввёл промокод в приложении, ссылка будет открываться с этим промокодом:

```text
https://t.me/GhostNetV_bot?start=pr_ПРОМОКОД
```

## Как собрать проект

### 1. Установи Flutter

Нужны:

- Flutter SDK;
- Android Studio;
- Visual Studio 2022 Community с компонентом **Desktop development with C++**;
- Git.

Проверь установку:

```powershell
flutter doctor
```

Все важные пункты должны быть без ошибок:

```text
Flutter
Android toolchain
Visual Studio
```

## 2. Распакуй архив

Например:

```text
C:\GhostNet\ghostnet_cyber_vpn_app
```

Открой PowerShell в папке проекта.

## 3. Создай платформенные папки Android и Windows

Выполни:

```powershell
flutter create --platforms=android,windows --org ru.ghostnet .
```

После этого Flutter создаст папки:

```text
android/
windows/
```

## 4. Установи зависимости

```powershell
flutter pub get
```

## 5. Создай иконки приложения

```powershell
dart run flutter_launcher_icons
```

## 6. Запусти приложение для проверки

Для Windows:

```powershell
flutter run -d windows
```

Для Android подключи телефон по USB или открой эмулятор:

```powershell
flutter run
```

## 7. Собери APK

```powershell
flutter build apk --release
```

Готовый APK будет здесь:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## 8. Собери Windows-версию

```powershell
flutter build windows --release
```

Готовая Windows-версия будет здесь:

```text
build\windows\x64\runner\Release
```

Важно: для Windows раздавай **всю папку Release**, а не только `.exe`, потому что рядом нужны `.dll` файлы.

## Как поменять ссылку Telegram-бота

Открой файл:

```text
lib/main.dart
```

Найди строки:

```dart
const String telegramBuyUrl = 'https://t.me/GhostNetV_bot?start=pr_WELCOME';
const String telegramBotUrl = 'https://t.me/GhostNetV_bot';
const String supportUrl = 'https://t.me/GhostNetV_bot';
```

Замени на свои ссылки при необходимости.

## Как поменять тарифы

Открой файл:

```text
lib/main.dart
```

Найди блок:

```dart
const tariffs = <Tariff>[
```

И измени цены, сроки или названия.

## Важно про личный кабинет

Сейчас личный кабинет работает как **локальный профиль** внутри приложения.

То есть приложение сохраняет:

- имя пользователя;
- Telegram username.

Реальные ключи, оплаты и сроки подписки пока открываются через Telegram-бота.

Для полноценного личного кабинета нужно подключить API-сервер, который будет:

- регистрировать пользователей;
- принимать оплату;
- выдавать ключи;
- проверять срок подписки;
- синхронизироваться с 3x-ui или твоей базой.

Этот шаблон можно использовать как первую рабочую версию, а потом подключить API.


## Security Patch 1.0.1+2

Перед загрузкой в GitHub прочитай `SECURITY_PATCH_RU.md`.
В проект добавлены защищённое хранение токена, API-таймауты, HTTPS-only Android-конфигурация и проверки сборки.


## Windows ATL CI fix

- Windows workflow закреплён на `windows-2022`;
- удалена попытка модифицировать Visual Studio через `vs_installer.exe`;
- добавлена безопасная проверка уже установленного ATL;
- проверяется фактическое наличие `atlbase.h`.


## Windows payment single-instance fix

- версия обновлена до `1.0.2+3`;
- исправлено открытие второго окна после возврата из ЮKassa;
- добавлен Win32 named Mutex;
- повторный запуск активирует существующее окно и завершается;
- исправление автоматически применяется при сборке GitHub Actions.


## Automatic update system

- версия приложения: `1.0.3+4`;
- проверка обновлений при запуске;
- ручная проверка в личном кабинете;
- manifest: `https://ghostnetcyber.ru/downloads/version.json`;
- поддержка Android APK и Windows ZIP;
- поддержка обычных и обязательных обновлений;
- GitHub Actions создаёт файлы с готовыми именами для сайта;
- инструкция: `AUTO_UPDATE_SETUP_RU.md`.


## Windows installer

- версия обновлена до `1.0.4+5`;
- Windows ZIP заменён на `GhostNet-Cyber-VPN-Setup.exe`;
- установщик создаётся через Inno Setup;
- установка выполняется без прав администратора;
- добавлены ярлыки, деинсталлятор и регистрация `ghostnet://`;
- Windows-система обновлений скачивает установщик EXE;
- инструкция: `WINDOWS_INSTALLER_RU.md`.


## ISCC verification fix

- удалён запуск `ISCC.exe /?`, который возвращал код `1`;
- проверка теперь читает путь и версию файла без запуска справки;
- реальная проверка компилятора выполняется при сборке установщика.


## Digital signing

- версия обновлена до `1.0.5+6`;
- Android APK подписывается постоянным JKS из GitHub Secrets;
- APK автоматически проверяется через `apksigner`;
- Windows EXE и Setup подписываются Authenticode через SignTool;
- используется SHA-256 и RFC 3161 timestamp;
- сертификаты и ключи удаляются с Runner после сборки;
- секретные форматы добавлены в `.gitignore`;
- инструкция: `DIGITAL_SIGNING_RU.md`.


## Final signing package

- создан постоянный Android release key в отдельном приватном архиве;
- добавлен скрипт автоматической установки GitHub Secrets через GitHub CLI;
- Windows-сборка больше не падает без PFX;
- при наличии доверенного PFX Windows EXE и Setup подписываются автоматически;
- приватные ключи не входят в GitHub-архив;
- инструкция: `SIGNING_FINAL_RU.md`.


## Android Base64 secret fix

- исправлена ошибка `base64: invalid input`;
- workflow удаляет CRLF/BOM перед декодированием JKS;
- добавлена строгая Base64-проверка;
- JKS проверяется через `keytool` до сборки;
- PowerShell-скрипты записывают секреты без завершающего CRLF.
