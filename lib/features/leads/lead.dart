import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';

/// A lead from `/leads` or `/leads/{id}`. Labels come from the server.
class Lead {
  const Lead({
    required this.id,
    required this.leadNo,
    required this.name,
    required this.status,
    required this.statusLabel,
    this.mobile,
    this.email,
    this.model,
    this.pincode,
    this.city,
    this.address,
    this.sourceLabel,
    this.enquiryAt,
    this.shopOwnership,
    this.shopAreaSqft,
    this.investmentReady,
    this.notes,
    this.lastCall,
    this.nextVisitAt,
    this.nextCallAt,
    this.onboarding,
    this.allowedActions = const [],
    this.state,
    this.source,
    this.campaign,
    this.adSet,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.consent,
    this.timeline,
    this.nextStatuses = const [],
    this.latitude,
    this.longitude,
    this.assignedTo,
    this.storeLocation,
  });

  final int id;
  final String leadNo;
  final String name;
  final String status;
  final String statusLabel;
  final String? mobile;
  final String? email;
  final String? model;
  final String? pincode;
  final String? city;
  final String? address;
  final String? sourceLabel;
  final DateTime? enquiryAt;
  final String? shopOwnership;
  final int? shopAreaSqft;
  final String? investmentReady;
  final String? notes;
  final LastCall? lastCall;
  final DateTime? nextVisitAt;
  final DateTime? nextCallAt;
  final OnboardingSummary? onboarding;
  final List<String> allowedActions;
  final String? state;
  final String? source;
  final String? campaign;
  final String? adSet;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final bool? consent;
  final String? timeline;
  final List<String> nextStatuses;
  final double? latitude;
  final double? longitude;
  final String? assignedTo;

  /// Where the store is proposed to open, from the site visit.
  final StoreLocation? storeLocation;

  bool allows(String action) => allowedActions.contains(action);

  bool get hasLocation => latitude != null && longitude != null;

  /// "LD-000029 · FOFO · 313001"
  String get subtitle => [leadNo, model, pincode].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
    id: (j['id'] as num).toInt(),
    leadNo: '${j['lead_no'] ?? ''}',
    name: '${j['name'] ?? ''}',
    status: '${j['status'] ?? ''}',
    statusLabel: '${j['status_label'] ?? j['status'] ?? ''}',
    mobile: str(j['mobile']),
    email: str(j['email']),
    model: str(j['model']),
    pincode: str(j['pincode']),
    city: str(j['city']),
    address: str(j['address']),
    sourceLabel: str(j['source_label']) ?? str(j['source']),
    enquiryAt: date(j['enquiry_at']),
    shopOwnership: str(j['shop_ownership']),
    shopAreaSqft: (j['shop_area_sqft'] as num?)?.toInt(),
    investmentReady: str(j['investment_ready']),
    notes: str(j['notes']),
    lastCall: j['last_call'] is Map<String, dynamic> ? LastCall.fromJson(j['last_call'] as Map<String, dynamic>) : null,
    nextVisitAt: date(j['next_visit_at']),
    nextCallAt: date(j['next_call_at']),
    onboarding: j['onboarding'] is Map<String, dynamic>
        ? OnboardingSummary.fromJson(j['onboarding'] as Map<String, dynamic>)
        : null,
    allowedActions: [for (final a in (j['allowed_actions'] as List? ?? const [])) '$a'],
    state: str(j['state']),
    source: str(j['source']),
    campaign: str(j['campaign']),
    adSet: str(j['ad_set']),
    utmSource: str(_utm(j, 'source')),
    utmMedium: str(_utm(j, 'medium')),
    utmCampaign: str(_utm(j, 'campaign')),
    consent: j['consent'] is bool ? j['consent'] as bool : null,
    timeline: str(j['timeline']),
    nextStatuses: [for (final n in (j['next_statuses'] as List? ?? const [])) '$n'],
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    assignedTo: j['rcm'] is Map ? str((j['rcm'] as Map)['name']) : null,
    storeLocation: j['store_location'] is Map<String, dynamic>
        ? StoreLocation.fromJson(j['store_location'] as Map<String, dynamic>)
        : null,
  );
}

class StoreLocation {
  const StoreLocation({this.address, this.landmark, this.pincode, this.latitude, this.longitude});

  final String? address;
  final String? landmark;
  final String? pincode;
  final double? latitude;
  final double? longitude;

  /// "Shop 4, Hiran Magri · near City Hospital · 313002"
  String get summary => [address, if (landmark != null) 'near $landmark', pincode].whereType<String>().join(' · ');

  factory StoreLocation.fromJson(Map<String, dynamic> j) => StoreLocation(
    address: str(j['address']),
    landmark: str(j['landmark']),
    pincode: str(j['pincode']),
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
  );
}

