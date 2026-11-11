import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/app_settings.dart';
import 'l10n/tr.dart';
import 'data/subscription_store.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'services/rates_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');
  // Язык интерфейса берём из системного (ru/uk/be/kk → русский, иначе английский).
  setAppLocaleFrom(WidgetsBinding.instance.platformDispatcher.locale);

  final settings = AppSettings();
  final rates = RatesService();
  await settings.load();
  await rates.load();
  await NotificationService.instance.init();

  final store = SubscriptionStore(settings: settings, rates: rates);
  await store.load();
  runApp(AppSubApp(store: store));

  // Курсы обновляем в фоне, не задерживая запуск.
  rates.refresh();
}

class AppSubApp extends StatelessWidget {
  const AppSubApp({super.key, required this.store});
  final SubscriptionStore store;

  @override
  Widget build(BuildContext context) {
    // Material You: при выборе «Из обоев» цвета берутся из обоев (Android 12+),
    // иначе используется выбранная палитра. Тема меняется сразу, без перезапуска.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return ListenableBuilder(
          listenable: store.settings,
          builder: (context, _) {
            final s = store.settings;
            final palette = kPalettes[s.paletteIndex.clamp(0, kPalettes.length - 1)];
            // «Из обоев»: системная схема как есть; иначе схема от цвета палитры.
            final useSystem = palette.seed == null;
            return MaterialApp(
              title: 'Recur',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ru'), Locale('en')],
              localeResolutionCallback: (locale, supported) {
                if (locale != null) setAppLocaleFrom(locale);
                return Locale(appLocale);
              },
              // При смене языка системы пересоздаём дерево, чтобы все надписи
              // обновились.
              builder: (context, child) =>
                  KeyedSubtree(key: ValueKey(appLocale), child: child!),
              themeMode: s.themeMode,
              theme: buildTheme(expressiveScheme(Brightness.light,
                  seed: palette.seed,
                  system: useSystem
                      ? schemeFromSystem(lightDynamic, Brightness.light)
                      : null)),
              darkTheme: buildTheme(expressiveScheme(Brightness.dark,
                  seed: palette.seed,
                  system: useSystem
                      ? schemeFromSystem(darkDynamic, Brightness.dark)
                      : null,
                  amoled: s.amoled)),
              home: HomeShell(store: store),
            );
          },
        );
      },
    );
  }
}
