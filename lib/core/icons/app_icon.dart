import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'app_icon_data.dart';

export 'app_icon_data.dart';
export 'app_icons.g.dart';

/// Draws an icon from [AppIcons]. Color and size default to the
/// surrounding [IconTheme], like Flutter's own [Icon].
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final AppIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? Sizes.icon;
    final c = color ?? theme.color ?? const Color(0xFF000000);
    final paint = CustomPaint(size: Size.square(s), painter: _IconPainter(icon, c));
    return semanticLabel == null ? ExcludeSemantics(child: paint) : Semantics(label: semanticLabel, child: paint);
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final AppIconData icon;
  final Color color;

  static const _grid = 24.0;
  static const _stroke = 1.75;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _grid;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      icon.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon || old.color != color;
}
