import 'dart:convert';
import 'dart:io';

import 'package:appsub/data/csv_import.dart';
import 'package:appsub/data/forecast.dart';
import 'package:appsub/l10n/en_strings.dart';
import 'package:appsub/l10n/en_strings_extra.dart';

import 'package:appsub/data/app_settings.dart';
import 'package:appsub/data/subscription_store.dart';
import 'package:appsub/models/subscription.dart';
import 'package:appsub/services/rates_service.dart';
import 'package:appsub/data/known_services.dart';
import 'package:appsub/l10n/tr.dart';
import 'package:appsub/theme/app_theme.dart';
import 'package:flutter/material.dart'
    show Brightness, HSVColor, Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appsub/services/email_parser.dart';
import 'package:appsub/services/sms_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('у всех надписей tr()/trf() есть английский перевод', () {
    final lit = RegExp(r"'((?:[^'\\]|\\.)*)'");
    final call = RegExp(r"\btrf?\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)");
    final cyr = RegExp(r'[А-Яа-яЁё]');
    final missing = <String>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('l10n'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        final key = lit
            .allMatches(m.group(1)!)
            .map((x) => x.group(1)!)
            .join()
            .replaceAll(r"\'", "'")
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\\', r'\');
        if (!cyr.hasMatch(key)) continue;
        if (kEn[key] == null && kEnExtra[key] == null) missing.add(key);
      }
    }
    expect(missing, isEmpty, reason: 'Нет перевода:\n${missing.join('\n')}');
  });

  group('Даты списаний, окончание, прогноз', () {
    Subscription mk({
      required BillingPeriod period,
      required DateTime next,
      double price = 10,
      DateTime? end,
      bool trial = false,
      List<PriceChange> changes = const [],
      int share = 1,
    }) =>
        Subscription(
          id: 'x',
          name: 'S',
          price: price,
          currency: 'USD',
          period: period,
          nextCharge: next,
          endDate: end,
          trial: trial,
          priceChanges: changes,
          shareCount: share,
        );

    test('месяц не «дрейфует»: 31 января → 28 февраля → 31 марта', () {
      final s = mk(period: BillingPeriod.monthly, next: DateTime(2026, 1, 31));
      final d = s.chargesBetween(DateTime(2026, 1, 1), DateTime(2026, 4, 30));
      expect(d, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('недельные списания', () {
      final s = mk(period: BillingPeriod.weekly, next: DateTime(2026, 11, 2));
      final d = s.chargesBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(d.map((e) => e.day), [2, 9, 16, 23, 30]);
    });

    test('годовое списание попадает в нужный месяц', () {
      final s = mk(period: BillingPeriod.yearly, next: DateTime(2026, 3, 14));
      final d = s.chargesBetween(DateTime(2026, 1, 1), DateTime(2027, 12, 31));
      expect(d, [DateTime(2026, 3, 14), DateTime(2027, 3, 14)]);
    });

    test('до даты первого списания списаний нет', () {
      final s = mk(period: BillingPeriod.monthly, next: DateTime(2026, 12, 11));
      expect(s.chargesBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 30)),
          isEmpty);
    });

    test('после даты окончания списаний нет', () {
      final s = mk(
        period: BillingPeriod.monthly,
        next: DateTime(2026, 11, 1),
        end: DateTime(2026, 12, 15),
      );
      final d = s.chargesBetween(DateTime(2026, 11, 1), DateTime(2027, 2, 28));
      expect(d, [DateTime(2026, 11, 1), DateTime(2026, 12, 1)]);
    });

    test('завершённая подписка ничего не стоит', () {
      final s = mk(
        period: BillingPeriod.monthly,
        next: DateTime(2020, 1, 1),
        end: DateTime(2021, 1, 1),
      );
      expect(s.isEnded, isTrue);
      expect(s.perMonth, 0);
    });

    test('триал даёт одно списание ― первое платное', () {
      final s = mk(
          period: BillingPeriod.monthly,
          next: DateTime(2026, 11, 16),
          trial: true);
      final d = s.chargesBetween(DateTime(2026, 11, 1), DateTime(2027, 6, 1));
      expect(d, [DateTime(2026, 11, 16)]);
    });

    test('история цены: JSON и влияние на год', () {
      final c = PriceChange(date: DateTime(2026, 10, 1), from: 10, to: 12);
      final s = mk(
          period: BillingPeriod.monthly,
          next: DateTime(2026, 12, 1),
          price: 12,
          changes: [c]);
      expect(s.yearlyPriceImpact, closeTo(24, 0.001));
      final back = Subscription.decodeList(Subscription.encodeList([s])).single;
      expect(back.priceChanges.single.to, 12);
      expect(back.priceChanges.single.from, 10);
    });

    test('прогноз: годовая подписка даёт пик в свой месяц', () {
      final monthly =
          mk(period: BillingPeriod.monthly, next: DateTime(2026, 1, 15));
      final yearly = mk(
          period: BillingPeriod.yearly, next: DateTime(2026, 3, 14), price: 120);
      final f = buildForecast([monthly, yearly],
          from: DateTime(2026, 1, 1), toBase: (s, a) => a);
      expect(f.months.length, 12);
      expect(f.months[0].amount, 10);
      expect(f.months[2].amount, 130);
      expect(f.total, closeTo(240, 0.001));
    });

    test('прогноз пропускает подписки без курса', () {
      final s = mk(period: BillingPeriod.monthly, next: DateTime(2026, 1, 15));
      final f = buildForecast([s],
          from: DateTime(2026, 1, 1), toBase: (s, a) => null);
      expect(f.total, 0);
      expect(f.skipped, 1);
    });

    test('календарь: списания по дням месяца', () {
      final s = mk(period: BillingPeriod.monthly, next: DateTime(2026, 11, 13));
      final m = chargesByDay([s], DateTime(2026, 12, 1));
      expect(m.keys, [DateTime(2026, 12, 13)]);
    });
  });

  group('Импорт CSV и настройки', () {
    test('разбор CSV: русские и английские значения, кавычки', () {
      const csv = '﻿Name;Amount;Currency;Period;Next charge;Category;Trial;Split between;My share\n'
          '"Netflix; HD";15,49;USD;Monthly;2026-12-01;Видео и музыка;no;1;15.49\n'
          'Облако;2990;rub;Раз в год;2027-02-10;Софт и облако;да;4;747.5\n'
          'Битая строка;abc;USD;Monthly;2026-12-01\n';
      final l = parseSubscriptionsCsv(csv);
      expect(l.length, 2);
      expect(l[0].name, 'Netflix; HD');
      expect(l[0].price, 15.49);
      expect(l[0].period, BillingPeriod.monthly);
      expect(l[0].trial, isFalse);
      expect(l[1].currency, 'RUB');
      expect(l[1].period, BillingPeriod.yearly);
      expect(l[1].trial, isTrue);
      expect(l[1].shareCount, 4);
    });

    test('настройки: лимит, свои категории и блокировка в копии', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppSettings();
      await a.update(
        monthlyBudget: 150,
        customCategories: ['Школа'],
        appLock: true,
      );
      final json = a.toJson();
      SharedPreferences.setMockInitialValues({});
      final b = AppSettings();
      await b.applyJson(json);
      expect(b.monthlyBudget, 150);
      expect(b.customCategories, ['Школа']);
      expect(b.appLock, isTrue);
    });
  });

  group('Палитры', () {
    test('основной цвет сохраняет оттенок плитки палитры', () {
      for (final p in kPalettes.where((p) => p.seed != null)) {
        final seedHue = HSVColor.fromColor(p.seed!).hue;
        final primaryHue = HSVColor.fromColor(
                expressiveScheme(Brightness.light, seed: p.seed).primary)
            .hue;
        var diff = (seedHue - primaryHue).abs();
        if (diff > 180) diff = 360 - diff;
        expect(diff, lessThan(25), reason: '${p.name}: $seedHue vs $primaryHue');
      }
    });
  });

  group('Английский язык', () {
    final cyr = RegExp(r'[А-Яа-яЁё]');

    tearDown(() => appLocale = 'ru');

    test('категории, периоды и палитры переведены', () {
      appLocale = 'en';
      for (final c in kCategories) {
        expect(cyr.hasMatch(tr(c)), isFalse, reason: 'категория $c');
      }
      for (final p in kPalettes) {
        expect(cyr.hasMatch(tr(p.name)), isFalse, reason: 'палитра ${p.name}');
      }
      for (final p in BillingPeriod.values) {
        expect(cyr.hasMatch(p.label), isFalse, reason: 'период $p');
        expect(cyr.hasMatch(p.shortLabel), isFalse, reason: 'период $p');
      }
      expect(tr('Аналитика'), 'Analytics');
    });

    test('подстановки и язык по системному', () {
      appLocale = 'en';
      expect(trf('через {d} дн.', {'d': 5}), 'in 5 days');
      expect(resolveAppLocale(const Locale('en', 'US')), 'en');
      expect(resolveAppLocale(const Locale('de')), 'en');
      expect(resolveAppLocale(const Locale('ru')), 'ru');
      expect(resolveAppLocale(const Locale('kk')), 'ru');
      appLocale = 'ru';
      expect(tr('Аналитика'), 'Аналитика');
    });
  });

  group('Резервная копия', () {
    Subscription sub() => Subscription(
          id: 'a1',
          name: 'Netflix',
          price: 10,
          currency: 'USD',
          period: BillingPeriod.monthly,
          nextCharge: DateTime(2030, 1, 1),
        );

    test('содержит настройки и тему и восстанавливает их', () async {
      SharedPreferences.setMockInitialValues({});
      final s1 = AppSettings();
      await s1.update(
        baseCurrency: 'USD',
        themeMode: ThemeMode.dark,
        paletteIndex: 3,
        amoled: true,
        reminderHour: 8,
        convertAll: true,
      );
      final store1 = SubscriptionStore(settings: s1, rates: RatesService());
      await store1.upsert(sub());
      final json = store1.exportJson();

      // «Переустановка»: чистое хранилище, новые объекты.
      SharedPreferences.setMockInitialValues({});
      final s2 = AppSettings();
      final store2 = SubscriptionStore(settings: s2, rates: RatesService());
      final n = await store2.importJson(json);

      expect(n, 1);
      expect(store2.items.single.name, 'Netflix');
      expect(s2.baseCurrency, 'USD');
      expect(s2.themeMode, ThemeMode.dark);
      expect(s2.paletteIndex, 3);
      expect(s2.amoled, isTrue);
      expect(s2.reminderHour, 8);
      expect(s2.convertAll, isTrue);
    });

    test('старая копия без настроек импортируется и не трогает настройки',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.update(baseCurrency: 'EUR');
      final store = SubscriptionStore(settings: s, rates: RatesService());
      final old = jsonEncode({
        'app': 'appsub',
        'version': 1,
        'subscriptions': [sub().toJson()],
      });
      final n = await store.importJson(old);
      expect(n, 1);
      expect(s.baseCurrency, 'EUR');
    });
  });

  group('EmailParser', () {
    test('извлекает сервис, сумму и валюту из чека', () {
      final c = EmailParser.parse(
        from: 'Netflix <info@mailer.netflix.com>',
        subject: 'Your receipt',
        body: 'Thank you. You were charged \$9.99 for your monthly plan.',
        date: DateTime(2026, 10, 5),
      );
      expect(c, isNotNull);
      expect(c!.name, 'Netflix');
      expect(c.price, 9.99);
      expect(c.currency, 'USD');
      expect(c.period, BillingPeriod.monthly);
    });

    test('русское письмо, годовая подписка', () {
      final c = EmailParser.parse(
        from: 'noreply@yandex.ru',
        subject: 'Оплата подписки',
        body: 'Списано 2990 руб. Ежегодная подписка.',
        date: DateTime(2026, 9, 1),
      );
      expect(c, isNotNull);
      expect(c!.currency, 'RUB');
      expect(c.period, BillingPeriod.yearly);
    });

    test('письмо без суммы игнорируется', () {
      final c = EmailParser.parse(
        from: 'a@b.com',
        subject: 'Hello',
        body: 'No money here',
        date: DateTime(2026, 1, 1),
      );
      expect(c, isNull);
    });

    test('dedupe оставляет самое свежее письмо сервиса', () {
      SubscriptionCandidate mk(DateTime d) => SubscriptionCandidate(
            name: 'Spotify',
            price: 5,
            currency: 'USD',
            period: BillingPeriod.monthly,
            date: d,
            subject: 's',
          );
      final r = EmailParser.dedupe(
          [mk(DateTime(2026, 1, 1)), mk(DateTime(2026, 3, 1))]);
      expect(r, hasLength(1));
      expect(r.first.date, DateTime(2026, 3, 1));
    });
  });

  group('Суммы и SMS', () {
    test('сумма с пробелом как разделителем тысяч', () {
      final a = EmailParser.findAmount('Покупка 1 399,50 KZT Glovo');
      expect(a, isNotNull);
      expect(a!.price, 1399.5);
      expect(a.currency, 'KZT');
    });

    test('SMS: известный сервис находится, интервал даёт период', () {
      final msgs = [
        SmsMessage('KaspiBank', 'Покупка 2 990 KZT Spotify', DateTime(2026, 9, 5)),
        SmsMessage('KaspiBank', 'Покупка 2 990 KZT Spotify', DateTime(2026, 10, 5)),
        SmsMessage('KaspiBank', 'Покупка 500 KZT Магазин', DateTime(2026, 10, 6)),
        SmsMessage('KaspiBank', 'Код подтверждения Spotify 1234', DateTime(2026, 10, 7)),
      ];
      final r = SmsParser.parse(msgs);
      expect(r, hasLength(1));
      expect(r.first.name, 'Spotify');
      expect(r.first.price, 2990);
      expect(r.first.period, BillingPeriod.monthly);
    });
  });

  group('Доли, триал, отмена', () {
    Subscription mk({bool trial = false, int share = 1}) => Subscription(
          id: '1',
          name: 'Netflix',
          price: 1000,
          currency: 'RUB',
          period: BillingPeriod.monthly,
          nextCharge: DateTime(2030, 1, 1),
          trial: trial,
          shareCount: share,
        );

    test('моя доля делится на число участников', () {
      expect(mk(share: 4).myPrice, 250);
      expect(mk(share: 4).perMonth, 250);
    });

    test('триал не входит в месячный итог', () {
      expect(mk(trial: true).perMonth, 0);
    });

    test('ссылка отмены: из справочника или поиск', () {
      expect(mk().cancelLink, contains('netflix.com'));
      final other = Subscription(
        id: '2',
        name: 'Мой сервис',
        price: 1,
        currency: 'RUB',
        period: BillingPeriod.monthly,
        nextCharge: DateTime(2030, 1, 1),
      );
      expect(other.cancelLink, contains('google.com/search'));
    });

    test('старые данные без новых полей читаются', () {
      final s = Subscription.fromJson({
        'id': 'x',
        'name': 'Old',
        'price': 5,
        'currency': 'USD',
        'period': 'monthly',
        'nextCharge': '2030-01-01T00:00:00.000',
      });
      expect(s.shareCount, 1);
      expect(s.trial, isFalse);
      expect(s.convert, isFalse);
    });
  });

  group('Subscription', () {
    test('прибавление месяца не выходит за конец месяца', () {
      expect(BillingPeriod.monthly.addTo(DateTime(2026, 1, 31)),
          DateTime(2026, 2, 28));
    });

    test('годовая цена приводится к месяцу', () {
      final s = Subscription(
        id: '1',
        name: 'X',
        price: 120,
        currency: 'USD',
        period: BillingPeriod.yearly,
        nextCharge: DateTime(2030, 1, 1),
      );
      expect(s.perMonth, 10);
    });

    test('прошедшая дата списания прокручивается вперёд', () {
      final s = Subscription(
        id: '1',
        name: 'X',
        price: 1,
        currency: 'USD',
        period: BillingPeriod.monthly,
        nextCharge: DateTime(2020, 1, 15),
      );
      final now = DateTime.now();
      expect(s.upcomingCharge.isBefore(DateTime(now.year, now.month, now.day)),
          isFalse);
    });

    test('JSON туда-обратно', () {
      final s = Subscription(
        id: '1',
        name: 'X',
        price: 4.5,
        currency: 'EUR',
        period: BillingPeriod.quarterly,
        nextCharge: DateTime(2026, 12, 1),
        fromEmail: true,
      );
      final back = Subscription.decodeList(Subscription.encodeList([s])).single;
      expect(back.name, 'X');
      expect(back.period, BillingPeriod.quarterly);
      expect(back.fromEmail, isTrue);
    });
  });
}
