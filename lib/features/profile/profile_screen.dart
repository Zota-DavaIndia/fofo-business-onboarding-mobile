import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';

final _deviceIdProvider = FutureProvider.autoDispose<String>((ref) => ref.watch(secureStoreProvider).deviceId());

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return const SizedBox.shrink();
    final deviceId = ref.watch(_deviceIdProvider).value ?? '…';

    return PageBody(
      children: [
        Text('Profile', style: context.text.title),
        Row(
          children: [
            Initials(user.name, size: 52),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: context.text.heading),
                  Text(user.designation, style: context.text.secondary),
                ],
              ),
            ),
          ],
        ),
        const SectionLabel('Contact'),
        GroupedList(
          children: [
            ListRow(title: user.email, subtitle: 'Email'),
            if (user.mobile != null) ListRow(title: user.mobile!, subtitle: 'Mobile'),
            if (user.territories.isNotEmpty)
              ListRow(title: user.territories.map((t) => t.name).join(', '), subtitle: 'Territories'),
          ],
        ),
        const SectionLabel('This phone'),
        GroupedList(
          children: [
            ListRow(title: Env.appVersion, subtitle: 'App version'),
            ListRow(
              title: deviceId,
              subtitle: 'Device ID',
              trailing: IconTile(
                AppIcons.copy,
                semanticLabel: 'Copy device ID',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: deviceId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device ID copied')));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: 'Sign out',
          kind: ButtonKind.secondary,
          icon: AppIcons.logout,
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
        ),
      ],
    );
  }
}
