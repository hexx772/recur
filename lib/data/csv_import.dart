import '../models/subscription.dart';

/// Разбор CSV, который приложение само экспортирует (разделитель `;`,
/// первая строка ― заголовок). Понимает русские и английские значения.
/// Строки, которые не удалось разобрать, пропускаются.
List<Subscription> parseSubscriptionsCsv(String text) {
  final rows = _splitRows(text.replaceAll('﻿', ''));
  if (rows.length < 2) return [];
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final out = <Subscription>[];
  for (var i = 1; i < rows.length; i++) {
    final c = rows[i];
    if (c.length < 5) continue;
    final price = double.tryParse(c[1].trim().replaceAll(',', '.'));
    final date = DateTime.tryParse(c[4].trim());
    final period = _period(c[3]);
    if (c[0].trim().isEmpty || price == null || price <= 0 || date == null) {
      continue;
    }
    out.add(Subscription(
      id: 'csv${stamp}_$i',
      name: c[0].trim(),
      price: price,
      currency: c[2].trim().toUpperCase(),
      period: period ?? BillingPeriod.monthly,
      nextCharge: dayOf(date),
      category: c.length > 5 && c[5].trim().isNotEmpty ? c[5].trim() : 'Другое',
      trial: c.length > 6 && _yes(c[6]),
      shareCount: c.length > 7 ? (int.tryParse(c[7].trim()) ?? 1).clamp(1, 99) : 1,
    ));
  }
  return out;
}

bool _yes(String v) {
  final s = v.trim().toLowerCase();
  return s == 'да' || s == 'yes' || s == 'true' || s == '1';
}

BillingPeriod? _period(String v) {
  final s = v.trim().toLowerCase();
  const names = {
    BillingPeriod.weekly: ['weekly', 'week', 'раз в неделю', 'неделя'],
    BillingPeriod.monthly: ['monthly', 'month', 'раз в месяц', 'месяц'],
    BillingPeriod.quarterly: [
      'every 3 months',
      '3 mo.',
      'раз в 3 месяца',
      '3 мес.'
    ],
    BillingPeriod.yearly: ['yearly', 'year', 'раз в год', 'год'],
  };
  for (final e in names.entries) {
    if (e.value.contains(s)) return e.key;
  }
  return null;
}

/// Делит текст на строки и ячейки по `;`, учитывая кавычки.
List<List<String>> _splitRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ';') {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
