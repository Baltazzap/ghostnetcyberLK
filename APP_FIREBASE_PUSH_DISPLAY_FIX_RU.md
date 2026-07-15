# GhostNet Cyber VPN — Firebase Push Display Fix

Исправлено отображение системных push-уведомлений на Android.

Что изменено:

- добавлен отдельный системный notification icon `ic_stat_ghostnet`;
- добавлен цвет уведомлений GhostNet;
- добавлены Firebase meta-data в AndroidManifest;
- канал уведомлений теперь создаётся с `Importance.max`;
- включены звук, вибрация и публичное отображение уведомлений;
- добавлена дополнительная проверка разрешения уведомлений через `flutter_local_notifications`;
- foreground-уведомления теперь показываются через local notification даже для data payload.

После установки лучше удалить старую версию приложения, установить новую, разрешить уведомления и снова войти в аккаунт.
