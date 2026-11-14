import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';
import '../leads/lead.dart' show date, str;

DateTime? _at(Object? v) => date(v);
double? _dbl(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

// ── day plan ─────────────────────────────────────────────────────────────

enum StopStatus {
  planned('Planned'),
  checkedIn('Checked in'),
  done('Visited');

  const StopStatus(this.label);

  final String label;

  static StopStatus parse(Object? v) => switch (v) {
    'checked_in' => checkedIn,
    'done' => done,
    _ => planned,
  };
}

class StoreVisitInfo {
  const StoreVisitInfo({
    required this.id,
    required this.checkedInAt,
    this.checkedOutAt,
    this.geoVerified = false,
    this.distanceM,
    this.summary,
    this.by,
  });

  final int id;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final bool geoVerified;
  final int? distanceM;
  final String? summary;
  final String? by;

  bool get isOpen => checkedOutAt == null;

  factory StoreVisitInfo.fromJson(Map<String, dynamic> j) => StoreVisitInfo(
    id: (j['id'] as num).toInt(),
    checkedInAt: _at(j['checked_in_at']) ?? DateTime.now(),
    checkedOutAt: _at(j['checked_out_at']),
    geoVerified: j['geo_verified'] == true,
    distanceM: _int(j['distance_m']),
    summary: str(j['summary']),
    by: str(j['by']),
  );
}

/// One stop on the day plan: a live store or a lead.
class PlanStop {
  const PlanStop({
    required this.id,
    required this.isStore,
    required this.name,
    required this.status,
    this.partnerId,
    this.leadId,
    this.subtitle,
    this.address,
    this.latitude,
    this.longitude,
    this.visit,
  });

  final int id;
  final bool isStore;
  final String name;
  final StopStatus status;
  final int? partnerId;
  final int? leadId;
  final String? subtitle;
  final String? address;
  final double? latitude;
  final double? longitude;
  final StoreVisitInfo? visit;

  bool get hasPin => latitude != null && longitude != null;

  factory PlanStop.fromJson(Map<String, dynamic> j) => PlanStop(
    id: (j['id'] as num).toInt(),
    isStore: j['kind'] == 'store',
    name: '${j['name'] ?? ''}',
    status: StopStatus.parse(j['status']),
    partnerId: _int(j['partner_id']),
    leadId: _int(j['lead_id']),
    subtitle: str(j['subtitle']),
    address: str(j['address']),
    latitude: _dbl(j['latitude']),
    longitude: _dbl(j['longitude']),
    visit: j['visit'] is Map<String, dynamic> ? StoreVisitInfo.fromJson(j['visit'] as Map<String, dynamic>) : null,
  );
}

final dayPlanProvider = FutureProvider.autoDispose<List<PlanStop>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/day-plan');
  return [
    for (final s in res.data)
      if (s is Map<String, dynamic>) PlanStop.fromJson(s),
  ];
});

/// A store or lead that can be added to the plan.
class PlanCandidate {
  const PlanCandidate({
    required this.id,
    required this.isStore,
    required this.name,
    required this.planned,
    this.subtitle,
    this.address,
  });

  final int id;
  final bool isStore;
  final String name;
  final bool planned;
  final String? subtitle;
  final String? address;
}

final planCandidatesProvider = FutureProvider.autoDispose
    .family<({List<PlanCandidate> stores, List<PlanCandidate> leads}), String>((ref, q) async {
      final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/day-plan/candidates', query: {'q': q});
      List<PlanCandidate> list(String key, bool store) => [
        for (final c in (res.data[key] as List? ?? const []))
          if (c is Map)
            PlanCandidate(
              id: _int(store ? c['partner_id'] : c['lead_id']) ?? 0,
              isStore: store,
              name: '${c['name'] ?? ''}',
              planned: c['planned'] == true,
              subtitle: store
                  ? str(c['subtitle'])
                  : [str(c['lead_no']), str(c['status_label'])].whereType<String>().join(' · '),
              address: str(c['address']),
            ),
      ];
      return (stores: list('stores', true), leads: list('leads', false));
    });

// ── stores ───────────────────────────────────────────────────────────────

class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.latitude,
    this.longitude,
    this.ownerName,
    this.ownerMobile,
    this.openVisit,
    this.recentVisits = const [],
    this.tickets = const [],
  });

  final int id;
  final String name;
  final String? code;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? ownerName;
  final String? ownerMobile;
  final StoreVisitInfo? openVisit;
  final List<StoreVisitInfo> recentVisits;
  final List<TicketInfo> tickets;

  factory StoreInfo.fromJson(Map<String, dynamic> j) => StoreInfo(
    id: (j['partner_id'] as num).toInt(),
    name: '${j['name'] ?? ''}',
    code: str(j['store_code']),
    address: str(j['address']),
    latitude: _dbl(j['latitude']),
    longitude: _dbl(j['longitude']),
    ownerName: str(j['owner_name']),
    ownerMobile: str(j['owner_mobile']),
    openVisit: j['open_visit'] is Map<String, dynamic>
        ? StoreVisitInfo.fromJson(j['open_visit'] as Map<String, dynamic>)
        : null,
    recentVisits: [
      for (final v in (j['recent_visits'] as List? ?? const []))
        if (v is Map<String, dynamic>) StoreVisitInfo.fromJson(v),
    ],
    tickets: [
      for (final t in (j['tickets'] as List? ?? const []))
        if (t is Map<String, dynamic>) TicketInfo.fromJson(t),
    ],
  );
}

