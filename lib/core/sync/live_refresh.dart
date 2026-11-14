import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../push/push.dart';
import 'alert_pulse.dart';

/// Groups of server data that can go stale. Providers that load one of
/// these watch its [liveSignalProvider], so bumping the signal refetches
/// them.
enum LiveTopic { dashboard, leads, visits, onboarding, alerts, field }

class LiveSignal extends Notifier<int> {
  LiveSignal(this.topic);

  final LiveTopic topic;

  @override
  int build() => 0;

  void bump() => state++;
}

final liveSignalProvider = NotifierProvider.family<LiveSignal, int, LiveTopic>(LiveSignal.new);

/// Which topics a server event affects. Event types follow the backend's
/// push payload, e.g. `lead.assigned` or `payment.verified`.
Set<LiveTopic> topicsForEvent(String type) {
  final kind = type.split('.').first;
  return switch (kind) {
    'lead' => {LiveTopic.leads, LiveTopic.dashboard, LiveTopic.alerts},
    'visit' => {LiveTopic.visits, LiveTopic.dashboard, LiveTopic.alerts},
    'onboarding' ||
    'payment' ||
    'drug_licence' ||
    'store' ||
    'licence' => {LiveTopic.onboarding, LiveTopic.dashboard, LiveTopic.alerts},
    'expense' || 'leave' || 'ticket' || 'attendance' => {LiveTopic.field, LiveTopic.alerts},
    _ => {LiveTopic.alerts},
  };
}

void refreshTopics(WidgetRef ref, Iterable<LiveTopic> topics) {
  for (final t in topics) {
    ref.read(liveSignalProvider(t).notifier).bump();
  }
}

/// Call with the data of a push message (or any server event) to refetch
/// what it touched.
void handleServerEvent(WidgetRef ref, Map<String, dynamic> data) {
  final type = data['type'];
  if (type is String) refreshTopics(ref, topicsForEvent(type));
}

/// Keeps signed-in screens fresh: a live alert check every [pulseEvery] while
/// the app is on screen refetches exactly what a new alert touched and hands it
/// to [onAlerts]; everything refetches when the app returns after [staleAfter],
/// and on a slow timer as a safety net. Push messages cover the app while it's
/// closed. Nothing here runs in the background.
class LiveRefresh extends ConsumerStatefulWidget {
  const LiveRefresh({
    super.key,
    required this.child,
    this.onAlerts,
    this.onOpenPush,
    this.staleAfter = const Duration(seconds: 30),
    this.interval = const Duration(minutes: 3),
    this.pulseEvery = const Duration(seconds: 15),
  });

  final Widget child;

  /// New alerts while the app is open (oldest first), e.g. to show a toast.
  final void Function(BuildContext context, List<PulseItem> items)? onAlerts;

  /// The user tapped a push notification: open what it is about.
  final void Function(BuildContext context, String? entity, int? entityId)? onOpenPush;
  final Duration staleAfter;
  final Duration interval;

  /// Null turns the live alert check off (tests).
  final Duration? pulseEvery;

  @override
  ConsumerState<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends ConsumerState<LiveRefresh> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  DateTime _lastRefresh = clock.now();
  late final AlertPulse _pulse = AlertPulse(
    interval: widget.pulseEvery ?? const Duration(days: 1),
    fetch: (after) async {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/notifications/pulse', query: {'after': ?after});
      return res.data;
    },
    onNew: (items, unread) {
      final topics = <LiveTopic>{LiveTopic.alerts};
      for (final i in items) {
        final type = i['type'];
        if (type is String) topics.addAll(topicsForEvent(type));
      }
      if (!mounted) return;
      refreshTopics(ref, topics);
      if (items.isNotEmpty) widget.onAlerts?.call(context, items);
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume, onPause: _stopTimer, onHide: _stopTimer);
    _startTimer();
    final push = ref.read(pushServiceProvider)
      // A push while on screen: check now, so the alert shows once, through the pulse.
      ..onForeground = ((_) => _pulse.tick())
      ..onOpened = ((m) {
        if (mounted) widget.onOpenPush?.call(context, m.entity, m.entityId);
      });
    if (ref.read(sessionProvider).value != null) push.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _stopTimer();
    super.dispose();
  }

  void _onResume() {
    if (clock.now().difference(_lastRefresh) >= widget.staleAfter) _refreshAll();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _refreshAll());
    if (widget.pulseEvery != null) _pulse.start();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _pulse.stop();
  }

  void _refreshAll() {
    if (ref.read(sessionProvider).value == null) return;
    _lastRefresh = clock.now();
    refreshTopics(ref, LiveTopic.values);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the session loaded so the timer and resume checks see it; a new
    // sign-in starts the live check afresh.
    ref.listen(sessionProvider.select((s) => s.value?.id), (prev, next) {
      _pulse.reset();
      if (next != null && widget.pulseEvery != null) _pulse.start();
      final push = ref.read(pushServiceProvider);
      next == null ? push.stop() : push.start();
    });
    ref.watch(sessionProvider);
    return widget.child;
  }
}
