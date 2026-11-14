/// One stage of an enquiry's journey, as sent by `/partner/track`. Titles,
/// wording and order come from the server; the app never names steps itself.
enum JourneyState { done, waiting, action, rejected, upcoming, closed }

class TrackStep {
  const TrackStep({required this.key, required this.title, required this.state, this.who, this.detail, this.date});

  final String key;
  final String title;
  final String? who;
  final JourneyState state;
  final String? detail;
  final DateTime? date;

  factory TrackStep.fromJson(Map<String, dynamic> j) => TrackStep(
    key: '${j['key'] ?? ''}',
    title: '${j['title'] ?? ''}',
    who: _str(j['who']),
    state: _state(j['state']),
    detail: _str(j['detail']),
    date: _date(j['date']),
  );

  static JourneyState _state(Object? v) => switch ('$v') {
    'done' => JourneyState.done,
    'waiting' => JourneyState.waiting,
    'action' => JourneyState.action,
    'rejected' => JourneyState.rejected,
    'closed' => JourneyState.closed,
    _ => JourneyState.upcoming,
  };
}

class Contact {
  const Contact({this.name, this.phone, this.email});

  final String? name;
  final String? phone;
  final String? email;

  bool get isEmpty => (name ?? '').isEmpty && (phone ?? '').isEmpty && (email ?? '').isEmpty;

  static Contact? fromJson(Object? j, {String phoneKey = 'phone'}) {
    if (j is! Map) return null;
    final c = Contact(name: _str(j['name']), phone: _str(j[phoneKey] ?? j['phone']), email: _str(j['email']));
    return c.isEmpty ? null : c;
  }
}

/// The whole journey of one enquiry, from `/partner/track`.
class Track {
  const Track({
    required this.accountType,
    required this.name,
    required this.reference,
    required this.done,
    required this.total,
    required this.steps,
    this.headline,
    this.storeName,
    this.storeCode,
    this.areaManager,
    this.support,
    this.signInAgain = false,
    this.mobile,
    this.leadReference,
  });

  final String accountType;
  final String name;
  final String? mobile;

  /// The enquiry's lead number, kept after approval for reference.
  final String? leadReference;

  /// Lead number before approval, partner number after.
  final String reference;
  final String? headline;
  final String? storeName;
  final String? storeCode;
  final int done;
  final int total;
  final List<TrackStep> steps;
  final Contact? areaManager;
  final Contact? support;

  /// Approved while signed in with the enquiry token: sign in again.
  final bool signInAgain;

  double get progress => total <= 0 ? 0 : (done / total).clamp(0, 1).toDouble();

  factory Track.fromJson(Map<String, dynamic> j) => Track(
    accountType: '${j['account_type'] ?? 'enquirer'}',
    name: '${j['name'] ?? ''}',
    reference: _str(j['partner_no']) ?? _str(j['reference']) ?? '',
    mobile: _str(j['mobile']),
    leadReference: _str(j['reference']),
    headline: _str(j['headline']),
    storeName: _str(j['store_name']),
    storeCode: _str(j['store_code']),
    done: _int(j['done']),
    total: _int(j['total']),
    steps: [
      for (final s in (j['steps'] as List? ?? const []))
        if (s is Map<String, dynamic>) TrackStep.fromJson(s),
    ],
    areaManager: Contact.fromJson(j['area_manager'], phoneKey: 'mobile'),
    support: Contact.fromJson(j['support']),
    signInAgain: j['sign_in_again'] == true,
  );
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
