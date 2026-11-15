import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';
import '../leads/lead.dart' show Activity, date, str;

DateTime? _date(Object? v) => date(v);

double? _num(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

/// The five steps, in order. Keys match the server's `steps[].key`.
enum StepKey {
  partnerVerification('partner_verification', 'Verify partner'),
  storeBasics('store_basics', 'Store details'),
  ownerDocuments('owner_documents', 'Owner, KYC and licences'),
  payment('payment', 'Franchise fee'),
  drugLicence('drug_licence', 'Drug licence');

  const StepKey(this.key, this.title);

  final String key;
  final String title;

  static StepKey? of(String? key) => values.where((s) => s.key == key).firstOrNull;
}

/// Where a step stands: `locked | open | submitted | approved | rejected | skipped`.
enum StepStatus {
  locked,
  open,
  submitted,
  approved,
  rejected,
  skipped;

  static StepStatus of(String? v) => values.where((s) => s.name == v).firstOrNull ?? locked;

  /// The field user can fill or fix it.
  bool get actionable => this == open || this == rejected;
}

class OnboardingStep {
  const OnboardingStep({
    required this.key,
    required this.label,
    required this.state,
    this.rejectionReason,
    this.rejectedFields = const [],
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final StepKey key;
  final String label;
  final StepStatus state;
  final String? rejectionReason;
  final List<String> rejectedFields;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  static OnboardingStep? fromJson(Map<String, dynamic> j) {
    final key = StepKey.of(j['key'] as String?);
    if (key == null) return null;
    return OnboardingStep(
      key: key,
      label: str(j['label']) ?? key.title,
      state: StepStatus.of(j['state'] as String?),
      rejectionReason: str(j['rejection_reason']),
      rejectedFields: [for (final f in (j['rejected_fields'] as List? ?? const [])) '$f'],
      submittedAt: date(j['submitted_at']),
      reviewedAt: date(j['reviewed_at']),
      reviewedBy: j['reviewed_by'] is Map ? str((j['reviewed_by'] as Map)['name']) : null,
    );
  }
}

class StoreDetails {
  const StoreDetails({
    this.name,
    this.format,
    this.pan,
    this.gstin,
    this.areaSqft,
    this.latitude,
    this.longitude,
    this.address,
    this.pincode,
    this.city,
    this.state,
    this.storefrontUrl,
  });

  final String? name;
  final String? format;
  final String? pan;
  final String? gstin;
  final int? areaSqft;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? pincode;
  final String? city;
  final String? state;
  final String? storefrontUrl;

  factory StoreDetails.fromJson(Map<String, dynamic> j) => StoreDetails(
    name: str(j['store_name'] ?? j['name']),
    format: str(j['store_format'] ?? j['format']),
    pan: str(j['store_pan'] ?? j['pan']),
    gstin: str(j['gstin']),
    areaSqft: _num(j['carpet_area_sqft'])?.toInt(),
    latitude: _num(j['latitude']),
    longitude: _num(j['longitude']),
    address: str(j['address']),
    pincode: str(j['pincode']),
    city: str(j['city']),
    state: str(j['state']),
    storefrontUrl: str(j['storefront_url']),
  );
}

class OwnerDetails {
  const OwnerDetails({
    this.name,
    this.mobile,
    this.email,
    this.address,
    this.pan,
    this.aadhaarMasked,
    this.pharmacistName,
    this.pharmacistRegNo,
  });

  final String? name;
  final String? mobile;
  final String? email;
  final String? address;
  final String? pan;
  final String? aadhaarMasked;
  final String? pharmacistName;
  final String? pharmacistRegNo;

  factory OwnerDetails.fromJson(Map<String, dynamic> j) => OwnerDetails(
    name: str(j['owner_name'] ?? j['name']),
    mobile: str(j['owner_mobile'] ?? j['mobile']),
    email: str(j['owner_email'] ?? j['email']),
    address: str(j['owner_address']),
    pan: str(j['owner_pan'] ?? j['pan']),
    aadhaarMasked: str(j['aadhaar_masked'] ?? j['aadhaar']),
    pharmacistName: str(j['pharmacist_name']),
    pharmacistRegNo: str(j['pharmacist_reg_no']),
  );
}

/// One uploaded document on an onboarding.
class OnboardingDoc {
  const OnboardingDoc({
    required this.id,
    required this.type,
    this.label,
    this.status,
    this.remarks,
    this.number,
    this.expiryDate,
    this.fileUrl,
  });

  final int id;
  final String type;
  final String? label;
  final String? status;
  final String? remarks;
  final String? number;
  final DateTime? expiryDate;
  final String? fileUrl;

  bool get approved => status == 'approved';
  bool get rejected => status == 'rejected';

  factory OnboardingDoc.fromJson(Map<String, dynamic> j) => OnboardingDoc(
    id: (j['id'] as num?)?.toInt() ?? 0,
    type: '${j['type'] ?? ''}',
    label: str(j['label']),
    status: str(j['status'] ?? j['state']),
    remarks: str(j['remarks'] ?? j['rejection_reason']),
    number: str(j['number']),
    expiryDate: date(j['expiry_date']),
    fileUrl: str(j['file_url']),
  );
}

/// The franchise fee exactly as the server reports it, from the onboarding and its payment records. Nothing
/// is assumed: while HO hasn't set the fee, [set] is false and the amounts are null; a figure the server
/// leaves out makes [Fee.fromJson] throw, so a screen shows "couldn't load" rather than a made-up number.
class Fee {
  const Fee({
    required this.set,
    required this.required,
    required this.paidVerified,
    required this.paidPending,
    this.amount,
    this.gst,
    this.total,
    this.balance,
    this.beneficiary,
    this.accountNo,
    this.ifsc,
    this.bank,
  });

  final bool set;
  final bool required;
  final double paidVerified;
  final double paidPending;
  final double? amount;
  final double? gst;
  final double? total;
  final double? balance;
  final String? beneficiary;
  final String? accountNo;
  final String? ifsc;
  final String? bank;

  /// Left to pay less what finance is already checking: what can still be reported. Null until the fee is set.
  double? get toReport => set ? (balance! - paidPending).clamp(0, double.infinity).toDouble() : null;

  factory Fee.fromJson(Map<String, dynamic> j) {
    double need(String key) => _num(j[key]) ?? (throw FormatException('The franchise fee came without "$key".'));
    final set = j['fee_set'];
    final required = j['payment_required'];
    if (set is! bool || required is! bool) {
      throw const FormatException('The franchise fee came without fee_set or payment_required.');
    }
    return Fee(
      set: set,
      required: required,
      paidVerified: need('paid_verified'),
      paidPending: need('paid_pending'),
      amount: set ? need('amount') : null,
      gst: set ? need('gst') : null,
      total: set ? need('total') : null,
      balance: set ? need('balance') : null,
      beneficiary: str(j['beneficiary']),
      accountNo: str(j['account_no']),
      ifsc: str(j['ifsc']),
      bank: str(j['bank']),
    );
  }

  /// The fee inside a larger response, or null when it is missing or incomplete (the screen then says so).
  static Fee? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    try {
      return Fee.fromJson(j);
    } on FormatException {
      return null;
    }
  }
}

/// One offline transfer of the franchise fee.
class Payment {
  const Payment({
    required this.id,
    required this.state,
    this.utr,
    this.date,
    this.amount = 0,
    this.mode,
    this.payerName,
    this.payerAccountMasked,
    this.payerBank,
    this.rejectionReason,
    this.editable = false,
    this.receiptNo,
  });

  final int id;
  final String state;
  final String? utr;
  final DateTime? date;
  final double amount;
  final String? mode;
  final String? payerName;
  final String? payerAccountMasked;
  final String? payerBank;
  final String? rejectionReason;
  final bool editable;
  final String? receiptNo;

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    state: '${j['state'] ?? 'submitted'}',
    utr: str(j['utr']),
    date: _date(j['payment_date']),
    amount: _num(j['amount'] ?? j['payment_amount']) ?? 0,
    mode: str(j['mode'] ?? j['payment_mode']),
    payerName: str(j['payer_name']),
    payerAccountMasked: str(j['payer_account_masked']),
    payerBank: str(j['payer_bank']),
    rejectionReason: str(j['rejection_reason']),
    editable: j['editable'] == true,
    receiptNo: str(j['receipt_no']),
  );
}

class DrugLicence {
  const DrugLicence({this.number, this.form, this.validTill, this.fileUrl, this.state});

  final String? number;
  final String? form;
  final DateTime? validTill;
  final String? fileUrl;
  final String? state;

  bool get isEmpty => number == null;

  factory DrugLicence.fromJson(Map<String, dynamic> j) => DrugLicence(
    number: str(j['dl_number'] ?? j['number']),
    form: str(j['dl_form'] ?? j['form']),
    validTill: date(j['dl_valid_till'] ?? j['valid_till']),
    fileUrl: str(j['file_url']),
    state: str(j['state']),
  );
}

/// An onboarding (the partner record, PT- number) from `/onboardings`.
class Onboarding {
  const Onboarding({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
    required this.statusLabel,
    this.leadId,
    this.mobile,
    this.model,
    this.waitingFor,
    this.openStep,
    this.steps = const [],
    this.store = const StoreDetails(),
    this.owner = const OwnerDetails(),
    this.documents = const [],
    this.fee,
    this.payments = const [],
    this.drugLicence = const DrugLicence(),
    this.storeCode,
    this.activatedAt,
    this.partnerVerified = false,
    this.verification = const PartnerVerification(),
  });

  final int id;
  final String number;
  final String name;
  final String status;
  final String statusLabel;
  final int? leadId;
  final String? mobile;
  final String? model;
  final String? waitingFor;
  final String? openStep;
  final List<OnboardingStep> steps;
  final StoreDetails store;
  final OwnerDetails owner;
  final List<OnboardingDoc> documents;

  /// Null when the server sent no complete fee figures.
  final Fee? fee;
  final List<Payment> payments;
  final DrugLicence drugLicence;
  final String? storeCode;
  final DateTime? activatedAt;
  final bool partnerVerified;
  final PartnerVerification verification;

  bool get isLive => storeCode != null || status == 'STORE_ACTIVE';

  OnboardingStep? step(StepKey key) => steps.where((s) => s.key == key).firstOrNull;

  /// The step the field user should act on now: anything sent back first,
  /// then the first open one.
  OnboardingStep? get nextStep =>
      steps.where((s) => s.state == StepStatus.rejected).firstOrNull ??
      steps.where((s) => s.state == StepStatus.open).firstOrNull;

  /// Steps done (approved or skipped), out of all steps.
  int get done => steps.where((s) => s.state == StepStatus.approved || s.state == StepStatus.skipped).length;

  /// "Ops", "Finance"... for whoever has the next move, or null for the field user.
  String? get waitingLabel => switch (waitingFor) {
    'ops' => 'Onboarding ops',
    'finance' => 'Finance',
    'compliance' => 'Compliance',
    _ => null,
  };

  factory Onboarding.fromJson(Map<String, dynamic> j) {
    final lead = j['lead'] is Map ? j['lead'] as Map : const {};
    final pv = j['partner_verification'] is Map ? j['partner_verification'] as Map : const {};
    return Onboarding(
      id: (j['id'] as num).toInt(),
      number: '${j['onboarding_no'] ?? ''}',
      name: '${lead['name'] ?? j['name'] ?? ''}',
      status: '${j['status'] ?? ''}',
      statusLabel: '${j['status_label'] ?? j['status'] ?? ''}',
      leadId: (j['lead_id'] as num?)?.toInt() ?? (lead['id'] as num?)?.toInt(),
      mobile: str(lead['mobile']),
      model: str(j['model'] ?? lead['model']),
      waitingFor: str(j['waiting_for']),
      openStep: str(j['open_step']),
      steps: [
        for (final s in (j['steps'] as List? ?? const []))
          if (s is Map<String, dynamic>) ?OnboardingStep.fromJson(s),
      ],
      store: j['store'] is Map<String, dynamic>
          ? StoreDetails.fromJson(j['store'] as Map<String, dynamic>)
          : const StoreDetails(),
      owner: j['owner'] is Map<String, dynamic>
          ? OwnerDetails.fromJson(j['owner'] as Map<String, dynamic>)
          : const OwnerDetails(),
      documents: [
        for (final d in (j['documents'] as List? ?? const []))
          if (d is Map<String, dynamic>) OnboardingDoc.fromJson(d),
      ],
      fee: Fee.tryParse(j['fee']),
      payments: [
        for (final p in (j['payments'] as List? ?? const []))
          if (p is Map<String, dynamic>) Payment.fromJson(p),
      ],
      drugLicence: j['drug_licence'] is Map<String, dynamic>
          ? DrugLicence.fromJson(j['drug_licence'] as Map<String, dynamic>)
          : const DrugLicence(),
      storeCode: str(j['store_code']),
      activatedAt: date(j['activated_at']),
      partnerVerified: pv['status'] == 'verified' || pv['verified_at'] != null,
      verification: PartnerVerification(
        method: str(pv['method']),
        status: str(pv['status']),
        verifiedBy: pv['verified_by'] is Map ? str((pv['verified_by'] as Map)['name']) : str(pv['verified_by']),
        verifiedAt: date(pv['verified_at']),
        calledPartner: pv['called_partner'] == true,
        photoUrl: str(pv['partner_photo_url']),
        signatureUrl: str(pv['signature_url']),
      ),
    );
  }
}

/// How the partner's identity was confirmed (step 1).
class PartnerVerification {
  const PartnerVerification({
    this.method,
    this.status,
    this.verifiedBy,
    this.verifiedAt,
    this.calledPartner = false,
    this.photoUrl,
    this.signatureUrl,
  });

  final String? method;
  final String? status;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final bool calledPartner;
  final String? photoUrl;
  final String? signatureUrl;

  String? get methodLabel => switch (method) {
    'field_attested' => 'In person, by the field user',
    'otp_sms' => 'Code by SMS',
    'otp_whatsapp' => 'Code by WhatsApp',
    _ => method,
  };
}

/// A document type from `/masters/onboarding`.
class DocType {
  const DocType({
    required this.type,
    required this.label,
    this.required = false,
    this.needsNumber = false,
    this.needsExpiry = false,
    this.alternativeFor,
    this.alternative,
    this.maxMb = 10,
  });

  final String type;
  final String label;
  final bool required;
  final bool needsNumber;
  final bool needsExpiry;
  final String? alternativeFor;
  final String? alternative;
  final int maxMb;

  factory DocType.fromJson(Map<String, dynamic> j) => DocType(
    type: '${j['type']}',
    label: '${j['label'] ?? j['type']}',
    required: j['required'] == true,
    needsNumber: j['needs_number'] == true,
    needsExpiry: j['needs_expiry'] == true,
    alternativeFor: str(j['alternative_for']),
    alternative: str(j['alternative']),
    maxMb: (j['max_mb'] as num?)?.toInt() ?? 10,
  );
}

class OnboardingMasters {
  const OnboardingMasters({
    this.storeFormats = const [],
    this.documentTypes = const [],
    this.paymentModes = const ['NEFT', 'RTGS', 'IMPS', 'UPI'],
    this.dlForms = const ['Form 20', 'Form 21', 'Form 20/21'],
  });

  final List<({String value, String label})> storeFormats;
  final List<DocType> documentTypes;
  final List<String> paymentModes;
  final List<String> dlForms;

  factory OnboardingMasters.fromJson(Map<String, dynamic> j) => OnboardingMasters(
    storeFormats: [
      for (final f in (j['store_formats'] as List? ?? const []))
        if (f is Map) (value: '${f['value']}', label: '${f['label'] ?? f['value']}'),
    ],
    documentTypes: [
      for (final d in (j['document_types'] as List? ?? const []))
        if (d is Map<String, dynamic>) DocType.fromJson(d),
    ],
    paymentModes: [
      for (final m in (j['payment_modes'] as List? ?? const ['NEFT', 'RTGS', 'IMPS', 'UPI'])) '$m',
    ],
    dlForms: [
      for (final f in (j['dl_forms'] as List? ?? const ['Form 20', 'Form 21', 'Form 20/21'])) '$f',
    ],
  );
}

/// The tabs on the Onboard screen. Values are the server's `tab` query.
enum OnboardingTab {
  needsAction('needs_action', 'Needs you'),
  waiting('waiting', 'Waiting'),
  live('live', 'Live');

  const OnboardingTab(this.query, this.label);

  final String query;
  final String label;
}

class OnboardingTabNotifier extends Notifier<OnboardingTab> {
  @override
  OnboardingTab build() => OnboardingTab.needsAction;

  void set(OnboardingTab tab) => state = tab;
}

final onboardingTabProvider = NotifierProvider<OnboardingTabNotifier, OnboardingTab>(OnboardingTabNotifier.new);

final onboardingsProvider = FutureProvider.autoDispose.family<List<Onboarding>, OnboardingTab>((ref, tab) async {
  ref.watch(liveSignalProvider(LiveTopic.onboarding));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/onboardings', query: {'tab': tab.query});
  return [for (final o in res.data) Onboarding.fromJson(o as Map<String, dynamic>)];
});

final onboardingProvider = FutureProvider.autoDispose.family<Onboarding, int>((ref, id) async {
  cacheFor(ref, const Duration(minutes: 1));
  ref.watch(liveSignalProvider(LiveTopic.onboarding));
  final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/onboardings/$id');
  return Onboarding.fromJson(res.data);
});

final onboardingActivitiesProvider = FutureProvider.autoDispose.family<List<Activity>, int>((ref, id) async {
  ref.watch(liveSignalProvider(LiveTopic.onboarding));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/onboardings/$id/activities');
  return [for (final a in res.data) Activity.fromJson(a as Map<String, dynamic>)];
});

final franchiseFeeProvider = FutureProvider.autoDispose.family<Fee, int>((ref, id) async {
  ref.watch(liveSignalProvider(LiveTopic.onboarding));
  final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/onboardings/$id/franchise-fee');
  return Fee.fromJson(res.data);
});

final onboardingMastersProvider = FutureProvider.family<OnboardingMasters, String>((ref, model) async {
  final res = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/masters/onboarding', query: {'model': model});
  return OnboardingMasters.fromJson(res.data);
});

/// After a change to an onboarding: reload it, its lists and Home.
void onboardingChanged(WidgetRef ref) =>
    refreshTopics(ref, const [LiveTopic.onboarding, LiveTopic.leads, LiveTopic.dashboard]);

/// "₹3,54,000" in the Indian grouping.
String rupees(double v) {
  final whole = v.round().abs().toString();
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '${v < 0 ? '-' : ''}₹$grouped';
}
