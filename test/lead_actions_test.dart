import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/auth/session.dart';
import 'package:fofo_onboarding/core/auth/user.dart';
import 'package:fofo_onboarding/core/masters.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/widgets/widgets.dart';
import 'package:fofo_onboarding/features/leads/lead.dart';
import 'package:fofo_onboarding/features/leads/lead_detail_screen.dart';
import 'package:fofo_onboarding/features/visits/visit.dart';
import 'package:material_ui/material_ui.dart';

class _FakeSession extends SessionController {
  _FakeSession(this.user);

  final AppUser user;

  @override
  Future<AppUser?> build() async => user;
}

AppUser _user(List<String> permissions) =>
    AppUser.fromJson({'id': 1, 'name': 'Arjun', 'role': 'field', 'permissions': permissions});

Lead _lead(List<String> actions) => Lead.fromJson({
  'id': 18,
  'lead_no': 'LD-000018',
  'name': 'Gaurav Mehta',
  'mobile': '9829012318',
  'status': 'ASSIGNED',
  'status_label': 'Assigned',
  'next_statuses': ['VISIT_SCHEDULED', 'VISITED', 'DROPPED'],
  'allowed_actions': actions,
});

Future<void> _pump(
  WidgetTester tester, {
  required Lead lead,
  List<Visit> visits = const [],
  List<String>? perms,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(
          () => _FakeSession(_user(perms ?? ['leads.view', 'leads.status', 'leads.update', 'visits.manage'])),
        ),
        leadProvider(18).overrideWith((ref) async => lead),
        leadActivitiesProvider(18).overrideWith((ref) async => const <Activity>[]),
        leadVisitsProvider(18).overrideWith((ref) async => visits),
        statusesProvider.overrideWith(
          (ref) async => {
            'VISIT_SCHEDULED': const StatusDef(code: 'VISIT_SCHEDULED', label: 'Visit Scheduled'),
            'VISITED': const StatusDef(code: 'VISITED', label: 'Visited'),
            'DROPPED': const StatusDef(code: 'DROPPED', label: 'Dropped', isExit: true, reasons: ['Partner withdrew']),
          },
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const LeadDetailScreen(id: 18)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('check-in is the main action when the server allows it', (tester) async {
    await _pump(tester, lead: _lead(['schedule_visit', 'checkin', 'add_note', 'change_status']));
    expect(find.text('Check in'), findsOneWidget);
    expect(find.bySemanticsLabel('Call Gaurav Mehta'), findsOneWidget);
  });

  testWidgets('an open check-in turns the main action into check-out', (tester) async {
    final open = Visit.fromJson({
      'id': 40,
      'kind': 'checkin',
      'status': 'checked_in',
      'lead': {'id': 18, 'name': 'Gaurav Mehta'},
      'checked_in_at': DateTime.now().toIso8601String(),
      'geo_verified': true,
    });
    await _pump(tester, lead: _lead(['checkout', 'add_note']), visits: [open]);
    expect(find.text('Check out'), findsOneWidget);
    expect(find.textContaining('Checked in at'), findsOneWidget);
  });

  testWidgets('no visit actions without visits.manage', (tester) async {
    await _pump(tester, lead: _lead(['schedule_visit', 'checkin']), perms: ['leads.view']);
    expect(find.text('Check in'), findsNothing);
    expect(find.text('Schedule visit'), findsNothing);
  });

  testWidgets('More lists only what is allowed, and closing asks for a reason', (tester) async {
    await _pump(tester, lead: _lead(['schedule_visit', 'add_note', 'change_status']));
    await tester.tap(find.bySemanticsLabel('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule a visit'), findsOneWidget);
    expect(find.text('Add a note'), findsOneWidget);
    expect(find.text('Change status'), findsOneWidget);
    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Log a call'), findsNothing);
    expect(find.text('Reassign'), findsNothing);

    await tester.tap(find.text('Close lead'));
    await tester.pumpAndSettle();
    expect(find.text('Visited'), findsNothing);
    await tester.tap(find.text('Dropped'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Close lead'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a reason.'), findsOneWidget);
  });
}
