import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leads/lead.dart' show date, str;
import '../onboarding/onboarding.dart';
import 'track_session.dart';

/// The approved partner's own record, from `/partner/me` (partner token).
class PartnerMe {
  const PartnerMe({
    required this.number,
    required this.status,
    this.model,
    this.openStep,
    this.waitingFor,
    this.rejectionReason,
    this.rejectedFields = const [],
    this.store = const StoreDetails(),
    this.owner = const OwnerDetails(),
    this.payment,
    this.drugLicence = const DrugLicence(),
    this.documents = const [],
    this.rcmName,
    this.rcmMobile,
    this.name,
    this.mobile,
  });

  final String? name;
  final String? mobile;

  final String number;
  final String status;
  final String? model;
  final String? openStep;
  final String? waitingFor;
  final String? rejectionReason;
  final List<String> rejectedFields;
  final StoreDetails store;
  final OwnerDetails owner;

  /// Null when the server sent no complete fee figures.
  final Fee? payment;
  final DrugLicence drugLicence;
  final List<OnboardingDoc> documents;
  final String? rcmName;
  final String? rcmMobile;

  /// The step the partner can fill now, or null when it's with Dava India.
  StepKey? get myTurn {
    if (waitingFor != null && waitingFor != 'partner') return null;
    final k = StepKey.of(openStep);
    return k == StepKey.partnerVerification ? null : k;
  }

  bool get fixing => rejectionReason != null;

  factory PartnerMe.fromJson(Map<String, dynamic> j) {
    final rcm = j['rcm'] is Map ? j['rcm'] as Map : const {};
    return PartnerMe(
      number: '${j['partner_no'] ?? ''}',
      status: '${j['status'] ?? ''}',
      model: str(j['model']),
      openStep: str(j['open_step']),
      waitingFor: str(j['waiting_for']),
      rejectionReason: str(j['rejection_reason']),
      rejectedFields: [for (final f in (j['rejected_fields'] as List? ?? const [])) '$f'],
      store: j['store'] is Map<String, dynamic>
          ? StoreDetails.fromJson(j['store'] as Map<String, dynamic>)
          : const StoreDetails(),
      owner: j['owner'] is Map<String, dynamic>
          ? OwnerDetails.fromJson(j['owner'] as Map<String, dynamic>)
          : const OwnerDetails(),
      payment: Fee.tryParse(j['payment']),
      drugLicence: j['drug_licence'] is Map<String, dynamic>
          ? DrugLicence.fromJson(j['drug_licence'] as Map<String, dynamic>)
          : const DrugLicence(),
      documents: [
        for (final d in (j['documents'] as List? ?? const []))
          if (d is Map<String, dynamic>) OnboardingDoc.fromJson(d),
      ],
      name: str(j['name']),
      mobile: str(j['mobile']),
      rcmName: str(rcm['name']),
      rcmMobile: str(rcm['mobile']),
    );
  }
}

/// One message in the customer's inbox.
class CustomerNotice {
  const CustomerNotice({required this.id, required this.title, this.body, this.at, this.read = false});

  final String id;
  final String title;
  final String? body;
  final DateTime? at;
  final bool read;

  factory CustomerNotice.fromJson(Map<String, dynamic> j) => CustomerNotice(
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    body: str(j['body']),
    at: date(j['created_at']),
    read: j['read_at'] != null,
  );
}

/// Bumped after the partner submits something, to reload what depends on it.
class PartnerRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final partnerRevisionProvider = NotifierProvider<PartnerRevision, int>(PartnerRevision.new);

final partnerMeProvider = FutureProvider.autoDispose<PartnerMe>((ref) async {
  ref.watch(partnerRevisionProvider);
  final res = await ref.watch(trackApiProvider).get<Map<String, dynamic>>('/partner/me');
  return PartnerMe.fromJson(res.data);
});

final partnerFeeProvider = FutureProvider.autoDispose<Fee>((ref) async {
  ref.watch(partnerRevisionProvider);
  final res = await ref.watch(trackApiProvider).get<Map<String, dynamic>>('/partner/franchise-fee');
  return Fee.fromJson(res.data);
});

final partnerPaymentsProvider = FutureProvider.autoDispose<List<Payment>>((ref) async {
  ref.watch(partnerRevisionProvider);
  final res = await ref.watch(trackApiProvider).get<List<dynamic>>('/partner/payments');
  return [for (final p in res.data) Payment.fromJson(p as Map<String, dynamic>)];
});

final customerInboxProvider = FutureProvider.autoDispose<({List<CustomerNotice> items, int unread})>((ref) async {
  ref.watch(partnerRevisionProvider);
  final res = await ref.watch(trackApiProvider).get<List<dynamic>>('/partner/notifications');
  return (
    items: [for (final n in res.data) CustomerNotice.fromJson(n as Map<String, dynamic>)],
    unread: (res.meta?['unread_count'] as num?)?.toInt() ?? 0,
  );
});

/// Onboarding masters for the partner's forms. The endpoint is public to
/// staff tokens only, so these are the defaults the server documents.
const partnerDocTypes = <DocType>[
  DocType(type: 'store_licence', label: 'Store licence', required: true, needsNumber: true, needsExpiry: true),
  DocType(type: 'owner_pan_file', label: 'Owner PAN card', required: true),
  DocType(type: 'id_proof', label: 'ID proof (Aadhaar)', required: true),
  DocType(type: 'owner_photo', label: 'Your photo', required: true),
  DocType(
    type: 'drug_licence',
    label: 'Drug licence',
    needsNumber: true,
    needsExpiry: true,
    alternative: 'dl_fee_receipt',
  ),
  DocType(type: 'dl_fee_receipt', label: 'Drug licence fee receipt', alternativeFor: 'drug_licence'),
];
