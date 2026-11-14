import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/form.dart';
import '../field/expenses_screen.dart';
import '../field/leave_screen.dart';
import '../field/tickets_screen.dart';

/// Opens what an alert is about: a lead, a visit, an onboarding, a ticket, the claims or the leave list.
/// Alerts with nothing to open go to the inbox.
void openAlert(BuildContext context, {String? entity, int? entityId}) {
  switch (entity) {
    case 'lead' when entityId != null:
      context.go('/leads/$entityId');
    case 'visit':
      context.go('/visits');
    case 'onboarding' when entityId != null:
      context.go('/onboarding/$entityId');
    case 'ticket' when entityId != null:
      pushForm<void>(context, TicketScreen(id: entityId));
    case 'expense':
      pushForm<void>(context, const ExpensesScreen());
    case 'leave':
      pushForm<void>(context, const LeaveScreen());
    default:
      context.push('/alerts');
  }
}
