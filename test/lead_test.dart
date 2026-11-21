import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/format.dart';
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

  test('quick filters and the filter sheet map to the CRM query', () {
    expect(LeadFilter.todayCalls.query, {'queue': 'today_calls'});
    expect(LeadFilter.fresh.query, {'queue': 'new'});
    expect(LeadFilter.archived.query, {'queue': 'closed'});
    expect(LeadFilter.all.query, isEmpty);
    expect(LeadTab.opportunities.query, 'opportunity');
    expect(LeadRefine(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 21), status: 'ASSIGNED').query, {
      'from': '2026-11-01',
      'to': '2026-11-21',
      'status': 'ASSIGNED',
    });
    expect(const LeadRefine().isEmpty, isTrue);
  });

  test('list fields: New badge, progress and last update', () {
    final l = Lead.fromJson({
      'id': 3,
      'lead_no': 'LD-000003',
      'name': 'Kapil Jain',
      'status': 'ASSIGNED',
      'status_label': 'Assigned',
      'is_new': true,
      'progress': 40,
      'last_update': {
        'by': {'id': 3, 'name': 'Call Centre Agent'},
        'at': '2026-11-21T05:00:00+00:00',
      },
      'onboarding': {'id': 9, 'onboarding_no': 'OB-000009', 'status_label': 'Store live', 'progress': 100},
    });
    expect(l.isNew, isTrue);
    expect(l.progress, 40);
    expect(l.lastUpdateBy, 'Call Centre Agent');
    expect(l.lastUpdateAt, isNotNull);
    expect(l.onboarding!.statusLabel, 'Store live');
    expect(l.onboarding!.progress, 100);
  });

  test('time ago reads like a person would say it', () {
    final now = DateTime(2026, 11, 21, 15);
    expect(formatAgo(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
    expect(formatAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(formatAgo(DateTime(2026, 11, 21, 9), now: now), '6h ago');
    expect(formatAgo(DateTime(2026, 11, 20, 22), now: now), 'Yesterday');
    expect(formatAgo(DateTime(2026, 11, 17, 10), now: now), '17 Nov');
  });

  test('badge colours by status, neutral when unknown', () {
    expect(toneForStatus('QUALIFIED'), Tone.success);
    expect(toneForStatus('FOLLOW_UP'), Tone.warning);
    expect(toneForStatus('ASSIGNED'), Tone.accent);
    expect(toneForStatus('DROPPED'), Tone.neutral);
    expect(toneForStatus('SOMETHING_NEW'), Tone.neutral);
  });

  test('opportunity badges: red when sent back, green once live', () {
    expect(toneForOnboarding('PAYMENT_REJECTED'), Tone.danger);
    expect(toneForOnboarding('STORE_ACTIVE'), Tone.success);
    expect(toneForOnboarding('DL_SUBMITTED'), Tone.info);
    expect(toneForOnboarding(null), Tone.info);
  });

  test('reads campaign, UTM, next moves and allowed actions', () {
    final l = Lead.fromJson({
      'id': 18,
      'lead_no': 'LD-000018',
      'name': 'Gaurav Mehta',
      'status': 'ASSIGNED',
      'source': 'website',
      'campaign': 'Google Ads',
      'utm': {'source': 'google', 'medium': null, 'campaign': 'franchise'},
      'consent': true,
      'timeline': 'within 2 months',
      'next_statuses': ['VISIT_SCHEDULED', 'VISITED', 'DROPPED'],
      'allowed_actions': ['schedule_visit', 'checkin'],
      'rcm': {'id': 6, 'name': 'RCM Udaipur'},
      'latitude': 24.58,
      'longitude': 73.71,
    });
    expect(l.utmSource, 'google');
    expect(l.utmMedium, isNull);
    expect(l.utmCampaign, 'franchise');
    expect(l.consent, isTrue);
    expect(l.nextStatuses, hasLength(3));
    expect(l.allows(LeadAction.checkin), isTrue);
    expect(l.allows(LeadAction.reassign), isFalse);
    expect(l.assignedTo, 'RCM Udaipur');
    expect(l.hasLocation, isTrue);
  });

  test('reads flat UTM keys too', () {
    final l = Lead.fromJson({'id': 1, 'name': 'A', 'utm_source': 'meta'});
    expect(l.utmSource, 'meta');
    expect(l.hasLocation, isFalse);
  });

  test('reads the proposed store location', () {
    final l = Lead.fromJson({
      'id': 1,
      'name': 'A',
      'store_location': {
        'address': 'Shop 4, Hiran Magri',
        'landmark': 'City Hospital',
        'pincode': '313002',
        'latitude': 24.57,
      },
    });
    expect(l.storeLocation?.summary, 'Shop 4, Hiran Magri · near City Hospital · 313002');
    expect(l.storeLocation?.latitude, 24.57);
  });
}
