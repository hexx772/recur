import 'dart:convert';

import '../data/known_services.dart';
import '../l10n/tr.dart';

enum BillingPeriod { weekly, monthly, quarterly, yearly }

extension BillingPeriodX on BillingPeriod {
  String get label => switch (this) {
        BillingPeriod.weekly => tr('Раз в неделю'),
        BillingPeriod.monthly => tr('Раз в месяц'),
        BillingPeriod.quarterly => tr('Раз в 3 месяца'),
        BillingPeriod.yearly => tr('Раз в год'),
      };

  String get shortLabel => switch (this) {
        BillingPeriod.weekly => tr('Неделя'),
        BillingPeriod.monthly => tr('Месяц'),
        BillingPeriod.quarterly => tr('3 мес.'),
        BillingPeriod.yearly => tr('Год'),
      };

  /// Стоимость, приведённая к месяцу.
  double monthlyFactor() => switch (this) {
        BillingPeriod.weekly => 52 / 12,
        BillingPeriod.monthly => 1,
        BillingPeriod.quarterly => 1 / 3,
        BillingPeriod.yearly => 1 / 12,
      };

  DateTime addTo(DateTime d) => switch (this) {
        BillingPeriod.weekly => d.add(const Duration(days: 7)),
        BillingPeriod.monthly => _addMonths(d, 1),
        BillingPeriod.quarterly => _addMonths(d, 3),
        BillingPeriod.yearly => _addMonths(d, 12),
      };
}

DateTime _addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.period,
    required this.nextCharge,
    this.category = 'Другое',
    this.remindDaysBefore = 3,
    this.fromEmail = false,
    this.trial = false,
    this.shareCount = 1,
    this.convert = false,
    this.cancelUrl,
  });

  final String id;
  final String name;

  /// Полная цена списания.
  final double price;
  final String currency;
  final BillingPeriod period;

  /// Дата списания. Для пробного периода это дата первого платного списания.
  final DateTime nextCharge;
  final String category;
  final int remindDaysBefore;
  final bool fromEmail;

  /// Пробный период: пока не платим, но нужно вовремя отменить.
  final bool trial;

  /// На скольких человек делится оплата (1 = плачу один).
  final int shareCount;

  /// Пересчитывать сумму в основную валюту из настроек.
  final bool convert;

  /// Своя ссылка отмены (иначе берётся из справочника или поиск).
  final String? cancelUrl;

  /// Ближайшая дата списания не в прошлом (прокручивает дату вперёд).
  /// Для пробного периода дата не прокручивается: триал не повторяется.
  DateTime get upcomingCharge {
    if (trial) return nextCharge;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    var d = nextCharge;
    var guard = 0;
    while (d.isBefore(start) && guard++ < 1000) {
      d = period.addTo(d);
    }
    return d;
  }

  int get daysLeft {
    final today = DateTime.now();
    return upcomingCharge
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  String get whenLabel {
    final d = daysLeft;
    if (d < 0) return tr('просрочено');
    return d == 0
        ? tr('сегодня')
        : d == 1
            ? tr('завтра')
            : trf('через {d} дн.', {'d': d});
  }

  /// Моя доля одного списания.
  double get myPrice => price / shareCount;

  /// Моя доля в месяц. Пробные подписки пока ничего не стоят.
  double get perMonth => trial ? 0 : myPrice * period.monthlyFactor();

  /// Ссылка, где можно отменить подписку.
  String get cancelLink =>
      cancelUrl ??
      KnownServices.cancelUrlFor(name) ??
      'https://www.google.com/search?q=${Uri.encodeQueryComponent('как отменить подписку $name')}';

  Subscription copyWith({
    String? name,
    double? price,
    String? currency,
    BillingPeriod? period,
    DateTime? nextCharge,
    String? category,
    int? remindDaysBefore,
    bool? trial,
    int? shareCount,
    bool? convert,
    String? cancelUrl,
  }) =>
      Subscription(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        currency: currency ?? this.currency,
        period: period ?? this.period,
        nextCharge: nextCharge ?? this.nextCharge,
        category: category ?? this.category,
        remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
        fromEmail: fromEmail,
        trial: trial ?? this.trial,
        shareCount: shareCount ?? this.shareCount,
        convert: convert ?? this.convert,
        cancelUrl: cancelUrl ?? this.cancelUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'currency': currency,
        'period': period.name,
        'nextCharge': nextCharge.toIso8601String(),
        'category': category,
        'remindDaysBefore': remindDaysBefore,
        'fromEmail': fromEmail,
        'trial': trial,
        'shareCount': shareCount,
        'convert': convert,
        'cancelUrl': cancelUrl,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        currency: j['currency'] as String,
        period: BillingPeriod.values.byName(j['period'] as String),
        nextCharge: DateTime.parse(j['nextCharge'] as String),
        category: j['category'] as String? ?? 'Другое',
        remindDaysBefore: j['remindDaysBefore'] as int? ?? 3,
        fromEmail: j['fromEmail'] as bool? ?? false,
        trial: j['trial'] as bool? ?? false,
        shareCount: (j['shareCount'] as int? ?? 1).clamp(1, 99),
        convert: j['convert'] as bool? ?? false,
        cancelUrl: j['cancelUrl'] as String?,
      );

  static String encodeList(List<Subscription> l) =>
      jsonEncode(l.map((s) => s.toJson()).toList());

  static List<Subscription> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
      .toList();
}
