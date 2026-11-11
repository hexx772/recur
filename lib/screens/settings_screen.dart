import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/known_services.dart';
import '../data/subscription_store.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/springy.dart';
import 'email_beta_screen.dart';
import 'sms_beta_screen.dart';
import '../l10n/tr.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});
  final SubscriptionStore store;

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleReminders(BuildContext context, bool on) async {
    if (on) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok && context.mounted) {
        _snack(context,
            tr('Разрешите уведомления для приложения в настройках Android'));
      }
    }
    await store.settings.update(remindersEnabled: on);
  }

  Future<void> _pickHour(BuildContext context) async {
    final s = store.settings;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: 0),
      helpText: tr('Во сколько напоминать'),
    );
    if (t != null) await s.update(reminderHour: t.hour);
  }

  Future<void> _import(BuildContext context) async {
    try {
      final n = await BackupService.importJson(store);
      if (n != null && context.mounted) {
        _snack(context, trf('Импортировано подписок: {n}', {'n': n}));
      }
    } catch (e) {
      if (context.mounted) _snack(context, trf('Не удалось импортировать: {e}', {'e': e}));
    }
  }

  Future<void> _export(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) _snack(context, trf('Не удалось экспортировать: {e}', {'e': e}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, store.settings, store.rates]),
      builder: (context, _) {
        final s = store.settings;
        final rates = store.rates;
        final scheme = Theme.of(context).colorScheme;
        final t = Theme.of(context).textTheme;
        final fmt = DateFormat('d MMM, HH:mm', appLocale);

        return CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(tr('Настройки'))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Group(
                    title: tr('Оформление'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Тема'), style: t.titleSmall),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ThemeMode>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                      value: ThemeMode.system,
                                      icon: Icon(Icons.brightness_auto_rounded),
                                      label: Text(tr('Авто'))),
                                  ButtonSegment(
                                      value: ThemeMode.light,
                                      icon: Icon(Icons.light_mode_rounded),
                                      label: Text(tr('Светлая'))),
                                  ButtonSegment(
                                      value: ThemeMode.dark,
                                      icon: Icon(Icons.dark_mode_rounded),
                                      label: Text(tr('Тёмная'))),
                                ],
                                selected: {s.themeMode},
                                onSelectionChanged: (v) =>
                                    s.update(themeMode: v.first),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Цветовая палитра'), style: t.titleSmall),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < kPalettes.length; i++)
                                  _Swatch(
                                    palette: kPalettes[i],
                                    selected: s.paletteIndex == i,
                                    onTap: () => s.update(paletteIndex: i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        title: Text(tr('Чёрный фон (AMOLED)')),
                        subtitle: Text(
                            tr('В тёмной теме: экономит заряд на OLED-экранах')),
                        value: s.amoled,
                        onChanged: (v) => s.update(amoled: v),
                      ),
                    ],
                  ),
                  _Group(
                    title: tr('Напоминания'),
                    children: [
                      SwitchListTile(
                        title: Text(tr('Push-напоминания о списаниях')),
                        subtitle: Text(
                            tr('За сколько дней напоминать, задаётся в каждой подписке')),
                        value: s.remindersEnabled,
                        onChanged: (v) => _toggleReminders(context, v),
                      ),
                      ListTile(
                        enabled: s.remindersEnabled,
                        title: Text(tr('Время напоминания')),
                        trailing: Text(
                            '${s.reminderHour.toString().padLeft(2, '0')}:00',
                            style: t.titleMedium),
                        onTap: s.remindersEnabled
                            ? () => _pickHour(context)
                            : null,
                      ),
                    ],
                  ),
                  _Group(
                    title: tr('Валюта'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Основная валюта'), style: t.titleSmall),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final c in kCurrencies)
                                  ChoiceChip(
                                    label: Text(c),
                                    selected: s.baseCurrency == c,
                                    onSelected: (_) =>
                                        s.update(baseCurrency: c),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        title: Text(trf('Пересчитывать все подписки в {base}',
                            {'base': s.baseCurrency})),
                        subtitle: Text(
                            tr('Применяется ко всем подпискам сразу. Для каждой '
                            'подписки можно изменить при редактировании.')),
                        value: s.convertAll,
                        onChanged: (v) async {
                          await s.update(convertAll: v);
                          await store.setConvertForAll(v);
                        },
                      ),
                      ListTile(
                        title: Text(tr('Курсы валют')),
                        subtitle: Text(
                          rates.loading
                              ? tr('Обновляю…')
                              : rates.error ??
                                  (rates.updated == null
                                      ? tr('Ещё не загружены')
                                      : trf('Обновлены {d}',
                                          {'d': fmt.format(rates.updated!)})),
                          style: rates.error != null
                              ? TextStyle(color: scheme.error)
                              : null,
                        ),
                        trailing: IconButton.filledTonal(
                          onPressed: rates.loading
                              ? null
                              : () => rates.refresh(force: true),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ],
                  ),
                  _Group(
                    title: tr('Данные'),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file_rounded),
                        title: Text(tr('Резервная копия (JSON)')),
                        subtitle: Text(
                            tr('Подписки и настройки, в том числе тема')),
                        onTap: () => _export(
                            context, () => BackupService.exportJson(store)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.table_chart_rounded),
                        title: Text(tr('Экспорт в таблицу (CSV)')),
                        onTap: () => _export(
                            context, () => BackupService.exportCsv(store)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.download_rounded),
                        title: Text(tr('Восстановить из копии')),
                        subtitle: Text(
                            tr('Подписки и настройки возвращаются из файла копии')),
                        onTap: () => _import(context),
                      ),
                    ],
                  ),
                  _Group(
                    title: tr('Автопоиск подписок · бета'),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: Text(tr('Почта (Gmail)')),
                        subtitle: Text(tr('Поиск чеков и списаний в письмах')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EmailBetaScreen(store: store)),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.sms_outlined),
                        title: Text(tr('SMS банка (Android)')),
                        subtitle:
                            Text(tr('Поиск списаний за известные сервисы')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SmsBetaScreen(store: store)),
                        ),
                      ),
                    ],
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

/// Круглая плитка с цветом палитры; у выбранной галочка и обводка.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // «Из обоев» показываем текущим акцентом с иконкой, остальные ― своим цветом.
    final color = palette.seed ?? scheme.primary;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Springy(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: 52,
              height: 52,
              decoration: ShapeDecoration(
                color: color,
                shape: selected
                    ? expressiveShape(16)
                    : const CircleBorder(),
                shadows: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                    : null,
              ),
              child: Icon(
                selected
                    ? Icons.check_rounded
                    : (palette.seed == null ? Icons.wallpaper_rounded : null),
                color: ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(tr(palette.name),
              style: t.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок на одной вертикали с текстом внутри карточки (16 dp).
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
            ),
          ),
          Material(
            color: scheme.surfaceContainerHigh,
            shape: expressiveShape(28),
            clipBehavior: Clip.antiAlias,
            // stretch: иначе блоки с Padding центрируются и «съезжают».
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children),
          ),
        ],
      ),
    );
  }
}
