import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/app/app.dart';
import 'package:fofo_onboarding/core/auth/session.dart';
import 'package:fofo_onboarding/core/auth/user.dart';
import 'package:fofo_onboarding/features/home/dashboard.dart';
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
    expect(find.text('Leads assigned to you will show here, with search and filters.'), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });
}
