import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/masters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/hscroll.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart';
import 'lead_filter_sheet.dart';
import 'lead_form_screen.dart';
import 'leads_board.dart';
import 'lead_status.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  late final TextEditingController _search = TextEditingController(text: ref.read(leadSearchProvider));
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => ref.read(leadSearchProvider.notifier).set(text));
  }

  Future<void> _openFilters(LeadTab tab, LeadFilter filter) async {
    final defs = ref.read(statusesProvider).value?.values ?? const <StatusDef>[];
    // Archived lists closed statuses; the rest of the Leads tab, the open ones. Opportunities are all qualified.
    final statuses = switch (tab) {
      LeadTab.opportunities => const <StatusDef>[],
      LeadTab.leads => [
        for (final d in defs)
          if (d.code != 'QUALIFIED' && d.isExit == (filter == LeadFilter.archived)) d,
      ],
    };
    final picked = await showLeadFilterSheet(context, current: ref.read(leadRefineProvider), statuses: statuses);
    if (picked != null) ref.read(leadRefineProvider.notifier).set(picked);
  }

  void _setTab(LeadTab t) {
    ref.read(leadQueueProvider.notifier).set(null);
    ref.read(leadRefineProvider.notifier).set(const LeadRefine());
    ref.read(leadTabProvider.notifier).set(t);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(statusesProvider);
    final tab = ref.watch(leadTabProvider);
    final filter = ref.watch(leadFilterProvider);
    final queue = ref.watch(leadQueueProvider);
    final refine = ref.watch(leadRefineProvider);
    final page = ref.watch(leadsProvider);
    final counts = page.value?.counts ?? const {};
    final canCreate = ref.watch(sessionProvider).value?.can(Perm.leadsCreate) ?? false;
    final c = context.colors;
    return PageBody(
      onRefresh: () => ref.refresh(leadsProvider.future),
      header: Row(
        children: [
          Expanded(child: Text('Leads', style: context.text.title)),
          IconTile(
            AppIcons.board,
            semanticLabel: 'Leads board',
            alignment: Alignment.centerRight,
            onTap: () => pushForm<void>(context, const LeadsBoardScreen()),
          ),
          if (canCreate) ...[
            const SizedBox(width: Space.xs),
            IconTile(
              AppIcons.plus,
              semanticLabel: 'Add a lead',
              color: c.accent,
              background: c.accentTint,
              alignment: Alignment.centerRight,
              onTap: () async {
                final id = await pushForm<int>(context, const LeadFormScreen());
                if (id != null && context.mounted) context.go('/leads/$id');
              },
            ),
          ],
        ],
      ),
      children: [
        SegmentedTabs<LeadTab>(
          values: LeadTab.values,
          selected: tab,
          label: (t) => counts[t] == null ? t.label : '${t.label} · ${counts[t]}',
          onSelect: _setTab,
        ),
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: _search,
                hint: 'Name, mobile or lead no.',
                leadingIcon: AppIcons.search,
                textInputAction: TextInputAction.search,
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(width: Space.sm),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconTile(
                  AppIcons.filter,
                  size: Sizes.field,
                  semanticLabel: refine.isEmpty ? 'Filter leads' : 'Filter leads, filters on',
                  onTap: () => _openFilters(tab, filter),
                ),
                if (!refine.isEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (tab == LeadTab.leads || queue != null)
          HScroll(
            spacing: Space.xs,
            children: [
              // A queue opened from Home comes first, selected; tapping it or any filter goes back to the normal filters.
              if (queue != null)
                AppChip(
                  height: 36,
                  label: '${queue.label}  ✕',
                  selected: true,
                  onTap: () => ref.read(leadQueueProvider.notifier).set(null),
                ),
              if (tab == LeadTab.leads)
                for (final f in LeadFilter.values)
                  AppChip(
                    height: 36,
                    label: f.label,
                    selected: queue == null && f == filter,
                    onTap: () {
                      ref.read(leadQueueProvider.notifier).set(null);
                      // The status list differs between open and archived leads.
                      if ((f == LeadFilter.archived) != (filter == LeadFilter.archived)) {
                        ref.read(leadRefineProvider.notifier).set(LeadRefine(from: refine.from, to: refine.to));
                      }
                      ref.read(leadFilterProvider.notifier).set(f);
                    },
                  ),
            ],
          ),
        ...page.when(
          skipLoadingOnReload: true,
          loading: () => [const SkeletonScope(label: 'Loading leads', child: SkeletonRows(count: 6))],
          error: (_, _) => [
            const SizedBox(height: Space.xl),
            MessageBlock(
              icon: AppIcons.alert,
              title: "Couldn't load leads",
              body: 'Check your connection and pull down to try again.',
              action: AppButton(
                label: 'Try again',
                kind: ButtonKind.secondary,
                onPressed: () => ref.invalidate(leadsProvider),
              ),
            ),
          ],
          data: (p) => p.items.isEmpty
              ? [
                  const SizedBox(height: Space.xl),
                  MessageBlock(
                    icon: AppIcons.leads,
                    title: tab == LeadTab.opportunities ? 'No opportunities here' : 'No leads here',
                    body: _search.text.trim().isNotEmpty
                        ? 'Nothing matches your search.'
                        : !refine.isEmpty || filter != LeadFilter.all || queue != null
                        ? 'Nothing matches these filters.'
                        : tab == LeadTab.opportunities
                        ? 'Leads you qualify move here for onboarding.'
                        : 'Leads assigned to you will show here.',
                  ),
                ]
              : [
                  GroupedList(
                    children: [
                      for (final l in p.items)
                        LeadRow(
                          lead: l,
                          opportunity: tab == LeadTab.opportunities,
                          onTap: () => context.go('/leads/${l.id}'),
                        ),
                    ],
                  ),
                  Text(
                    '${p.items.length} ${tab == LeadTab.opportunities ? (p.items.length == 1 ? 'opportunity' : 'opportunities') : (p.items.length == 1 ? 'lead' : 'leads')}',
                    style: context.text.label,
                  ),
                ],
        ),
      ],
    );
  }
}

