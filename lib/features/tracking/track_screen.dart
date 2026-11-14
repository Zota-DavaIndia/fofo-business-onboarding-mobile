import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/brand/logo.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import '../onboarding/onboarding.dart';
import 'partner.dart';
import 'customer_profile_screen.dart';
import 'partner_forms.dart';
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
          child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 22)),
        ),
        if (track.accountType == 'partner')
          IconTile(
            AppIcons.bell,
            semanticLabel: 'Updates',
            onTap: () => pushForm<void>(context, const CustomerInboxScreen()),
          ),
        const SizedBox(width: Space.xs),
        Semantics(
          button: true,
          label: 'Profile',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => pushForm<void>(context, const CustomerProfileScreen()),
            child: Initials(track.name, size: 40),
          ),
        ),
      ],
    );

    if (track.signInAgain) {
      return PageBody(
        bottom: ActionBar(
          children: [AppButton(label: 'Sign in again', onPressed: signOut)],
        ),
        header: header,
        children: [
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
      header: header,
      children: [
        const SizedBox(height: Space.xs),
        _Summary(track: track),
        if (track.accountType == 'partner') ...[_StepActions(track: track), const PartnerDetailsList()],
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

/// The partner's own steps as tiles: done ones greyed with a tick, the one
/// that's theirs to fill highlighted and tappable, the rest waiting or
/// locked.
class _StepActions extends ConsumerWidget {
  const _StepActions({required this.track});

  final Track track;

  static const _order = [StepKey.storeBasics, StepKey.ownerDocuments, StepKey.payment, StepKey.drugLicence];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(partnerMeProvider).value;
    final byKey = {for (final s in track.steps) s.key: s};
    final steps = [
      for (final k in _order)
        if (byKey[k.key] != null || (k != StepKey.payment)) (k, byKey[k.key]),
    ];
    final fixing = me?.myTurn != null && (me?.fixing ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Set up your store'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 1.7,
          children: [
            for (final (k, step) in steps)
              _StepTile(
                stepKey: k,
                state: _state(k, step, me),
                onTap: me == null ? null : () => _open(context, ref, me, k),
              ),
          ],
        ),
        if (fixing && me?.rejectionReason != null) ...[
          const SizedBox(height: Space.sm),
          AppCard(
            color: context.colors.tintOf(context.colors.danger),
            child: Text(me!.rejectionReason!, style: context.text.body),
          ),
        ],
      ],
    );
  }

  static _TileState _state(StepKey k, TrackStep? step, PartnerMe? me) {
    if (me?.myTurn == k) return me!.fixing ? _TileState.fix : _TileState.todo;
    return switch (step?.state) {
      JourneyState.done => _TileState.done,
      JourneyState.waiting => _TileState.review,
      JourneyState.action => _TileState.todo,
      JourneyState.rejected => _TileState.fix,
      _ => _TileState.locked,
    };
  }

  Future<void> _open(BuildContext context, WidgetRef ref, PartnerMe me, StepKey k) async {
    final saved = await pushForm<bool>(context, partnerFormFor(me, k));
    if (saved == true) {
      ref.read(partnerRevisionProvider.notifier).bump();
      try {
        await ref.read(trackSessionProvider.notifier).refresh();
      } catch (_) {}
    }
  }
}

enum _TileState { done, todo, fix, review, locked }

class _StepTile extends StatelessWidget {
  const _StepTile({required this.stepKey, required this.state, this.onTap});

  final StepKey stepKey;
  final _TileState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = switch (stepKey) {
      StepKey.storeBasics => 'Store details',
      StepKey.ownerDocuments => 'Documents',
      StepKey.payment => 'Franchise fee',
      StepKey.drugLicence => 'Drug licence',
      StepKey.partnerVerification => 'Verification',
    };
    final icon = switch (stepKey) {
      StepKey.storeBasics => AppIcons.store,
      StepKey.ownerDocuments => AppIcons.id,
      StepKey.payment => AppIcons.rupee,
      _ => AppIcons.shield,
    };
    final active = state == _TileState.todo || state == _TileState.fix;
    final (Color bg, Color fg, Color iconBg, AppIconData shown, String status) = switch (state) {
      _TileState.todo => (c.primary, c.onPrimary, c.onPrimary.withValues(alpha: 0.18), icon, 'Fill now'),
      _TileState.fix => (c.danger, c.onPrimary, c.onPrimary.withValues(alpha: 0.18), icon, 'Correct now'),
      _TileState.done => (c.card, c.textTertiary, c.tintOf(c.success), AppIcons.check, 'Done'),
      _TileState.review => (c.card, c.textSecondary, c.tintOf(c.info), AppIcons.clock, 'In review'),
      _TileState.locked => (c.card, c.textTertiary, context.fieldFill, AppIcons.lock, 'Later'),
    };
    final iconColor = switch (state) {
      _TileState.done => c.success,
      _TileState.review => c.info,
      _TileState.locked => c.textTertiary,
      _ => fg,
    };
    return Semantics(
      button: active,
      enabled: active,
      label: '$label, $status',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.card)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(Radii.tile)),
                child: AppIcon(shown, size: Sizes.iconSmall, color: iconColor),
              ),
              const Spacer(),
              Text(
                label,
                style: context.text.bodyStrong.copyWith(
                  color: active ? fg : (state == _TileState.locked ? c.textTertiary : c.textPrimary),
                ),
              ),
              Text(status, style: context.text.label.copyWith(color: active ? fg.withValues(alpha: 0.9) : fg)),
            ],
          ),
        ),
      ),
    );
  }
}
