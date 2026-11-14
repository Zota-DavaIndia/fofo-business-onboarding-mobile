import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'logo_paths.g.dart';

/// The app's logo: a clay circle with an italic "fa", the same mark as the
/// launcher icon, followed by the official davaindia lettering. [height] is
/// the height of the whole logo. Dark mode uses a copy of the lettering with
/// a lighter green so "india" stays readable.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final h = height;
    return Semantics(
      label: 'Dava India field app',
      image: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: h,
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: CustomPaint(
              size: Size(h * 0.5 * faSize.width / faSize.height, h * 0.5),
              painter: _FaPainter(c.onPrimary),
            ),
          ),
          SizedBox(width: h * 0.28),
          Image.asset(
            dark ? 'assets/brand/lettering-dark.png' : 'assets/brand/lettering.png',
            height: h,
            filterQuality: FilterQuality.medium,
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
