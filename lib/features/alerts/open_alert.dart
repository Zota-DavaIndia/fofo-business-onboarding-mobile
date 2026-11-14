import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/form.dart';
import '../field/expenses_screen.dart';
import '../field/leave_screen.dart';
import '../field/tickets_screen.dart';
import '../leads/lead_detail_screen.dart';
import '../onboarding/onboarding_detail_screen.dart';

DateTime? _lastOpen;

/// Opens what an alert is about: a lead, a visit, an onboarding, a ticket, the claims or the leave list.
/// Detail screens slide in over the current one, so Back returns to the alert. Alerts with nothing to
/// open go to the inbox. A second call right after the first (a double tap, or a toast and a push for
/// the same alert) is ignored, so the screen never opens twice.
void openAlert(BuildContext context, {String? entity, int? entityId}) {
  final now = DateTime.now();
  if (_lastOpen != null && now.difference(_lastOpen!) < const Duration(milliseconds: 800)) return;
  _lastOpen = now;
  switch (entity) {
    case 'lead' when entityId != null:
      pushForm<void>(context, LeadDetailScreen(id: entityId));
    case 'visit':
      context.go('/visits');
    case 'onboarding' when entityId != null:
      pushForm<void>(context, OnboardingDetailScreen(id: entityId));
    case 'ticket' when entityId != null:
      pushForm<void>(context, TicketScreen(id: entityId));
    case 'expense':
      pushForm<void>(context, const ExpensesScreen());
    case 'leave':
      pushForm<void>(context, const LeaveScreen());
    default:
      final here = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
      if (here != '/alerts') context.push('/alerts');
  }
}
