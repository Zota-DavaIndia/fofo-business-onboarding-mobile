import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/icons/app_icon.dart';
import 'package:fofo_onboarding/core/theme/app_theme.dart';
import 'package:fofo_onboarding/core/theme/tokens.dart';
import 'package:fofo_onboarding/features/home/stat_card.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('text sits on the bottom edge when a neighbour wraps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'New assignments waiting for a first visit',
                      value: '4',
                      icon: AppIcons.leads,
                      tone: StatTone.clay,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(label: 'Visits', value: '3', icon: AppIcons.visit, tone: StatTone.olive),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final cards = tester.getSize(find.byType(StatCard).first).height;
    expect(tester.getSize(find.byType(StatCard).last).height, cards);
    expect(tester.getBottomLeft(find.text('Visits')).dy, tester.getBottomLeft(find.textContaining('first visit')).dy);
    expect(tester.getTopLeft(find.text('3')).dy, greaterThan(tester.getTopLeft(find.text('4')).dy));
  });
}
