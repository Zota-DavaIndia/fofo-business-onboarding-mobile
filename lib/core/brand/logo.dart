import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'logo_paths.g.dart';

/// The in-app logo: the official davaindia icon, then the "davaindia" word
/// with "FIELD FORCE" set under it in clay caps. [height] is the height of
/// the word; the icon spans the word and tagline together. Dark mode uses
/// the lettering with a lighter green and the lighter clay.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = height * 0.355;
    return Semantics(
      label: 'Davaindia Field Force',
      image: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            dark ? 'assets/brand/icon-dark.png' : 'assets/brand/icon.png',
            height: height * 1.5,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: height * 0.3),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                dark ? 'assets/brand/wordmark-dark.png' : 'assets/brand/wordmark.png',
                height: height,
                filterQuality: FilterQuality.medium,
              ),
              SizedBox(height: height * 0.14),
              Padding(
                padding: EdgeInsets.only(left: height * 0.1),
                child: Text(
                  'FIELD FORCE',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: AppText.family,
                    fontWeight: FontWeight.w600,
                    fontSize: size,
                    letterSpacing: size * 0.06,
                    height: 1,
                    color: context.colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The clay circle with a white italic "ff": the app icon's mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
      child: CustomPaint(
        size: Size(size * 0.48 * brandMarkSize.width / brandMarkSize.height, size * 0.48),
        painter: _FaPainter(c.onPrimary),
      ),
    );
  }
}

class _FaPainter extends CustomPainter {
  _FaPainter(this.color);

  final Color color;

  static final _path = () {
    final p = Path();
    brandMark(p);
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.height / brandMarkSize.height);
    canvas.drawPath(_path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FaPainter old) => old.color != color;
}