/// A lead on the list: name with a New badge, lead number and date, who updated it last, status and progress.
class LeadRow extends StatelessWidget {
  const LeadRow({super.key, required this.lead, required this.onTap, this.opportunity = false});

  final Lead lead;
  final VoidCallback onTap;

  /// Shows the onboarding number, stage and progress instead of the lead's.
  final bool opportunity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = lead;
    final ob = opportunity ? l.onboarding : null;
    final added = l.enquiryAt;
    final line = [
      ob?.number ?? l.leadNo,
      if (ob == null) ?l.sourceLabel,
      if (ob == null && added != null) formatShortDay(added),
      if (ob != null) ?l.model,
    ].where((s) => s.isNotEmpty).join(' · ');
    final updated = [
      if (l.lastUpdateBy != null) 'Updated by ${l.lastUpdateBy}',
      if (l.lastUpdateAt != null) formatAgo(l.lastUpdateAt!),
    ].join(' · ');
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Row(
            children: [
              Initials(l.name),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(l.name, style: context.text.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (l.isNew && !opportunity) ...[
                          const SizedBox(width: Space.xs),
                          const StatusBadge('New', tone: Tone.info),
                        ],
                      ],
                    ),
                    if (line.isNotEmpty) Text(line, style: context.text.label),
                    if (updated.isNotEmpty)
                      Text(
                        updated,
                        style: context.text.caption.copyWith(color: c.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: Space.xxs),
                    StatusBadge(
                      ob?.statusLabel ?? l.statusLabel,
                      tone: ob != null ? toneForOnboarding(ob.status) : toneForStatus(l.status),
                    ),
                  ],
                ),
              ),
              if (l.progress != null) ...[
                const SizedBox(width: Space.sm),
                ProgressRing(l.progress!, color: opportunity ? c.success : c.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
