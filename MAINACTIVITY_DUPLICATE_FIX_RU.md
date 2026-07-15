# Исправление ошибки Redeclaration MainActivity

Сборка APK падала с ошибкой:

```text
Redeclaration:
class MainActivity : FlutterActivity
```

Причина: в проекте оказалось два файла `MainActivity.kt`:

```text
android/app/src/main/kotlin/ru/ghostnet/cybervpn/MainActivity.kt
android/app/src/main/kotlin/ru/ghostnet/ghostnet_cyber_vpn/MainActivity.kt
```

Теперь `tools/patch_app_name.py` удаляет все дубликаты и создаёт один правильный файл:

```text
android/app/src/main/kotlin/ru/ghostnet/cybervpn/MainActivity.kt
```

После обновления:

1. Скопируй файлы поверх проекта.
2. Commit.
3. Push.
4. Запусти Build Android APK заново.
5. Удали старое приложение с телефона и установи новый APK.
