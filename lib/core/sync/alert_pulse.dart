import 'dart:async';

/// A new alert from a pulse: `{id, type, title, body, entity?, entity_id?}`.
typedef PulseItem = Map<String, dynamic>;

/// The live check behind real-time alerts while the app is open: asks the server every
/// [interval] for alerts since the last answer, and reports only ones it hasn't seen.
/// The first answer just sets the starting point, so opening the app doesn't replay old alerts.
/// Push messages cover the app when it's closed; this covers it while it's on screen.
class AlertPulse {
  AlertPulse({required this.fetch, required this.onNew, this.interval = const Duration(seconds: 15)});

  /// Calls the pulse endpoint with `after` and returns its `data`.
  final Future<Map<String, dynamic>> Function(String? after) fetch;

  /// New alerts (oldest first) and the unread count. Also called with no items when only the count moved.
  final void Function(List<PulseItem> items, int unread) onNew;
  final Duration interval;

  Timer? _timer;
  String? _after;
  int? _unread;
  bool _busy = false;
  final _seen = <String>{};

  bool get running => _timer != null;

  void start() {
    if (_timer != null) return;
    tick();
    _timer = Timer.periodic(interval, (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forgets the starting point, e.g. after signing out.
  void reset() {
    stop();
    _after = null;
    _unread = null;
    _seen.clear();
  }

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final data = await fetch(_after);
      final first = _after == null;
      final unread = (data['unread_count'] as num?)?.toInt() ?? 0;
      final fresh = <PulseItem>[
        for (final i in (data['items'] as List? ?? const []))
          if (i is Map<String, dynamic> && _seen.add('${i['id']}')) i,
      ];
      if (_seen.length > 500) _seen.remove(_seen.first);
      _after = data['server_time'] as String? ?? _after;
      if (!first && (fresh.isNotEmpty || unread != _unread)) onNew(fresh, unread);
      _unread = unread;
    } catch (_) {
      // Offline or signed out: try again on the next tick.
    } finally {
      _busy = false;
    }
  }
}
