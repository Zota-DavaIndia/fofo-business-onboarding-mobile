import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../core/icons/app_icon.dart';
import '../core/sync/live_refresh.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/toast.dart';
import '../features/alerts/open_alert.dart';
import '../core/widgets/widgets.dart';
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
      onAlerts: (context, items) {
        // The inbox already shows new alerts as they arrive; a toast there would repeat them.
        if (GoRouter.of(context).routerDelegate.currentConfiguration.uri.path == '/alerts') return;
        // One toast for the newest alert; several at once point to the inbox.
        final last = items.last;
        final many = items.length > 1;
        final title = many ? '${items.length} new alerts' : '${last['title'] ?? 'New alert'}';
        final body = many ? null : last['body'] as String?;
        showToast(
          context,
          body == null || body.isEmpty ? title : '$title\n$body',
          duration: const Duration(seconds: 5),
          onTap: () => many
              ? context.push('/alerts')
              : last['can_open'] == true
              ? openAlert(context, entity: last['entity'] as String?, entityId: (last['entity_id'] as num?)?.toInt())
              : showToast(context, '${last['note'] ?? "This isn't yours to open any more."}'),
        );
      },
      onOpenPush: (context, entity, id) => openAlert(context, entity: entity, entityId: id),
      child: Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: bottomBarDecoration(context),
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
