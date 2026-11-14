import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/widgets/toast.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows one toast at a time, announced, and hides on its own', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showToast(context, 'Saved', kind: ToastKind.success),
                  child: const Text('a'),
                ),
                TextButton(onPressed: () => showToast(context, 'Second'), child: const Text('b')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsOneWidget);
    final live = tester.widgetList<Semantics>(find.ancestor(of: find.text('Saved'), matching: find.byType(Semantics)));
    expect(live.any((s) => s.properties.liveRegion == true && s.properties.label == 'Saved'), isTrue);

    await tester.tap(find.text('b'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Second'), findsNothing);
  });
}
