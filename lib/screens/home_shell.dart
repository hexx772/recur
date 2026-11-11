import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/subscription_store.dart';
import '../services/notification_service.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../l10n/tr.dart';

/// Каркас с нижней навигацией: подписки, аналитика, настройки.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final SubscriptionStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Переход влево (на вкладку левее) анимируется в обратную сторону.
  bool _reverse = false;

  @override
  void initState() {
    super.initState();
    // Разрешение на уведомления спрашиваем при самом первом открытии.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askNotificationsOnce();
      // Тексты виджетов и уведомлений зависят от языка: обновляем их.
      widget.store.resync();
    });
  }

  Future<void> _askNotificationsOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('asked_notifications') ?? false) return;
      // Флаг ставим до запроса: спрашиваем ровно один раз, даже если отказали.
      await prefs.setBool('asked_notifications', true);
      final granted = await NotificationService.instance.requestPermission();
      if (granted) {
        await NotificationService.instance
            .rescheduleAll(widget.store.items, widget.store.settings);
      }
    } catch (_) {
      // Без уведомлений приложение работает; включить можно в настройках.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(store: widget.store),
      AnalyticsScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 450),
        reverse: _reverse,
        transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
          animation: primary,
          secondaryAnimation: secondary,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: scheme.surface,
          child: child,
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _reverse = i < _index;
          _index = i;
        }),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions_rounded),
            label: tr('Подписки'),
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large_rounded),
            label: tr('Аналитика'),
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: tr('Настройки'),
          ),
        ],
      ),
    );
  }
}
