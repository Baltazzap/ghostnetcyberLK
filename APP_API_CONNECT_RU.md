# GhostNet App + API

Эта версия приложения подключена к API:

- API адрес: `https://api.ghostnetcyber.ru`
- Регистрация: `POST /api/auth/register`
- Вход: `POST /api/auth/login`
- Профиль: `GET /api/me`
- Тарифы: `GET /api/plans`
- Покупка: `POST /api/purchase/create`
- Мои подписки: `GET /api/subscriptions/my`

## Что изменено

1. Вход и регистрация теперь идут через сервер, а не локально.
2. Токен сохраняется в приложении через `SharedPreferences`.
3. Тарифы загружаются с API.
4. Кнопка покупки создаёт ссылку через API и открывает Telegram-бота.
5. В личном кабинете показываются реальные подписки, дата окончания, лимит устройств, количество серверов.
6. Есть кнопки копирования ссылки подписки и VLESS-ключей.
7. Для Android включён `INTERNET` и `usesCleartextTraffic=true`, чтобы временно работал API по `http://IP:8000`.

## Важно

Пока API работает без домена и HTTPS. Для релиза лучше подключить домен и SSL, потом заменить в `lib/main.dart`:

```dart
const String apiBaseUrl = 'https://api.ghostnetcyber.ru';
```

на:

```dart
const String apiBaseUrl = 'https://api.твой-домен.ru';
```
