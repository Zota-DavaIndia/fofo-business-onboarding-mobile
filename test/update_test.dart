import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/update/update.dart';
import 'package:fofo_onboarding/features/update/update_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('versions compare by number, not text', () {
    expect(compareVersions('1.10.0', '1.9.2'), 1);
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    expect(compareVersions('0.9.9', '1.0.0'), -1);
  });

  test('a release is newer by version, or by build at the same version', () {
    const r = Release(version: '1.1.0', build: 3, apkUrl: 'x');
    expect(isNewer(r, current: '1.0.0', currentBuild: 1), isTrue);
    expect(isNewer(r, current: '1.1.0', currentBuild: 3), isFalse);
    expect(isNewer(r, current: '1.1.0', currentBuild: 2), isTrue);
    expect(isNewer(r, current: '1.1.0', currentBuild: 0), isFalse); // local builds have no build number
    expect(isNewer(r, current: '1.2.0', currentBuild: 9), isFalse);
  });

  test('release reads version.json from the release workflow', () {
    final r = Release.fromJson({
      'version': '1.1.0',
      'build': 2,
      'apk_url': 'https://example.test/app.apk',
      'sha256': 'ab',
      'size': 60817408,
    });
    expect(r.sizeLabel, '58 MB');
    expect(r.build, 2);
  });

  test('version.json is read from the text GitHub serves (application/octet-stream)', () {
    const text = '{"version": "1.1.3", "build": 5, "apk_url": "https://example.test/app.apk", "size": 100}';
    expect(releaseFrom(text)?.version, '1.1.3');
    expect(releaseFrom(text.codeUnits)?.build, 5);
    expect(releaseFrom({'version': '1.1.3', 'apk_url': 'x'})?.version, '1.1.3');
    expect(releaseFrom('<html>Not Found</html>'), isNull);
    expect(releaseFrom('{"message": "x"}'), isNull);
    expect(releaseFrom(null), isNull);
  });

  testWidgets('the version row shows Update, then the download percentage, then Install', (tester) async {
    const r = Release(version: '9.0.0', build: 1, apkUrl: 'https://example.com/app.apk');
    Future<void> pump() => tester.pumpWidget(
      ProviderScope(
        overrides: [availableUpdateProvider.overrideWith((ref) async => r)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AppVersionRow()),
        ),
      ),
    );
    addTearDown(() {
      Updater.progress.value = null;
      Updater.ready.value = null;
    });
    await pump();
    await tester.pump();
    expect(find.text('App version · 9.0.0 is available'), findsOneWidget);
    expect(find.text('Update ›'), findsOneWidget);

    Updater.progress.value = 0.45;
    await tester.pump();
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('App version · downloading 9.0.0'), findsOneWidget);

    Updater.progress.value = null;
    Updater.ready.value = (release: r, path: '/tmp/app.apk');
    await tester.pump();
    expect(find.text('Install ›'), findsOneWidget);
    expect(find.text('App version · 9.0.0 downloaded'), findsOneWidget);
  });

  testWidgets('tapping the ring stops the download', (tester) async {
    var stopped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DownloadProgress(0.45, onStop: () => stopped++)),
      ),
    );
    expect(find.text('45%'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Stop download, 45 percent done'));
    expect(stopped, 1);
  });

  testWidgets('the watcher offers each new release once and checks again on its interval', (tester) async {
    var latest = '9.0.0';
    var checks = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          availableUpdateProvider.overrideWith((ref) async {
            checks++;
            return Release(version: latest, build: 1, apkUrl: 'https://example.com/app.apk');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          navigatorKey: nav,
          builder: (context, child) => UpdateWatcher(
            navigatorKey: nav,
            every: const Duration(minutes: 1),
            fetch: (_) async => '/tmp/app.apk',
            child: child!,
          ),
          home: const Text('the app'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(find.text('Version 9.0.0'), findsNothing);
    expect(find.text('9.0.0'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget); // downloaded before the screen opened

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);

    // Same release on the next check: not offered again.
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('9.0.0'), findsNothing);

    // A newer one is.
    latest = '9.1.0';
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(checks, 3);
    expect(find.text('9.1.0'), findsOneWidget);
  });
}
