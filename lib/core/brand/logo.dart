import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'logo_paths.g.dart';

/// The davaindia wordmark with a small "fa" tag beside it. [height] is the
/// height of the wordmark letters; the tag is sized from it. Both are drawn
/// from the same vector outlines as the app icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 20});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = height;
    final faHeight = h * 0.62;
    return Semantics(
      label: 'Dava India field app',
      image: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(h * wordmarkSize.width / wordmarkSize.height, h),
            painter: _PathsPainter(wordmarkSize, [(wordmarkDava, c.brandOrange), (wordmarkIndia, c.brandGreen)]),
          ),
          SizedBox(width: h * 0.32),
          Container(
            padding: EdgeInsets.symmetric(horizontal: h * 0.36, vertical: h * 0.22),
            decoration: BoxDecoration(color: c.accentTint, borderRadius: BorderRadius.circular(h * 0.3)),
            child: CustomPaint(
              size: Size(faHeight * faSize.width / faSize.height, faHeight),
              painter: _PathsPainter(faSize, [(faMark, c.accent)]),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _PathBuilder = void Function(Path);

class _PathsPainter extends CustomPainter {
  _PathsPainter(this.box, this.parts);

  final Size box;
  final List<(_PathBuilder, Color)> parts;

  static final _cache = <_PathBuilder, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.height / box.height);
    final paint = Paint()..isAntiAlias = true;
    for (final (build, color) in parts) {
      final path = _cache.putIfAbsent(build, () {
        final p = Path();
        build(p);
        return p;
      });
      canvas.drawPath(path, paint..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PathsPainter old) =>
      old.box != box || !listEquals([for (final p in old.parts) p.$2], [for (final p in parts) p.$2]);
}
