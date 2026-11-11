import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки приложения. Хранятся на устройстве и входят в резервную копию.
class AppSettings extends ChangeNotifier {
  static const _key = 'app_settings_v1';

  /// Основная валюта для пересчёта и аналитики.
  String baseCurrency = 'RUB';

  /// Пересчитывать все подписки в основную валюту.
  bool convertAll = false;

  /// Push-напоминания о списаниях.
  bool remindersEnabled = true;

  /// Час суток (0–23), когда приходят напоминания.
  int reminderHour = 10;

  /// Тема: как в системе, светлая или тёмная.
  ThemeMode themeMode = ThemeMode.system;

  /// Номер цветовой палитры (0 = динамические цвета из обоев).
  int paletteIndex = 0;

  /// Чисто чёрный фон в тёмной теме (экономит заряд на OLED).
  bool amoled = false;

  Map<String, dynamic> toJson() => {
        'baseCurrency': baseCurrency,
        'convertAll': convertAll,
        'remindersEnabled': remindersEnabled,
        'reminderHour': reminderHour,
        'themeMode': themeMode.name,
        'paletteIndex': paletteIndex,
        'amoled': amoled,
      };

  /// Применяет значения из JSON; отсутствующие поля остаются как были.
  void _fromJson(Map<String, dynamic> j) {
    baseCurrency = j['baseCurrency'] as String? ?? baseCurrency;
    convertAll = j['convertAll'] as bool? ?? convertAll;
    remindersEnabled = j['remindersEnabled'] as bool? ?? remindersEnabled;
    reminderHour = (j['reminderHour'] as int? ?? reminderHour).clamp(0, 23);
    final mode = j['themeMode'] as String?;
    themeMode = ThemeMode.values.asNameMap()[mode] ?? themeMode;
    paletteIndex = (j['paletteIndex'] as int? ?? paletteIndex).clamp(0, 99);
    amoled = j['amoled'] as bool? ?? amoled;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Не удалось прочитать настройки: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
    notifyListeners();
  }

  Future<void> update({
    String? baseCurrency,
    bool? convertAll,
    bool? remindersEnabled,
    int? reminderHour,
    ThemeMode? themeMode,
    int? paletteIndex,
    bool? amoled,
  }) async {
    this.baseCurrency = baseCurrency ?? this.baseCurrency;
    this.convertAll = convertAll ?? this.convertAll;
    this.remindersEnabled = remindersEnabled ?? this.remindersEnabled;
    this.reminderHour = reminderHour ?? this.reminderHour;
    this.themeMode = themeMode ?? this.themeMode;
    this.paletteIndex = paletteIndex ?? this.paletteIndex;
    this.amoled = amoled ?? this.amoled;
    await _save();
  }

  /// Восстановление настроек из резервной копии.
  Future<void> applyJson(Map<String, dynamic> json) async {
    _fromJson(json);
    await _save();
  }
}
