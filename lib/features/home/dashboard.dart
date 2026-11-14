import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';
import '../leads/lead.dart' show date, str;

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String, int> _counts(Object? raw) {
  final out = <String, int>{};
  if (raw is Map) {
    raw.forEach((k, v) => out['$k'] = _int(v));
  } else if (raw is List) {
    for (final e in raw) {
      if (e is Map && (e['status'] ?? e['key']) != null) {
        out['${e['status'] ?? e['key']}'] = _int(e['count'] ?? e['total']);
      }
    }
  }
  return out;
}

/// Where an attention row or a stage leads.
sealed class HomeTarget {
  const HomeTarget();

  static HomeTarget? fromJson(Object? j) {
    if (j is! Map) return null;
    return switch (j['screen']) {
      'leads' => LeadsTarget('${j['queue'] ?? 'open'}'),
      'onboardings' => OnboardingsTarget('${j['tab'] ?? 'needs_action'}'),
      _ => null,
    };
  }
}

class LeadsTarget extends HomeTarget {
  const LeadsTarget(this.queue);

  final String queue;
}

class OnboardingsTarget extends HomeTarget {
  const OnboardingsTarget(this.tab);

  final String tab;
}

/// One "Needs attention" row.
class Attention {
  const Attention({required this.key, required this.label, required this.count, this.target});

  final String key;
  final String label;
  final int count;
  final HomeTarget? target;

  factory Attention.fromJson(Map<String, dynamic> j) => Attention(
    key: '${j['key']}',
    label: '${j['label'] ?? j['key']}',
    count: _int(j['count']),
    target: HomeTarget.fromJson(j['target']),
  );
}

/// One card of the Lead-to-Billing strip. [count] is null when the user
/// can't see that stage.
class Stage {
  const Stage({required this.no, required this.name, this.team, required this.group, this.count});

  final int no;
  final String name;
  final String? team;

  /// `lead` or `onb`.
  final String group;
  final int? count;

  bool get isLead => group == 'lead';

  factory Stage.fromJson(Map<String, dynamic> j) => Stage(
    no: _int(j['no']),
    name: '${j['name'] ?? ''}',
    team: str(j['team']),
    group: '${j['group'] ?? 'lead'}',
    count: j['count'] == null ? null : _int(j['count']),
  );
}

/// A lead in the "Recent" list.
class RecentLead {
  const RecentLead({
    required this.id,
    required this.leadNo,
    required this.name,
    this.sourceLabel,
    this.statusLabel,
    this.status,
    this.createdAt,
  });

  final int id;
  final String leadNo;
  final String name;
  final String? sourceLabel;
  final String? statusLabel;
  final String? status;
  final DateTime? createdAt;

  factory RecentLead.fromJson(Map<String, dynamic> j) => RecentLead(
    id: _int(j['id']),
    leadNo: '${j['lead_no'] ?? ''}',
    name: '${j['name'] ?? ''}',
    sourceLabel: str(j['source_label']),
    statusLabel: str(j['status_label']),
    status: str(j['status']),
    createdAt: date(j['created_at']),
  );
}

/// `today` on the dashboard.
typedef TodayCounts = ({int newLeads, int calls, int visits, int qualified});

/// Everything for Home, from one `GET /dashboard`, already limited to the
/// user's own scope.
class Dashboard {
  const Dashboard({
    this.byStatus = const {},
    this.bySource = const {},
    this.byModel = const {},
    this.total = 0,
    this.conversionPct = 0,
    this.qualifiedThisMonth = 0,
    this.onboardingNeedsAction = 0,
    this.onboardingWaiting = 0,
    this.onboardingLive = 0,
    this.attention = const [],
    this.today = (newLeads: 0, calls: 0, visits: 0, qualified: 0),
    this.stages = const [],
    this.recent = const [],
  });

  final Map<String, int> byStatus;
  final Map<String, int> bySource;
  final Map<String, int> byModel;
  final int total;
  final int conversionPct;
  final int qualifiedThisMonth;
  final int onboardingNeedsAction;
  final int onboardingWaiting;
  final int onboardingLive;
  final List<Attention> attention;
  final TodayCounts today;
  final List<Stage> stages;
  final List<RecentLead> recent;

  int count(String status) => byStatus[status] ?? 0;

  factory Dashboard.fromJson(Object? data) {
    final j = data is Map ? data : const {};
    final ob = j['onboarding'] is Map ? j['onboarding'] as Map : const {};
    final t = j['today'] is Map ? j['today'] as Map : const {};
    return Dashboard(
      byStatus: _counts(j['by_status']),
      bySource: _counts(j['by_source']),
      byModel: _counts(j['by_model']),
      total: _int(j['total']),
      conversionPct: _int(j['conversion_pct']),
      qualifiedThisMonth: _int(j['qualified_this_month']),
      onboardingNeedsAction: _int(ob['needs_action']),
      onboardingWaiting: _int(ob['waiting']),
      onboardingLive: _int(ob['live']),
      attention: [
        for (final a in (j['attention'] as List? ?? const []))
          if (a is Map<String, dynamic>) Attention.fromJson(a),
      ],
      today: (
        newLeads: _int(t['new_leads']),
        calls: _int(t['calls']),
        visits: _int(t['visits']),
        qualified: _int(t['qualified']),
      ),
      stages: [
        for (final s in (j['stages'] as List? ?? const []))
          if (s is Map<String, dynamic>) Stage.fromJson(s),
      ],
      recent: [
        for (final r in (j['recent'] as List? ?? const []))
          if (r is Map<String, dynamic>) RecentLead.fromJson(r),
      ],
    );
  }
}

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.dashboard));
  final res = await ref.watch(apiClientProvider).get<Object?>('/dashboard');
  return Dashboard.fromJson(res.data);
});
