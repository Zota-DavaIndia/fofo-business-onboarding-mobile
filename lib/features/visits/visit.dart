import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/masters.dart';
import '../../core/sync/live_refresh.dart';
import '../leads/lead.dart' show date, str;

/// Values of a visit's `status`.
abstract final class VisitStatus {
  static const scheduled = 'scheduled';
  static const checkedIn = 'checked_in';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

/// A visit from `/visits` or `/leads/{id}/visits`.
class Visit {
  const Visit({
    required this.id,
    required this.status,
    required this.leadId,
    required this.leadName,
    this.kind,
    this.leadNo,
    this.address,
    this.leadLatitude,
    this.leadLongitude,
    this.scheduledAt,
    this.checkedInAt,
    this.checkedOutAt,
    this.distanceM,
    this.radiusM,
    this.geoVerified = false,
    this.outcome,
    this.summary,
    this.notes,
  });

  final int id;
  final String status;
  final int leadId;
  final String leadName;
  final String? kind;
  final String? leadNo;
  final String? address;
  final double? leadLatitude;
  final double? leadLongitude;
  final DateTime? scheduledAt;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final int? distanceM;
  final int? radiusM;
  final bool geoVerified;
  final String? outcome;
  final String? summary;
  final String? notes;

  bool get isScheduled => status == VisitStatus.scheduled;
  bool get isOpen => status == VisitStatus.checkedIn;

  /// When it happens or happened: the plan for scheduled ones, else check-in.
  DateTime? get when => scheduledAt ?? checkedInAt;

  factory Visit.fromJson(Map<String, dynamic> j) {
    final lead = j['lead'] is Map ? j['lead'] as Map : const {};
    return Visit(
      id: (j['id'] as num).toInt(),
      status: '${j['status'] ?? ''}',
      kind: str(j['kind']),
      leadId: (lead['id'] as num?)?.toInt() ?? (j['lead_id'] as num?)?.toInt() ?? 0,
      leadName: '${lead['name'] ?? ''}',
      leadNo: str(lead['lead_no']),
      address: str(lead['address']),
      leadLatitude: (lead['latitude'] as num?)?.toDouble(),
      leadLongitude: (lead['longitude'] as num?)?.toDouble(),
      scheduledAt: date(j['scheduled_at']),
      checkedInAt: date(j['checked_in_at']),
      checkedOutAt: date(j['checked_out_at']),
      distanceM: (j['distance_m'] as num?)?.toInt(),
      radiusM: (j['radius_m'] as num?)?.toInt(),
      geoVerified: j['geo_verified'] == true,
      outcome: str(j['outcome']),
      summary: str(j['summary']),
      notes: str(j['notes']),
    );
  }
}

List<Visit> _parse(List<dynamic> data) => [for (final v in data) Visit.fromJson(v as Map<String, dynamic>)];

int _byTime(Visit a, Visit b) => (a.when ?? DateTime(9999)).compareTo(b.when ?? DateTime(9999));

/// Visits scheduled for today on the phone's calendar, earliest first.
final todaysVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.visits));
  final res = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/visits', query: {'date': isoDay(DateTime.now()), 'status': VisitStatus.scheduled});
  return _parse(res.data)..sort(_byTime);
});

/// The tabs on the Visits screen.
enum VisitsTab {
  today('Today'),
  upcoming('Upcoming'),
  done('Done');

  const VisitsTab(this.label);

  final String label;
}

class VisitsTabNotifier extends Notifier<VisitsTab> {
  @override
  VisitsTab build() => VisitsTab.today;

  void set(VisitsTab tab) => state = tab;
}

final visitsTabProvider = NotifierProvider<VisitsTabNotifier, VisitsTab>(VisitsTabNotifier.new);

/// The list for one tab. Today and upcoming run earliest first; done runs
/// newest first.
final visitsProvider = FutureProvider.autoDispose.family<List<Visit>, VisitsTab>((ref, tab) async {
  ref.watch(liveSignalProvider(LiveTopic.visits));
  final api = ref.watch(apiClientProvider);
  final now = DateTime.now();
  final query = switch (tab) {
    VisitsTab.today => {'date': isoDay(now)},
    VisitsTab.upcoming => {
      'from': isoDay(now.add(const Duration(days: 1))),
      'to': isoDay(now.add(const Duration(days: 60))),
      'status': VisitStatus.scheduled,
    },
    VisitsTab.done => {'status': VisitStatus.completed},
  };
  final res = await api.get<List<dynamic>>('/visits', query: query);
  final list = _parse(res.data).where((v) => v.status != VisitStatus.cancelled).toList()..sort(_byTime);
  return tab == VisitsTab.done ? list.reversed.toList() : list;
});

/// Check-ins not yet checked out. Usually none or one.
final openVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.visits));
  final res = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/visits', query: {'status': VisitStatus.checkedIn});
  return _parse(res.data);
});

/// All visits of one lead.
final leadVisitsProvider = FutureProvider.autoDispose.family<List<Visit>, int>((ref, leadId) async {
  ref.watch(liveSignalProvider(LiveTopic.visits));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/leads/$leadId/visits');
  return _parse(res.data)..sort(_byTime);
});
