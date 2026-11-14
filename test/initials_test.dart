import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, String name) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Center(child: Initials(name)),
  ),
);

void main() {
  testWidgets('initials skip separators and use two words', (tester) async {
    await _pump(tester, 'Demo · Store details rejected');
    expect(find.text('DS'), findsOneWidget);
    await _pump(tester, 'kavita sharma');
    expect(find.text('KS'), findsOneWidget);
    await _pump(tester, 'Arjun');
    expect(find.text('A'), findsOneWidget);
  });
}
