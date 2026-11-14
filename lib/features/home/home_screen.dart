import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/brand/logo.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/hscroll.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import '../alerts/alerts.dart';
import '../field/field.dart';
import '../field/my_day_card.dart';
import '../field/plan.dart';
import '../leads/lead.dart';
import '../leads/lead_status.dart';
import '../leads/leads_board.dart';
import '../onboarding/onboarding.dart';
import '../onboarding/onboarding_board.dart';
import 'dashboard.dart';
import 'stat_card.dart';
import '../update/update_screen.dart';

/// Opens the list behind an attention row or a tile.
void openTarget(BuildContext context, WidgetRef ref, HomeTarget target, {String? label}) {
  switch (target) {
    case LeadsTarget(:final queue):
      ref.read(leadQueueProvider.notifier).set((queue: queue, label: label ?? queue.replaceAll('_', ' ')));
      context.go('/leads');
    case OnboardingsTarget(:final tab):
      ref
          .read(onboardingTabProvider.notifier)
          .set(OnboardingTab.values.where((t) => t.query == tab).firstOrNull ?? OnboardingTab.needsAction);
      context.go('/onboarding');
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return const SizedBox.shrink();
    final canSeeCounts = user.can(Perm.dashboardView);
    final dashboard = canSeeCounts ? ref.watch(dashboardProvider) : null;
    final unread = ref.watch(unreadAlertsProvider);
    final territories = user.territories.map((t) => t.name).join(', ');
    final d = dashboard?.value;
    final loading = dashboard != null && d == null && !dashboard.hasError;

    return PageBody(
      onRefresh: () async {
        ref.invalidate(alertsProvider);
        ref.invalidate(todayProvider);
        ref.invalidate(expensesProvider);
        ref.invalidate(leavesProvider);
        ref.invalidate(dayPlanProvider);
        ref.invalidate(ticketsProvider);
        if (canSeeCounts) {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        }
      },
      header: Row(
        children: [
          const Expanded(
            child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 22)),
          ),
          _Bell(unread: unread),
        ],
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi ${user.firstName}', style: context.text.title),
            Text(
              territories.isEmpty ? user.designation : '${user.designation} · $territories',
              style: context.text.secondary,
            ),
          ],
        ),
        const UpdateBanner(),
        if (user.can(Perm.attendanceMark)) const MyDayCard(),
        if (user.can(Perm.expensesClaim) ||
            user.can(Perm.leaveApply) ||
            user.can(Perm.dayplanManage) ||
            user.can(Perm.ticketsRaise))
          const WorkTiles(),
        if (dashboard?.hasError ?? false)
          AppCard(child: Text("Couldn't load your numbers. Pull down to retry.", style: context.text.secondary)),
        if (loading)
          const SkeletonScope(
            label: 'Loading your numbers',
            child: SkeletonRows(count: 4, lead: BoneLead.none),
          ),
        if (d != null) ...[
          const SectionLabel('Overview'),
          _Headline(d: d),
          if (d.attention.isNotEmpty) ...[const SectionLabel('Needs attention'), _AttentionList(items: d.attention)],
          const SectionLabel('Today'),
          _TodayRow(today: d.today),
          if (d.stages.isNotEmpty) ...[const SectionLabel('Lead to billing'), _StageStrip(stages: d.stages)],
          if (d.recent.isNotEmpty) ...[
            const SectionLabel('Recent leads'),
            _RecentLeads(items: d.recent.take(8).toList()),
          ],
        ],
      ],
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconTile(
          AppIcons.bell,
          semanticLabel: unread > 0 ? 'Alerts, $unread unread' : 'Alerts',
          alignment: Alignment.centerRight,
          onTap: () => context.push('/alerts'),
        ),
        if (unread > 0)
          Positioned(
            right: -4,
            top: 2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.page, width: 2),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: context.text.caption.copyWith(color: c.onPrimary, fontWeight: FontWeight.w600, height: 1),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttentionList extends ConsumerWidget {
  const _AttentionList({required this.items});

  final List<Attention> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return GroupedList(
      children: [
        for (final a in items)
          ListRow(
            title: a.label,
            dim: a.count == 0,
            leading: IconTile(
              a.count == 0 ? AppIcons.check : AppIcons.alert,
              color: a.count == 0 ? c.textTertiary : c.danger,
              background: a.count == 0 ? context.fieldFill : c.tintOf(c.danger),
              size: 32,
              iconSize: 16,
            ),
            trailing: Text(
              '${a.count}',
              style: context.text.bodyStrong.copyWith(color: a.count == 0 ? c.textTertiary : c.danger),
            ),
            onTap: a.target == null ? null : () => openTarget(context, ref, a.target!, label: a.label),
          ),
      ],
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.today});

  final TodayCounts today;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('New leads', today.newLeads),
      ('Calls logged', today.calls),
      ('Visits checked in', today.visits),
      ('Qualified', today.qualified),
    ];
    // Tiles size to their one-line label; the row scrolls sideways when it
    // doesn't fit, instead of wrapping labels.
    return HScroll(
      children: [
        for (var i = 0; i < items.length; i++)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${items[i].$2}', style: context.text.number.copyWith(fontSize: 22)),
                  const SizedBox(height: Space.xs),
                  Text(
                    items[i].$1,
                    maxLines: 1,
                    softWrap: false,
                    style: context.text.caption.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Headline extends ConsumerWidget {
  const _Headline({required this.d});

  final Dashboard d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void leads(LeadFilter f) {
      ref.read(leadQueueProvider.notifier).set(null);
      ref.read(leadFilterProvider.notifier).set(f);
      context.go('/leads');
    }

    final cards = [
      StatCard(
        label: 'Total leads',
        value: '${d.total}',
        icon: AppIcons.leads,
        tone: StatTone.clay,
        onTap: () => leads(LeadFilter.all),
      ),
      StatCard(
        label: 'Qualified',
        value: '${d.count('QUALIFIED')}',
        caption: '${d.conversionPct}% · ${d.qualifiedThisMonth} this month',
        icon: AppIcons.check,
        tone: StatTone.teal,
        onTap: () => leads(LeadFilter.qualified),
      ),
      StatCard(
        label: 'Onboarding: your action',
        value: '${d.onboardingNeedsAction}',
        caption: '${d.onboardingWaiting} with review teams',
        icon: AppIcons.store,
        tone: StatTone.mustard,
        onTap: () => openTarget(context, ref, const OnboardingsTarget('needs_action')),
      ),
      StatCard(
        label: 'Stores live',
        value: '${d.onboardingLive}',
        icon: AppIcons.shield,
        tone: StatTone.olive,
        onTap: () => openTarget(context, ref, const OnboardingsTarget('live')),
      ),
    ];
    Widget row(int a, int b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[a]),
          const SizedBox(width: Space.sm),
          Expanded(child: cards[b]),
        ],
      ),
    );
    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: Space.sm),
        row(2, 3),
      ],
    );
  }
}

