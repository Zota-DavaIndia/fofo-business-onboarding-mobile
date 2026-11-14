import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/widgets/date_sheet.dart';
import 'package:fofo_onboarding/core/widgets/form.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('a new time starts in working hours', () {
    expect(suggestedSlot(DateTime(2026, 11, 16, 10, 7)), DateTime(2026, 11, 16, 11, 10));
    // too early: 11 am today
    expect(suggestedSlot(DateTime(2026, 11, 16, 3, 22)), DateTime(2026, 11, 16, 11));
    // evening: 11 am tomorrow
    expect(suggestedSlot(DateTime(2026, 11, 16, 20, 30)), DateTime(2026, 11, 17, 11));
  });

  testWidgets('the date sheet picks a day and keeps days outside the range disabled', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showDateSheet(
              context,
              initial: DateTime(2026, 11, 15),
              first: DateTime(2026, 11, 15),
              last: DateTime(2026, 12, 31),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.text('10')); // before the first day: nothing happens
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);

    await tester.tap(find.text('24'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 12, 24));
  });
}
