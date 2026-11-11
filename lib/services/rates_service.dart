import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';

/// Курсы валют для пересчёта. Берутся с публичного API без ключа
/// (запрос не содержит данных пользователя) и кэшируются на устройстве.
class RatesService extends ChangeNotifier {
  static const _key = 'rates_v1';
  static final _url = Uri.parse('https://open.er-api.com/v6/latest/USD');

  Map<String, double> _perUsd = {};
  DateTime? updated;
  bool loading = false;
  String? error;

  bool get ready => _perUsd.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _perUsd = (j['rates'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        updated = DateTime.tryParse(j['updated'] as String? ?? '');
      } catch (_) {
        _perUsd = {};
      }
    }
    notifyListeners();
  }

  /// Обновляет курсы, если они старше 12 часов (или [force]).
  Future<void> refresh({bool force = false}) async {
    final u = updated;
    if (!force &&
        ready &&
        u != null &&
        DateTime.now().difference(u) < const Duration(hours: 12)) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await http.get(_url).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final rates = (j['rates'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      if (rates.isEmpty) throw Exception('пустой ответ');
      _perUsd = rates;
      updated = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({'rates': _perUsd, 'updated': updated!.toIso8601String()}),
      );
    } catch (e) {
      error = trf('Не удалось обновить курсы: {e}', {'e': e});
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Пересчёт суммы. null, если курса для валюты нет.
  double? convert(double amount, String from, String to) {
    if (from == to) return amount;
    final a = _perUsd[from];
    final b = _perUsd[to];
    if (a == null || b == null || a == 0) return null;
    return amount / a * b;
  }
}
