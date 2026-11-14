import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';

/// Lead counts for the signed-in user, from `GET /dashboard`.
class Dashboard {
  const Dashboard(this.byStatus);

  final Map<String, int> byStatus;

  int count(String status) => byStatus[status] ?? 0;

  /// Accepts `by_status` as a map (`{"NEW": 3}`) or a list
  /// (`[{"status": "NEW", "count": 3}]`).
  factory Dashboard.fromJson(Object? data) {
    final out = <String, int>{};
    final raw = data is Map ? data['by_status'] : null;
    if (raw is Map) {
      raw.forEach((k, v) => out['$k'] = v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    } else if (raw is List) {
      for (final e in raw) {
        if (e is Map && e['status'] != null) {
          final v = e['count'] ?? e['total'];
          out['${e['status']}'] = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        }
      }
    }
    return Dashboard(out);
  }
}

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) async {
  final res = await ref.watch(apiClientProvider).get<Object?>('/dashboard');
  return Dashboard.fromJson(res.data);
});
