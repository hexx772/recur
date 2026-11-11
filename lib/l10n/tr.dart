import 'dart:ui';

import 'en_strings.dart';

/// Язык интерфейса: 'ru' или 'en'. Выбирается по языку системы.
String appLocale = 'ru';

bool get isRu => appLocale == 'ru';

/// Для украинского, белорусского и казахского системных языков показываем
/// русский (как и в Android-части приложения), для остальных английский.
const _russianLike = {'ru', 'uk', 'be', 'kk'};

String resolveAppLocale(Locale l) =>
    _russianLike.contains(l.languageCode) ? 'ru' : 'en';

void setAppLocaleFrom(Locale l) => appLocale = resolveAppLocale(l);

/// Перевод: ключом служит русский текст. Если перевода нет, показывается русский.
String tr(String ru) => isRu ? ru : (kEn[ru] ?? ru);

/// Перевод строки с параметрами вида `{name}`.
String trf(String ru, Map<String, Object> args) {
  var s = tr(ru);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}
