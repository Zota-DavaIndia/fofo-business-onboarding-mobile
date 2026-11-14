import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'onboarding.dart';
import 'onboarding_board.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(onboardingTabProvider);
    final list = ref.watch(onboardingsProvider(tab));
    return PageBody(
      onRefresh: () async {
        ref.invalidate(onboardingsProvider(tab));
        await ref.read(onboardingsProvider(tab).future);
      },
      header: Row(
        children: [
          Expanded(child: Text('Onboarding', style: context.text.title)),
          IconTile(
            AppIcons.board,
            semanticLabel: 'Onboarding board',
            alignment: Alignment.centerRight,
            onTap: () => pushForm<void>(context, const OnboardingBoardScreen()),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            for (final t in OnboardingTab.values) ...[
              if (t != OnboardingTab.values.first) const SizedBox(width: Space.xs),
              AppChip(
                label: t.label,
                height: 36,
                selected: t == tab,
                onTap: () => ref.read(onboardingTabProvider.notifier).set(t),
              ),
            ],
          ],
        ),
        ...list.when(
          loading: () => [
            const SkeletonScope(
              label: 'Loading onboardings',
              child: SkeletonRows(count: 4, lead: BoneLead.none),
            ),
          ],
          error: (_, _) => [
            const SizedBox(height: Space.xl),
            MessageBlock(
              icon: AppIcons.alert,
              title: "Couldn't load onboardings",
              body: 'Check your connection and pull down to try again.',
              action: AppButton(
                label: 'Try again',
                kind: ButtonKind.secondary,
                onPressed: () => ref.invalidate(onboardingsProvider(tab)),
              ),
            ),
          ],
          data: (items) => items.isEmpty
              ? [
                  const SizedBox(height: Space.xl),
                  MessageBlock(
                    icon: AppIcons.store,
                    title: switch (tab) {
                      OnboardingTab.needsAction => 'Nothing needs you',
                      OnboardingTab.waiting => 'Nothing waiting',
                      OnboardingTab.live => 'No live stores yet',
                    },
                    body: switch (tab) {
                      OnboardingTab.needsAction => 'When a lead qualifies, its onboarding shows here for you to fill.',
                      OnboardingTab.waiting =>
                        'Steps you send for review show here until ops, finance or compliance act.',
                      OnboardingTab.live => 'Stores that go live show here.',
                    },
                  ),
                ]
              : [
                  GroupedList(children: [for (final o in items) _OnboardingRow(onboarding: o)]),
                ],
        ),
      ],
    );
  }
}

class _OnboardingRow extends StatelessWidget {
  const _OnboardingRow({required this.onboarding});

  final Onboarding onboarding;

  @override
  Widget build(BuildContext context) {
    final o = onboarding;
    final c = context.colors;
    final next = o.nextStep;
    final (String badge, Tone tone) = o.isLive
        ? ('Live', Tone.success)
        : next?.state == StepStatus.rejected
        ? ('Fix', Tone.danger)
        : o.waitingLabel != null
        ? (o.waitingLabel!, Tone.info)
        : next != null
        ? ('Your turn', Tone.accent)
        : (o.statusLabel, Tone.neutral);
    final where = o.isLive
        ? [if (o.storeCode != null) o.storeCode!, if (o.store.name != null) o.store.name!].join(' · ')
        : (next?.key.title ?? o.statusLabel);
    final total = o.steps.isEmpty ? 5 : o.steps.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/onboarding/${o.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.name, style: context.text.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${o.number} · $where', style: context.text.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: Space.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: o.isLive ? 1 : o.done / total,
                      minHeight: 5,
                      backgroundColor: context.fieldFill,
                      color: o.isLive ? c.success : c.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            StatusBadge(badge, tone: tone),
          ],
        ),
      ),
    );
  }
}
