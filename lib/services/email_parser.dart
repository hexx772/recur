import '../models/subscription.dart';

/// Кандидат в подписки, найденный в письме или SMS. Пользователь подтверждает
/// его вручную.
class SubscriptionCandidate {
  SubscriptionCandidate({
    required this.name,
    required this.price,
    required this.currency,
    required this.period,
    required this.date,
    required this.subject,
  });

  final String name;
  final double price;
  final String currency;
  final BillingPeriod period;
  final DateTime date;
  final String subject;
}

class EmailParser {
  /// Поисковый запрос Gmail для писем о списаниях.
  static const gmailQuery =
      'newer_than:180d (subject:(receipt OR invoice OR subscription OR renewal '
      'OR payment OR чек OR квитанция OR подписка OR списание OR оплата))';

  // Число с необязательными разделителями тысяч (обычный или неразрывный пробел).
  static const _num =
      r'(\d{1,3}(?:[\s ]\d{3})+(?:[.,]\d{1,2})?|\d{1,7}(?:[.,]\d{1,2})?)';
  static const _cur = r'(\$|€|£|₽|₸|USD|EUR|RUB|KZT|GBP)';
  static const _curAfter =
      r'(\$|€|£|₽|₸|USD|EUR|RUB|KZT|GBP|руб|тг|тенге)';

  static final _amount = RegExp(
    '(?:$_cur\\s?$_num|$_num\\s?$_curAfter)',
    caseSensitive: false,
  );

  static const _symbols = {
    r'$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    '₽': 'RUB',
    '₸': 'KZT',
    'руб': 'RUB',
    'тг': 'KZT',
    'тенге': 'KZT',
  };

  static const _genericSenders = ['no-reply', 'noreply', 'support', 'billing'];

  /// Находит первую сумму с валютой в тексте.
  static ({double price, String currency})? findAmount(String text) {
    final m = _amount.firstMatch(text);
    if (m == null) return null;
    final rawCur = (m.group(1) ?? m.group(4))!;
    final rawNum = (m.group(2) ?? m.group(3))!
        .replaceAll(RegExp(r'[\s ]'), '')
        .replaceAll(',', '.');
    final price = double.tryParse(rawNum);
    if (price == null || price <= 0) return null;
    final currency = _symbols[rawCur] ??
        _symbols[rawCur.toLowerCase()] ??
        rawCur.toUpperCase();
    return (price: price, currency: currency);
  }

  /// Разбирает одно письмо. Возвращает null, если не похоже на списание.
  static SubscriptionCandidate? parse({
    required String from,
    required String subject,
    required String body,
    required DateTime date,
  }) {
    final text = '$subject\n$body';
    final a = findAmount(text);
    if (a == null) return null;

    return SubscriptionCandidate(
      name: _serviceName(from),
      price: a.price,
      currency: a.currency,
      period: guessPeriod(text),
      date: date,
      subject: subject,
    );
  }

  static BillingPeriod guessPeriod(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'annual|yearly|per year|/year|год|ежегодн').hasMatch(t)) {
      return BillingPeriod.yearly;
    }
    if (RegExp(r'quarter|3 months|квартал').hasMatch(t)) {
      return BillingPeriod.quarterly;
    }
    if (RegExp(r'weekly|per week|/week|недел').hasMatch(t)) {
      return BillingPeriod.weekly;
    }
    return BillingPeriod.monthly;
  }

  /// Название сервиса из заголовка From, например `Netflix <info@netflix.com>`.
  static String _serviceName(String from) {
    final display = RegExp(r'^\s*"?([^"<]+?)"?\s*<').firstMatch(from)?.group(1);
    if (display != null && display.trim().isNotEmpty) return display.trim();
    final domain = RegExp(r'@([\w.-]+)').firstMatch(from)?.group(1) ?? from;
    final parts = domain.split('.')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return from;
    final core = parts.length >= 2 ? parts[parts.length - 2] : parts.first;
    if (_genericSenders.contains(core.toLowerCase()) && parts.length >= 3) {
      return _cap(parts[parts.length - 3]);
    }
    return _cap(core);
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Схлопывает несколько писем одного сервиса в одного кандидата (самое свежее).
  static List<SubscriptionCandidate> dedupe(List<SubscriptionCandidate> all) {
    final byName = <String, SubscriptionCandidate>{};
    for (final c in all) {
      final k = c.name.toLowerCase();
      final prev = byName[k];
      if (prev == null || c.date.isAfter(prev.date)) byName[k] = c;
    }
    return byName.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}
