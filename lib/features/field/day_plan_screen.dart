import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/session.dart';
import '../../core/icons/app_icon.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/map_view.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import '../leads/lead_detail_screen.dart';
import 'plan.dart';
import 'store_screen.dart';

Tone _tone(StopStatus s) => switch (s) {
  StopStatus.planned => Tone.neutral,
  StopStatus.checkedIn => Tone.info,
  StopStatus.done => Tone.success,
};

PinTone _pin(StopStatus s) => switch (s) {
  StopStatus.planned => PinTone.accent,
  StopStatus.checkedIn => PinTone.info,
  StopStatus.done => PinTone.success,
};

/// Today's stops on a map and in order; each opens the store or the lead.
class DayPlanScreen extends ConsumerWidget {
  const DayPlanScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await pushForm<void>(context, const AddStopsScreen());
    ref.invalidate(dayPlanProvider);
  }

  Future<void> _open(BuildContext context, WidgetRef ref, PlanStop s) async {
    if (s.isStore && s.partnerId != null) {
      await pushForm<void>(context, StoreScreen(id: s.partnerId!));
    } else if (s.leadId != null) {
      await pushForm<void>(context, LeadDetailScreen(id: s.leadId!));
    }
    ref.invalidate(dayPlanProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, PlanStop s) async {
    if (s.status != StopStatus.planned) return;
    final ok = await showChoiceSheet<bool>(
      context,
      title: s.name,
      options: const [(true, 'Remove from today'), (false, 'Keep')],
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete<Object?>('/day-plan/${s.id}');
      ref.invalidate(dayPlanProvider);
    } on ApiException catch (e) {
      if (context.mounted) showSaveError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(dayPlanProvider);
    return PageBody(
      onRefresh: () => ref.refresh(dayPlanProvider.future),
      header: Row(
        children: [
          IconTile(
            AppIcons.left,
            semanticLabel: 'Back',
            alignment: Alignment.centerLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: Text('Day plan', style: context.text.title)),
          IconTile(
            AppIcons.plus,
            semanticLabel: 'Add stops',
            color: context.colors.accent,
            background: context.colors.accentTint,
            alignment: Alignment.centerRight,
            onTap: () => _add(context, ref),
          ),
        ],
      ),
      children: plan.when(
        loading: () => [
          const SkeletonScope(
            label: 'Loading your plan',
            child: Column(
              children: [
                SkeletonCard(lines: 4),
                SizedBox(height: Space.md),
                SkeletonRows(count: 3),
              ],
            ),
          ),
        ],
        error: (_, _) => [
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load your plan",
            body: 'Check your connection and pull down to try again.',
            action: AppButton(
              label: 'Try again',
              kind: ButtonKind.secondary,
              onPressed: () => ref.invalidate(dayPlanProvider),
            ),
          ),
        ],
        data: (stops) {
          if (stops.isEmpty) {
            return [
              const SizedBox(height: Space.xl),
              MessageBlock(
                icon: AppIcons.route,
                title: 'Plan your day',
                body: 'Add the stores and leads you will visit today. They show on a map in order, and each one opens for check-in.',
                action: AppButton(label: 'Add stops', icon: AppIcons.plus, onPressed: () => _add(context, ref)),
              ),
            ];
          }
          final done = stops.where((s) => s.status == StopStatus.done).length;
          final pins = [
            for (var i = 0; i < stops.length; i++)
              if (stops[i].hasPin)
                MapPin(
                  stops[i].latitude!,
                  stops[i].longitude!,
                  label: '${i + 1}. ${stops[i].name}',
                  note: stops[i].address,
                  tone: _pin(stops[i].status),
                ),
          ];
          return [
            Text('$done of ${stops.length} visited', style: context.text.secondary),
            if (pins.isNotEmpty) MapCard(pins: pins, height: 200),
            const SectionLabel('Stops'),
            GroupedList(
              children: [
                for (var i = 0; i < stops.length; i++)
                  GestureDetector(
                    onLongPress: () => _remove(context, ref, stops[i]),
                    child: ListRow(
                      title: stops[i].name,
                      subtitle: [
                        stops[i].isStore ? 'Store' : 'Lead',
                        ?stops[i].subtitle,
                        if (!stops[i].hasPin) 'no pin yet',
                      ].join(' · '),
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: stops[i].isStore
                              ? context.colors.tintOf(context.colors.info)
                              : context.colors.accentTint,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: context.text.bodyStrong.copyWith(
                            color: stops[i].isStore ? context.colors.info : context.colors.accent,
                          ),
                        ),
                      ),
                      trailing: StatusBadge(stops[i].status.label, tone: _tone(stops[i].status)),
                      onTap: () => _open(context, ref, stops[i]),
                    ),
                  ),
              ],
            ),
            Text('Hold a planned stop to remove it.', style: context.text.label),
          ];
        },
      ),
    );
  }
}

