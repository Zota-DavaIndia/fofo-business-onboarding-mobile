import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'logo_paths.g.dart';

/// The official Dava India logo with a small "fa" tag beside it. [height] is
/// the height of the logo image; the tag is sized from it. Dark mode uses a
/// copy with a lighter green so "india" stays readable.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final h = height;
    final faHeight = h * 0.36;
    return Semantics(
      label: 'Dava India field app',
      image: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            dark ? 'assets/brand/logo-dark.png' : 'assets/brand/logo.png',
            height: h,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: h * 0.22),
          Container(
            padding: EdgeInsets.symmetric(horizontal: h * 0.2, vertical: h * 0.12),
            decoration: BoxDecoration(color: c.accentTint, borderRadius: BorderRadius.circular(h * 0.17)),
            child: CustomPaint(
              size: Size(faHeight * faSize.width / faSize.height, faHeight),
              painter: _FaPainter(c.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaPainter extends CustomPainter {
  _FaPainter(this.color);

  final Color color;

  static final _path = () {
    final p = Path();
    faMark(p);
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.height / faSize.height);
    canvas.drawPath(_path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FaPainter old) => old.color != color;
}
