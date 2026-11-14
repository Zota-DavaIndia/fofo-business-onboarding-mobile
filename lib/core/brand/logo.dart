import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'logo_paths.g.dart';

/// The davaindia wordmark with "fa" under its right end, the same artwork
/// as the app icon. Drawn from vector paths, so it stays sharp at any size.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = height * logoSize.width / logoSize.height;
    return Semantics(
      label: 'Dava India field app',
      image: true,
      child: CustomPaint(
        size: Size(width, height),
        painter: _LogoPainter(dava: c.brandOrange, india: c.brandGreen, fa: c.accent),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.dava, required this.india, required this.fa});

  final Color dava;
  final Color india;
  final Color fa;

  static final _dava = Path();
  static final _india = Path();
  static final _fa = Path();
  static bool _built = false;

  static void _build() {
    if (_built) return;
    logoDava(_dava);
    logoIndia(_india);
    logoFa(_fa);
    _built = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _build();
    canvas.save();
    canvas.scale(size.height / logoSize.height);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawPath(_dava, paint..color = dava);
    canvas.drawPath(_india, paint..color = india);
    canvas.drawPath(_fa, paint..color = fa);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.dava != dava || old.india != india || old.fa != fa;
}
