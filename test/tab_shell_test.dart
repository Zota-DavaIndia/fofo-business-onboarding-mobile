import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/app/app.dart';
import 'package:fofo_onboarding/core/auth/session.dart';
import 'package:fofo_onboarding/core/auth/user.dart';
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
          final status = f.query['status'];
          return status == null ? all : all.where((l) => l.status == status).toList();
        }),
        dashboardProvider.overrideWith(
          (ref) async => Dashboard.fromJson({
            'by_status': {'ASSIGNED': 4},
          }),
        ),
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
    expect(
      find.text('Good morning, Arjun').evaluate().isNotEmpty ||
          find.text('Good afternoon, Arjun').evaluate().isNotEmpty ||
          find.text('Good evening, Arjun').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('4'), findsOneWidget);
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

  testWidgets('a Home card opens Leads on its list', (tester) async {
    await _pump(tester, _user(['leads.view', 'dashboard.view']));
    await tester.tap(find.text('New assignments'));
    await tester.pumpAndSettle();
    expect(find.text('Gaurav Mehta'), findsOneWidget);
    expect(find.text('Rekha Choudhary'), findsNothing);
  });
}
