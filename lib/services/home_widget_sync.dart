import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../l10n/tr.dart';
import '../models/subscription.dart';

/// Передаёт данные виджетам рабочего стола (Android) и просит их обновиться.
///
/// Виджетов три: список (все подписки, прокручивается), ближайшее списание
/// и итог за месяц. Все читают одни и те же ключи.
class HomeWidgetSync {
  static const _pkg = 'com.appsub.appsub';
  static const _providers = [
    '$_pkg.SubsWidgetProvider',
    '$_pkg.NextWidgetProvider',
    '$_pkg.TotalWidgetProvider',
  ];

  static Future<void> update(
    List<Subscription> sortedByDate,
    Map<String, double> perMonthByCurrency,
  ) async {
    try {
      final money = NumberFormat('#,##0.##', appLocale);
      final whole = NumberFormat('#,##0', appLocale);

      final total = perMonthByCurrency.entries
          .map((e) => '${whole.format(e.value)} ${e.key}')
          .join(' · ');
      final year = perMonthByCurrency.entries
          .map((e) => '${whole.format(e.value * 12)} ${e.key}')
          .join(' · ');

      final list = [
        for (final s in sortedByDate)
          {
            'n': s.name,
            'i': s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
            'p': '${money.format(s.myPrice)} ${s.currency}',
            'd': DateFormat.MMMd(appLocale).format(s.upcomingCharge),
            'w': s.trial
                ? trf('триал · {when}', {'when': s.whenLabel})
                : s.whenLabel,
            'u': s.remindDaysBefore > 0 && s.daysLeft <= s.remindDaysBefore,
            't': s.trial,
          },
      ];

      final next = sortedByDate.isEmpty ? null : sortedByDate.first;

      await HomeWidget.saveWidgetData<String>('subs_json', jsonEncode(list));
      await HomeWidget.saveWidgetData<int>('count', sortedByDate.length);
      await HomeWidget.saveWidgetData<String>('total', total);
      await HomeWidget.saveWidgetData<String>('year', year);
      await HomeWidget.saveWidgetData<int>(
          'trials', sortedByDate.where((s) => s.trial).length);
      await HomeWidget.saveWidgetData<String>('next_name', next?.name ?? '');
      await HomeWidget.saveWidgetData<String>(
          'next_initial', next == null ? '' : next.name[0].toUpperCase());
      await HomeWidget.saveWidgetData<String>('next_price',
          next == null ? '' : '${money.format(next.myPrice)} ${next.currency}');
      await HomeWidget.saveWidgetData<String>('next_when',
          next == null
              ? ''
              : (next.trial
                  ? trf('триал · {when}', {'when': next.whenLabel})
                  : next.whenLabel));
      await HomeWidget.saveWidgetData<String>(
          'next_date',
          next == null
              ? ''
              : DateFormat.MMMMd(appLocale).format(next.upcomingCharge));
      await HomeWidget.saveWidgetData<bool>(
          'next_urgent',
          next != null &&
              next.remindDaysBefore > 0 &&
              next.daysLeft <= next.remindDaysBefore);

      for (final p in _providers) {
        await HomeWidget.updateWidget(qualifiedAndroidName: p);
      }
    } catch (_) {
      // Виджеты необязательны: сбой не должен ломать приложение.
    }
  }
}
