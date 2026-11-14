import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'onboarding.dart';
import 'onboarding_detail_screen.dart' show formFor, permissionFor;

/// One label and value in a details card.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});

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

/// A card of [DetailRow]s, skipping empty values. Null when all are empty.
Widget? detailCard(List<(String, String?)> rows) {
  final shown = [
    for (final (k, v) in rows)
      if (v != null && v.trim().isNotEmpty) DetailRow(k, v),
  ];
  return shown.isEmpty ? null : GroupedList(children: shown);
}

/// A file on the server: tap to open it (signed link, 15 minutes).
class FileRow extends StatelessWidget {
  const FileRow({super.key, required this.label, this.url, this.subtitle, this.tone});

  final String label;
  final String? url;
  final String? subtitle;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isImage = url != null && !url!.toLowerCase().contains('.pdf') && url!.contains('photo');
    return ListRow(
      title: label,
      subtitle: (subtitle == null || subtitle!.isEmpty) ? (url == null ? 'Not uploaded' : 'Tap to open') : subtitle,
      leading: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(Radii.tile),
              child: Image.network(
                url!,
                width: Sizes.tile,
                height: Sizes.tile,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => IconTile(AppIcons.doc, color: c.accent, background: c.accentTint),
              ),
            )
          : IconTile(AppIcons.doc, color: c.accent, background: c.accentTint),
      trailing: tone == null ? null : StatusBadge(_toneLabel(tone!), tone: tone!),
      onTap: url == null ? null : () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
    );
  }

  static String _toneLabel(Tone t) => switch (t) {
    Tone.success => 'Approved',
    Tone.danger => 'Rejected',
    Tone.info => 'In review',
    _ => 'Sent',
  };
}

Tone docTone(String? state) => switch (state) {
  'approved' || 'verified' => Tone.success,
  'rejected' => Tone.danger,
  'pending' || 'submitted' || 'in_review' => Tone.info,
  _ => Tone.neutral,
};

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Store details as cards.
List<Widget> storeDetails(StoreDetails s) => [
  ?detailCard([
    ('Store name', s.name),
    ('Format', s.format == null ? null : _cap(s.format!)),
    ('Store PAN', s.pan),
    ('GSTIN', s.gstin),
    ('Carpet area', s.areaSqft == null ? null : '${s.areaSqft} sq ft'),
    ('Address', s.address),
    ('Pincode', s.pincode),
    ('City', [s.city, s.state].whereType<String>().join(', ')),
    ('Pin', s.latitude == null ? null : '${s.latitude!.toStringAsFixed(5)}, ${s.longitude!.toStringAsFixed(5)}'),
  ]),
  if (s.storefrontUrl != null) ...[
    const SectionLabel('Photo'),
    GroupedList(
      children: [FileRow(label: 'Shop front', url: s.storefrontUrl)],
    ),
  ],
];

/// Owner, pharmacist and documents as cards.
List<Widget> ownerDetails(OwnerDetails o, List<OnboardingDoc> docs) => [
  ?detailCard([
    ('Owner', o.name),
    ('Mobile', o.mobile),
    ('Email', o.email),
    ('PAN', o.pan),
    ('Aadhaar', o.aadhaarMasked),
    ('Address', o.address),
    ('Pharmacist', o.pharmacistName),
    ('Registration no.', o.pharmacistRegNo),
  ]),
  if (docs.isNotEmpty) ...[
    const SectionLabel('Documents'),
    GroupedList(
      children: [
        for (final d in docs)
          FileRow(
            label: d.label ?? _cap(d.type.replaceAll('_', ' ')),
            url: d.fileUrl,
            subtitle: [
              if (d.number != null) d.number!,
              if (d.expiryDate != null) 'valid till ${formatDay(d.expiryDate!)}',
              if (d.rejected && d.remarks != null) d.remarks!,
            ].join(' · '),
            tone: docTone(d.status),
          ),
      ],
    ),
  ],
];

/// The drug licence as a card and its file.
List<Widget> drugLicenceDetails(DrugLicence d) => [
  ?detailCard([
    ('Licence no.', d.number),
    ('Form', d.form),
    ('Valid till', d.validTill == null ? null : formatDay(d.validTill!)),
  ]),
  if (d.fileUrl != null)
    GroupedList(
      children: [FileRow(label: 'Drug licence', url: d.fileUrl, tone: docTone(d.state))],
    ),
];

