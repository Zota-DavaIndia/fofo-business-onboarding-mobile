import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Standard scrolling screen body: safe area, 16 px side padding, items
/// spaced evenly. Pass [bottom] for a solid action bar.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.bottom, this.onRefresh});

  final List<Widget> children;
  final Widget? bottom;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.xxl),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: Space.md), children[i]],
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: onRefresh!,
        color: context.colors.accent,
        backgroundColor: context.colors.card,
        child: list,
      );
    }
    return Scaffold(
      body: SafeArea(bottom: bottom == null, child: list),
      bottomNavigationBar: bottom,
    );
  }
}
