import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/features/tracking/track.dart';
import 'package:fofo_onboarding/features/tracking/track_screen.dart';
import 'package:fofo_onboarding/features/tracking/track_session.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> _json({bool signInAgain = false}) => {
  'account_type': 'enquirer',
  'name': 'Ravi Shankar',
  'reference': 'LD-000001',
  'partner_no': null,
  'headline': 'Call from our team: we will call you shortly.',
  'done': 1,
  'total': 4,
  'area_manager': {'name': 'Arjun Kumar', 'mobile': '9845000000'},
  'support': {'phone': '+91 80 4000 0000'},
  'sign_in_again': signInAgain,
  'steps': [
    {
      'key': 'enquiry',
      'title': 'Enquiry received',
      'who': 'Dava India',
      'state': 'done',
      'detail': 'Reference LD-000001.',
      'date': '2026-10-17T10:01:00+05:30',
    },
    {'key': 'call', 'title': 'Call from our team', 'state': 'waiting', 'detail': 'Soon.', 'date': null},
    {'key': 'x', 'title': 'Fix your documents', 'state': 'rejected', 'detail': 'PAN photo is blurred.'},
    {'key': 'y', 'title': 'Something new', 'state': 'brand_new_state'},
  ],
};

class _Fake extends TrackSession {
  _Fake(this.track);
  final Track track;
  @override
  Future<Track?> build() async => track;
  @override
  Future<void> refresh() async {}
}

Future<void> _pump(WidgetTester tester, Track track) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [trackSessionProvider.overrideWith(() => _Fake(track))],
      child: MaterialApp(theme: AppTheme.light(), home: const TrackScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('parses the journey and tolerates unknown states', () {
    final t = Track.fromJson(_json());
    expect(t.reference, 'LD-000001');
    expect(t.progress, 0.25);
    expect(t.steps.map((s) => s.state), [
      JourneyState.done,
      JourneyState.waiting,
      JourneyState.rejected,
      JourneyState.upcoming,
    ]);
    expect(t.steps.first.date, isNotNull);
    expect(t.areaManager?.phone, '9845000000');
  });

  test('partner number replaces the lead reference once approved', () {
    final t = Track.fromJson({..._json(), 'partner_no': 'PT-000041'});
    expect(t.reference, 'PT-000041');
  });

  test('dates are written the same way everywhere', () {
    expect(formatDate(DateTime(2026, 10, 17, 15, 1)), '17 Oct 2026, 3:01 pm');
    expect(formatDate(DateTime(2026, 1, 2, 0, 5)), '2 Jan 2026, 12:05 am');
  });

  testWidgets('draws one row per step with its badge', (tester) async {
    await _pump(tester, Track.fromJson(_json()));
    expect(find.text('Ravi Shankar'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    for (final title in ['Enquiry received', 'Call from our team', 'Fix your documents', 'Something new']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    for (final badge in ['Completed', 'In progress', 'Needs correction', 'Upcoming']) {
      expect(find.text(badge), findsOneWidget, reason: badge);
    }
    expect(find.text('Need help?'), findsOneWidget);
  });

  testWidgets('asks to sign in again after approval', (tester) async {
    await _pump(tester, Track.fromJson(_json(signInAgain: true)));
    expect(find.text('Your application is approved'), findsOneWidget);
    expect(find.text('Sign in again'), findsWidgets);
    expect(find.text('Enquiry received'), findsNothing);
  });
}
