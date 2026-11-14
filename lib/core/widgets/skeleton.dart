import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'widgets.dart';

/// Wraps a loading layout: pulses it gently and reads as one "Loading"
/// to screen readers. Holds still when the phone asks for reduced motion.
class SkeletonScope extends StatefulWidget {
  const SkeletonScope({super.key, required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _opacity = Tween<double>(
    begin: 1,
    end: 0.5,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      liveRegion: true,
      excludeSemantics: true,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}

/// One placeholder shape. Takes the field fill of the layer it sits on.
class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 12, this.radius = Radii.badge, this.circle = false, this.color});

  /// Width in px; null fills the available width.
  final double? width;
  final double height;
  final double radius;
  final bool circle;
  final Color? color;

  const Bone.circle(double size, {super.key, this.color}) : width = size, height = size, radius = 0, circle = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? context.fieldFill,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// What sits at the start of a placeholder row.
enum BoneLead { none, circle, tile, time }

/// Placeholder for a [GroupedList] of [ListRow]s: leading shape, a title
/// and subtitle line, and an optional badge. Widths vary a little per row
/// so it doesn't read as a grid.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 5, this.lead = BoneLead.circle, this.badge = true});

  final int count;
  final BoneLead lead;
  final bool badge;

  static const _title = [0.55, 0.42, 0.62, 0.48, 0.38, 0.58];
  static const _sub = [0.36, 0.3, 0.4, 0.26, 0.33, 0.28];

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: SizedBox(
              height: Sizes.tile,
              child: Row(
                children: [
                  switch (lead) {
                    BoneLead.circle => const Padding(
                      padding: EdgeInsets.only(right: Space.md),
                      child: Bone.circle(Sizes.tile),
                    ),
                    BoneLead.tile => const Padding(
                      padding: EdgeInsets.only(right: Space.md),
                      child: Bone(width: Sizes.tile, height: Sizes.tile, radius: Radii.tile),
                    ),
                    BoneLead.time => const Padding(
                      padding: EdgeInsets.only(right: Space.md),
                      child: SizedBox(
                        width: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Bone(width: 36, height: 12),
                            SizedBox(height: Space.xs),
                            Bone(width: 20, height: 10),
                          ],
                        ),
                      ),
                    ),
                    BoneLead.none => const SizedBox.shrink(),
                  },
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone(width: c.maxWidth * _title[i % _title.length], height: 13),
                          const SizedBox(height: Space.xs),
                          Bone(width: c.maxWidth * _sub[i % _sub.length], height: 10),
                        ],
                      ),
                    ),
                  ),
                  if (badge) ...[const SizedBox(width: Space.sm), const Bone(width: 58, height: 18)],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder for a card of text: a few lines, the last one shorter.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) const SizedBox(height: Space.sm),
              Bone(width: i == lines - 1 ? c.maxWidth * 0.45 : null, height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder for a row of chips.
class SkeletonChips extends StatelessWidget {
  const SkeletonChips({super.key, this.widths = const [84, 96, 110, 72]});

  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [for (final w in widths) Bone(width: w, height: 40, radius: Radii.tile)],
    );
  }
}

/// A small label placeholder, the size of a [SectionLabel].
class SkeletonLabel extends StatelessWidget {
  const SkeletonLabel({super.key, this.width = 80});

  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
    child: Bone(width: width, height: 10),
  );
}
