import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/widgets/skeleton.dart';
import 'package:material_ui/material_ui.dart';

Widget _app({required bool reduceMotion}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: const Scaffold(
      body: SkeletonScope(label: 'Loading leads', child: SkeletonRows(count: 3)),
    ),
  ),
);

final _fade = find.descendant(of: find.byType(SkeletonScope), matching: find.byType(FadeTransition));

void main() {
  testWidgets('reads as one loading label', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: false));
    expect(find.bySemanticsLabel('Loading leads'), findsOneWidget);
    expect(find.byType(Bone), findsWidgets);
  });

  testWidgets('pulses, and holds still with reduced motion', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 450));
    final moving = tester.widget<FadeTransition>(_fade).opacity.value;
    expect(moving, lessThan(1));

    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 450));
    final still = tester.widget<FadeTransition>(_fade).opacity.value;
    expect(still, 1);
  });

  testWidgets('a section label bar keeps its width in a list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ListView(children: const [SkeletonLabel(width: 56)])),
      ),
    );
    expect(tester.getSize(find.byType(Bone)).width, 56);
  });
}
