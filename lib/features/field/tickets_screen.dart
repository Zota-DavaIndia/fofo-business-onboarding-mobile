import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'plan.dart';

Tone ticketTone(String status) => switch (status) {
  'open' => Tone.warning,
  'in_progress' => Tone.info,
  'resolved' => Tone.success,
  _ => Tone.neutral,
};

/// Tickets raised for the user's stores: open ones first, resolved in their own tab.
class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(ticketsProvider(_open));
    return PageBody(
      onRefresh: () => ref.refresh(ticketsProvider(_open).future),
      header: PageHeader('Tickets', onBack: () => Navigator.of(context).maybePop()),
      children: [
        Row(
          children: [
            AppChip(label: 'Open', selected: _open, onTap: () => setState(() => _open = true)),
            const SizedBox(width: Space.xs),
            AppChip(label: 'Resolved', selected: !_open, onTap: () => setState(() => _open = false)),
          ],
        ),
        ...data.when(
          loading: () => [const SkeletonScope(label: 'Loading tickets', child: SkeletonRows(count: 4))],
          error: (_, _) => [
            MessageBlock(
              icon: AppIcons.alert,
              title: "Couldn't load tickets",
              body: 'Check your connection and pull down to try again.',
            ),
          ],
          data: (list) => list.isEmpty
              ? [
                  MessageBlock(
                    icon: AppIcons.alert,
                    title: _open ? 'No open tickets' : 'Nothing resolved yet',
                    body: 'Raise a ticket from a store when it has a problem with products, billing, dispatch or accounts.',
                  ),
                ]
              : [
                  GroupedList(
                    children: [
                      for (final t in list)
                        ListRow(
                          title: t.subject,
                          subtitle: [
                            t.number,
                            ?t.storeName,
                            t.categoryLabel,
                            if (t.createdAt != null) formatShortDay(t.createdAt!),
                          ].join(' · '),
                          trailing: StatusBadge(
                            t.high && t.isOpen ? 'Urgent' : t.statusLabel,
                            tone: t.high && t.isOpen ? Tone.danger : ticketTone(t.status),
                          ),
                          onTap: () async {
                            await pushForm<void>(context, TicketScreen(id: t.id));
                            ref.invalidate(ticketsProvider);
                          },
                        ),
                    ],
                  ),
                ],
        ),
      ],
    );
  }
}

class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(ticketProvider(id));
    return PageBody(
      onRefresh: () => ref.refresh(ticketProvider(id).future),
      header: PageHeader('Ticket', onBack: () => Navigator.of(context).maybePop()),
      children: t.when(
        loading: () => [const SkeletonScope(child: SkeletonCard(lines: 4))],
        error: (_, _) => [
          MessageBlock(icon: AppIcons.alert, title: "Couldn't load this ticket", body: 'Pull down to try again.'),
        ],
        data: (t) => [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.subject, style: context.text.heading),
                    Text([t.number, t.categoryLabel, if (t.high) 'Urgent'].join(' · '), style: context.text.label),
                  ],
                ),
              ),
              StatusBadge(t.statusLabel, tone: ticketTone(t.status)),
            ],
          ),
          GroupedList(
            children: [
              if (t.storeName != null) ListRow(title: t.storeName!, subtitle: 'Store'),
              if (t.raisedBy != null)
                ListRow(
                  title: t.raisedBy!,
                  subtitle: t.createdAt == null ? 'Raised by' : 'Raised ${formatDate(t.createdAt!)}',
                ),
            ],
          ),
          if (t.description != null) AppCard(child: Text(t.description!, style: context.text.body)),
          if (t.photoUrl != null)
            AppButton(
              label: 'View photo',
              icon: AppIcons.eye,
              kind: ButtonKind.secondary,
              onPressed: () => launchUrl(Uri.parse(t.photoUrl!), mode: LaunchMode.externalApplication),
            ),
          if (t.updates.isNotEmpty) ...[
            const SectionLabel('Updates'),
            GroupedList(
              children: [
                for (final u in t.updates)
                  ListRow(
                    title: [?u.statusLabel, ?u.note].join(' · '),
                    subtitle: [?u.by, if (u.at != null) formatDate(u.at!)].join(' · '),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
