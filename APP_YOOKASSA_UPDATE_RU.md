# GhostNet App — оплата через ЮKassa

Кнопка покупки тарифа теперь вызывает:

```text
POST /api/payments/yookassa/create
```

Приложение получает `confirmation_url` и открывает страницу оплаты ЮKassa.

После `payment.succeeded` API выдаёт подписку через 3x-ui, и пользователь увидит её в разделе «Мои ключи».
