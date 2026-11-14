import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/masters.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/partner_code.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'onboarding.dart';
import 'step_details.dart';
import 'step_forms.dart';

/// The permission each step needs.
String permissionFor(StepKey key) => switch (key) {
  StepKey.partnerVerification => Perm.onboardingVerifyPartner,
  StepKey.payment => Perm.paymentsRecord,
  _ => Perm.onboardingSubmit,
};

/// The form for a step.
Widget formFor(Onboarding o, StepKey key) => switch (key) {
  StepKey.partnerVerification => PartnerVerificationScreen(onboarding: o),
  StepKey.storeBasics => StoreBasicsScreen(onboarding: o),
  StepKey.ownerDocuments => OwnerDocsScreen(onboarding: o),
  StepKey.payment => PaymentStepScreen(onboardingId: o.id),
  StepKey.drugLicence => DrugLicenceScreen(onboarding: o),
};

class OnboardingDetailScreen extends ConsumerWidget {
  const OnboardingDetailScreen({super.key, required this.id});

  final int id;

  Future<void> _open(BuildContext context, WidgetRef ref, Widget form) async {
    final saved = await pushForm<bool>(context, form);
    if (saved == true) onboardingChanged(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ref.watch(onboardingProvider(id));
    final user = ref.watch(sessionProvider).value;
    bool can(StepKey k) => user?.can(permissionFor(k)) ?? false;
    final back = PageHeader(
      ob.value?.number ?? 'Onboarding',
      onBack: () => context.canPop() ? context.pop() : context.go('/onboarding'),
    );
    return ob.when(
      skipLoadingOnReload: true,
      loading: () => PageBody(
        children: [
          back,
          const SkeletonScope(
            label: 'Loading onboarding',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Bone(width: 180, height: 16),
                SizedBox(height: Space.sm),
                Bone(width: 140, height: 10),
                SizedBox(height: Space.lg),
                SkeletonRows(count: 5, lead: BoneLead.circle, badge: false),
              ],
            ),
          ),
        ],
      ),
      error: (_, _) => PageBody(
        children: [
          back,
          const SizedBox(height: Space.xl),
          MessageBlock(
            icon: AppIcons.alert,
            title: "Couldn't load this onboarding",
            body: 'Check your connection and try again.',
            action: AppButton(
              label: 'Try again',
              kind: ButtonKind.secondary,
              onPressed: () => ref.invalidate(onboardingProvider(id)),
            ),
          ),
        ],
      ),
      data: (o) {
        final next = o.nextStep;
        final canNext = next != null && can(next.key);
        return PageBody(
          onRefresh: () async {
            ref.invalidate(onboardingActivitiesProvider(id));
            ref.invalidate(onboardingProvider(id));
            await ref.read(onboardingProvider(id).future);
          },
          bottom: (canNext || o.mobile != null)
              ? ActionBar(
                  children: [
                    Row(
                      children: [
                        if (o.mobile != null)
                          _Square(
                            icon: AppIcons.phone,
                            label: 'Call ${o.name}',
                            onTap: () => launchUrl(Uri(scheme: 'tel', path: o.mobile)),
                          ),
                        if (canNext) ...[
                          if (o.mobile != null) const SizedBox(width: Space.sm),
                          Expanded(
                            child: AppButton(
                              label: _actionLabel(next),
                              onPressed: () => _open(context, ref, formFor(o, next.key)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              : null,
          children: [
            back,
            Text(o.name, style: context.text.heading),
            Text([o.model, o.store.name, o.store.city].whereType<String>().join(' · '), style: context.text.label),
            if (o.isLive)
              AppCard(
                color: context.colors.tintOf(context.colors.success),
                child: Text(
                  [
                    'Store is live',
                    if (o.storeCode != null) o.storeCode!,
                    if (o.activatedAt != null) formatDay(o.activatedAt!),
                  ].join(' · '),
                  style: context.text.bodyStrong.copyWith(color: context.colors.success),
                ),
              )
            else if (o.waitingLabel != null)
              AppCard(
                color: context.colors.tintOf(context.colors.info),
                child: Text(
                  'With ${o.waitingLabel} for review',
                  style: context.text.body.copyWith(color: context.colors.info),
                ),
              ),
            if (ref.watch(appConfigProvider).value?.fieldIssuesCodes ?? false)
              TextLink(
                label: 'Give the partner a sign-in code',
                onTap: () => showPartnerCode(context, ref, '/onboardings/${o.id}/partner-code', name: o.name),
              ),
            const SectionLabel('Steps'),
            GroupedList(
              children: [
                for (final s in o.steps)
                  _StepRow(
                    step: s,
                    onTap: s.state == StepStatus.locked
                        ? null
                        : () async {
                            await pushForm<void>(
                              context,
                              s.key == StepKey.payment
                                  ? PaymentStepScreen(onboardingId: o.id)
                                  : StepDetailsScreen(onboardingId: o.id, step: s.key),
                            );
                            onboardingChanged(ref);
                          },
                  ),
              ],
            ),
            if (o.fee.required && o.step(StepKey.payment)?.state != StepStatus.skipped) ...[
              const SectionLabel('Franchise fee'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Total, with GST', style: context.text.secondary)),
                        Text(rupees(o.fee.total), style: context.text.bodyStrong),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: o.fee.total == 0 ? 0 : (o.fee.paidVerified / o.fee.total).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: context.fieldFill,
                        color: context.colors.success,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        '${rupees(o.fee.paidVerified)} verified',
                        if (o.fee.paidPending > 0) '${rupees(o.fee.paidPending)} with finance',
                        '${rupees(o.fee.balance)} left',
                      ].join(' · '),
                      style: context.text.label,
                    ),
                  ],
                ),
              ),
            ],
            const SectionLabel('Timeline'),
            _Timeline(id: id),
          ],
        );
      },
    );
  }

  static String _actionLabel(OnboardingStep s) {
    final fix = s.state == StepStatus.rejected;
    return switch (s.key) {
      StepKey.partnerVerification => 'Verify partner',
      StepKey.storeBasics => fix ? 'Fix store details' : 'Fill store details',
      StepKey.ownerDocuments => fix ? 'Fix owner documents' : 'Add owner documents',
      StepKey.payment => fix ? 'Fix payment' : 'Record payment',
      StepKey.drugLicence => fix ? 'Fix drug licence' : 'Add drug licence',
    };
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, this.onTap});

  final OnboardingStep step;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = step;
    final (AppIconData icon, Color tone, String sub) = switch (s.state) {
      StepStatus.approved => (
        AppIcons.check,
        c.success,
        s.reviewedAt == null ? 'Approved' : 'Approved ${formatDay(s.reviewedAt!)}',
      ),
      StepStatus.submitted => (
        AppIcons.clock,
        c.info,
        s.submittedAt == null ? 'In review' : 'Sent ${formatDay(s.submittedAt!)} · in review',
      ),
      StepStatus.rejected => (AppIcons.alert, c.danger, s.rejectionReason ?? 'Sent back for changes'),
      StepStatus.open => (AppIcons.right, c.accent, 'Ready to fill'),
      StepStatus.skipped => (AppIcons.check, c.textTertiary, 'Not needed'),
      StepStatus.locked => (AppIcons.lock, c.textTertiary, 'Opens after the step before'),
    };
    final dim = s.state == StepStatus.locked || s.state == StepStatus.skipped;
    return ListRow(
      title: s.key.title,
      subtitle: sub,
      leading: IconTile(icon, color: tone, background: c.tintOf(tone), size: 32, iconSize: 16),
      trailing: onTap == null ? null : AppIcon(AppIcons.right, size: Sizes.iconSmall, color: c.textTertiary),
      onTap: onTap,
      dim: dim,
    );
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.icon, required this.label, required this.onTap});

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: Sizes.button,
          height: Sizes.button,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(Radii.control)),
          child: AppIcon(icon, size: Sizes.icon, color: context.colors.textPrimary),
        ),
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(onboardingActivitiesProvider(id))
        .when(
          skipLoadingOnReload: true,
          loading: () => const SkeletonScope(
            label: 'Loading timeline',
            child: SkeletonRows(count: 3, lead: BoneLead.none, badge: false),
          ),
          error: (_, _) => AppCard(child: Text("Couldn't load the timeline.", style: context.text.secondary)),
          data: (list) => list.isEmpty
              ? AppCard(child: Text('Nothing yet.', style: context.text.secondary))
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
