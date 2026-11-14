import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Standard scrolling screen body: safe area, 16 px side padding, items
/// spaced evenly. [header] stays pinned at the top while the rest scrolls;
/// a [PageHeader] passed as the first child is pinned the same way. Pass
/// [bottom] for a solid action bar.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.header, this.bottom, this.onRefresh});

  final List<Widget> children;
  final Widget? header;
  final Widget? bottom;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pinned = header ?? (children.isNotEmpty && children.first is PageHeader ? children.first : null);
    final items = header == null && pinned != null ? children.skip(1).toList() : children;
    // The list runs to the bottom edge and scrolls under the home indicator;
    // its inset is added as padding after the last item instead of a fixed
    // band. With an action bar, the bar takes care of the inset.
    final inset = bottom == null ? MediaQuery.paddingOf(context).bottom : 0.0;
    Widget list = ListView(
      padding: EdgeInsets.fromLTRB(Space.screen, pinned == null ? Space.sm : Space.xs, Space.screen, Space.xxl + inset),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: Space.md), items[i]],
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
      body: SafeArea(
        bottom: false,
        child: pinned == null
            ? list
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: context.colors.page,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.sm),
                      child: pinned,
                    ),
                  ),
                  Expanded(child: list),
                ],
              ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}