/// What was sent for one step, its review, and the form when it's the
/// user's turn.
class StepDetailsScreen extends ConsumerWidget {
  const StepDetailsScreen({super.key, required this.onboardingId, required this.step});

  final int onboardingId;
  final StepKey step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ref.watch(onboardingProvider(onboardingId));
    final o = ob.value;
    final s = o?.step(step);
    final can = ref.watch(sessionProvider).value?.can(permissionFor(step)) ?? false;
    final act = o != null && s != null && s.state.actionable && can;
    return PageBody(
      onRefresh: () async {
        ref.invalidate(onboardingProvider(onboardingId));
        await ref.read(onboardingProvider(onboardingId).future);
      },
      bottom: act
          ? ActionBar(
              children: [
                AppButton(
                  label: s.state == StepStatus.rejected ? 'Fix' : 'Fill',
                  onPressed: () async {
                    final saved = await pushForm<bool>(context, formFor(o, step));
                    if (saved == true) onboardingChanged(ref);
                  },
                ),
              ],
            )
          : null,
      children: [
        PageHeader(step.title, onBack: () => Navigator.of(context).maybePop()),
        if (o == null)
          const SkeletonScope(child: SkeletonCard(lines: 5))
        else ...[
          Text('${o.name} · ${o.number}', style: context.text.label),
          if (s != null) _ReviewCard(step: s),
          ..._body(context, o),
        ],
      ],
    );
  }

  List<Widget> _body(BuildContext context, Onboarding o) {
    final empty = [AppCard(child: Text('Nothing sent for this step yet.', style: context.text.secondary))];
    switch (step) {
      case StepKey.partnerVerification:
        final v = o.verification;
        if (v.status == null || v.status == 'pending') return empty;
        return [
          ?detailCard([
            ('How', v.methodLabel),
            ('Called partner', v.calledPartner ? 'Yes' : null),
            ('Verified by', v.verifiedBy),
            ('Verified on', v.verifiedAt == null ? null : formatDate(v.verifiedAt!)),
          ]),
          if (v.photoUrl != null || v.signatureUrl != null)
            GroupedList(
              children: [
                if (v.photoUrl != null) FileRow(label: 'Partner photo', url: v.photoUrl),
                if (v.signatureUrl != null) FileRow(label: 'Signature', url: v.signatureUrl),
              ],
            ),
        ];
      case StepKey.storeBasics:
        final w = storeDetails(o.store);
        return o.store.name == null ? empty : w;
      case StepKey.ownerDocuments:
        return o.owner.name == null && o.documents.isEmpty ? empty : ownerDetails(o.owner, o.documents);
      case StepKey.payment:
        return const [];
      case StepKey.drugLicence:
        return o.drugLicence.isEmpty ? empty : drugLicenceDetails(o.drugLicence);
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = step;
    final (Color tone, String title, String? body) = switch (s.state) {
      StepStatus.approved => (
        c.success,
        'Approved',
        [
          if (s.reviewedBy != null) 'by ${s.reviewedBy}',
          if (s.reviewedAt != null) formatDate(s.reviewedAt!),
        ].join(' · '),
      ),
      StepStatus.submitted => (
        c.info,
        'In review',
        s.submittedAt == null ? null : 'Sent ${formatDate(s.submittedAt!)}',
      ),
      StepStatus.rejected => (
        c.danger,
        'Sent back${s.reviewedBy == null ? '' : ' by ${s.reviewedBy}'}',
        s.rejectionReason,
      ),
      StepStatus.open => (c.accent, 'Ready to fill', null),
      StepStatus.skipped => (c.textSecondary, 'Not needed for this store', null),
      StepStatus.locked => (c.textSecondary, 'Opens after the step before', null),
    };
    return AppCard(
      color: c.tintOf(tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.bodyStrong.copyWith(color: tone)),
          if (body != null && body.isNotEmpty) Text(body, style: context.text.body),
        ],
      ),
    );
  }
}
