import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import '../../core/brand/logo.dart';
import 'dashboard.dart';
import 'stat_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return const SizedBox.shrink();
    final canSeeCounts = user.can(Perm.dashboardView);
    final dashboard = canSeeCounts ? ref.watch(dashboardProvider) : null;

    final territories = user.territories.map((t) => t.name).join(', ');

    return PageBody(
      onRefresh: canSeeCounts ? () => ref.refresh(dashboardProvider.future) : null,
      children: [
        Row(
          children: [
            const Expanded(
              child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 30)),
            ),
            IconTile(
              AppIcons.bell,
              semanticLabel: 'Alerts',
              alignment: Alignment.centerRight,
              onTap: () => context.push('/alerts'),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greeting()}, ${user.firstName}', style: context.text.title),
            Text(
              territories.isEmpty ? user.designation : '${user.designation} · $territories',
              style: context.text.secondary,
            ),
          ],
        ),
        if (dashboard != null) ...[const SizedBox(height: Space.xxs), _Counters(dashboard: dashboard)],
        const SectionLabel("Today's visits"),
        AppCard(child: Text('No visits scheduled for today.', style: context.text.secondary)),
      ],
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.dashboard});

  final AsyncValue<Dashboard> dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard.value;
    String n(String status) => d == null ? '–' : '${d.count(status)}';
    final items = [
      ('New assignments', n('ASSIGNED'), AppIcons.leads, StatTone.clay),
      ('Visits scheduled', n('VISIT_SCHEDULED'), AppIcons.visit, StatTone.olive),
      ('Follow-ups', n('FOLLOW_UP'), AppIcons.sync, StatTone.mustard),
      ('Qualified', n('QUALIFIED'), AppIcons.check, StatTone.teal),
    ];
    Widget card(int i) => StatCard(label: items[i].$1, value: items[i].$2, icon: items[i].$3, tone: items[i].$4);
    // Each row takes the height of its tallest card; the cards stretch to
    // match, and their text stays on the bottom edge.
    Widget row(int a, int b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: card(a)),
          const SizedBox(width: Space.sm),
          Expanded(child: card(b)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(0, 1),
        const SizedBox(height: Space.sm),
        row(2, 3),
        if (dashboard.hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text("Couldn't load counts. Pull down to retry.", style: context.text.label),
          ),
      ],
    );
  }
}
