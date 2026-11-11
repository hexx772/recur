import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../services/email_parser.dart';
import '../services/sms_service.dart';
import '../theme/app_theme.dart';
import 'edit_screen.dart';
import '../l10n/tr.dart';

/// БЕТА (Android): поиск подписок в SMS банка. Ничего не добавляется без
/// подтверждения, SMS не сохраняются и никуда не отправляются.
class SmsBetaScreen extends StatefulWidget {
  const SmsBetaScreen({super.key, required this.store});
  final SubscriptionStore store;

  @override
  State<SmsBetaScreen> createState() => _SmsBetaScreenState();
}

class _SmsBetaScreenState extends State<SmsBetaScreen> {
  final _sms = SmsService();
  List<SubscriptionCandidate>? _found;
  bool _loading = false;
  bool _denied = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
      _denied = false;
    });
    try {
      if (!await _sms.requestPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final r = await _sms.scan();
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
          SliverAppBar.large(title: Text(tr('SMS банка · бета'))),
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
                    SmsService.supported
                        ? tr('Бета-функция. Приложение читает входящие SMS за последние '
                            '180 дней и ищет списания за известные сервисы '
                            '(Netflix, Spotify и др.). Периодичность определяется по '
                            'интервалу между списаниями. SMS не сохраняются и '
                            'никуда не отправляются. Каждую находку нужно '
                            'подтвердить вручную.')
                        : tr('Эта функция доступна только на Android.'),
                    style: t.bodyMedium
                        ?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ),
                const SizedBox(height: 16),
                if (SmsService.supported)
                  FilledButton.icon(
                    onPressed: _loading ? null : _scan,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sms_outlined),
                    label: Text(_loading ? tr('Ищу…') : tr('Разрешить и найти')),
                  ),
                if (_denied)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Доступ к SMS не разрешён.'),
                            style: TextStyle(color: scheme.error)),
                        TextButton(
                          onPressed: openAppSettings,
                          child: Text(tr('Открыть настройки приложения')),
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                if (_found != null && _found!.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(tr('Подходящих списаний не найдено.')),
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
