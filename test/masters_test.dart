import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/masters.dart';

void main() {
  test('client ids are distinct UUID v4 values', () {
    final ids = {for (var i = 0; i < 200; i++) newClientId()};
    expect(ids, hasLength(200));
    final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(ids.every(v4.hasMatch), isTrue);
  });

  test('dates go out with the phone offset', () {
    final s = isoWithOffset(DateTime(2026, 11, 16, 11, 5));
    expect(s, startsWith('2026-11-16T11:05:00'));
    expect(RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s), isTrue);
    expect(isoDay(DateTime(2026, 1, 3)), '2026-01-03');
  });

  test('status master parses moves and reasons', () {
    final s = StatusDef.fromJson({
      'code': 'DROPPED',
      'label': 'Dropped',
      'is_exit': true,
      'next': <String>[],
      'reasons': ['Partner withdrew', 'Other'],
    });
    expect(s.isExit, isTrue);
    expect(s.reasons, ['Partner withdrew', 'Other']);
    final v = StatusDef.fromJson({
      'code': 'VISITED',
      'label': 'Visited',
      'next': ['QUALIFIED', 'FOLLOW_UP'],
    });
    expect(v.isExit, isFalse);
    expect(v.next, ['QUALIFIED', 'FOLLOW_UP']);
  });

  test('app config falls back when fields are missing', () {
    final c = AppConfig.fromJson({
      'geofence_radius_m': 500,
      'upload': {'max_mb': 8},
    });
    expect(c.geofenceRadiusM, 500);
    expect(c.maxGpsAccuracyM, 50);
    expect(c.uploadMaxMb, 8);
  });
}
