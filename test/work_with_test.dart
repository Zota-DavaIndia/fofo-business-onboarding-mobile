import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/format.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/features/field/field.dart';
import 'package:fofo_onboarding/features/field/work_with_sheet.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('names join with commas and a final "and"', () {
    expect(joinNames([]), '');
    expect(joinNames(['Ravi']), 'Ravi');
    expect(joinNames(['Ravi', 'Amit']), 'Ravi and Amit');
    expect(joinNames(['Ravi', 'Amit', 'Neha']), 'Ravi, Amit and Neha');
  });

  test('a started day lists who the user is working with', () {
    final t = parseToday({
      'state': 'started',
      'day': {
        'id': 1,
        'date': '2026-11-22',
        'started_at': '2026-11-22T09:12:00+05:30',
        'distance_km': 0,
        'pings': 0,
        'with': [
          {'id': 7, 'name': 'Ravi Sharma', 'designation': 'Area manager'},
        ],
      },
    });
    expect(t.day!.workingWith.single.name, 'Ravi Sharma');
    expect(parseToday({'state': 'not_started'}).day, isNull);
  });

  testWidgets('the sheet returns the picked ids, or null when dismissed', (tester) async {
    const team = [
      Colleague(id: 7, name: 'Ravi Sharma', designation: 'Area manager', relation: Relation.manager),
      Colleague(id: 9, name: 'Amit Verma', designation: 'RCM', relation: Relation.peer),
    ];
    List<int>? result = [-1];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await pickWorkWith(context, team),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Area manager · Your manager'), findsOneWidget);
    expect(find.text('Start day'), findsOneWidget);
    await tester.tap(find.text('Amit Verma'));
    await tester.pump();
    await tester.tap(find.text('Start day with 1'));
    await tester.pumpAndSettle();
    expect(result, [9]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // tap the scrim
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
