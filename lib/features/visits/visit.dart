import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';

/// A visit from `/visits`, with the few lead fields the lists need.
class Visit {
  const Visit({
    required this.id,
    required this.status,
    required this.leadId,
    required this.leadName,
    this.leadNo,
    this.address,
    this.scheduledAt,
  });

  final int id;
  final String status;
  final int leadId;
  final String leadName;
  final String? leadNo;
  final String? address;
  final DateTime? scheduledAt;

  factory Visit.fromJson(Map<String, dynamic> j) {
    final lead = j['lead'] is Map ? j['lead'] as Map : const {};
    return Visit(
      id: (j['id'] as num).toInt(),
      status: '${j['status'] ?? ''}',
      leadId: (lead['id'] as num?)?.toInt() ?? 0,
      leadName: '${lead['name'] ?? ''}',
      leadNo: lead['lead_no'] as String?,
      address: lead['address'] as String?,
      scheduledAt: j['scheduled_at'] == null ? null : DateTime.tryParse('${j['scheduled_at']}')?.toLocal(),
    );
  }
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Visits scheduled for today on the phone's calendar, earliest first.
final todaysVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.visits));
  final res = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/visits', query: {'date': _day(DateTime.now()), 'status': 'scheduled'});
  final visits = [for (final v in res.data) Visit.fromJson(v as Map<String, dynamic>)]
    ..sort((a, b) => (a.scheduledAt ?? DateTime(9999)).compareTo(b.scheduledAt ?? DateTime(9999)));
  return visits;
});
