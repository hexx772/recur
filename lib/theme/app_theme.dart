import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Стиль в духе Material 3 Expressive: динамические цвета, смелые формы,
/// крупная жирная типографика. Готовых компонентов Expressive во Flutter нет,
/// поэтому формы и шрифты задаются здесь.
const kSeedColor = Color(0xFF5B4FE9);

/// Squircle-подобная форма: мягче обычного скругления.
ShapeBorder expressiveShape(double radius) =>
    RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));

/// Палитра приложения. Первая использует цвета обоев (Material You).
class AppPalette {
  const AppPalette(this.name, this.seed);
  final String name;

  /// null: брать цвет из обоев (на Android 12+), иначе фирменный индиго.
  final Color? seed;
}

const kPalettes = [
  AppPalette('Из обоев', null),
  AppPalette('Индиго', Color(0xFF5B4FE9)),
  AppPalette('Изумруд', Color(0xFF1E8E5A)),
  AppPalette('Роза', Color(0xFFD6336C)),
  AppPalette('Апельсин', Color(0xFFEF6C00)),
  AppPalette('Океан', Color(0xFF0277BD)),
  AppPalette('Фиолет', Color(0xFF8E24AA)),
];

/// Переносит системную схему Material You в схему Flutter. Пакет
/// `dynamic_color` отдаёт её собственным типом (из `material_ui`), поэтому цвета
/// копируются поштучно. Если чего-то не хватает, возвращает null, и тогда
/// схема строится от цвета по умолчанию.
ColorScheme? schemeFromSystem(dynamic s, Brightness b) {
  if (s == null) return null;
  try {
    Color c(dynamic v) => v as Color;
    return ColorScheme(
      brightness: b,
      primary: c(s.primary),
      onPrimary: c(s.onPrimary),
      primaryContainer: c(s.primaryContainer),
      onPrimaryContainer: c(s.onPrimaryContainer),
      secondary: c(s.secondary),
      onSecondary: c(s.onSecondary),
      secondaryContainer: c(s.secondaryContainer),
      onSecondaryContainer: c(s.onSecondaryContainer),
      tertiary: c(s.tertiary),
      onTertiary: c(s.onTertiary),
      tertiaryContainer: c(s.tertiaryContainer),
      onTertiaryContainer: c(s.onTertiaryContainer),
      error: c(s.error),
      onError: c(s.onError),
      errorContainer: c(s.errorContainer),
      onErrorContainer: c(s.onErrorContainer),
      surface: c(s.surface),
      onSurface: c(s.onSurface),
      onSurfaceVariant: c(s.onSurfaceVariant),
      outline: c(s.outline),
      outlineVariant: c(s.outlineVariant),
      surfaceContainerLowest: c(s.surfaceContainerLowest),
      surfaceContainerLow: c(s.surfaceContainerLow),
      surfaceContainer: c(s.surfaceContainer),
      surfaceContainerHigh: c(s.surfaceContainerHigh),
      surfaceContainerHighest: c(s.surfaceContainerHighest),
      inverseSurface: c(s.inverseSurface),
      onInverseSurface: c(s.onInverseSurface),
      inversePrimary: c(s.inversePrimary),
      shadow: c(s.shadow),
      scrim: c(s.scrim),
      surfaceTint: c(s.surfaceTint),
    );
  } catch (_) {
    return null;
  }
}

/// Цветовая схема приложения.
///
/// [system] ― схема Material You из обоев: берётся как есть. Иначе схема
/// строится от [seed] вариантом vibrant, который сохраняет оттенок выбранного
/// цвета (режим expressive сдвигает оттенок и делал бы плитку палитры
/// непохожей на результат).
ColorScheme expressiveScheme(
  Brightness b, {
  Color? seed,
  ColorScheme? system,
  bool amoled = false,
}) {
  final scheme = system ??
      ColorScheme.fromSeed(
        seedColor: seed ?? kSeedColor,
        brightness: b,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      );
  if (b == Brightness.dark && amoled) {
    // Чёрный фон: поверхности темнее, акценты прежние.
    return scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0B0B0D),
      surfaceContainer: const Color(0xFF141416),
      surfaceContainerHigh: const Color(0xFF1B1B1E),
      surfaceContainerHighest: const Color(0xFF242427),
    );
  }
  return scheme;
}

ThemeData buildTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final t = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: t.copyWith(
      displayMedium: t.displayMedium?.copyWith(
          fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.0),
      headlineMedium:
          t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: expressiveShape(24),
      extendedPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      extendedTextStyle: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: const StadiumBorder()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      // Underline-граница держит подпись внутри заливки (как в M3 filled),
      // а скругление и отсутствие линии дают нужную «таблетку».
      border: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(shape: expressiveShape(32)),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: expressiveShape(28),
    ),
  );
}
