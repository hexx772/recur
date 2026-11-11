import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Пружинное нажатие: элемент слегка «проваливается» и упруго возвращается.
class Springy extends StatefulWidget {
  const Springy({super.key, required this.child, this.onTap, this.pressed = 0.95});

  final Widget child;
  final VoidCallback? onTap;
  final double pressed;

  @override
  State<Springy> createState() => _SpringyState();
}

class _SpringyState extends State<Springy> with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 520, damping: 16);
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 1);

  void _to(double target) =>
      _c.animateWith(SpringSimulation(_spring, _c.value, target, _c.velocity));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _to(widget.pressed),
      onTapUp: (_) => _to(1),
      onTapCancel: () => _to(1),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Плавное появление с подъёмом; задержка растёт с номером элемента.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index.clamp(0, 8)) * 80),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 28), child: child),
      ),
      child: child,
    );
  }
}
