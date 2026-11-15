import 'package:material_ui/material_ui.dart';

import '../../core/brand/logo.dart';
import '../../core/theme/app_theme.dart';

/// Shown while the saved session is being restored: the in-app logo centred on the page colour, with
/// three dots pulsing below. The native launch screen is the same colour, so the hand-off doesn't flash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.page,
      body: const Stack(
        children: [
          Center(child: AppLogo(height: 34)),
          Positioned(bottom: 90, left: 0, right: 0, child: Center(child: DotsLoader())),
        ],
      ),
    );
  }
}

/// Three dots that pulse one after another. Still dots when the phone asks for reduced motion.
class DotsLoader extends StatefulWidget {
  const DotsLoader({super.key, this.color, this.size = 8});

  final Color? color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.accent; // clay, lighter in dark mode
    final still = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: widget.size * 0.9),
              () {
                // Each dot rises and fades in a third of a cycle after the one before it.
                final t = still ? 1.0 : _pulse((_anim.value - i * 0.18) % 1.0);
                return Transform.scale(
                  scale: 0.7 + 0.3 * t,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.35 + 0.65 * t),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }

  /// 0 → 1 → 0 over the first 60% of the cycle, then rest.
  static double _pulse(double x) {
    if (x > 0.6) return 0;
    final p = x / 0.6;
    return p < 0.5 ? Curves.easeOut.transform(p * 2) : Curves.easeIn.transform((1 - p) * 2);
  }
}
