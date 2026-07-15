# Как сделать полноценный личный кабинет с выдачей ключей

Текущий шаблон открывает Telegram-бота для покупки и выдачи ключей.

Для полной автоматизации нужна связка:

```text
GhostNet App
↓
GhostNet API Server
↓
База данных пользователей / подписок
↓
3x-ui API или база 3x-ui
↓
Платёжная система
```

## Что должен делать API

1. Регистрация пользователя.
2. Авторизация по логину/паролю или Telegram ID.
3. Список тарифов.
4. Проверка промокода.
5. Создание платежа.
6. Проверка оплаты.
7. Выдача ключа/ссылки подписки.
8. Продление подписки.
9. Просмотр активных ключей.
10. Уведомление о скором окончании подписки.

## Минимальные API-методы

```text
POST /auth/register
POST /auth/login
GET  /plans
POST /promo/check
POST /payment/create
GET  /payment/status/{id}
GET  /user/keys
POST /user/keys/{id}/renew
GET  /support
```

## Варианты backend

Можно сделать на:

- Node.js + Express + PostgreSQL;
- Python FastAPI + PostgreSQL;
- PHP Laravel;
- Go.

Для старта проще всего: **FastAPI + PostgreSQL** или **Node.js + Express**.
