import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/hscroll.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart';
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

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(leadFilterProvider);
    final queue = ref.watch(leadQueueProvider);
    final leads = ref.watch(leadsProvider);
    final canCreate = ref.watch(sessionProvider).value?.can(Perm.leadsCreate) ?? false;
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
              color: context.colors.accent,
              background: context.colors.accentTint,
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
        AppField(
          controller: _search,
          hint: 'Name, mobile or lead no.',
          leadingIcon: AppIcons.search,
          textInputAction: TextInputAction.search,
          onChanged: _onSearch,
        ),
        HScroll(
          spacing: Space.xs,
          children: List.generate(LeadFilter.values.length + (queue == null ? 0 : 1), (i) {
            // A queue opened from Home comes first, selected; tapping it
            // or any filter goes back to the normal filters.
            if (queue != null && i == 0) {
              return AppChip(
                height: 36,
                label: '${queue.label}  ✕',
                selected: true,
                onTap: () => ref.read(leadQueueProvider.notifier).set(null),
              );
            }
            final f = LeadFilter.values[i - (queue == null ? 0 : 1)];
            return AppChip(
              height: 36,
              label: f.label,
              selected: queue == null && f == filter,
              onTap: () {
                ref.read(leadQueueProvider.notifier).set(null);
                ref.read(leadFilterProvider.notifier).set(f);
              },
            );
          }),
        ),
        ...leads.when(
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
          data: (list) => list.isEmpty
              ? [
                  const SizedBox(height: Space.xl),
                  MessageBlock(
                    icon: AppIcons.leads,
                    title: 'No leads here',
                    body: _search.text.trim().isNotEmpty
                        ? 'Nothing matches your search.'
                        : filter == LeadFilter.all
                        ? 'Leads assigned to you will show here.'
                        : 'No leads with this status right now.',
                  ),
                ]
              : [
                  GroupedList(
                    children: [
                      for (final l in list)
                        ListRow(
                          title: l.name,
                          subtitle: l.subtitle,
                          leading: Initials(l.name),
                          trailing: StatusBadge(l.statusLabel, tone: toneForStatus(l.status)),
                          onTap: () => context.go('/leads/${l.id}'),
                        ),
                    ],
                  ),
                  Text('${list.length} ${list.length == 1 ? 'lead' : 'leads'}', style: context.text.label),
                ],
        ),
      ],
    );
  }
}
