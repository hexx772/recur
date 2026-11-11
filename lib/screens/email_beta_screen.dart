import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../services/email_parser.dart';
import '../services/gmail_service.dart';
import '../theme/app_theme.dart';
import 'edit_screen.dart';
import '../l10n/tr.dart';

/// БЕТА: поиск подписок в Gmail. Ничего не добавляется без подтверждения.
class EmailBetaScreen extends StatefulWidget {
  const EmailBetaScreen({super.key, required this.store});
  final SubscriptionStore store;

  @override
  State<EmailBetaScreen> createState() => _EmailBetaScreenState();
}

class _EmailBetaScreenState extends State<EmailBetaScreen> {
  final _gmail = GmailService();
  List<SubscriptionCandidate>? _found;
  bool _loading = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _gmail.scan();
      if (mounted) setState(() => _found = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(SubscriptionCandidate c) async {
    final draft = Subscription(
      id: '',
      name: c.name,
      price: c.price,
      currency: c.currency,
      period: c.period,
      nextCharge: c.period.addTo(c.date),
      fromEmail: true,
    );
    final s = await Navigator.push<Subscription>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditScreen(draft: draft, settings: widget.store.settings),
      ),
    );
    if (s != null) {
      await widget.store.upsert(s);
      if (mounted) setState(() => _found?.remove(c));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(tr('Почта · бета'))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: ShapeDecoration(
                    color: scheme.tertiaryContainer,
                    shape: expressiveShape(32),
                  ),
                  child: Text(
                    tr('Бета-функция. Приложение читает письма Gmail (только чтение), '
                    'ищет чеки и уведомления о списании за последние 180 дней. '
                    'Письма не сохраняются и никуда не отправляются. Результаты '
                    'могут быть неточными, поэтому каждую находку подтверждайте '
                    'вручную.'),
                    style: t.bodyMedium
                        ?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _scan,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_loading ? tr('Ищу…') : tr('Войти в Google и найти')),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                if (_found != null && _found!.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(tr('Ничего не найдено.')),
                  ),
                for (final c in _found ?? <SubscriptionCandidate>[])
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Material(
                      color: scheme.surfaceContainerHigh,
                      shape: expressiveShape(28),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        title: Text(c.name, style: t.titleMedium),
                        subtitle: Text(
                            '${c.subject}\n${DateFormat.yMMMd(appLocale).format(c.date)} · ${c.period.label}'),
                        isThreeLine: true,
                        trailing: Text('${c.price} ${c.currency}',
                            style: t.titleMedium),
                        onTap: () => _confirm(c),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
