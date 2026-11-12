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

  /// Шаг в месяцах (0 для недельной периодичности).
  int get stepMonths => switch (this) {
        BillingPeriod.weekly => 0,
        BillingPeriod.monthly => 1,
        BillingPeriod.quarterly => 3,
        BillingPeriod.yearly => 12,
      };

  /// Дата [n]-го шага от [anchor]. Каждый раз считается от исходной даты,
  /// поэтому число месяца не «дрейфует» (31 января → 28 февраля → 31 марта).
  DateTime shift(DateTime anchor, int n) => this == BillingPeriod.weekly
      ? DateTime(anchor.year, anchor.month, anchor.day + 7 * n)
      : addMonths(anchor, stepMonths * n);

  DateTime addTo(DateTime d) => shift(d, 1);
}

/// Прибавляет месяцы с учётом длины месяца (допускает отрицательные [months]).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Изменение цены подписки.
class PriceChange {
  PriceChange({required this.date, required this.from, required this.to});
  final DateTime date;
  final double from;
  final double to;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'from': from, 'to': to};

  factory PriceChange.fromJson(Map<String, dynamic> j) => PriceChange(
        date: DateTime.parse(j['date'] as String),
        from: (j['from'] as num).toDouble(),
        to: (j['to'] as num).toDouble(),
      );
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
    this.endDate,
    this.priceChanges = const [],
    this.sharedWith = const [],
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

  /// Дата окончания подписки (оплачено до…). После неё списаний нет.
  final DateTime? endDate;

  /// История изменений цены.
  final List<PriceChange> priceChanges;

  /// Имена остальных участников общей оплаты.
  final List<String> sharedWith;

  bool get isEnded =>
      endDate != null && dayOf(endDate!).isBefore(dayOf(DateTime.now()));

  /// Дата [n]-го списания, считая от даты [nextCharge].
  DateTime chargeAt(int n) => period.shift(nextCharge, n);

  /// Номер первого списания не раньше [from] (но не меньше 0: списаний до
  /// указанной даты у подписки не было).
  int _firstIndexAtOrAfter(DateTime from) {
    final f = dayOf(from);
    final anchor = dayOf(nextCharge);
    if (!f.isAfter(anchor)) return 0;
    int n;
    if (period == BillingPeriod.weekly) {
      n = (f.difference(anchor).inDays / 7).floor();
    } else {
      final months = (f.year - anchor.year) * 12 + f.month - anchor.month;
      n = (months / period.stepMonths).floor();
    }
    n = (n - 2).clamp(0, 1 << 30);
    while (dayOf(chargeAt(n)).isBefore(f)) {
      n++;
    }
    return n;
  }

  /// Списания в промежутке [from]..[to] (включительно). Пробная подписка
  /// даёт только первое платное списание. После даты окончания списаний нет.
  List<DateTime> chargesBetween(DateTime from, DateTime to) {
    final f = dayOf(from);
    final t = dayOf(to);
    final end = endDate == null ? null : dayOf(endDate!);
    bool ok(DateTime d) =>
        !d.isBefore(f) && !d.isAfter(t) && (end == null || !d.isAfter(end));
    if (trial) {
      final d = dayOf(nextCharge);
      return ok(d) ? [d] : [];
    }
    final out = <DateTime>[];
    var n = _firstIndexAtOrAfter(f);
    for (var guard = 0; guard < 3000; guard++, n++) {
      final d = dayOf(chargeAt(n));
      if (d.isAfter(t)) break;
      if (ok(d)) out.add(d);
    }
    return out;
  }

  /// Ближайшая дата списания не в прошлом. Для пробного периода дата не
  /// прокручивается: триал не повторяется.
  DateTime get upcomingCharge {
    if (trial) return nextCharge;
    return chargeAt(_firstIndexAtOrAfter(DateTime.now()));
  }

  int get daysLeft =>
      dayOf(upcomingCharge).difference(dayOf(DateTime.now())).inDays;

  String get whenLabel {
    if (isEnded) return tr('завершена');
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

  /// Моя доля в месяц. Пробные и завершённые подписки ничего не стоят.
  double get perMonth =>
      (trial || isEnded) ? 0 : myPrice * period.monthlyFactor();

  /// Как последнее изменение цены влияет на расходы за год (моя доля).
  double get yearlyPriceImpact {
    if (priceChanges.isEmpty || trial || isEnded) return 0;
    final c = priceChanges.last;
    return (c.to - c.from) / shareCount * 12 * period.monthlyFactor();
  }

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
    DateTime? endDate,
    List<PriceChange>? priceChanges,
    List<String>? sharedWith,
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
        endDate: endDate ?? this.endDate,
        priceChanges: priceChanges ?? this.priceChanges,
        sharedWith: sharedWith ?? this.sharedWith,
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
        'endDate': endDate?.toIso8601String(),
        'priceChanges': priceChanges.map((c) => c.toJson()).toList(),
        'sharedWith': sharedWith,
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
        endDate: j['endDate'] == null
            ? null
            : DateTime.tryParse(j['endDate'] as String),
        priceChanges: [
          for (final c in (j['priceChanges'] as List? ?? const []))
            PriceChange.fromJson(c as Map<String, dynamic>),
        ],
        sharedWith: [
          for (final n in (j['sharedWith'] as List? ?? const [])) n as String,
        ],
      );

  static String encodeList(List<Subscription> l) =>
      jsonEncode(l.map((s) => s.toJson()).toList());

  static List<Subscription> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
      .toList();
}
