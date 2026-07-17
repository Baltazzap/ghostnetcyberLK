# Исправление сборки 1.0.7+8

Исправлена единственная ошибка, останавливавшая `flutter analyze` и сборку APK:

`The named parameter 'minHeight' isn't defined`

В компактной строке реферальной системы неверный параметр:

```dart
Container(
  minHeight: 44,
)
```

заменён на корректное ограничение Flutter:

```dart
Container(
  constraints: const BoxConstraints(minHeight: 44),
)
```

Версия приложения сохранена: `1.0.7+8`.
API, авторизация, оплата, VPN, админка, поддержка и остальная логика не изменялись.
