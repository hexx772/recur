import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../data/app_settings.dart';
import '../l10n/tr.dart';
import '../models/subscription.dart';

const _initSettings = InitializationSettings(
  android: AndroidInitializationSettings('ic_stat_recur'),
);

/// Обработчик нажатий на кнопки уведомления, когда приложение не открыто
/// (кнопка «Отложить»). Выполняется в отдельном изоляте.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse r) =>
    NotificationService.handleResponse(r);

/// Push-напоминания о списаниях, об окончании пробного периода и подписки.
///
/// Используется неточное планирование (без разрешения на точные будильники):
/// уведомление может прийти с небольшой задержкой, зато ничего не нужно
/// разрешать дополнительно. В напоминании есть кнопки «Как отменить»
/// (открывает страницу отмены) и «Отложить» (повтор через сутки).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Сколько ближайших списаний планировать вперёд для одной подписки.
  static const _ahead = 3;

  static const _cancelAction = 'cancel';
  static const _snoozeAction = 'snooze';
  static const _snoozeIdShift = 500000000;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      await _plugin.initialize(
        settings: _initSettings,
        onDidReceiveNotificationResponse: handleResponse,
        onDidReceiveBackgroundNotificationResponse:
            notificationBackgroundHandler,
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

  /// Реакция на кнопки уведомления.
  static Future<void> handleResponse(NotificationResponse r) async {
    final data = _decode(r.payload);
    if (data == null) return;
    try {
      if (r.actionId == _cancelAction) {
        final url = data['u'] as String?;
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      } else if (r.actionId == _snoozeAction) {
        await _snooze(data);
      }
    } catch (e) {
      debugPrint('Notification action failed: $e');
    }
  }

  static Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Повторяет напоминание через сутки. Работает и в фоновом изоляте, поэтому
  /// всё нужное (тексты кнопок, канал) берётся из полезной нагрузки.
  static Future<void> _snooze(Map<String, dynamic> data) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: _initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {}
    final id = (data['i'] as int) + _snoozeIdShift;
    await plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(days: 1)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: data['n'] as String?,
      body: data['b'] as String?,
      payload: jsonEncode(data),
      notificationDetails: _details(
        channel: data['ch'] as String? ?? 'Charges',
        cancelLabel: data['cl'] as String? ?? 'Cancel',
        snoozeLabel: data['sl'] as String? ?? 'Snooze',
      ),
    );
  }

  static NotificationDetails _details({
    required String channel,
    required String cancelLabel,
    required String snoozeLabel,
    bool actions = true,
  }) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'charges',
          channel,
          channelDescription: channel,
          importance: Importance.high,
          priority: Priority.high,
          actions: actions
              ? [
                  AndroidNotificationAction(_cancelAction, cancelLabel,
                      showsUserInterface: true),
                  AndroidNotificationAction(_snoozeAction, snoozeLabel),
                ]
              : null,
        ),
      );

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
      final channel = tr('Списания');
      final cancelLabel = tr('Как отменить');
      final snoozeLabel = tr('Отложить на день');
      final details = _details(
          channel: channel, cancelLabel: cancelLabel, snoozeLabel: snoozeLabel);

      tz.TZDateTime at(DateTime day) => tz.TZDateTime(
          tz.local, day.year, day.month, day.day, settings.reminderHour);

      for (final s in items) {
        if (s.isEnded) continue;
        // Для триала напоминаем всегда: хотя бы за день до конца.
        final remind = s.trial
            ? (s.remindDaysBefore == 0 ? 1 : s.remindDaysBefore)
            : s.remindDaysBefore;
        final price = '${money.format(s.myPrice)} ${s.currency}';

        if (remind > 0) {
          final today = dayOf(DateTime.now());
          final charges = s.trial
              ? [s.upcomingCharge]
              : s.chargesBetween(today, today.add(const Duration(days: 800)));
          for (var k = 0; k < charges.length && k < _ahead; k++) {
            final charge = charges[k];
            final when = at(charge.subtract(Duration(days: remind)));
            if (!when.isAfter(now)) continue;
            final title = s.trial
                ? trf('Пробный период {name} заканчивается', {'name': s.name})
                : (remind == 1
                    ? trf('{name}: списание завтра', {'name': s.name})
                    : trf('{name}: списание через {n} дн.',
                        {'name': s.name, 'n': remind}));
            final body = s.trial
                ? trf('Отмените до {date}, иначе спишется {price}',
                    {'date': dateFmt.format(charge), 'price': price})
                : '$price · ${dateFmt.format(charge)}';
            final id = _id(s.id, k);
            await _plugin.zonedSchedule(
              id: id,
              scheduledDate: when,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              title: title,
              body: body,
              payload: jsonEncode({
                'u': s.cancelLink,
                'n': title,
                'b': body,
                'i': id,
                'cl': cancelLabel,
                'sl': snoozeLabel,
                'ch': channel,
              }),
              notificationDetails: details,
            );
          }
        }

        // Подписка скоро заканчивается: предупреждаем за несколько дней.
        final end = s.endDate;
        if (end != null) {
          final lead = remind > 0 ? remind : 3;
          final when = at(dayOf(end).subtract(Duration(days: lead)));
          if (when.isAfter(now)) {
            await _plugin.zonedSchedule(
              id: _id(s.id, 3),
              scheduledDate: when,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              title: trf('{name} скоро заканчивается', {'name': s.name}),
              body: trf('Оплачено до {date}. Продлить или отказаться?',
                  {'date': dateFmt.format(end)}),
              notificationDetails: _details(
                  channel: channel,
                  cancelLabel: cancelLabel,
                  snoozeLabel: snoozeLabel,
                  actions: false),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Reschedule failed: $e');
    }
  }

  int _id(String subId, int k) => (subId.hashCode.abs() % 100000000) * 4 + k;
}
