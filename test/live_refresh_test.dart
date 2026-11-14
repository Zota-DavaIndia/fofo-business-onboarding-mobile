import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/auth/session.dart';
import 'package:fofo_onboarding/core/auth/user.dart';
import 'package:fofo_onboarding/core/sync/live_refresh.dart';
import 'package:material_ui/material_ui.dart';

class _FakeSession extends SessionController {
  _FakeSession(this.user);

  final AppUser? user;

  @override
  Future<AppUser?> build() async => user;
}

final _user = AppUser.fromJson({'id': 1, 'name': 'A', 'email': 'a@example.com', 'role': 'rcm', 'permissions': []});

Widget _app(AppUser? user, {Widget? child}) => ProviderScope(
  overrides: [sessionProvider.overrideWith(() => _FakeSession(user))],
  child: MaterialApp(
    home: LiveRefresh(
      interval: const Duration(seconds: 10),
      child: child ?? Consumer(builder: (_, ref, _) => Text('${ref.watch(liveSignalProvider(LiveTopic.dashboard))}')),
    ),
  ),
);

void main() {
  test('server events map to the data they change', () {
    expect(topicsForEvent('lead.assigned'), containsAll([LiveTopic.leads, LiveTopic.dashboard]));
    expect(topicsForEvent('payment.verified'), containsAll([LiveTopic.onboarding, LiveTopic.dashboard]));
    expect(topicsForEvent('visit.reminder'), contains(LiveTopic.visits));
    expect(topicsForEvent('something.new'), {LiveTopic.alerts});
  });

  testWidgets('refreshes on the timer while signed in', (tester) async {
    await tester.pumpWidget(_app(_user));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('does nothing when signed out', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pump(const Duration(seconds: 25));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('refreshes when the app returns after being away', (tester) async {
    await tester.pumpWidget(_app(_user));
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 40));
    expect(find.text('0'), findsOneWidget, reason: 'no timer while in the background');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a server event refreshes its topics', (tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      _app(
        _user,
        child: Consumer(
          builder: (_, ref, _) {
            captured = ref;
            return Text('${ref.watch(liveSignalProvider(LiveTopic.onboarding))}');
          },
        ),
      ),
    );
    handleServerEvent(captured, {'type': 'payment.verified'});
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
