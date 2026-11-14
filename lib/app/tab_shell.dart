import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../core/icons/app_icon.dart';
import '../core/sync/live_refresh.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'modules.dart';

/// Hosts the tab screens and the solid bottom tab bar. Only tabs the user
/// is allowed to open are shown.
class TabShell extends ConsumerWidget {
  const TabShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    final visible = [
      for (var i = 0; i < tabModules.length; i++)
        if (user != null && tabModules[i].allows(user)) (index: i, module: tabModules[i]),
    ];

    return LiveRefresh(
      child: Scaffold(
        body: shell,
        bottomNavigationBar: ColoredBox(
          color: context.colors.card,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.tabBar),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final t in visible)
                    _Tab(
                      module: t.module,
                      selected: shell.currentIndex == t.index,
                      onTap: () => shell.goBranch(t.index, initialLocation: shell.currentIndex == t.index),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.module, required this.selected, required this.onTap});

  final AppModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.accent : c.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: module.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: Sizes.tile,
                  height: Sizes.tile,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accentTint : c.card,
                    borderRadius: BorderRadius.circular(Radii.tile),
                  ),
                  child: AppIcon(module.icon, color: fg),
                ),
                const SizedBox(height: 3),
                Text(module.label, style: context.text.caption.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
