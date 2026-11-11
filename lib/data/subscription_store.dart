import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../services/home_widget_sync.dart';
import '../services/notification_service.dart';
import '../services/rates_service.dart';
import 'app_settings.dart';
import '../l10n/tr.dart';

/// Локальное хранилище подписок. Данные остаются на устройстве.
class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore({required this.settings, required this.rates}) {
    settings.addListener(_onSettings);
    rates.addListener(_onRates);
  }

  static const _key = 'subscriptions_v1';

  final AppSettings settings;
  final RatesService rates;

  List<Subscription> _items = [];

  List<Subscription> get items {
    final l = [..._items];
    l.sort((a, b) => a.upcomingCharge.compareTo(b.upcomingCharge));
    return l;
  }

  int get trialCount => _items.where((s) => s.trial).length;

  /// Итог в месяц по валютам. Подписки с включённым пересчётом сводятся в
  /// основную валюту (если курс известен), остальные считаются в своей.
  /// Смешивать разные валюты без пересчёта нельзя.
  Map<String, double> get monthlyTotals {
    final m = <String, double>{};
    for (final s in _items) {
      final v = s.perMonth;
      if (v <= 0) continue;
      if (s.convert) {
        final c = rates.convert(v, s.currency, settings.baseCurrency);
        if (c != null) {
          m[settings.baseCurrency] = (m[settings.baseCurrency] ?? 0) + c;
          continue;
        }
      }
      m[s.currency] = (m[s.currency] ?? 0) + v;
    }
    return m;
  }

  /// Стоимость подписки в месяц в основной валюте, или null, если курса нет.
  double? monthlyInBase(Subscription s) =>
      rates.convert(s.perMonth, s.currency, settings.baseCurrency);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _items = Subscription.decodeList(raw);
      } catch (e) {
        debugPrint('Не удалось прочитать подписки: $e');
      }
    }
    notifyListeners();
    await _afterChange();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, Subscription.encodeList(_items));
    notifyListeners();
    await _afterChange();
  }

  /// Пересобирает виджеты и напоминания (например, после смены языка).
  Future<void> resync() => _afterChange();

  /// Обновляет виджет рабочего стола и напоминания.
  Future<void> _afterChange() async {
    await HomeWidgetSync.update(items, monthlyTotals);
    await NotificationService.instance.rescheduleAll(items, settings);
  }

  void _onSettings() {
    notifyListeners();
    _afterChange();
  }

  void _onRates() {
    notifyListeners();
    HomeWidgetSync.update(items, monthlyTotals);
  }

  Future<void> upsert(Subscription s) async {
    final i = _items.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      _items[i] = s;
    } else {
      _items.add(s);
    }
    await _save();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
  }

  /// Включает или выключает пересчёт валюты у всех подписок сразу.
  Future<void> setConvertForAll(bool value) async {
    _items = [for (final s in _items) s.copyWith(convert: value)];
    await _save();
  }

  bool hasSimilar(String name) => _items
      .any((e) => e.name.toLowerCase().trim() == name.toLowerCase().trim());

  // ---- Резервная копия ----

  /// Копия содержит и подписки, и настройки приложения (валюта, напоминания,
  /// тема), чтобы после переустановки всё восстановилось целиком.
  String exportJson() => jsonEncode({
        'app': 'appsub',
        'version': 2,
        'exported': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'subscriptions': _items.map((s) => s.toJson()).toList(),
      });

  String exportCsv() {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final b = StringBuffer(
        tr('Название;Сумма;Валюта;Периодичность;Следующее списание;Категория;Пробный;Делится на;Моя доля\n'));
    for (final s in items) {
      b.writeln([
        esc(s.name),
        s.price,
        s.currency,
        s.period.label,
        s.upcomingCharge.toIso8601String().substring(0, 10),
        esc(s.category),
        s.trial ? tr('да') : tr('нет'),
        s.shareCount,
        s.myPrice.toStringAsFixed(2),
      ].join(';'));
    }
    return b.toString();
  }

  /// Импорт из JSON-копии: подписки с тем же id заменяются, остальные
  /// добавляются; настройки, если они есть в файле, восстанавливаются
  /// (копии версии 1 их не содержат). Возвращает число импортированных записей.
  Future<int> importJson(String text) async {
    final j = jsonDecode(text);
    final list = j is Map<String, dynamic> ? j['subscriptions'] : j;
    if (list is! List) throw FormatException(tr('Неверный формат файла'));
    final incoming = list
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final s in incoming) {
      final i = _items.indexWhere((e) => e.id == s.id);
      if (i >= 0) {
        _items[i] = s;
      } else {
        _items.add(s);
      }
    }
    await _save();
    if (j is Map<String, dynamic> && j['settings'] is Map<String, dynamic>) {
      await settings.applyJson(j['settings'] as Map<String, dynamic>);
    }
    return incoming.length;
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    rates.removeListener(_onRates);
    super.dispose();
  }
}
