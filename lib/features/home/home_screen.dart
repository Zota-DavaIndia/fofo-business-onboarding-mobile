import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import '../../core/brand/logo.dart';
import '../leads/lead.dart';
import '../visits/visit.dart';
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
      onRefresh: () async {
        ref.invalidate(todaysVisitsProvider);
        if (canSeeCounts) {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        }
      },
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
        if (user.can(Perm.visitsManage)) ...[const SectionLabel("Today's visits"), const _TodaysVisits()],
      ],
    );
  }
}

class _Counters extends ConsumerWidget {
  const _Counters({required this.dashboard});

  final AsyncValue<Dashboard> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = dashboard.value;
    String n(String status) => d == null ? '–' : '${d.count(status)}';
    final items = [
      ('New assignments', n('ASSIGNED'), AppIcons.leads, StatTone.clay, LeadFilter.assigned),
      ('Visits scheduled', n('VISIT_SCHEDULED'), AppIcons.visit, StatTone.olive, LeadFilter.visitScheduled),
      ('Follow-ups', n('FOLLOW_UP'), AppIcons.followUp, StatTone.mustard, LeadFilter.followUp),
      ('Qualified', n('QUALIFIED'), AppIcons.check, StatTone.teal, LeadFilter.qualified),
    ];
    Widget card(int i) => StatCard(
      label: items[i].$1,
      value: items[i].$2,
      icon: items[i].$3,
      tone: items[i].$4,
      onTap: () {
        // Opens the Leads tab on the list behind this number.
        ref.read(leadFilterProvider.notifier).set(items[i].$5);
        context.go('/leads');
      },
    );
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

class _TodaysVisits extends ConsumerWidget {
  const _TodaysVisits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(todaysVisitsProvider);
    return visits.when(
      loading: () => AppCard(child: Text('Loading today\'s visits…', style: context.text.secondary)),
      error: (_, _) =>
          AppCard(child: Text("Couldn't load today's visits. Pull down to retry.", style: context.text.secondary)),
      data: (list) => list.isEmpty
          ? AppCard(child: Text('No visits scheduled for today.', style: context.text.secondary))
          : GroupedList(
              children: [
                for (final v in list)
                  ListRow(
                    title: v.leadName,
                    subtitle: [v.leadNo, v.address].whereType<String>().join(' · '),
                    leading: SizedBox(
                      width: 64,
                      child: Text(
                        v.scheduledAt == null ? '–' : formatTime(v.scheduledAt!),
                        style: context.text.bodyStrong,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
