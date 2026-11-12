import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../l10n/tr.dart';
import '../services/app_lock.dart';
import '../theme/app_theme.dart';

/// «Ворота» блокировки: если блокировка включена, закрывает приложение при
/// запуске и после того, как оно пробыло в фоне дольше [_relockAfter].
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.settings, required this.child});
  final AppSettings settings;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const _relockAfter = Duration(seconds: 15);

  bool _locked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettings);
    _locked = widget.settings.appLock;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (!widget.settings.appLock && _locked) setState(() => _locked = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (widget.settings.appLock &&
          !_locked &&
          p != null &&
          DateTime.now().difference(p) > _relockAfter) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    try {
      // Если защиту экрана сняли, блокировка не должна запереть пользователя.
      if (!await AppLock.supported()) {
        await widget.settings.update(appLock: false);
        if (mounted) setState(() => _locked = false);
        return;
      }
      final ok = await AppLock.authenticate(tr('Подтвердите, что это вы'));
      if (ok && mounted) setState(() => _locked = false);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: ShapeDecoration(
                    color: scheme.primaryContainer,
                    shape: expressiveShape(44),
                  ),
                  child: Icon(Icons.lock_rounded,
                      size: 56, color: scheme.primary),
                ),
                const SizedBox(height: 24),
                Text('Recur', style: t.headlineMedium),
                const SizedBox(height: 8),
                Text(tr('Приложение заблокировано'),
                    style: t.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(tr('Разблокировать')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
