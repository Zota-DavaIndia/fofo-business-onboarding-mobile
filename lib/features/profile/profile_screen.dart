import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';
import 'change_password_screen.dart';
import '../../core/widgets/toast.dart';
import '../../core/update/update.dart';
import '../update/update_screen.dart';

final _deviceIdProvider = FutureProvider.autoDispose<String>((ref) => ref.watch(secureStoreProvider).deviceId());

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return const SizedBox.shrink();
    final deviceId = ref.watch(_deviceIdProvider).value ?? '…';

    return PageBody(
      header: Text('Profile', style: context.text.title),
      children: [
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
        const SectionLabel('Security'),
        GroupedList(
          children: [
            ListRow(
              title: 'Change password',
              leading: IconTile(AppIcons.lock, color: context.colors.accent, background: context.colors.accentTint),
              trailing: AppIcon(AppIcons.right, size: Sizes.iconSmall, color: context.colors.textTertiary),
              onTap: () => pushForm<bool>(context, const ChangePasswordScreen()),
            ),
          ],
        ),
        const SectionLabel('This phone'),
        GroupedList(
          children: [
            if (ref.watch(availableUpdateProvider).value case final r?)
              ListRow(
                title: Env.appVersion,
                subtitle: 'App version · ${r.version} is ready',
                trailing: TextLink(
                  label: 'Update',
                  onTap: () => pushForm<void>(context, UpdateScreen(release: r)),
                ),
              )
            else
              ListRow(title: Env.appVersion, subtitle: 'App version'),
            ListRow(
              title: deviceId,
              subtitle: 'Device ID',
              trailing: IconTile(
                AppIcons.copy,
                semanticLabel: 'Copy device ID',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: deviceId));
                  showToast(context, 'Device ID copied', kind: ToastKind.success);
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
