import 'package:material_ui/material_ui.dart';

import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/skeleton.dart';

/// Light gradient card for one Home counter, with the number in the tone's deep shade. The number and
/// label sit at the bottom, so cards in the same row line up when one label wraps.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
    this.caption,
  });

  final String label;

  /// A smaller line under the label, e.g. "33% · 3 this month". Empty while loading: a placeholder bar.
  final String? caption;

  /// Null while loading: shows a placeholder bar.
  final String? value;
  final AppIconData icon;
  final StatTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.stats.tint(tone);
    final fg = t.ink;
    return Semantics(
      label: '$label: ${value ?? 'loading'}${caption == null ? '' : ', $caption'}',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card + 2),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.top, t.bottom]),
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
                    color: fg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.tile - 1),
                  ),
                  child: AppIcon(icon, size: Sizes.iconSmall + 1, color: fg),
                ),
                const Spacer(),
                const SizedBox(height: Space.md),
                if (value case final v?)
                  Text(
                    v,
                    style: context.text.number.copyWith(color: fg, fontSize: 26, fontWeight: FontWeight.w700),
                  )
                else
                  SkeletonScope(
                    label: 'Loading $label',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Bone(width: 40, height: 24, color: fg.withValues(alpha: 0.15)),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(label, style: context.text.label.copyWith(color: fg)),
                if (caption case final c? when c.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Bone(width: 72, height: 9, color: fg.withValues(alpha: 0.12)),
                  )
                else if (caption != null)
                  Text(caption!, style: context.text.caption.copyWith(color: t.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
