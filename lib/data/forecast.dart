import '../models/subscription.dart';

/// Списания по дням месяца [month] (для календаря). Ключ ― дата без времени.
Map<DateTime, List<Subscription>> chargesByDay(
    List<Subscription> subs, DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final out = <DateTime, List<Subscription>>{};
  for (final s in subs) {
    for (final d in s.chargesBetween(first, last)) {
      out.putIfAbsent(d, () => []).add(s);
    }
  }
  return out;
}

/// Сумма расходов за один месяц.
class MonthTotal {
  MonthTotal(this.month, this.amount);
  final DateTime month;
  final double amount;
}

class Forecast {
  Forecast(this.months, this.skipped);
  final List<MonthTotal> months;

  /// Сколько подписок не удалось пересчитать из-за отсутствия курса валюты.
  final int skipped;

  double get total => months.fold(0, (a, m) => a + m.amount);
  double get maxMonth =>
      months.fold(0, (a, m) => m.amount > a ? m.amount : a);
}

/// Прогноз расходов на [months] месяцев вперёд, начиная с месяца [from].
/// Учитывает фактические даты списаний, поэтому годовые подписки дают
/// «пики» в нужный месяц. [toBase] переводит сумму одного списания (моя доля)
/// в основную валюту; null значит, что курса нет и подписка пропускается.
Forecast buildForecast(
  List<Subscription> subs, {
  required DateTime from,
  int months = 12,
  required double? Function(Subscription s, double amount) toBase,
}) {
  final skippedIds = <String>{};
  final result = <MonthTotal>[];
  for (var i = 0; i < months; i++) {
    final start = addMonths(DateTime(from.year, from.month, 1), i);
    final end = DateTime(start.year, start.month + 1, 0);
    var sum = 0.0;
    for (final s in subs) {
      if (s.isEnded) continue;
      final charges = s.chargesBetween(start, end);
      if (charges.isEmpty) continue;
      final v = toBase(s, s.myPrice);
      if (v == null) {
        skippedIds.add(s.id);
        continue;
      }
      sum += v * charges.length;
    }
    result.add(MonthTotal(start, sum));
  }
  return Forecast(result, skippedIds.length);
}
