import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/forecast.dart';
import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';
import '../widgets/springy.dart';
import '../l10n/tr.dart';

/// Аналитика расходов: по категориям, самые дорогие, пробные периоды.
/// Суммы приводятся к основной валюте из настроек.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.store});
  final SubscriptionStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final t = Theme.of(context).textTheme;
        final base = store.settings.baseCurrency;
        final money = NumberFormat('#,##0', appLocale);

        final paying = store.items.where((s) => s.perMonth > 0).toList();
        final rows = <(Subscription, double)>[];
        var skipped = 0;
        for (final s in paying) {
          final v = store.monthlyInBase(s);
          if (v == null) {
            skipped++;
          } else {
            rows.add((s, v));
          }
        }
        final total = rows.fold<double>(0, (a, r) => a + r.$2);

        final byCat = <String, double>{};
        for (final r in rows) {
          byCat[r.$1.category] = (byCat[r.$1.category] ?? 0) + r.$2;
        }
        final cats = byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final top = [...rows]..sort((a, b) => b.$2.compareTo(a.$2));
        final trials = store.items.where((s) => s.trial).toList();

        // Экономия от общей оплаты: полная цена минус моя доля, в месяц.
        var saved = 0.0;
        for (final s in store.items.where((s) => s.shareCount > 1 && !s.trial)) {
          final full = s.price * s.period.monthlyFactor();
          final c = store.rates.convert(full, s.currency, base);
          final mine = store.monthlyInBase(s);
          if (c != null && mine != null) saved += c - mine;
        }

        // Прогноз на 12 месяцев с учётом реальных дат списаний.
        final forecast = buildForecast(
          store.items,
          from: DateTime.now(),
          toBase: (s, a) => store.rates.convert(a, s.currency, base),
        );

        // Как повышения цен влияют на расходы за год.
        var priceImpact = 0.0;
        var raised = 0;
        for (final s in store.items) {
          final y = s.yearlyPriceImpact;
          if (y > 0) {
            final c = store.rates.convert(y, s.currency, base);
            if (c != null) {
              priceImpact += c;
              raised++;
            }
          }
        }

        final colors = _palette(scheme.primary, cats.length);

        return CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(tr('Аналитика'))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (rows.isEmpty && trials.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        paying.isEmpty
                            ? tr('Добавьте подписки, и здесь появится разбивка расходов.')
                            : trf(
                                'Для пересчёта в {base} нужны курсы валют. Обновите их в настройках.',
                                {'base': base}),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (rows.isNotEmpty) ...[
                    Entrance(
                      index: 0,
                      child: _Card(
                        color: scheme.surfaceContainerHigh,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('РАСХОДЫ ПО КАТЕГОРИЯМ'),
                                style: t.labelMedium?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary)),
                            const SizedBox(height: 16),
                            Center(
                              child: SizedBox(
                                width: 220,
                                height: 220,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, p, _) => CustomPaint(
                                    painter: _DonutPainter(
                                      values: [for (final c in cats) c.value],
                                      colors: colors,
                                      progress: p,
                                      track: scheme.surfaceContainerHighest,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(money.format(total * p),
                                              style: t.headlineMedium),
                                          Text(trf('{base} / мес', {'base': base}),
                                              style: t.bodySmall?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (var i = 0; i < cats.length; i++)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: ShapeDecoration(
                                        color: colors[i],
                                        shape: expressiveShape(5),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(tr(cats[i].key),
                                            style: t.bodyLarge)),
                                    Text(
                                      '${money.format(cats[i].value)} $base · '
                                      '${(cats[i].value / total * 100).round()}%',
                                      style: t.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      index: 1,
                      child: _Card(
                        color: scheme.surfaceContainerHigh,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('САМЫЕ ДОРОГИЕ'),
                                style: t.labelMedium?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary)),
                            const SizedBox(height: 12),
                            for (final r in top.take(5))
                              _Bar(
                                name: r.$1.name,
                                value: r.$2,
                                max: top.first.$2,
                                label: '${money.format(r.$2)} $base',
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      index: 2,
                      child: _Card(
                        color: scheme.surfaceContainerHigh,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('ПРОГНОЗ НА 12 МЕСЯЦЕВ'),
                                style: t.labelMedium?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary)),
                            const SizedBox(height: 16),
                            _ForecastChart(forecast: forecast, base: base),
                            const SizedBox(height: 12),
                            Text(
                              trf('Всего за 12 месяцев: {sum} {base}', {
                                'sum': money.format(forecast.total),
                                'base': base,
                              }),
                              style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (raised > 0) ...[
                    const SizedBox(height: 16),
                    Entrance(
                      index: 3,
                      child: _Card(
                        color: scheme.errorContainer,
                        child: Row(
                          children: [
                            Icon(Icons.trending_up_rounded,
                                color: scheme.onErrorContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                trf('Цены выросли: +{sum} {base} в год ({n})', {
                                  'sum': money.format(priceImpact),
                                  'base': base,
                                  'n': raised,
                                }),
                                style: t.titleSmall?.copyWith(
                                    color: scheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (skipped > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      trf(
                          'Не учтено подписок без курса валюты: {n}. Обновите курсы в настройках.',
                          {'n': skipped}),
                      style: t.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ],
                  if (trials.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Entrance(
                      index: 2,
                      child: _Card(
                        color: scheme.tertiaryContainer,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.hourglass_top_rounded,
                                  color: scheme.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Text(tr('Пробные периоды'),
                                  style: t.titleMedium?.copyWith(
                                      color: scheme.onTertiaryContainer)),
                            ]),
                            const SizedBox(height: 8),
                            for (final s in trials)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  trf('{name}: отмените до {date} ({when})', {
                                    'name': s.name,
                                    'date': DateFormat.MMMd(appLocale)
                                        .format(s.upcomingCharge),
                                    'when': s.whenLabel,
                                  }),
                                  style: t.bodyMedium?.copyWith(
                                      color: scheme.onTertiaryContainer),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (saved > 0.5) ...[
                    const SizedBox(height: 16),
                    Entrance(
                      index: 3,
                      child: _Card(
                        color: scheme.secondaryContainer,
                        child: Row(
                          children: [
                            Icon(Icons.savings_rounded,
                                color: scheme.onSecondaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                trf(
                                    'Общая оплата экономит вам {sum} {base} в месяц',
                                    {'sum': money.format(saved), 'base': base}),
                                style: t.titleSmall?.copyWith(
                                    color: scheme.onSecondaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Палитра в духе основного цвета: тот же тон, сдвиг оттенка.
  static List<Color> _palette(Color primary, int n) {
    final hsv = HSVColor.fromColor(primary);
    return [
      for (var i = 0; i < n; i++)
        hsv
            .withHue((hsv.hue + i * 52) % 360)
            .withSaturation(hsv.saturation.clamp(0.45, 0.8))
            .withValue(hsv.value.clamp(0.65, 0.95))
            .toColor(),
    ];
  }
}

/// Столбчатая диаграмма расходов по месяцам (анимированная).
class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.forecast, required this.base});
  final Forecast forecast;
  final String base;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final maxV = forecast.maxMonth <= 0 ? 1.0 : forecast.maxMonth;
    final compact = NumberFormat.compact(locale: appLocale);
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in forecast.months)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: m.amount / maxV),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (m.amount == forecast.maxMonth && m.amount > 0)
                            Text(compact.format(m.amount),
                                maxLines: 1,
                                style: t.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary)),
                          const SizedBox(height: 4),
                          Container(
                            height: 8 + 100 * v.clamp(0.0, 1.0),
                            decoration: ShapeDecoration(
                              color: m.amount == forecast.maxMonth
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: 0.4),
                              shape: expressiveShape(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final m in forecast.months)
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat.MMM(appLocale)
                        .format(m.month)
                        .substring(0, 1)
                        .toUpperCase(),
                    style: t.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(color: color, shape: expressiveShape(32)),
        child: child,
      );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.name,
    required this.value,
    required this.max,
    required this.label,
  });
  final String name;
  final double value;
  final double max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(name,
                      style: t.bodyLarge, overflow: TextOverflow.ellipsis)),
              Text(label,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: max == 0 ? 0 : value / max),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, f, _) => LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: ShapeDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: const StadiumBorder(),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: math.max(12, c.maxWidth * f.clamp(0.0, 1.0)),
                    decoration: ShapeDecoration(
                      color: scheme.primary,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.progress,
    required this.track,
  });

  final List<double> values;
  final List<Color> colors;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 34.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const gap = 0.07; // зазор между секторами, рад
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2 * progress;
      final draw = math.max(0.0, sweep - (values.length > 1 ? gap : 0));
      if (draw > 0) {
        canvas.drawArc(arc, start + (values.length > 1 ? gap / 2 : 0), draw,
            false, paint..color = colors[i]);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      !identical(old.values, values) && !_same(old.values, values);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
