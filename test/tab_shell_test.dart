import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/app/app.dart';
import 'package:fofo_onboarding/core/auth/session.dart';
import 'package:fofo_onboarding/core/auth/user.dart';
import 'package:fofo_onboarding/core/update/update.dart';
import 'package:fofo_onboarding/features/alerts/alerts.dart';
import 'package:fofo_onboarding/features/home/dashboard.dart';
import 'package:fofo_onboarding/features/leads/lead.dart';
import 'package:fofo_onboarding/features/visits/visit.dart';
import 'package:fofo_onboarding/features/tracking/track.dart';
import 'package:fofo_onboarding/features/tracking/track_session.dart';

class _FakeSession extends SessionController {
  _FakeSession(this.user);

  final AppUser? user;

  @override
  Future<AppUser?> build() async => user;
}

class _NoTrack extends TrackSession {
  @override
  Future<Track?> build() async => null;
}

AppUser _user(List<String> permissions) => AppUser.fromJson({
  'id': 1,
  'name': 'Arjun Kumar',
  'email': 'arjun@example.com',
  'role': 'field',
  'role_label': 'RCM',
  'permissions': permissions,
});

Future<void> _pump(WidgetTester tester, AppUser? user) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSession(user)),
        trackSessionProvider.overrideWith(_NoTrack.new),
        todaysVisitsProvider.overrideWith((ref) async => const <Visit>[]),
        leadsProvider.overrideWith((ref) async {
          final f = ref.watch(leadFilterProvider);
          final all = [
            Lead.fromJson({
              'id': 1,
              'lead_no': 'LD-000001',
              'name': 'Gaurav Mehta',
              'status': 'ASSIGNED',
              'status_label': 'Assigned',
            }),
            Lead.fromJson({
              'id': 2,
              'lead_no': 'LD-000002',
              'name': 'Rekha Choudhary',
              'status': 'FOLLOW_UP',
              'status_label': 'Follow Up',
            }),
          ];
          // The visits_due queue holds the assigned lead in this fake.
          if (ref.watch(leadQueueProvider)?.queue == 'visits_due') return [all.first];
          final status = f.query['status'];
          return status == null ? all : all.where((l) => l.status == status).toList();
        }),
        dashboardProvider.overrideWith(
          (ref) async => Dashboard.fromJson({
            'total': 5,
            'by_status': {'ASSIGNED': 4, 'QUALIFIED': 1},
            'attention': [
              {
                'key': 'visits_overdue',
                'label': 'Visits overdue',
                'count': 1,
                'target': {'screen': 'leads', 'queue': 'visits_due'},
              },
            ],
            'today': {'new_leads': 1, 'calls': 2, 'visits': 0, 'qualified': 0},
          }),
        ),
        alertsProvider.overrideWith((ref) async => (items: const <Alert>[], unread: 0)),
        availableUpdateProvider.overrideWith((ref) async => null),
      ],
      child: const FieldApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows only the tabs the user is allowed', (tester) async {
    await _pump(tester, _user(['leads.view', 'dashboard.view']));

    expect(find.text('Leads'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Visits'), findsNothing);
    expect(find.text('Onboard'), findsNothing);
    expect(find.text('Hi Arjun'), findsOneWidget);
    expect(find.text('Visits overdue'), findsOneWidget);
    expect(find.text('Total leads'), findsOneWidget);
  });

  testWidgets('a user with every permission sees all five tabs', (tester) async {
    await _pump(tester, _user(['leads.view', 'visits.manage', 'onboarding.view', 'dashboard.view']));
    for (final label in ['Leads', 'Visits', 'Home', 'Onboard', 'Profile']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('signed out users land on sign in', (tester) async {
    await _pump(tester, null);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('switching tabs opens that module', (tester) async {
    await _pump(tester, _user(['leads.view']));
    await tester.tap(find.text('Leads'));
    await tester.pumpAndSettle();
    expect(find.text('Gaurav Mehta'), findsOneWidget);
    expect(find.text('Rekha Choudhary'), findsOneWidget);
  });

  testWidgets('filter chips narrow the list', (tester) async {
    await _pump(tester, _user(['leads.view']));
    await tester.tap(find.text('Leads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow-up'));
    await tester.pumpAndSettle();
    expect(find.text('Rekha Choudhary'), findsOneWidget);
    expect(find.text('Gaurav Mehta'), findsNothing);
  });

  testWidgets('a Needs attention row opens Leads on its queue', (tester) async {
    // A phone-sized screen, so the row sits above the tab bar.
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _pump(tester, _user(['leads.view', 'dashboard.view']));
    await tester.tap(find.text('Visits overdue'));
    await tester.pumpAndSettle();
    expect(find.text('Visits overdue  ✕'), findsOneWidget);
    expect(find.text('Gaurav Mehta'), findsOneWidget);
    expect(find.text('Rekha Choudhary'), findsNothing);
  });
}
