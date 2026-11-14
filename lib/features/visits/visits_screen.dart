import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import '../leads/lead.dart';
import 'visit.dart';
import 'visit_forms.dart';

class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(visitsTabProvider);
    final visits = ref.watch(visitsProvider(tab));
    final open = ref.watch(openVisitsProvider).value ?? const <Visit>[];
    return PageBody(
      onRefresh: () async {
        ref.invalidate(openVisitsProvider);
        ref.invalidate(visitsProvider(tab));
        await ref.read(visitsProvider(tab).future);
      },
      children: [
        Text('Visits', style: context.text.title),
        for (final v in open) _OpenVisit(visit: v),
        Row(
          children: [
            for (final t in VisitsTab.values) ...[
              if (t != VisitsTab.values.first) const SizedBox(width: Space.xs),
              AppChip(
                label: t.label,
                height: 36,
                selected: t == tab,
                onTap: () => ref.read(visitsTabProvider.notifier).set(t),
              ),
            ],
          ],
        ),
        ...visits.when(
          loading: () => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxl),
              child: Text('Loading visits…', style: context.text.secondary),
            ),
          ],
          error: (_, _) => [
            const SizedBox(height: Space.xl),
            MessageBlock(
              icon: AppIcons.alert,
              title: "Couldn't load visits",
              body: 'Check your connection and pull down to try again.',
              action: AppButton(
                label: 'Try again',
                kind: ButtonKind.secondary,
                onPressed: () => ref.invalidate(visitsProvider(tab)),
              ),
            ),
          ],
          data: (list) => list.isEmpty ? [const SizedBox(height: Space.xl), _Empty(tab: tab)] : _days(context, list),
        ),
      ],
    );
  }

  /// One card per day, with the day above it.
  List<Widget> _days(BuildContext context, List<Visit> list) {
    final groups = <String, List<Visit>>{};
    for (final v in list) {
      final at = v.when;
      groups.putIfAbsent(at == null ? 'No date' : _dayLabel(at), () => []).add(v);
    }
    return [
      for (final MapEntry(key: day, value: items) in groups.entries) ...[
        SectionLabel(day),
        GroupedList(children: [for (final v in items) _VisitRow(visit: v)]),
      ],
    ];
  }
}

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final name = formatPicked(d).split(' · ').first;
  return switch (diff) {
    0 => 'Today, ${name.split(', ').last}',
    1 => 'Tomorrow, ${name.split(', ').last}',
    -1 => 'Yesterday, ${name.split(', ').last}',
    _ => d.year == now.year ? name : formatDay(d),
  };
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final at = visit.when;
    final (String label, Tone tone) = switch (visit.status) {
      VisitStatus.scheduled => ('Scheduled', Tone.accent),
      VisitStatus.checkedIn => ('Checked in', Tone.info),
      VisitStatus.completed when visit.kind == 'checkin' => (
        visit.geoVerified ? 'Visited' : 'Not verified',
        visit.geoVerified ? Tone.success : Tone.warning,
      ),
      VisitStatus.completed => ('Done', Tone.neutral),
      _ => (visit.status, Tone.neutral),
    };
    final time = at == null ? null : formatTime(at).split(' ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/visits/lead/${visit.leadId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: time == null
                  ? Text('–', style: context.text.label)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time.first, style: context.text.bodyStrong),
                        Text(time.last, style: context.text.label),
                      ],
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.leadName, style: context.text.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    visit.address ?? visit.leadNo ?? '',
                    style: context.text.label.copyWith(color: c.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            StatusBadge(label, tone: tone),
          ],
        ),
      ),
    );
  }
}

class _OpenVisit extends ConsumerWidget {
  const _OpenVisit({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = visit.checkedInAt;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(visit.leadName, style: context.text.bodyStrong)),
              const StatusBadge('In progress', tone: Tone.info),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (at != null) 'Checked in ${formatTime(at)}',
              visit.geoVerified ? 'verified at the shop' : 'not verified',
            ].join(' · '),
            style: context.text.label,
          ),
          const SizedBox(height: Space.md),
          AppButton(
            label: 'Check out',
            icon: AppIcons.check,
            onPressed: () async {
              final saved = await pushForm<bool>(context, CheckOutScreen(visit: visit));
              if (saved == true) leadChanged(ref);
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final VisitsTab tab;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (tab) {
      VisitsTab.today => ('No visits today', 'Schedule one from a lead, or check in when you reach a shop.'),
      VisitsTab.upcoming => ('Nothing planned', 'Visits you schedule from a lead show here.'),
      VisitsTab.done => ('No visits yet', 'Finished visits show here.'),
    };
    return MessageBlock(icon: AppIcons.visit, title: title, body: body);
  }
}