class _StageStrip extends StatelessWidget {
  const _StageStrip({required this.stages});

  final List<Stage> stages;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HScroll(
      children: [
        for (final s in stages)
          Builder(
            builder: (context) {
              final known = s.count != null;
              return GestureDetector(
                onTap: !known
                    ? null
                    : () =>
                          pushForm<void>(context, s.isLead ? const LeadsBoardScreen() : const OnboardingBoardScreen()),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 96),
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(Radii.card)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${s.no.toString().padLeft(2, '0')}  ',
                              style: TextStyle(color: s.isLead ? c.accent : c.info, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: s.name),
                          ],
                        ),
                        maxLines: 1,
                        softWrap: false,
                        style: context.text.caption.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(known ? '${s.count}' : '—', style: context.text.number.copyWith(fontSize: 18)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _RecentLeads extends StatelessWidget {
  const _RecentLeads({required this.items});

  final List<RecentLead> items;

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      children: [
        for (final l in items)
          ListRow(
            title: l.name,
            subtitle: [
              l.leadNo,
              if (l.sourceLabel != null) l.sourceLabel!,
              if (l.createdAt != null) formatShortDay(l.createdAt!),
            ].join(' · '),
            leading: Initials(l.name),
            trailing: l.statusLabel == null ? null : StatusBadge(l.statusLabel!, tone: toneForStatus(l.status ?? '')),
            onTap: () => context.go('/leads/${l.id}'),
          ),
      ],
    );
  }
}
