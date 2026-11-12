import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_settings.dart';
import '../data/known_services.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';
import '../widgets/springy.dart';
import '../l10n/tr.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({
    super.key,
    required this.settings,
    this.existing,
    this.draft,
  });

  final AppSettings settings;

  /// Редактирование существующей подписки.
  final Subscription? existing;

  /// Предзаполненный черновик (например, из почты или SMS).
  final Subscription? draft;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _cancelUrl;
  late String _currency;
  late BillingPeriod _period;
  late DateTime _date;
  late String _category;
  late int _remind;
  late bool _trial;
  late int _share;
  late bool _convert;
  late final TextEditingController _names;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final s = widget.existing ?? widget.draft;
    _name = TextEditingController(text: s?.name ?? '');
    _price = TextEditingController(text: s == null ? '' : '${s.price}');
    _cancelUrl = TextEditingController(text: s?.cancelUrl ?? '');
    _currency = s?.currency ?? widget.settings.baseCurrency;
    if (!kCurrencies.contains(_currency)) _currency = kCurrencies.first;
    _period = s?.period ?? BillingPeriod.monthly;
    _date = s?.nextCharge ?? DateTime.now().add(const Duration(days: 30));
    // Категория хранится русским ключом, а переводится только при показе.
    _category = s?.category ?? 'Другое';
    _remind = s?.remindDaysBefore ?? 3;
    _trial = s?.trial ?? false;
    _share = s?.shareCount ?? 1;
    // Для новой подписки по умолчанию берём общую настройку.
    _convert = s == null || widget.existing == null && widget.draft != null
        ? widget.settings.convertAll
        : s.convert;
    _names = TextEditingController(text: (s?.sharedWith ?? []).join(', '));
    _endDate = s?.endDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cancelUrl.dispose();
    _names.dispose();
    super.dispose();
  }

  /// Диалог «своя категория».
  Future<void> _addCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Новая категория')),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('Название категории')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: Text(tr('Отмена'))),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: Text(tr('Добавить'))),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    final exists = kCategories.contains(name) ||
        widget.settings.customCategories.contains(name);
    if (!exists) {
      await widget.settings
          .update(customCategories: [...widget.settings.customCategories, name]);
    }
    if (mounted) setState(() => _category = name);
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _openCancel() async {
    final custom = _cancelUrl.text.trim();
    final link = custom.isNotEmpty
        ? custom
        : (KnownServices.cancelUrlFor(_name.text) ??
            'https://www.google.com/search?q=${Uri.encodeQueryComponent('как отменить подписку ${_name.text}')}');
    final ok = await launchUrl(Uri.parse(link),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Не удалось открыть ссылку'))));
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final base = widget.existing ?? widget.draft;
    final custom = _cancelUrl.text.trim();
    final newPrice = double.parse(_price.text.replaceAll(',', '.'));
    final old = widget.existing;
    // Если цена изменилась, записываем это в историю.
    final changes = [...?old?.priceChanges];
    if (old != null && old.price != newPrice) {
      changes.add(
          PriceChange(date: DateTime.now(), from: old.price, to: newPrice));
    }
    final others = _share > 1
        ? _names.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    Navigator.pop(
      context,
      Subscription(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        price: newPrice,
        currency: _currency,
        period: _period,
        nextCharge: _date,
        category: _category,
        remindDaysBefore: _remind,
        fromEmail: base?.fromEmail ?? false,
        trial: _trial,
        shareCount: _share,
        convert: _convert,
        cancelUrl: custom.isEmpty ? null : custom,
        endDate: _endDate,
        priceChanges: changes,
        sharedWith: others,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.existing != null;
    final base = widget.settings.baseCurrency;
    final price = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
    final money = NumberFormat('#,##0.##', appLocale);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(editing ? tr('Сохранить изменения') : tr('Добавить подписку')),
            ),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(editing ? tr('Редактировать') : tr('Новая подписка')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Entrance(
                    index: 0,
                    child: _Preview(
                      name: _name,
                      price: _price,
                      currency: _currency,
                      period: _period,
                      share: _share,
                      trial: _trial,
                    ),
                  ),
                  if (!editing) ...[
                    const SizedBox(height: 20),
                    Entrance(
                      index: 1,
                      child: _Section(
                        title: tr('Быстрый выбор'),
                        child: SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: KnownServices.all.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final p = KnownServices.all[i];
                              return ActionChip(
                                label: Text(p.display),
                                onPressed: () => setState(() {
                                  _name.text = p.display;
                                  _category = p.category;
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Entrance(
                    index: 2,
                    child: _Section(
                      title: tr('Сервис и сумма'),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            decoration:
                                InputDecoration(labelText: tr('Название')),
                            textCapitalization: TextCapitalization.sentences,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? tr('Введите название')
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _price,
                            decoration:
                                InputDecoration(labelText: tr('Сумма')),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = double.tryParse(
                                  (v ?? '').replaceAll(',', '.'));
                              return (n == null || n <= 0)
                                  ? tr('Введите сумму')
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final c in kCurrencies)
                                  ChoiceChip(
                                    label: Text(c),
                                    selected: _currency == c,
                                    onSelected: (_) =>
                                        setState(() => _currency = c),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    index: 3,
                    child: _Section(
                      title: tr('Как часто списывают'),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<BillingPeriod>(
                          showSelectedIcon: false,
                          segments: [
                            for (final p in BillingPeriod.values)
                              ButtonSegment(
                                  value: p, label: Text(p.shortLabel)),
                          ],
                          selected: {_period},
                          onSelectionChanged: (s) =>
                              setState(() => _period = s.first),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    index: 4,
                    child: _Section(
                      title: _trial
                          ? tr('Первое платное списание')
                          : tr('Следующее списание'),
                      child: Springy(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: ShapeDecoration(
                            color: scheme.secondaryContainer,
                            shape: expressiveShape(24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_rounded,
                                  color: scheme.onSecondaryContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat.yMMMMd(appLocale).format(_date),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: scheme.onSecondaryContainer),
                                ),
                              ),
                              Icon(Icons.edit_calendar_rounded,
                                  color: scheme.onSecondaryContainer),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    index: 5,
                    child: _Section(
                      title: tr('Категория'),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in kCategories)
                              ChoiceChip(
                                label: Text(tr(c)),
                                selected: _category == c,
                                onSelected: (_) =>
                                    setState(() => _category = c),
                              ),
                            // Свои категории можно удалить крестиком.
                            for (final c in widget.settings.customCategories)
                              InputChip(
                                label: Text(c),
                                selected: _category == c,
                                onSelected: (_) =>
                                    setState(() => _category = c),
                                onDeleted: () async {
                                  final cats = [
                                    ...widget.settings.customCategories
                                  ]..remove(c);
                                  await widget.settings
                                      .update(customCategories: cats);
                                  if (_category == c) _category = 'Другое';
                                  if (mounted) setState(() {});
                                },
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 18),
                              label: Text(tr('Своя категория')),
                              onPressed: _addCategory,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    index: 6,
                    child: _Section(
                      title: tr('Напомнить заранее'),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(value: 0, label: Text(tr('Нет'))),
                            ButtonSegment(value: 1, label: Text(tr('1 дн.'))),
                            ButtonSegment(value: 3, label: Text(tr('3 дн.'))),
                            ButtonSegment(value: 7, label: Text(tr('7 дн.'))),
                          ],
                          selected: {_remind},
                          onSelectionChanged: (s) =>
                              setState(() => _remind = s.first),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    index: 7,
                    child: _Section(
                      title: tr('Дополнительно'),
                      child: Column(
                        children: [
                          _OptionCard(
                            icon: Icons.hourglass_top_rounded,
                            title: tr('Пробный период'),
                            subtitle: _trial
                                ? tr('В итоги не входит. Напомним отменить до списания.')
                                : tr('Бесплатный триал, который нужно вовремя отменить'),
                            value: _trial,
                            onChanged: (v) => setState(() => _trial = v),
                          ),
                          const SizedBox(height: 8),
                          _OptionCard(
                            icon: Icons.group_rounded,
                            title: tr('Делю оплату с другими'),
                            subtitle: _share > 1
                                ? trf('Платят {n} чел. Ваша доля: {sum} {cur}', {
                                    'n': _share,
                                    'sum': money.format(price / _share),
                                    'cur': _currency,
                                  })
                                : tr('Семейный тариф или оплата на компанию'),
                            value: _share > 1,
                            onChanged: (v) =>
                                setState(() => _share = v ? 2 : 1),
                            trailing: _share > 1
                                ? _Stepper(
                                    value: _share,
                                    min: 2,
                                    max: 10,
                                    onChanged: (v) =>
                                        setState(() => _share = v),
                                  )
                                : null,
                          ),
                          if (_share > 1) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _names,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                  labelText:
                                      tr('Имена остальных (через запятую)')),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _OptionCard(
                            icon: Icons.event_busy_rounded,
                            title: tr('Подписка заканчивается'),
                            subtitle: _endDate == null
                                ? tr('Оплачено до определённой даты? Напомним заранее')
                                : DateFormat.yMMMMd(appLocale).format(_endDate!),
                            value: _endDate != null,
                            onChanged: (v) {
                              if (v) {
                                _pickEndDate();
                              } else {
                                setState(() => _endDate = null);
                              }
                            },
                            trailing: _endDate == null
                                ? null
                                : TextButton(
                                    onPressed: _pickEndDate,
                                    child: Text(tr('Изменить дату'))),
                          ),
                          const SizedBox(height: 8),
                          _OptionCard(
                            icon: Icons.currency_exchange_rounded,
                            title: trf('Пересчитывать в {base}', {'base': base}),
                            subtitle: _currency == base
                                ? tr('Подписка уже в основной валюте')
                                : tr('Сумма войдёт в итог по текущему курсу'),
                            value: _convert,
                            onChanged: (v) => setState(() => _convert = v),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cancelUrl,
                            decoration: InputDecoration(
                              labelText: tr('Ссылка для отмены (необязательно)'),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _name.text.trim().isEmpty ? null : _openCancel,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(tr('Как отменить подписку')),
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (editing && widget.existing!.priceChanges.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Section(
                      title: tr('История цены'),
                      child: _PriceHistory(
                        changes: widget.existing!.priceChanges,
                        currency: _currency,
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Список изменений цены подписки.
class _PriceHistory extends StatelessWidget {
  const _PriceHistory({required this.changes, required this.currency});
  final List<PriceChange> changes;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0.##', appLocale);
    final date = DateFormat.yMMMd(appLocale);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: expressiveShape(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in changes.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    c.to > c.from
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 20,
                    color: c.to > c.from ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${date.format(c.date)}: ${money.format(c.from)} → ${money.format(c.to)} $currency',
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок на одной линии с левым краем полей и карточек.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Карточка-переключатель в стиле Expressive.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: ShapeDecoration(
        color: value ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        shape: expressiveShape(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon,
                  color: value ? scheme.onPrimaryContainer : scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: value
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: t.bodySmall?.copyWith(
                            color: value
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 64,
          child: Text(trf('{n} чел.', {'n': value}),
              textAlign: TextAlign.center, style: t.titleMedium),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// Живой предпросмотр карточки: обновляется по мере ввода.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.price,
    required this.currency,
    required this.period,
    required this.share,
    required this.trial,
  });

  final TextEditingController name;
  final TextEditingController price;
  final String currency;
  final BillingPeriod period;
  final int share;
  final bool trial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0.##', appLocale);
    return ListenableBuilder(
      listenable: Listenable.merge([name, price]),
      builder: (context, _) {
        final n = name.text.trim();
        final p = double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
        final mine = p / share;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            color: scheme.primaryContainer,
            shape: expressiveShape(36),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: scheme.tertiaryContainer,
                  shape: expressiveShape(n.isEmpty ? 30 : 20),
                ),
                child: Text(
                  n.isEmpty ? '?' : n[0].toUpperCase(),
                  style: t.headlineSmall
                      ?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.isEmpty ? tr('Название сервиса') : n,
                      style: t.titleLarge
                          ?.copyWith(color: scheme.onPrimaryContainer),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p == 0
                          ? period.label
                          : '${money.format(mine)} $currency · ${period.label.toLowerCase()}'
                              '${share > 1 ? ' (ваша доля)' : ''}',
                      style: t.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.8)),
                    ),
                    if (trial)
                      Text(tr('Пробный период: пока ничего не списывается'),
                          style: t.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.8)))
                    else if (p > 0 && period != BillingPeriod.monthly)
                      Text(
                        trf('≈ {sum} {cur} в месяц', {
                          'sum': money.format(mine * period.monthlyFactor()),
                          'cur': currency,
                        }),
                        style: t.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.8)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