/// UTM values come either nested (`utm.source`) or flat (`utm_source`).
Object? _utm(Map<String, dynamic> j, String key) => (j['utm'] is Map ? (j['utm'] as Map)[key] : null) ?? j['utm_$key'];

/// Values of `allowed_actions` on a lead.
abstract final class LeadAction {
  static const scheduleVisit = 'schedule_visit';
  static const checkin = 'checkin';
  static const checkout = 'checkout';
  static const addNote = 'add_note';
  static const changeStatus = 'change_status';
  static const reassign = 'reassign';
  static const openOnboarding = 'open_onboarding';
}

class LastCall {
  const LastCall({this.summary, this.disposition, this.at});

  final String? summary;
  final String? disposition;
  final DateTime? at;

  factory LastCall.fromJson(Map<String, dynamic> j) =>
      LastCall(summary: str(j['summary']), disposition: str(j['disposition']), at: date(j['created_at']));
}

class OnboardingSummary {
  const OnboardingSummary({required this.id, this.number, this.status, this.waitingFor});

  final int id;
  final String? number;
  final String? status;
  final String? waitingFor;

  factory OnboardingSummary.fromJson(Map<String, dynamic> j) => OnboardingSummary(
    id: (j['id'] as num).toInt(),
    number: str(j['onboarding_no']),
    status: str(j['status']),
    waitingFor: str(j['waiting_for']),
  );
}

/// One entry of a lead's timeline, from `/leads/{id}/activities`.
class Activity {
  const Activity({required this.id, required this.type, required this.title, this.notes, this.by, this.at});

  final int id;
  final String type;
  final String title;
  final String? notes;
  final String? by;
  final DateTime? at;

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: (j['id'] as num).toInt(),
    type: '${j['type'] ?? ''}',
    title: '${j['title'] ?? ''}',
    notes: str(j['notes']),
    by: j['user'] is Map ? str((j['user'] as Map)['name']) : null,
    at: date(j['created_at']),
  );
}

String? str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// The filter chips on the Leads tab. Status filters match the Home counts.
enum LeadFilter {
  all('All', {}),
  assigned('Assigned', {'status': 'ASSIGNED'}),
  visitScheduled('Visit scheduled', {'status': 'VISIT_SCHEDULED'}),
  followUp('Follow-up', {'status': 'FOLLOW_UP'}),
  qualified('Qualified', {'status': 'QUALIFIED'}),
  closed('Closed', {'queue': 'closed'});

  const LeadFilter(this.label, this.query);

  final String label;
  final Map<String, String> query;
}

class LeadFilterNotifier extends Notifier<LeadFilter> {
  @override
  LeadFilter build() => LeadFilter.all;

  void set(LeadFilter filter) => state = filter;
}

final leadFilterProvider = NotifierProvider<LeadFilterNotifier, LeadFilter>(LeadFilterNotifier.new);

class LeadSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String text) => state = text.trim();
}

final leadSearchProvider = NotifierProvider<LeadSearchNotifier, String>(LeadSearchNotifier.new);

/// A server queue the Leads list is showing instead of a status filter,
/// opened from a Home "Needs attention" row.
typedef LeadQueue = ({String queue, String label});

class LeadQueueNotifier extends Notifier<LeadQueue?> {
  @override
  LeadQueue? build() => null;

  void set(LeadQueue? queue) => state = queue;
}

final leadQueueProvider = NotifierProvider<LeadQueueNotifier, LeadQueue?>(LeadQueueNotifier.new);

/// The user's leads for the current filter and search. The server only
/// returns leads in the user's scope.
final leadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.leads));
  final filter = ref.watch(leadFilterProvider);
  final queue = ref.watch(leadQueueProvider);
  final search = ref.watch(leadSearchProvider);
  final res = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>(
        '/leads',
        query: {
          ...queue == null ? filter.query : {'queue': queue.queue},
          if (search.isNotEmpty) 'q': search,
          'per_page': 100,
        },
      );
  return [for (final l in res.data) Lead.fromJson(l as Map<String, dynamic>)];
});

final leadProvider = FutureProvider.autoDispose.family<Lead, int>((ref, id) async {
  ref.watch(liveSignalProvider(LiveTopic.leads));
  final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/leads/$id');
  return Lead.fromJson(res.data);
});

/// After a change to a lead or its visits: reload the lead, its timeline,
/// visits and every list that shows them.
void leadChanged(WidgetRef ref) => refreshTopics(ref, const [LiveTopic.leads, LiveTopic.visits, LiveTopic.dashboard]);

final leadActivitiesProvider = FutureProvider.autoDispose.family<List<Activity>, int>((ref, id) async {
  ref.watch(liveSignalProvider(LiveTopic.leads));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/leads/$id/activities');
  return [for (final a in res.data) Activity.fromJson(a as Map<String, dynamic>)];
});
