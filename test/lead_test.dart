import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/widgets/widgets.dart';
import 'package:fofo_onboarding/features/leads/lead.dart';
import 'package:fofo_onboarding/features/leads/lead_status.dart';

void main() {
  test('parses a lead as the staging API sends it', () {
    final l = Lead.fromJson({
      'id': 29,
      'lead_no': 'LD-000029',
      'name': 'Kamlesh Sukhwal',
      'mobile': '7877851728',
      'model': 'FOFO',
      'pincode': '313001',
      'status': 'VISITED',
      'status_label': 'Visited',
      'source_label': 'Instagram',
      'shop_area_sqft': 4343,
      'last_call': {
        'summary': 'Can start next month',
        'disposition': 'interested',
        'created_at': '2026-11-14T01:12:48+00:00',
      },
      'onboarding': null,
      'allowed_actions': ['schedule_visit', 'checkin'],
      'enquiry_at': '2026-11-14T01:11:45+00:00',
    });
    expect(l.subtitle, 'LD-000029 · FOFO · 313001');
    expect(l.lastCall?.summary, 'Can start next month');
    expect(l.onboarding, isNull);
    expect(l.allowedActions, contains('checkin'));
    expect(l.enquiryAt, isNotNull);
  });

  test('timeline entries keep who and when', () {
    final a = Activity.fromJson({
      'id': 155,
      'type': 'status',
      'title': 'Visit Scheduled → Visited',
      'user': {'id': 6, 'name': 'RCM Udaipur'},
      'created_at': '2026-11-14T01:22:05+00:00',
    });
    expect(a.by, 'RCM Udaipur');
    expect(a.at, isNotNull);
  });

  test('status filters match the Home counts', () {
    expect(LeadFilter.assigned.query, {'status': 'ASSIGNED'});
    expect(LeadFilter.followUp.query, {'status': 'FOLLOW_UP'});
    expect(LeadFilter.closed.query, {'queue': 'closed'});
    expect(LeadFilter.all.query, isEmpty);
  });

  test('badge colours by status, neutral when unknown', () {
    expect(toneForStatus('QUALIFIED'), Tone.success);
    expect(toneForStatus('FOLLOW_UP'), Tone.warning);
    expect(toneForStatus('ASSIGNED'), Tone.accent);
    expect(toneForStatus('DROPPED'), Tone.neutral);
    expect(toneForStatus('SOMETHING_NEW'), Tone.neutral);
  });
}
