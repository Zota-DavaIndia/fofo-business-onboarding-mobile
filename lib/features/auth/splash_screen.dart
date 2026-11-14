import 'package:material_ui/material_ui.dart';

import '../../core/brand/logo.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Shown while the saved session is being restored: the in-app logo centred on a full light clay
/// gradient. The native launch screen is the gradient's top colour, so the hand-off doesn't flash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.stats.tint(StatTone.clay);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.top, t.bottom]),
        ),
        child: Stack(
          children: [
            const Center(child: AppLogo(height: 34)),
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    color: c.primary,
                    backgroundColor: c.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
