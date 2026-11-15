import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/features/visits/visit.dart';

void main() {
  test('parses an open check-in', () {
    final v = Visit.fromJson({
      'id': 17,
      'kind': 'checkin',
      'status': 'checked_in',
      'lead': {'id': 29, 'lead_no': 'LD-000029', 'name': 'Kamlesh Sukhwal', 'latitude': 24.6, 'longitude': 73.7},
      'checked_in_at': '2026-11-14T06:52:05+00:00',
      'distance_m': 38,
      'radius_m': 500,
      'geo_verified': true,
    });
    expect(v.isOpen, isTrue);
    expect(v.isScheduled, isFalse);
    expect(v.leadId, 29);
    expect(v.leadLatitude, 24.6);
    expect(v.distanceM, 38);
    expect(v.geoVerified, isTrue);
    expect(v.when, v.checkedInAt);
  });

  test('a scheduled visit sorts by its plan', () {
    final v = Visit.fromJson({
      'id': 8,
      'kind': 'schedule',
      'status': 'scheduled',
      'lead': {'id': 23, 'name': 'Sunita Paliwal'},
      'scheduled_at': '2026-11-15T11:00:00+00:00',
    });
    expect(v.isScheduled, isTrue);
    expect(v.when, v.scheduledAt);
    expect(v.geoVerified, isFalse);
  });

  test('a check-in result is explained in words', () {
    String result(Map<String, dynamic> extra) => Visit.fromJson({
      'id': 1,
      'status': 'completed',
      'kind': 'checkin',
      'lead': {'id': 2, 'name': 'Asha'},
      ...extra,
    }).checkResult;

    expect(result({'geo_verified': true, 'geo_check': 'distance', 'distance_m': 40}), 'Verified at the shop · 40 m');
    expect(
      result({'geo_verified': true, 'geo_check': 'pincode', 'geo_pincode': '313001'}),
      "Verified in the lead's area (pincode 313001)",
    );
    expect(
      result({'geo_check': 'wrong_area', 'geo_pincode': '332205'}),
      "Checked in outside the lead's area (pincode 332205)",
    );
    expect(result({'geo_check': 'unconfirmed'}), 'Waiting for the office to confirm the site location');
    expect(
      result({'geo_check': 'distance', 'distance_m': 900, 'radius_m': 500}),
      'Checked in 900 m from the shop (must be within 500 m)',
    );
    expect(result({}), 'Location not usable: no GPS fix, a mock location or too inaccurate');
    expect(result({'distance_m': 700, 'radius_m': 500}), 'Checked in 700 m from the shop (must be within 500 m)');
  });
}
