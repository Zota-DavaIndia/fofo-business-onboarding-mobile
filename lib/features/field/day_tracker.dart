import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/masters.dart';
import 'field.dart';

/// Records the route while the working day runs: a position stream (kept
/// alive in the background by a foreground service on Android and background
/// location on iOS), batched to `POST /attendance/pings`. Pings wait in a file
/// when there's no network and go out with the next batch.
class DayTracker {
  DayTracker(this._ref);

  final Ref _ref;
  StreamSubscription<Position>? _sub;
  Timer? _flushTimer;
  final _pending = <Map<String, Object?>>[];
  bool _flushing = false;
  bool _loaded = false;

  bool get running => _sub != null;

  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/pending_pings.json');

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString());
        if (list is List) _pending.addAll(list.whereType<Map<String, Object?>>());
      }
    } catch (_) {
      // A broken file only loses unsent pings; the day itself is on the server.
    }
  }

  Future<void> _save() async {
    try {
      await (await _file()).writeAsString(jsonEncode(_pending));
    } catch (_) {}
  }

  /// Starts recording if it isn't already. Safe to call on every app start.
  Future<void> start() async {
    await _load();
    if (_sub != null) return;
    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        intervalDuration: const Duration(minutes: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Your working day is running',
          notificationText: 'Davaindia Field Force is recording your route until you end the day.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      ),
      _ => const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    };
    try {
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_add, onError: (_) {});
    } catch (_) {
      _sub = null;
      return;
    }
    _flushTimer = Timer.periodic(const Duration(minutes: 2), (_) => flush());
  }

  /// Stops recording and sends what's left.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }

  void _add(Position p) {
    _pending.add({
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy_m': p.accuracy,
      'is_mock_location': p.isMocked,
      'captured_at': isoWithOffset(p.timestamp),
    });
    _save();
    if (_pending.length >= 10) flush();
  }

  Future<void> flush() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    final batch = List<Map<String, Object?>>.of(_pending.take(500));
    try {
      await _ref.read(apiClientProvider).post<Object?>('/attendance/pings', body: {'pings': batch});
      _pending.removeRange(0, batch.length);
      await _save();
      _ref.invalidate(todayProvider);
    } catch (_) {
      // Offline or the day was ended elsewhere: keep them for the next try,
      // but don't let a dead day grow the file forever.
      if (_pending.length > 5000) _pending.removeRange(0, _pending.length - 5000);
    } finally {
      _flushing = false;
    }
  }
}

final dayTrackerProvider = Provider<DayTracker>((ref) {
  final t = DayTracker(ref);
  ref.onDispose(() => t.stop());
  return t;
});

/// Keeps the tracker in step with the server's day: on while started, off otherwise.
final dayTrackingProvider = Provider<void>((ref) {
  final can = ref.watch(sessionProvider).value?.can(Perm.attendanceMark) ?? false;
  final tracker = ref.watch(dayTrackerProvider);
  if (!can) {
    tracker.stop();
    return;
  }
  final today = ref.watch(todayProvider).value;
  if (today?.state == DayState.started) {
    tracker.start();
  } else if (today != null) {
    tracker.stop();
  }
});
