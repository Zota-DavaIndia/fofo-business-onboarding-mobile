import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import 'dashboard.dart';

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
            const Expanded(child: Wordmark()),
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
      ('New assignments', n('ASSIGNED')),
      ('Visits scheduled', n('VISIT_SCHEDULED')),
      ('Follow-ups', n('FOLLOW_UP')),
      ('Qualified', n('QUALIFIED')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 2.2,
          children: [
            for (final (label, value) in items)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: context.text.label),
                    Text(value, style: context.text.number),
                  ],
                ),
              ),
          ],
        ),
        if (dashboard.hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text("Couldn't load counts. Pull down to retry.", style: context.text.label),
          ),
      ],
    );
  }
}
