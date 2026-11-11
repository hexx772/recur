import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_settings.dart';
import '../l10n/tr.dart';
import '../models/subscription.dart';

/// Push-напоминания о списаниях и об окончании пробного периода.
///
/// Используется неточное планирование (без разрешения на точные будильники):
/// уведомление может прийти с небольшой задержкой, зато ничего не нужно
/// разрешать дополнительно.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Сколько ближайших списаний планировать вперёд для одной подписки.
  static const _ahead = 3;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_recur'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  /// Запрашивает разрешение на уведомления (Android 13+).
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> permissionGranted() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Пересоздаёт все напоминания по текущему списку подписок.
  Future<void> rescheduleAll(
      List<Subscription> items, AppSettings settings) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!settings.remindersEnabled) return;

      final now = tz.TZDateTime.now(tz.local);
      final dateFmt = DateFormat.MMMd(appLocale);
      final money = NumberFormat('#,##0.##', appLocale);

      for (final s in items) {
        // Для триала напоминаем всегда: хотя бы за день до конца.
        final remind = s.trial
            ? (s.remindDaysBefore == 0 ? 1 : s.remindDaysBefore)
            : s.remindDaysBefore;
        if (remind == 0) continue;

        var charge = s.upcomingCharge;
        final count = s.trial ? 1 : _ahead;
        for (var k = 0; k < count; k++) {
          final day = charge.subtract(Duration(days: remind));
          final when = tz.TZDateTime(tz.local, day.year, day.month, day.day,
              settings.reminderHour);
          if (when.isAfter(now)) {
            final price = '${money.format(s.myPrice)} ${s.currency}';
            await _plugin.zonedSchedule(
              id: _id(s.id, k),
              scheduledDate: when,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              title: s.trial
                  ? trf('Пробный период {name} заканчивается', {'name': s.name})
                  : (remind == 1
                      ? trf('{name}: списание завтра', {'name': s.name})
                      : trf('{name}: списание через {n} дн.',
                          {'name': s.name, 'n': remind})),
              body: s.trial
                  ? trf('Отмените до {date}, иначе спишется {price}', {
                      'date': dateFmt.format(charge),
                      'price': price,
                    })
                  : '$price · ${dateFmt.format(charge)}',
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  'charges',
                  tr('Списания'),
                  channelDescription: tr('Напоминания о предстоящих списаниях'),
                  importance: Importance.high,
                  priority: Priority.high,
                ),
              ),
            );
          }
          charge = s.period.addTo(charge);
        }
      }
    } catch (e) {
      debugPrint('Reschedule failed: $e');
    }
  }

  int _id(String subId, int k) => (subId.hashCode.abs() % 100000000) * 4 + k;
}
