import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/sync/live_refresh.dart';
import '../leads/lead.dart' show date, str;

/// `date()` from leads, under a name the `date` fields below don't shadow.
DateTime? _at(Object? v) => date(v);

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

// ── working day ──────────────────────────────────────────────────────────

enum DayState {
  notStarted,
  started,
  ended;

  static DayState parse(Object? v) => switch (v) {
    'started' => started,
    'ended' => ended,
    _ => notStarted,
  };
}

class WorkDay {
  const WorkDay({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.endedBySystem = false,
    this.distanceKm = 0,
    this.pings = 0,
    this.date,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool endedBySystem;
  final double distanceKm;
  final int pings;
  final DateTime? date;

  factory WorkDay.fromJson(Map<String, dynamic> j) => WorkDay(
    id: (j['id'] as num).toInt(),
    startedAt: _at(j['started_at']) ?? DateTime.now(),
    endedAt: _at(j['ended_at']),
    endedBySystem: j['ended_by_system'] == true,
    distanceKm: _num(j['distance_km']),
    pings: (j['pings'] as num?)?.toInt() ?? 0,
    date: DateTime.tryParse('${j['date']}'),
  );
}

typedef Today = ({DayState state, WorkDay? day});

Today parseToday(Object? data) {
  final j = data is Map ? data : const {};
  return (
    state: DayState.parse(j['state']),
    day: j['day'] is Map<String, dynamic> ? WorkDay.fromJson(j['day'] as Map<String, dynamic>) : null,
  );
}

final todayProvider = FutureProvider<Today>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref.watch(apiClientProvider).get<Object?>('/attendance/today');
  return parseToday(res.data);
});

// ── expenses ─────────────────────────────────────────────────────────────

enum ExpenseStatus {
  draft('To submit'),
  submitted('Submitted'),
  approved('Approved'),
  rejected('Rejected');

  const ExpenseStatus(this.label);

  final String label;

  static ExpenseStatus parse(Object? v) => values.where((s) => s.name == v).firstOrNull ?? draft;
}

class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.station,
    required this.stationLabel,
    required this.category,
    required this.categoryLabel,
    required this.amount,
    required this.status,
    this.travelMode,
    this.travelModeLabel,
    this.distanceKm,
    this.description,
    this.receiptUrl,
    this.approvedAmount,
    this.reviewNote,
  });

  final int id;
  final DateTime date;
  final String station;
  final String stationLabel;
  final String category;
  final String categoryLabel;
  final double amount;
  final ExpenseStatus status;
  final String? travelMode;
  final String? travelModeLabel;
  final double? distanceKm;
  final String? description;
  final String? receiptUrl;
  final double? approvedAmount;
  final String? reviewNote;

  bool get canEdit => status == ExpenseStatus.draft;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: (j['id'] as num).toInt(),
    date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
    station: '${j['station']}',
    stationLabel: '${j['station_label'] ?? j['station']}',
    category: '${j['category']}',
    categoryLabel: '${j['category_label'] ?? j['category']}',
    amount: _num(j['amount']),
    status: ExpenseStatus.parse(j['status']),
    travelMode: str(j['travel_mode']),
    travelModeLabel: str(j['travel_mode_label']),
    distanceKm: j['distance_km'] == null ? null : _num(j['distance_km']),
    description: str(j['description']),
    receiptUrl: str(j['receipt_url']),
    approvedAmount: j['approved_amount'] == null ? null : _num(j['approved_amount']),
    reviewNote: str(j['review_note']),
  );
}

typedef ExpenseMonth = ({List<Expense> items, Map<ExpenseStatus, double> totals});

/// The month shown on the Expenses screen, as `YYYY-MM`.
final expenseMonthProvider = NotifierProvider<ExpenseMonthNotifier, DateTime>(ExpenseMonthNotifier.new);

class ExpenseMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void shift(int months) => state = DateTime(state.year, state.month + months);
}

String monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

final expensesProvider = FutureProvider.autoDispose.family<ExpenseMonth, String>((ref, month) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/expenses', query: {'month': month});
  final t = (res.meta?['totals'] as Map?) ?? const {};
  return (
    items: [
      for (final e in res.data)
        if (e is Map<String, dynamic>) Expense.fromJson(e),
    ],
    totals: {for (final s in ExpenseStatus.values) s: _num(t[s.name])},
  );
});

// ── leave ────────────────────────────────────────────────────────────────

enum LeaveStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const LeaveStatus(this.label);

  final String label;

  static LeaveStatus parse(Object? v) => values.where((s) => s.name == v).firstOrNull ?? pending;
}

class Leave {
  const Leave({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.from,
    required this.to,
    required this.days,
    required this.reason,
    required this.status,
    this.halfDay = false,
    this.reviewNote,
    this.canCancel = false,
  });

  final int id;
  final String type;
  final String typeLabel;
  final DateTime from;
  final DateTime to;
  final double days;
  final String reason;
  final LeaveStatus status;
  final bool halfDay;
  final String? reviewNote;
  final bool canCancel;

  factory Leave.fromJson(Map<String, dynamic> j) => Leave(
    id: (j['id'] as num).toInt(),
    type: '${j['type']}',
    typeLabel: '${j['type_label'] ?? j['type']}',
    from: DateTime.tryParse('${j['from_date']}') ?? DateTime.now(),
    to: DateTime.tryParse('${j['to_date']}') ?? DateTime.now(),
    days: _num(j['days']),
    reason: '${j['reason'] ?? ''}',
    status: LeaveStatus.parse(j['status']),
    halfDay: j['half_day'] == true,
    reviewNote: str(j['review_note']),
    canCancel: j['can_cancel'] == true,
  );
}

typedef LeaveYear = ({List<Leave> items, List<({String type, String label, double days})> taken, int pending});

final leavesProvider = FutureProvider.autoDispose<LeaveYear>((ref) async {
  ref.watch(liveSignalProvider(LiveTopic.field));
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/leaves');
  final meta = res.meta ?? const {};
  return (
    items: [
      for (final l in res.data)
        if (l is Map<String, dynamic>) Leave.fromJson(l),
    ],
    taken: [
      for (final t in (meta['taken'] as List? ?? const []))
        if (t is Map) (type: '${t['type']}', label: '${t['label'] ?? t['type']}', days: _num(t['days'])),
    ],
    pending: (meta['pending'] as num?)?.toInt() ?? 0,
  );
});

/// "1", "0.5", "2.5" days.
String formatDays(double d) => d == d.roundToDouble() ? '${d.toInt()}' : d.toStringAsFixed(1);

/// "₹1,180" (no paise when whole).
String formatRupees(double v) {
  final whole = v == v.roundToDouble();
  final parts = (whole ? v.toInt().toString() : v.toStringAsFixed(2)).split('.');
  final digits = parts.first;
  // Indian grouping: last three, then pairs.
  final buf = StringBuffer();
  final n = digits.length;
  for (var i = 0; i < n; i++) {
    buf.write(digits[i]);
    final left = n - i - 1;
    if (left > 0 && (left == 3 || (left > 3 && (left - 3) % 2 == 0))) buf.write(',');
  }
  return '₹$buf${parts.length > 1 ? '.${parts[1]}' : ''}';
}
