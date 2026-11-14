import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import 'partner.dart';
import 'track_session.dart';

/// "98450 12345"
String _phone(String m) => m.length == 10 ? '${m.substring(0, 5)} ${m.substring(5)}' : m;

/// The customer's own profile: who they are, their store, who to call, and
/// sign out.
class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(trackSessionProvider).value;
    if (track == null) return const SizedBox.shrink();
    final partner = track.accountType == 'partner';
    final me = partner ? ref.watch(partnerMeProvider).value : null;
    final c = context.colors;
    final store = me?.store.name ?? track.storeName;
    final rcmPhone = me?.rcmMobile ?? track.areaManager?.phone;
    final rcmName = me?.rcmName ?? track.areaManager?.name;
    return PageBody(
      children: [
        PageHeader('Profile', onBack: () => Navigator.of(context).maybePop()),
        Row(
          children: [
            Initials(track.name, size: 64),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.name, style: context.text.heading),
                  Text(partner ? 'Franchise partner' : 'Franchise applicant', style: context.text.label),
                ],
              ),
            ),
          ],
        ),
        const SectionLabel('Your account'),
        GroupedList(
          children: [
            if (track.mobile case final m?)
              ListRow(
                title: _phone(m),
                subtitle: 'Mobile you sign in with',
                leading: IconTile(AppIcons.phone, color: c.accent, background: c.accentTint),
              ),
            if (partner)
              ListRow(
                title: track.reference,
                subtitle: 'Partner number',
                leading: IconTile(AppIcons.id, color: c.accent, background: c.accentTint),
              ),
            if (track.leadReference case final r? when r != track.reference || !partner)
              ListRow(
                title: r,
                subtitle: 'Enquiry reference',
                leading: IconTile(AppIcons.doc, color: c.accent, background: c.accentTint),
              ),
          ],
        ),
        if (store != null || track.storeCode != null) ...[
          const SectionLabel('Your store'),
          GroupedList(
            children: [
              if (store != null)
                ListRow(
                  title: store,
                  subtitle: [?me?.store.city, ?me?.model].join(' · '),
                  leading: IconTile(AppIcons.store, color: c.accent, background: c.accentTint),
                ),
              if (track.storeCode case final code?)
                ListRow(
                  title: code,
                  subtitle: 'Store code',
                  leading: IconTile(AppIcons.check, color: c.success, background: c.tintOf(c.success)),
                ),
            ],
          ),
        ],
        if (rcmName != null || track.support != null) ...[
          const SectionLabel('Need help?'),
          GroupedList(
            children: [
              if (rcmName != null)
                ListRow(
                  title: rcmName,
                  subtitle: 'Your area manager',
                  leading: Initials(rcmName),
                  trailing: rcmPhone == null
                      ? null
                      : IconTile(
                          AppIcons.phone,
                          semanticLabel: 'Call $rcmName',
                          color: c.accent,
                          background: c.accentTint,
                          onTap: () => launchUrl(Uri(scheme: 'tel', path: rcmPhone)),
                        ),
                ),
              if (track.support case final s? when !s.isEmpty)
                ListRow(
                  title: s.phone ?? s.email ?? 'Support',
                  subtitle: 'Dava India support',
                  leading: IconTile(AppIcons.chat, color: c.accent, background: c.accentTint),
                  trailing: s.phone == null
                      ? null
                      : IconTile(
                          AppIcons.phone,
                          semanticLabel: 'Call support',
                          color: c.accent,
                          background: c.accentTint,
                          onTap: () => launchUrl(Uri(scheme: 'tel', path: s.phone)),
                        ),
                ),
            ],
          ),
        ],
        const SectionLabel('This phone'),
        GroupedList(
          children: [ListRow(title: Env.appVersion, subtitle: 'App version')],
        ),
        const SizedBox(height: Space.md),
        AppButton(
          label: 'Sign out',
          icon: AppIcons.logout,
          kind: ButtonKind.secondary,
          onPressed: () async {
            Navigator.of(context).maybePop();
            await ref.read(trackSessionProvider.notifier).signOut();
          },
        ),
      ],
    );
  }
}
