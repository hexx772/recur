import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/forecast.dart';
import '../data/subscription_store.dart';
import '../l10n/tr.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';
import '../widgets/springy.dart';

/// Календарь списаний: месяц с точками на днях списаний, итог за месяц и
/// список списаний (за выбранный день или за весь месяц).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store});
  final SubscriptionStore store;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;
  bool _reverse = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month, 1);
  }

  void _go(int delta) => setState(() {
        _reverse = delta < 0;
        _month = DateTime(_month.year, _month.month + delta, 1);
        _selected = null;
      });

  void _today() {
    final n = DateTime.now();
    final target = DateTime(n.year, n.month, 1);
    setState(() {
      _reverse = target.isBefore(_month);
      _month = target;
      _selected = dayOf(n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final store = widget.store;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final subs = store.items.where((s) => !s.isEnded).toList();
        final byDay = chargesByDay(subs, _month);
        final base = store.settings.baseCurrency;

        // Сумма за месяц в основной валюте (без курса подписка пропускается).
        var total = 0.0;
        for (final e in byDay.entries) {
          for (final s in e.value) {
            final v = store.rates.convert(s.myPrice, s.currency, base);
            if (v != null) total += v;
          }
        }
        final money = NumberFormat('#,##0.##', appLocale);

        final days = (_selected != null
                ? (byDay[_selected] ?? const <Subscription>[])
                    .map((s) => (_selected!, s))
                : [
                    for (final k in byDay.keys.toList()..sort())
                      for (final s in byDay[k]!) (k, s),
                  ])
            .toList();

        return CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(tr('Календарь'))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Entrance(
                    index: 0,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _go(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            toBeginningOfSentenceCase(
                                DateFormat.yMMMM(appLocale).format(_month))!,
                            textAlign: TextAlign.center,
                            style: t.titleLarge,
                          ),
                        ),
                        TextButton(
                            onPressed: _today, child: Text(tr('Сегодня'))),
                        IconButton.filledTonal(
                          onPressed: () => _go(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 380),
                    reverse: _reverse,
                    transitionBuilder: (child, a, b) => SharedAxisTransition(
                      animation: a,
                      secondaryAnimation: b,
                      transitionType: SharedAxisTransitionType.horizontal,
                      fillColor: Colors.transparent,
                      child: child,
                    ),
                    child: Column(
                      key: ValueKey(_month),
                      children: [
                        _MonthGrid(
                          month: _month,
                          byDay: byDay,
                          selected: _selected,
                          onSelect: (d) => setState(
                              () => _selected = _selected == d ? null : d),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: ShapeDecoration(
                            color: scheme.primaryContainer,
                            shape: expressiveShape(32),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Сумма за месяц').toUpperCase(),
                                style: t.labelMedium?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onPrimaryContainer),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${money.format(total)} $base',
                                style: t.headlineMedium?.copyWith(
                                    color: scheme.onPrimaryContainer),
                              ),
                              Text(
                                trf('Списаний: {n}', {
                                  'n': byDay.values
                                      .fold<int>(0, (a, l) => a + l.length)
                                }),
                                style: t.bodyMedium?.copyWith(
                                    color: scheme.onPrimaryContainer
                                        .withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (days.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _selected == null
                                  ? tr('В этом месяце списаний нет')
                                  : tr('В этот день списаний нет'),
                              style: t.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant),
                            ),
                          )
                        else
                          for (final (d, s) in days)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ChargeRow(date: d, sub: s),
                            ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Сетка месяца: числа и цветные точки по числу списаний в день.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final Map<DateTime, List<Subscription>> byDay;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final first = loc.firstDayOfWeekIndex; // 0 = воскресенье
    final lead = (month.weekday % 7 - first + 7) % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + count) / 7).ceil();
    final today = dayOf(DateTime.now());
    final dotColors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: expressiveShape(32),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      loc.narrowWeekdays[(first + i) % 7],
                      style: t.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final n = r * 7 + c - lead + 1;
                      if (n < 1 || n > count) {
                        return const AspectRatio(
                            aspectRatio: 0.9, child: SizedBox());
                      }
                      final d = DateTime(month.year, month.month, n);
                      final list = byDay[d] ?? const <Subscription>[];
                      final isSel = selected == d;
                      final isToday = d == today;
                      return AspectRatio(
                        aspectRatio: 0.9,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Springy(
                            pressed: 0.9,
                            onTap: () => onSelect(d),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              decoration: ShapeDecoration(
                                color: isSel
                                    ? scheme.primaryContainer
                                    : Colors.transparent,
                                shape: isToday
                                    ? RoundedSuperellipseBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        side: BorderSide(
                                            color: scheme.primary, width: 2),
                                      )
                                    : expressiveShape(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$n',
                                    style: t.bodyMedium?.copyWith(
                                      fontWeight: list.isEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w800,
                                      color: isSel
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  SizedBox(
                                    height: 6,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (final s in list.take(3))
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
                                            decoration: BoxDecoration(
                                              color: dotColors[
                                                  s.name.hashCode.abs() %
                                                      dotColors.length],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.date, required this.sub});
  final DateTime date;
  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0.##', appLocale);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: expressiveShape(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: ShapeDecoration(
              color: scheme.secondaryContainer,
              shape: expressiveShape(16),
            ),
            child: Column(
              children: [
                Text('${date.day}',
                    style: t.titleMedium
                        ?.copyWith(color: scheme.onSecondaryContainer)),
                Text(
                  DateFormat.MMM(appLocale).format(date),
                  style: t.labelSmall
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name,
                    style: t.titleMedium, overflow: TextOverflow.ellipsis),
                Text(
                  sub.trial
                      ? tr('первое платное списание')
                      : tr(sub.category),
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text('${money.format(sub.myPrice)} ${sub.currency}',
              style: t.titleMedium),
        ],
      ),
    );
  }
}
