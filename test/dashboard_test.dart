import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/features/home/dashboard.dart';

void main() {
  test('reads by_status as a map', () {
    final d = Dashboard.fromJson({
      'by_status': {'ASSIGNED': 4, 'FOLLOW_UP': '2'},
    });
    expect(d.count('ASSIGNED'), 4);
    expect(d.count('FOLLOW_UP'), 2);
    expect(d.count('QUALIFIED'), 0);
  });

  test('reads by_status as a list', () {
    final d = Dashboard.fromJson({
      'by_status': [
        {'status': 'VISIT_SCHEDULED', 'count': 3},
      ],
    });
    expect(d.count('VISIT_SCHEDULED'), 3);
  });

  test('tolerates an unexpected shape', () {
    expect(Dashboard.fromJson(null).byStatus, isEmpty);
    expect(Dashboard.fromJson([1, 2]).byStatus, isEmpty);
  });
}
