import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Which layer a widget sits on. Fields, chips and secondary buttons pick
/// their fill from it: one shade off a card, a different shade off the page.
enum SurfaceLevel { page, card }

class Surface extends InheritedWidget {
  const Surface({super.key, required this.level, required super.child});

  final SurfaceLevel level;

  static SurfaceLevel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Surface>()?.level ?? SurfaceLevel.page;

  @override
  bool updateShouldNotify(Surface old) => old.level != level;
}

extension SurfaceFill on BuildContext {
  /// Fill for a field-like control on the current layer.
  Color get fieldFill => Surface.of(this) == SurfaceLevel.card ? colors.fieldOnCard : colors.fieldOnPage;
}