/// Pick live stores and open leads for today's plan.
class AddStopsScreen extends ConsumerStatefulWidget {
  const AddStopsScreen({super.key});

  @override
  ConsumerState<AddStopsScreen> createState() => _AddStopsScreenState();
}

class _AddStopsScreenState extends ConsumerState<AddStopsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';
  bool _stores = true;
  final _busy = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _addStop(PlanCandidate c) async {
    final key = '${c.isStore}-${c.id}';
    setState(() => _busy.add(key));
    try {
      await ref
          .read(apiClientProvider)
          .post<Object?>(
            '/day-plan',
            body: {'kind': c.isStore ? 'store' : 'lead', if (c.isStore) 'partner_id': c.id else 'lead_id': c.id},
          );
      ref.invalidate(planCandidatesProvider);
    } on ApiException catch (e) {
      if (mounted) showSaveError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(planCandidatesProvider(_q));
    final list = _stores ? data.value?.stores : data.value?.leads;
    return PageBody(
      header: PageHeader('Add stops', onBack: () => Navigator.of(context).maybePop()),
      children: [
        AppField(
          controller: _search,
          hint: _stores ? 'Store name, code or city' : 'Lead name, mobile or number',
          leadingIcon: AppIcons.search,
          onChanged: (t) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = t.trim()));
          },
        ),
        Row(
          children: [
            AppChip(label: 'Stores', selected: _stores, onTap: () => setState(() => _stores = true)),
            const SizedBox(width: Space.xs),
            AppChip(label: 'Leads', selected: !_stores, onTap: () => setState(() => _stores = false)),
          ],
        ),
        if (data.isLoading && list == null)
          const SkeletonScope(child: SkeletonRows(count: 5))
        else if (data.hasError)
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load the list",
            body: 'Pull down on the plan and try again.',
          )
        else if (list == null || list.isEmpty)
          MessageBlock(
            icon: _stores ? AppIcons.store : AppIcons.leads,
            title: _stores ? 'No live stores' : 'No open leads',
            body: _stores ? 'Stores show here once they go live in your area.' : 'Leads assigned to you show here.',
          )
        else
          GroupedList(
            children: [
              for (final c in list)
                ListRow(
                  title: c.name,
                  subtitle: [?c.subtitle, ?c.address].where((s) => s.isNotEmpty).join(' · '),
                  trailing: c.planned
                      ? StatusBadge('Planned', tone: Tone.success)
                      : _busy.contains('${c.isStore}-${c.id}')
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconTile(
                          AppIcons.plus,
                          semanticLabel: 'Add ${c.name}',
                          color: context.colors.accent,
                          background: context.colors.accentTint,
                          size: 36,
                          iconSize: 18,
                          onTap: () => _addStop(c),
                        ),
                  onTap: c.planned ? null : () => _addStop(c),
                ),
            ],
          ),
      ],
    );
  }
}
