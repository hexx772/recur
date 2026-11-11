import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';
import '../widgets/springy.dart';
import 'edit_screen.dart';
import 'email_beta_screen.dart';
import 'sms_beta_screen.dart';
import '../l10n/tr.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});
  final SubscriptionStore store;

  Future<void> _add(BuildContext context) async {
    final s = await Navigator.push<Subscription>(
      context,
      MaterialPageRoute(
          builder: (_) => EditScreen(settings: store.settings)),
    );
    if (s != null) await store.upsert(s);
  }

  Future<void> _edit(BuildContext context, Subscription sub) async {
    final s = await Navigator.push<Subscription>(
      context,
      MaterialPageRoute(
          builder: (_) => EditScreen(settings: store.settings, existing: sub)),
    );
    if (s != null) await store.upsert(s);
  }

  Future<bool> _confirmDelete(BuildContext context, Subscription s) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(trf('Удалить «{name}»?', {'name': s.name})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('Отмена'))),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr('Удалить'))),
          ],
        ),
      ) ??
      false;

  /// Меню по долгому нажатию на карточку.
  void _actions(BuildContext context, Subscription s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.name, style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(tr('Изменить')),
              onTap: () {
                Navigator.pop(sheet);
                _edit(context, s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_schedule_send_rounded),
              title: Text(tr('Как отменить подписку')),
              subtitle: Text(tr('Откроется страница отмены в браузере')),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await launchUrl(Uri.parse(s.cancelLink),
                    mode: LaunchMode.externalApplication);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('Не удалось открыть ссылку'))));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(tr('Удалить')),
              onTap: () async {
                Navigator.pop(sheet);
                if (await _confirmDelete(context, s)) await store.remove(s.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _autoFind(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tr('Найти подписки автоматически')),
              subtitle: Text(tr('Бета-функции')),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: Text(tr('В почте (Gmail)')),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EmailBetaScreen(store: store)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: Text(tr('В SMS банка (Android)')),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SmsBetaScreen(store: store)));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.items;
        return Scaffold(
          floatingActionButton: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(tr('Добавить')),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(tr('Подписки')),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filledTonal(
                      tooltip: tr('Найти автоматически (бета)'),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      onPressed: () => _autoFind(context),
                    ),
                  ),
                ],
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(color: scheme.primary),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Entrance(
                    index: 0,
                    child: _Summary(
                      totals: store.monthlyTotals,
                      count: items.length,
                      trials: store.trialCount,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = items[i];
                      return Entrance(
                        key: ValueKey('e_${s.id}'),
                        index: i + 1,
                        child: Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: ShapeDecoration(
                              color: scheme.errorContainer,
                              shape: expressiveShape(28),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(Icons.delete_outline,
                                color: scheme.onErrorContainer),
                          ),
                          confirmDismiss: (_) => _confirmDelete(context, s),
                          onDismissed: (_) => store.remove(s.id),
                          child: _Tile(
                            sub: s,
                            onTap: () => _edit(context, s),
                            onLongPress: () => _actions(context, s),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (context, v, child) => Transform.rotate(
                angle: (1 - v) * -0.6,
                child: Transform.scale(scale: v, child: child)),
            child: Container(
              width: 120,
              height: 120,
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: expressiveShape(44),
              ),
              child: Icon(Icons.subscriptions_rounded,
                  size: 56, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Пока пусто'), style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            tr('Добавьте подписку вручную\nили найдите автоматически (бета).'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.totals,
    required this.count,
    required this.trials,
  });
  final Map<String, double> totals;
  final int count;
  final int trials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0', appLocale);
    final yearly = totals.entries
        .map((e) => '${money.format(e.value * 12)} ${e.key}')
        .join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: ShapeDecoration(
        color: scheme.primaryContainer,
        shape: expressiveShape(40),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                  color: scheme.tertiaryContainer, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -24,
            child: Container(
              width: 72,
              height: 72,
              decoration: ShapeDecoration(
                  color: scheme.secondaryContainer, shape: expressiveShape(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('В МЕСЯЦ'),
                    style: t.labelLarge?.copyWith(
                        letterSpacing: 1.5, color: scheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                if (totals.isEmpty)
                  Text('0',
                      style: t.displayMedium
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                for (final e in totals.entries)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: e.value),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${money.format(v)} ${e.key}',
                        style: t.displayMedium
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  [
                    if (totals.isNotEmpty) trf('В год: {y}', {'y': yearly}),
                    trf('подписок: {n}', {'n': count}),
                    if (trials > 0) trf('триалов: {n}', {'n': trials}),
                  ].join(' · '),
                  style: t.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.sub,
    required this.onTap,
    required this.onLongPress,
  });
  final Subscription sub;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  ShapeBorder _avatarShape() {
    switch (sub.name.codeUnitAt(0) % 3) {
      case 0:
        return const CircleBorder();
      case 1:
        return expressiveShape(18);
      default:
        return const StadiumBorder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final urgent =
        sub.remindDaysBefore > 0 && sub.daysLeft <= sub.remindDaysBefore;
    final money = NumberFormat('#,##0.##', appLocale);
    final avatarColors = [
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.primaryContainer, scheme.onPrimaryContainer),
    ][sub.name.codeUnitAt(0) % 3];

    // Цвет чипа: триал и срочные списания выделяются.
    final chipBg = urgent
        ? scheme.errorContainer
        : sub.trial
            ? scheme.tertiaryContainer
            : scheme.secondaryContainer;
    final chipFg = urgent
        ? scheme.onErrorContainer
        : sub.trial
            ? scheme.onTertiaryContainer
            : scheme.onSecondaryContainer;

    return Springy(
      onTap: onTap,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh,
            shape: expressiveShape(28),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                    color: avatarColors.$1, shape: _avatarShape()),
                child: Text(sub.name[0].toUpperCase(),
                    style: t.titleLarge?.copyWith(color: avatarColors.$2)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name,
                        style: t.titleMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        sub.period.label,
                        DateFormat.MMMd(appLocale).format(sub.upcomingCharge),
                        if (sub.shareCount > 1) '÷${sub.shareCount}',
                      ].join(' · '),
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${money.format(sub.myPrice)} ${sub.currency}',
                      style: t.titleMedium),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: ShapeDecoration(
                        color: chipBg, shape: const StadiumBorder()),
                    child: Text(
                      sub.trial
                          ? trf('триал · {when}', {'when': sub.whenLabel})
                          : sub.whenLabel,
                      style: t.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700, color: chipFg),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
