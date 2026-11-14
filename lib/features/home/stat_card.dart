import 'package:material_ui/material_ui.dart';

import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Gradient card for one Home counter. The number and label sit at the
/// bottom, so cards in the same row line up when one label wraps.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  final String label;
  final String value;
  final AppIconData icon;
  final StatTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = context.stats.of(tone);
    const fg = Color(0xFFFFFFFF);
    return Semantics(
      label: '$label: $value',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card + 2),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.tile - 1),
                  ),
                  child: AppIcon(icon, size: Sizes.iconSmall + 1, color: fg),
                ),
                const Spacer(),
                const SizedBox(height: Space.md),
                Text(
                  value,
                  style: context.text.number.copyWith(color: fg, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(label, style: context.text.label.copyWith(color: fg.withValues(alpha: 0.92))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
