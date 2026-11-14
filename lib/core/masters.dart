import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/session.dart';
import 'network/api_client.dart';

/// A lead status from `/masters/statuses`: where it can move next and,
/// for exits, the reasons to pick from.
class StatusDef {
  const StatusDef({
    required this.code,
    required this.label,
    this.isExit = false,
    this.next = const [],
    this.reasons = const [],
  });

  final String code;
  final String label;
  final bool isExit;
  final List<String> next;
  final List<String> reasons;

  factory StatusDef.fromJson(Map<String, dynamic> j) => StatusDef(
    code: '${j['code']}',
    label: '${j['label'] ?? j['code']}',
    isExit: j['is_exit'] == true,
    next: [for (final n in (j['next'] as List? ?? const [])) '$n'],
    reasons: [for (final r in (j['reasons'] as List? ?? const [])) '$r'],
  );
}

/// A value and its label, for sources, users and similar pick lists.
typedef Choice = ({String value, String label});

/// `GET /app/config` values the field screens use.
class AppConfig {
  const AppConfig({
    this.geofenceRadiusM = 100,
    this.maxGpsAccuracyM = 50,
    this.uploadMaxMb = 10,
    this.otpDriver,
    this.enquiryTracking = false,
    this.field = const FieldOptions(),
  });

  final int geofenceRadiusM;
  final int maxGpsAccuracyM;
  final int uploadMaxMb;

  /// `fixed | sms | field`. With `field`, the field user issues sign-in
  /// codes to customers.
  final String? otpDriver;
  final bool enquiryTracking;

  bool get fieldIssuesCodes => otpDriver == 'field';

  /// Expense and leave choices; labels come from the server.
  final FieldOptions field;

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
    geofenceRadiusM: (j['geofence_radius_m'] as num?)?.toInt() ?? 100,
    maxGpsAccuracyM: (j['max_gps_accuracy_m'] as num?)?.toInt() ?? 50,
    uploadMaxMb: ((j['upload'] as Map?)?['max_mb'] as num?)?.toInt() ?? 10,
    otpDriver: (j['features'] as Map?)?['otp_driver'] as String?,
    enquiryTracking: (j['features'] as Map?)?['enquiry_tracking'] == true,
    field: j['field'] is Map<String, dynamic>
        ? FieldOptions.fromJson(j['field'] as Map<String, dynamic>)
        : const FieldOptions(),
  );
}

/// `{code, label}` choice lists for expenses and leave, from `GET /app/config`.
class FieldOptions {
  const FieldOptions({
    this.stations = const [('hq', 'HQ'), ('ex_hq', 'Ex-HQ'), ('outstation', 'Outstation')],
    this.categories = const [
      ('travel', 'Travel'),
      ('food', 'Food'),
      ('lodging', 'Lodging'),
      ('phone', 'Phone'),
      ('other', 'Other'),
    ],
    this.travelModes = const [
      ('bike', 'Bike'),
      ('car', 'Car'),
      ('bus', 'Bus'),
      ('train', 'Train'),
      ('auto', 'Auto'),
      ('other', 'Other'),
    ],
    this.leaveTypes = const [('casual', 'Casual'), ('sick', 'Sick'), ('earned', 'Earned'), ('unpaid', 'Unpaid')],
    this.receiptOver = 500,
    this.ticketCategories = const [
      ('product', 'Product'),
      ('software', 'Billing software'),
      ('dispatch', 'Dispatch'),
      ('accounts', 'Accounts'),
      ('other', 'Other'),
    ],
  });

  final List<(String, String)> stations;
  final List<(String, String)> categories;
  final List<(String, String)> travelModes;
  final List<(String, String)> leaveTypes;

  /// A claim above this needs a receipt photo.
  final double receiptOver;
  final List<(String, String)> ticketCategories;

  static List<(String, String)> _opts(Object? raw, List<(String, String)> fallback) {
    final out = <(String, String)>[
      for (final o in (raw is List ? raw : const []))
        if (o is Map && o['code'] != null) ('${o['code']}', '${o['label'] ?? o['code']}'),
    ];
    return out.isEmpty ? fallback : out;
  }

  factory FieldOptions.fromJson(Map<String, dynamic> j) {
    const d = FieldOptions();
    return FieldOptions(
      stations: _opts(j['expense_stations'], d.stations),
      categories: _opts(j['expense_categories'], d.categories),
      travelModes: _opts(j['travel_modes'], d.travelModes),
      leaveTypes: _opts(j['leave_types'], d.leaveTypes),
      receiptOver: (j['expense_receipt_over'] as num?)?.toDouble() ?? d.receiptOver,
      ticketCategories: _opts(j['ticket_categories'], d.ticketCategories),
    );
  }
}

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final res = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/app/config');
  return AppConfig.fromJson(res.data);
});

final statusesProvider = FutureProvider<Map<String, StatusDef>>((ref) async {
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/masters/statuses');
  return {
    for (final s in res.data)
      if (s is Map<String, dynamic>) '${s['code']}': StatusDef.fromJson(s),
  };
});

final sourcesProvider = FutureProvider<List<Choice>>((ref) async {
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/masters/sources');
  return [
    for (final s in res.data)
      if (s is Map) (value: '${s['code']}', label: '${s['label'] ?? s['code']}'),
  ];
});

/// People a lead can be handed to.
final fieldUsersProvider = FutureProvider.autoDispose<List<Choice>>((ref) async {
  final res = await ref.watch(apiClientProvider).get<List<dynamic>>('/masters/field-users');
  return [
    for (final u in res.data)
      if (u is Map) (value: '${u['id']}', label: [u['name'], u['designation']].whereType<String>().join(' · ')),
  ];
});

/// City and state for a pincode, or null when it isn't in the master.
Future<({String? city, String? state, bool serviceable})?> lookupPincode(ApiClient api, String pincode) async {
  try {
    final res = await api.get<Map<String, dynamic>>('/masters/pincodes/$pincode');
    final d = res.data;
    return (city: d['city'] as String?, state: d['state'] as String?, serviceable: d['serviceable'] == true);
  } catch (_) {
    return null;
  }
}

final _random = Random.secure();

/// Random UUID v4 for `client_uuid`, so a retried write isn't saved twice.
String newClientId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// ISO 8601 with the phone's offset, the way the API wants dates.
String isoWithOffset(DateTime d) {
  final local = d.toLocal();
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final hh = off.inHours.abs().toString().padLeft(2, '0');
  final mm = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}:${two(local.second)}$sign$hh:$mm';
}

/// "2026-11-14"
String isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
