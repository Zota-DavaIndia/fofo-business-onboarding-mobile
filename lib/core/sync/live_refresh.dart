import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';

/// Groups of server data that can go stale. Providers that load one of
/// these watch its [liveSignalProvider], so bumping the signal refetches
/// them.
enum LiveTopic { dashboard, leads, visits, onboarding, alerts }

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

/// Keeps signed-in screens fresh: refetches when the app returns to the
/// foreground after [staleAfter], and on a slow timer while it stays open.
/// Push messages are the main real-time path; the timer only covers a late
/// or missed push. Nothing runs in the background.
class LiveRefresh extends ConsumerStatefulWidget {
  const LiveRefresh({
    super.key,
    required this.child,
    this.staleAfter = const Duration(seconds: 30),
    this.interval = const Duration(minutes: 3),
  });

  final Widget child;
  final Duration staleAfter;
  final Duration interval;

  @override
  ConsumerState<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends ConsumerState<LiveRefresh> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  DateTime _lastRefresh = clock.now();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume, onPause: _stopTimer, onHide: _stopTimer);
    _startTimer();
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
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _refreshAll() {
    if (ref.read(sessionProvider).value == null) return;
    _lastRefresh = clock.now();
    refreshTopics(ref, LiveTopic.values);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the session loaded so the timer and resume checks see it.
    ref.watch(sessionProvider);
    return widget.child;
  }
}
