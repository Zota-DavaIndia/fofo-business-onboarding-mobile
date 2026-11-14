import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart';
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
    final leads = ref.watch(leadsProvider);
    return PageBody(
      onRefresh: () => ref.refresh(leadsProvider.future),
      children: [
        Text('Leads', style: context.text.title),
        AppField(
          controller: _search,
          hint: 'Name, mobile or lead no.',
          leadingIcon: AppIcons.search,
          textInputAction: TextInputAction.search,
          onChanged: _onSearch,
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: LeadFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
            itemBuilder: (context, i) {
              final f = LeadFilter.values[i];
              return _Chip(
                label: f.label,
                selected: f == filter,
                onTap: () => ref.read(leadFilterProvider.notifier).set(f),
              );
            },
          ),
        ),
        ...leads.when(
          loading: () => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxl),
              child: Text('Loading leads…', style: context.text.secondary),
            ),
          ],
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accentTint : context.fieldFill,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Text(label, style: context.text.secondary.copyWith(color: selected ? c.accent : c.textSecondary)),
        ),
      ),
    );
  }
}
