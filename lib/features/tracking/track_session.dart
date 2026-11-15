import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/network/api_client.dart';
import 'track.dart';

/// API client for the enquiry tracking token. That token can only read
/// `/partner/track`, so it is kept apart from the staff session.
final trackApiProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(secureStoreProvider);
  return ApiClient(token: store.trackToken, onUnauthorized: () => ref.read(trackSessionProvider.notifier).signOut());
});

/// The signed-in enquirer's journey, or null when nobody is tracking.
final trackSessionProvider = AsyncNotifierProvider<TrackSession, Track?>(TrackSession.new);

class TrackSession extends AsyncNotifier<Track?> {
  @override
  Future<Track?> build() async {
    final store = ref.read(secureStoreProvider);
    if (await store.trackToken() == null) return null;
    try {
      return await _fetch();
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.status == 403) {
        await store.clearTrack();
        return null;
      }
      final cached = await store.lastTrack();
      if (cached != null) return Track.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      rethrow;
    }
  }

  Future<Track> _fetch() async {
    final res = await ref.read(trackApiProvider).get<Map<String, dynamic>>('/partner/track');
    await ref.read(secureStoreProvider).saveLastTrack(jsonEncode(res.data));
    return Track.fromJson(res.data);
  }

  /// Sends the OTP again. Throws [ApiException] (for example "wait 30 seconds").
  Future<void> resend(String mobile) async {
    await ref.read(apiClientProvider).post<dynamic>('/partner/auth/request-otp', body: {'mobile': mobile});
  }

  /// Throws [ApiException] with the server's message on a wrong or expired code.
  Future<void> verify({required String mobile, required String otp}) async {
    final store = ref.read(secureStoreProvider);
    final res = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/partner/auth/verify-otp',
          body: {
            'mobile': mobile,
            'otp': otp,
            'device_id': await store.deviceId(),
            'hardware_id': await store.hardwareId(),
            'platform': Platform.operatingSystem,
            'device_name': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim(),
          },
        );
    await store.saveTrackToken('${res.data['token']}');
    final track = res.data['track'];
    if (track is Map<String, dynamic>) {
      await store.saveLastTrack(jsonEncode(track));
      state = AsyncData(Track.fromJson(track));
    } else {
      state = AsyncData(await _fetch());
    }
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await _fetch());
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
    }
  }

  Future<void> signOut() async {
    final current = state.value;
    if (current?.accountType == 'partner') {
      try {
        await ref.read(trackApiProvider).post<dynamic>('/partner/auth/logout');
      } on ApiException {
        // The token is dropped on the phone either way.
      }
    }
    await ref.read(secureStoreProvider).clearTrack();
    state = const AsyncData(null);
  }
}
