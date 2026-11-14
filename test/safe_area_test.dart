import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/theme/tokens.dart';
import 'package:fofo_onboarding/core/widgets/form.dart';
import 'package:fofo_onboarding/core/widgets/page.dart';
import 'package:fofo_onboarding/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

// System bar heights in logical pixels.
const _android = {'gesture bar': 24.0, '3-button bar': 48.0};
const _iosHomeIndicator = 34.0;

Future<double> _pump(WidgetTester tester, double inset, Widget child) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3
    ..padding = FakeViewPadding(bottom: inset * 3)
    ..viewPadding = FakeViewPadding(bottom: inset * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
  await tester.pumpAndSettle();
  return tester.getSize(find.byType(MaterialApp)).height;
}

Widget _checkOut() => PageBody(
  bottom: ActionBar(children: [AppButton(label: 'Check out', onPressed: () {})]),
  children: const [Text('Outcome')],
);

Widget _sheetLauncher() => Scaffold(
  body: Builder(
    builder: (context) => TextButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => SheetBody(
          title: 'Code',
          footer: AppButton(label: 'Copy', onPressed: () {}),
          children: const [Text('123456')],
        ),
      ),
      child: const Text('open'),
    ),
  ),
);

void main() {
  for (final MapEntry(key: name, value: inset) in _android.entries) {
    testWidgets('Android $name: the action bar button keeps a gap above the bar', (tester) async {
      final screen = await _pump(tester, inset, _checkOut());
      final gap = screen - inset - tester.getRect(find.byType(AppButton)).bottom;
      // The 3-button bar is often painted solid, so the inset alone would look like touching it.
      expect(gap, greaterThanOrEqualTo(Space.lg));
      // The bar's own colour still runs to the screen edge behind the system bar.
      expect(tester.getRect(find.byType(ActionBar)).bottom, screen);
    });

    testWidgets('Android $name: a sheet footer keeps a gap above the bar', (tester) async {
      final screen = await _pump(tester, inset, _sheetLauncher());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final gap = screen - inset - tester.getRect(find.byType(AppButton)).bottom;
      expect(gap, greaterThanOrEqualTo(Space.lg));
    });
  }

  testWidgets(
    'iOS: the action bar button sits just above the home indicator',
    (tester) async {
      final screen = await _pump(tester, _iosHomeIndicator, _checkOut());
      final bottom = tester.getRect(find.byType(AppButton)).bottom;
      // The indicator strip is see-through, so the inset is the gap; no extra space stacked on it.
      expect(bottom, screen - _iosHomeIndicator);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'iOS without a home indicator still leaves a gap',
    (tester) async {
      final screen = await _pump(tester, 0, _checkOut());
      expect(screen - tester.getRect(find.byType(AppButton)).bottom, Space.lg);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
