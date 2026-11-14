import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import 'lead.dart';
import 'lead_status.dart';

class LeadDetailScreen extends ConsumerWidget {
  const LeadDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadProvider(id));
    final back = PageHeader('Lead', onBack: () => context.canPop() ? context.pop() : context.go('/leads'));
    return lead.when(
      loading: () => PageBody(
        children: [
          back,
          Text('Loading…', style: context.text.secondary),
        ],
      ),
      error: (_, _) => PageBody(
        children: [
          back,
          const SizedBox(height: Space.xl),
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load this lead",
            body: 'Check your connection and try again.',
            action: AppButton(
              label: 'Try again',
              kind: ButtonKind.secondary,
              onPressed: () => ref.invalidate(leadProvider(id)),
            ),
          ),
        ],
      ),
      data: (l) => PageBody(
        onRefresh: () async {
          ref.invalidate(leadActivitiesProvider(id));
          ref.invalidate(leadProvider(id));
          await ref.read(leadProvider(id).future);
        },
        children: [back, ..._content(context, ref, l)],
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, Lead l) {
    final details = <(String, String)>[
      if (l.sourceLabel != null) ('Source', l.sourceLabel!),
      if (l.enquiryAt != null) ('Enquired', formatDate(l.enquiryAt!)),
      if (l.pincode != null || l.city != null) ('Location', [l.pincode, l.city].whereType<String>().join(' · ')),
      if (l.address != null) ('Address', l.address!),
      if (l.shopOwnership != null || l.shopAreaSqft != null)
        (
          'Shop',
          [
            if (l.shopOwnership != null) _cap(l.shopOwnership!),
            if (l.shopAreaSqft != null) '${l.shopAreaSqft} sq ft',
          ].join(' · '),
        ),
      if (l.investmentReady != null) ('Investment ready', _cap(l.investmentReady!)),
      if (l.nextVisitAt != null) ('Next visit', formatDate(l.nextVisitAt!)),
      if (l.nextCallAt != null) ('Next call', formatDate(l.nextCallAt!)),
    ];
    return [
      Row(
        children: [
          Initials(l.name, size: 52),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.name, style: context.text.heading),
                Text(l.subtitle, style: context.text.label),
              ],
            ),
          ),
          StatusBadge(l.statusLabel, tone: toneForStatus(l.status)),
        ],
      ),
      if (l.mobile != null || l.email != null) ...[
        const SectionLabel('Contact'),
        GroupedList(
          children: [
            if (l.mobile != null) _CopyRow(value: l.mobile!, label: 'Mobile', icon: AppIcons.phone),
            if (l.email != null) _CopyRow(value: l.email!, label: 'Email', icon: AppIcons.chat),
          ],
        ),
      ],
      if (l.lastCall?.summary != null) ...[
        const SectionLabel('From the call centre'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.lastCall!.summary!, style: context.text.body),
              const SizedBox(height: Space.xs),
              Text(
                [
                  if (l.lastCall!.disposition != null) _cap(l.lastCall!.disposition!.replaceAll('_', ' ')),
                  if (l.lastCall!.at != null) formatDate(l.lastCall!.at!),
                ].join(' · '),
                style: context.text.label,
              ),
            ],
          ),
        ),
      ],
      if (details.isNotEmpty) ...[
        const SectionLabel('Details'),
        GroupedList(
          children: [for (final (k, v) in details) _InfoRow(label: k, value: v)],
        ),
      ],
      if (l.notes != null) ...[
        const SectionLabel('Notes'),
        AppCard(child: Text(l.notes!, style: context.text.secondary)),
      ],
      if (l.onboarding case final o?) ...[
        const SectionLabel('Onboarding'),
        GroupedList(
          children: [
            if (o.number != null) _InfoRow(label: 'Number', value: o.number!),
            if (o.status != null) _InfoRow(label: 'Status', value: _cap(o.status!.replaceAll('_', ' ').toLowerCase())),
            if (o.waitingFor != null) _InfoRow(label: 'Waiting for', value: _cap(o.waitingFor!)),
          ],
        ),
      ],
      const SectionLabel('Timeline'),
      _Timeline(id: id),
    ];
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Padding(
              padding: const EdgeInsets.only(right: Space.md),
              child: Text(label, style: context.text.secondary),
            ),
          ),
          Expanded(child: Text(value, style: context.text.body)),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: value,
      subtitle: label,
      leading: IconTile(icon, color: context.colors.accent, background: context.colors.accentTint),
      trailing: IconTile(
        AppIcons.copy,
        semanticLabel: 'Copy $label',
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
        },
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(leadActivitiesProvider(id));
    return items.when(
      loading: () => AppCard(child: Text('Loading…', style: context.text.secondary)),
      error: (_, _) => AppCard(child: Text("Couldn't load the timeline.", style: context.text.secondary)),
      data: (list) => list.isEmpty
          ? AppCard(child: Text('Nothing has happened on this lead yet.', style: context.text.secondary))
          : GroupedList(
              children: [
                for (final a in list)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: context.text.body),
                        if (a.notes != null) Text(a.notes!, style: context.text.secondary),
                        Text(
                          [if (a.by != null) a.by!, if (a.at != null) formatDate(a.at!)].join(' · '),
                          style: context.text.label,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
