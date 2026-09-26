# Notifications

All notifications are local: scheduled on the device by
`flutter_local_notifications`, with no push service and no server.

## What is scheduled

| Notification | When | Body |
| --- | --- | --- |
| Morning reminder | Daily, at the configured time (default 09:00) | Today's Safe Spending, one line per budget running today |
| Evening summary | Daily, at the configured time (default 20:00) | A nudge to review the day |
| Bill reminders | Per bill: on the due date or *n* days before, at the bill's time or 09:00 | The bill's title and amount |

Each is independently switchable in Settings; the master toggle turns all
daily notifications off.

## Two schedulers, one visual identity

- `NotificationService` (`lib/features/settings/domain/services/`) owns the
  daily reminders on channel `budget_reminders`, with fixed ids
  (morning 1001, evening 1002).
- `BillReminderService`
  (`lib/features/bills/domain/usecases/schedule_bill_reminder_usecase.dart`)
  owns bill reminders on channel `bill_reminders`, with ids derived
  deterministically from the bill id, so re-scheduling replaces rather than
  duplicates.

Both use the same small monochrome status-bar icon
(`NotificationService.notificationIcon` →
`android/app/src/main/res/drawable/ic_notification.xml`) and the same accent
colour. **Never point a notification at `@mipmap/ic_launcher`**: Android
renders an opaque PNG as a solid white square in the status bar.

## Keeping the morning body accurate

A repeating daily notification stores its text when it is scheduled, so the
safe-spending figure inside it would otherwise be frozen at that moment and
drift from reality as the user records expenses.

`NotificationBloc` therefore listens to `RefreshBuses.expenses` and
`RefreshBuses.budgets` and re-schedules after a three-second debounce, so a
burst of changes (a restore, a bulk import) costs one reschedule. Failures
are swallowed and retried on the next change; a platform that refuses to
schedule never breaks the app.

## Time zones and permission

- The device time zone is resolved with `flutter_timezone`, falling back to
  UTC, and notifications are scheduled with `matchDateTimeComponents: time`
  so they repeat at the same local time across DST changes.
- Android 13+ notification permission is requested at startup.
  `NotificationBloc.initializeOnStartup` waits for the outcome before
  `runApp`, but a denial is not fatal: the app starts normally with
  notifications simply not firing.
- Android schedules use `inexactAllowWhileIdle`, which survives Doze without
  requesting the exact-alarm permission.

## Debug aid

Debug builds schedule an extra test notification one minute after startup, so
channel, icon, permission and time zone can be verified on a device without
waiting for the morning. Release builds do not.
