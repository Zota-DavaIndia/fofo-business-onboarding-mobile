import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/widgets.dart';
import 'alerts.dart';
import 'open_alert.dart';

/// The staff inbox: new assignments, approvals, rejections, payments.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  static AppIconData _icon(Alert a) => switch (a.entity) {
    'lead' => AppIcons.leads,
    'visit' => AppIcons.visit,
    'onboarding' => a.type.contains('payment') ? AppIcons.rupee : AppIcons.store,
    _ => AppIcons.bell,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(alertsProvider);
    final c = context.colors;
    return PageBody(
      onRefresh: () async {
        ref.invalidate(alertsProvider);
        await ref.read(alertsProvider.future);
      },
      children: [
        PageHeader(
          'Alerts',
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
          trailing: (inbox.value?.unread ?? 0) > 0
              ? TextLink(label: 'Mark all read', onTap: () => markAllAlertsRead(ref))
              : null,
        ),
        ...inbox.when(
          loading: () => [
            const SkeletonScope(
              label: 'Loading alerts',
              child: SkeletonRows(count: 6, lead: BoneLead.tile, badge: false),
            ),
          ],
          error: (_, _) => [
            const SizedBox(height: Space.xl),
            MessageBlock(
              icon: AppIcons.alert,
              title: "Couldn't load alerts",
              body: 'Check your connection and pull down to try again.',
              action: AppButton(
                label: 'Try again',
                kind: ButtonKind.secondary,
                onPressed: () => ref.invalidate(alertsProvider),
              ),
            ),
          ],
          data: (d) => d.items.isEmpty
              ? [
                  const SizedBox(height: Space.xl),
                  const MessageBlock(
                    icon: AppIcons.bell,
                    title: 'No alerts',
                    body: 'New assignments, approvals and payment updates show here.',
                  ),
                ]
              : [
                  GroupedList(
                    children: [
                      for (final a in d.items)
                        ListRow(
                          title: a.title,
                          subtitle: [if (a.body != null) a.body!, if (a.at != null) formatDate(a.at!)].join(' · '),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconTile(
                                _icon(a),
                                color: a.read ? c.textTertiary : c.accent,
                                background: a.read ? context.fieldFill : c.accentTint,
                              ),
                              if (!a.read)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: c.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: c.card, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            if (!a.read) await markAlertRead(ref, a.id);
                            if (context.mounted &&
                                (a.route != null || const {'ticket', 'expense', 'leave'}.contains(a.entity))) {
                              openAlert(context, entity: a.entity, entityId: a.entityId);
                            }
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
