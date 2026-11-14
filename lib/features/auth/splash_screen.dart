import 'package:material_ui/material_ui.dart';

import '../../core/brand/logo.dart';
import '../../core/theme/app_theme.dart';

/// Shown while the saved session is being restored. The "fa" circle sits at
/// the exact centre of the screen, where the native launch screen draws it,
/// so the hand-off doesn't jump.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _mark = 104.0;
  static const _logoWidth = 250.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final centre = box.maxHeight / 2;
          return Stack(
            children: [
              Positioned(
                top: centre - _mark / 2,
                left: 0,
                right: 0,
                child: const Center(child: FaMark(size: _mark)),
              ),
              Positioned(
                top: centre + _mark / 2 + 28,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    dark ? 'assets/brand/logo-dark.png' : 'assets/brand/logo.png',
                    width: _logoWidth,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: 'Dava India',
                  ),
                ),
              ),
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
          );
        },
      ),
    );
  }
}
