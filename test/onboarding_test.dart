import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/features/onboarding/onboarding.dart';
import 'package:fofo_onboarding/features/tracking/partner.dart';

Map<String, dynamic> _rejected() => {
  'id': 7,
  'onboarding_no': 'PT-000007',
  'lead_id': 36,
  'lead': {'id': 36, 'name': 'Demo · Store details rejected', 'mobile': '9000000103', 'model': 'FOFO'},
  'model': 'FOFO',
  'status': 'BASIC_REJECTED',
  'status_label': 'Basic Rejected',
  'waiting_for': 'field',
  'steps': [
    {'key': 'partner_verification', 'label': 'Partner verified', 'state': 'approved'},
    {
      'key': 'store_basics',
      'label': 'Store basics',
      'state': 'rejected',
      'rejection_reason': 'The shop-front photo is not clear.',
      'rejected_fields': ['storefront'],
      'reviewed_by': {'id': 3, 'name': 'Onboarding Ops'},
    },
    {'key': 'owner_documents', 'state': 'locked'},
    {'key': 'payment', 'state': 'locked'},
    {'key': 'drug_licence', 'state': 'locked'},
  ],
  'store': {
    'store_name': 'Dava India Koramangala 103',
    'store_pan': 'ENQDM0103F',
    'carpet_area_sqft': 320,
    'latitude': 12.956,
  },
  'fee': {
    'fee_set': true,
    'amount': 300000,
    'gst': 54000,
    'total': 354000,
    'paid_verified': 0,
    'paid_pending': 0,
    'balance': 354000,
    'payment_required': true,
  },
  'payments': [
    {
      'id': 1,
      'utr': 'SBIN123456',
      'payment_date': '2026-11-13',
      'amount': 100000,
      'mode': 'NEFT',
      'state': 'submitted',
      'editable': true,
    },
  ],
  'documents': [
    {'id': 4, 'type': 'owner_pan', 'status': 'rejected', 'remarks': 'Blurred'},
  ],
};

void main() {
  group('franchise fee figures come only from the server', () {
    Map<String, dynamic> base() => {
      'fee_set': true,
      'fee': 300000,
      'gst': 54000,
      'total': 354000,
      'paid_verified': 100000,
      'paid_pending': 50000,
      'balance': 254000,
      'payment_required': true,
    };

    test('real figures are read as sent', () {
      final f = Fee.fromJson(base());
      expect([f.total, f.balance, f.paidVerified, f.paidPending], [354000, 254000, 100000, 50000]);
      expect(f.toReport, 204000);
    });

    test('a missing figure is an error, never a zero', () {
      for (final key in ['balance', 'total', 'paid_verified', 'paid_pending', 'fee_set', 'payment_required']) {
        expect(() => Fee.fromJson(base()..remove(key)), throwsFormatException, reason: key);
        expect(Fee.tryParse(base()..remove(key)), isNull, reason: key);
      }
    });

    test('a fee HO has not set has no amounts and nothing to report', () {
      final f = Fee.fromJson({
        'fee_set': false,
        'fee': null,
        'gst': null,
        'total': null,
        'balance': null,
        'paid_verified': 0,
        'paid_pending': 0,
        'payment_required': true,
      });
      expect([f.set, f.total, f.balance, f.toReport], [false, null, null, null]);
    });
  });

  test('parses an onboarding and finds the step to fix', () {
    final o = Onboarding.fromJson(_rejected());
    expect(o.number, 'PT-000007');
    expect(o.name, 'Demo · Store details rejected');
    expect(o.mobile, '9000000103');
    expect(o.steps, hasLength(5));
    expect(o.done, 1);
    final next = o.nextStep!;
    expect(next.key, StepKey.storeBasics);
    expect(next.state, StepStatus.rejected);
    expect(next.rejectedFields, ['storefront']);
    expect(next.reviewedBy, 'Onboarding Ops');
    expect(o.store.areaSqft, 320);
    expect(o.fee!.balance, 354000);
    expect(o.payments.single.editable, isTrue);
    expect(o.payments.single.date, DateTime(2026, 11, 13).toLocal());
    expect(o.documents.single.rejected, isTrue);
    expect(o.waitingLabel, isNull);
    expect(o.isLive, isFalse);
  });

  test('unknown step keys are skipped', () {
    final j = _rejected()
      ..['steps'] = [
        {'key': 'agreement', 'state': 'open'},
        {'key': 'payment', 'state': 'open'},
      ];
    final o = Onboarding.fromJson(j);
    expect(o.steps.map((s) => s.key), [StepKey.payment]);
  });

  test('a live store and a store waiting on finance', () {
    final live = Onboarding.fromJson({..._rejected(), 'status': 'STORE_ACTIVE', 'store_code': 'DI-BLR-104'});
    expect(live.isLive, isTrue);
    final waiting = Onboarding.fromJson({..._rejected(), 'waiting_for': 'finance'});
    expect(waiting.waitingLabel, 'Finance');
  });

  test('rupees use Indian grouping', () {
    expect(rupees(354000), '₹3,54,000');
    expect(rupees(999), '₹999');
    expect(rupees(12345678), '₹1,23,45,678');
    expect(rupees(0), '₹0');
  });

  test("the customer's turn follows open_step unless Dava India has it", () {
    final mine = PartnerMe.fromJson({
      'partner_no': 'PT-000007',
      'status': 'BASIC_REJECTED',
      'open_step': 'store_basics',
      'waiting_for': null,
      'rejection_reason': 'Photo not clear',
      'rejected_fields': ['storefront'],
      'payment': {
        'fee_set': true,
        'fee': 300000,
        'gst': 54000,
        'amount_due': 354000,
        'balance': 354000,
        'paid_verified': 0,
        'paid_pending': 0,
        'payment_required': true,
      },
    });
    expect(mine.myTurn, StepKey.storeBasics);
    expect(mine.fixing, isTrue);
    expect(mine.payment!.total, 354000);

    final theirs = PartnerMe.fromJson({
      'partner_no': 'PT-1',
      'status': 'DL_SUBMITTED',
      'open_step': 'drug_licence',
      'waiting_for': 'compliance',
    });
    expect(theirs.myTurn, isNull);

    final verify = PartnerMe.fromJson({
      'partner_no': 'PT-2',
      'status': 'ACCOUNT_CREATED',
      'open_step': 'partner_verification',
    });
    expect(verify.myTurn, isNull);
  });
}