final storeProvider = FutureProvider.autoDispose.family<StoreInfo, int>((ref, id) async {
  final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/stores/$id');
  return StoreInfo.fromJson(res.data);
});

// ── tickets ──────────────────────────────────────────────────────────────

class TicketUpdateInfo {
  const TicketUpdateInfo({this.statusLabel, this.note, this.by, this.at});

  final String? statusLabel;
  final String? note;
  final String? by;
  final DateTime? at;
}

class TicketInfo {
  const TicketInfo({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.categoryLabel,
    required this.subject,
    this.storeName,
    this.partnerId,
    this.high = false,
    this.description,
    this.photoUrl,
    this.raisedBy,
    this.createdAt,
    this.updates = const [],
  });

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String categoryLabel;
  final String subject;
  final String? storeName;
  final int? partnerId;
  final bool high;
  final String? description;
  final String? photoUrl;
  final String? raisedBy;
  final DateTime? createdAt;
  final List<TicketUpdateInfo> updates;

  bool get isOpen => status == 'open' || status == 'in_progress';

  factory TicketInfo.fromJson(Map<String, dynamic> j) => TicketInfo(
    id: (j['id'] as num).toInt(),
    number: '${j['ticket_no'] ?? '#${j['id']}'}',
    status: '${j['status']}',
    statusLabel: '${j['status_label'] ?? j['status']}',
    categoryLabel: '${j['category_label'] ?? j['category']}',
    subject: '${j['subject'] ?? ''}',
    storeName: str(j['store_name']),
    partnerId: _int(j['partner_id']),
    high: j['priority'] == 'high',
    description: str(j['description']),
    photoUrl: str(j['photo_url']),
    raisedBy: str(j['raised_by']),
    createdAt: _at(j['created_at']),
    updates: [
      for (final u in (j['updates'] as List? ?? const []))
        if (u is Map)
          TicketUpdateInfo(
            statusLabel: str(u['status_label']),
            note: str(u['note']),
            by: str(u['by']),
            at: _at(u['at']),
          ),
    ],
  );
}

final ticketsProvider = FutureProvider.autoDispose.family<List<TicketInfo>, bool>((ref, open) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/tickets', query: {'status': open ? 'open' : 'closed'});
  return [
    for (final t in res.data)
      if (t is Map<String, dynamic>) TicketInfo.fromJson(t),
  ];
});

final ticketProvider = FutureProvider.autoDispose.family<TicketInfo, int>((ref, id) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/tickets/$id');
  return TicketInfo.fromJson(res.data);
});

// ── calendar ─────────────────────────────────────────────────────────────

enum CalendarKind { visit, callback, followUp, activity, plan, leave }

class CalendarItem {
  const CalendarItem({
    required this.day,
    required this.kind,
    required this.title,
    this.at,
    this.subtitle,
    this.leadId,
    this.partnerId,
    this.activityId,
    this.done = false,
  });

  /// The local day, `YYYY-MM-DD`.
  final String day;
  final CalendarKind kind;
  final String title;
  final DateTime? at;
  final String? subtitle;
  final int? leadId;
  final int? partnerId;
  final int? activityId;
  final bool done;

  factory CalendarItem.fromJson(Map<String, dynamic> j) => CalendarItem(
    day: '${j['date']}',
    kind: switch (j['type']) {
      'visit' => CalendarKind.visit,
      'callback' => CalendarKind.callback,
      'follow_up' => CalendarKind.followUp,
      'plan' => CalendarKind.plan,
      'leave' => CalendarKind.leave,
      _ => CalendarKind.activity,
    },
    title: '${j['title'] ?? ''}',
    at: _at(j['at']),
    subtitle: str(j['subtitle']),
    leadId: _int(j['lead_id']),
    partnerId: _int(j['partner_id']),
    activityId: _int(j['activity_id']),
    done: j['done'] == true,
  );
}

final calendarProvider = FutureProvider.autoDispose.family<List<CalendarItem>, String>((ref, month) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/calendar', query: {'month': month});
  return [
    for (final i in res.data)
      if (i is Map<String, dynamic>) CalendarItem.fromJson(i),
  ];
});
