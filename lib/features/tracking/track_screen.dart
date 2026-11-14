import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/brand/logo.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import 'track.dart';
import 'track_session.dart';

/// Read-only journey of a franchise enquiry, for the person who made it.
/// Everything shown comes from `/partner/track`.
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  @override
  void initState() {
    super.initState();
    // The docs ask for a fresh read whenever the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      await ref.read(trackSessionProvider.notifier).refresh();
    } catch (_) {
      // Offline: the last saved journey stays on screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(trackSessionProvider).value;
    if (track == null) return const SizedBox.shrink();
    final signOut = ref.read(trackSessionProvider.notifier).signOut;

    final header = Row(
      children: [
        const Expanded(
          child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 30)),
        ),
        IconTile(AppIcons.logout, semanticLabel: 'Sign out', alignment: Alignment.centerRight, onTap: signOut),
      ],
    );

    if (track.signInAgain) {
      return PageBody(
        bottom: ActionBar(
          children: [AppButton(label: 'Sign in again', onPressed: signOut)],
        ),
        children: [
          header,
          const SizedBox(height: Space.xxl),
          const MessageBlock(
            icon: AppIcons.check,
            title: 'Your application is approved',
            body: 'Please sign in again with the same mobile number to continue.',
          ),
        ],
      );
    }

    return PageBody(
      onRefresh: _refresh,
      children: [
        header,
        const SizedBox(height: Space.xs),
        _Summary(track: track),
        const SectionLabel('Your journey'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xs),
          child: Column(
            children: [
              for (var i = 0; i < track.steps.length; i++)
                _StepRow(step: track.steps[i], last: i == track.steps.length - 1),
            ],
          ),
        ),
        if (track.areaManager != null || track.support != null) ...[
          const SectionLabel('Need help?'),
          GroupedList(
            children: [
              if (track.areaManager case final am?)
                _ContactRow(title: am.name ?? 'Area manager', subtitle: 'Your area manager', phone: am.phone),
              if (track.support case final s?)
                _ContactRow(title: s.phone ?? s.email ?? 'Support', subtitle: 'Dava India support', phone: s.phone),
            ],
          ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(track.name, style: context.text.heading),
          Text([track.reference, ?track.storeCode].where((s) => s.isNotEmpty).join(' · '), style: context.text.label),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: track.progress,
                    minHeight: 6,
                    color: c.primary,
                    backgroundColor: c.fieldOnCard,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Text('${track.done} of ${track.total}', style: context.text.label),
            ],
          ),
          if (track.headline case final h?) ...[const SizedBox(height: Space.md), Text(h, style: context.text.body)],
        ],
      ),
    );
  }
}

/// One timeline row: a status dot on a vertical rail, then the step text.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});

  final TrackStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, tone, color, icon) = switch (step.state) {
      JourneyState.done => ('Completed', Tone.success, c.success, AppIcons.check),
      JourneyState.waiting => ('In progress', Tone.info, c.info, AppIcons.clock),
      JourneyState.action => ('Your turn', Tone.accent, c.accent, AppIcons.alert),
      JourneyState.rejected => ('Needs correction', Tone.danger, c.danger, AppIcons.alert),
      JourneyState.upcoming => ('Upcoming', Tone.neutral, c.textTertiary, null),
      JourneyState.closed => ('Closed', Tone.neutral, c.textTertiary, AppIcons.close),
    };
    final muted = step.state == JourneyState.upcoming;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: muted ? c.fieldOnCard : c.tintOf(color), shape: BoxShape.circle),
                  child: icon == null ? null : AppIcon(icon, size: 15, color: color),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: c.separator),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? Space.md : Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: context.text.bodyStrong.copyWith(color: muted ? c.textTertiary : c.textPrimary),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      StatusBadge(label, tone: tone),
                    ],
                  ),
                  if (step.who case final w?) Text(w, style: context.text.caption),
                  if (step.detail case final d?) ...[
                    const SizedBox(height: Space.xxs),
                    Text(
                      d,
                      style: context.text.secondary.copyWith(
                        color: step.state == JourneyState.rejected ? c.danger : null,
                      ),
                    ),
                  ],
                  if (step.date case final dt?) ...[
                    const SizedBox(height: Space.xxs),
                    Text(formatDate(dt), style: context.text.label),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.title, required this.subtitle, this.phone});

  final String title;
  final String subtitle;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final p = phone;
    return ListRow(
      title: p == null || title == p ? title : '$title · $p',
      subtitle: subtitle,
      leading: IconTile(AppIcons.phone, color: context.colors.accent, background: context.colors.accentTint),
      trailing: p == null
          ? null
          : IconTile(
              AppIcons.copy,
              semanticLabel: 'Copy number',
              onTap: () {
                Clipboard.setData(ClipboardData(text: p));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number copied')));
              },
            ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "17 Oct 2026, 3:01 am" in the phone's time zone.
String formatDate(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}
