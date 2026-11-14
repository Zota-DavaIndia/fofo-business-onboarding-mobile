import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../network/api_client.dart';
import 'login_id.dart';
import 'secure_store.dart';
import 'user.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(secureStoreProvider);
  return ApiClient(token: store.token, onUnauthorized: () => ref.read(sessionProvider.notifier).signedOut());
});

/// The signed-in user, or null when signed out.
final sessionProvider = AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);

class SessionController extends AsyncNotifier<AppUser?> {
  SecureStore get _store => ref.read(secureStoreProvider);
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<AppUser?> build() async {
    if (await _store.token() == null) return null;
    try {
      final res = await _api.get<Map<String, dynamic>>('/auth/me');
      await _store.saveUser(jsonEncode(res.data));
      return AppUser.fromJson(res.data);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _store.clearSession();
        return null;
      }
      // Offline or server down: open with the last known user.
      final cached = await _store.user();
      if (cached != null) return AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      rethrow;
    }
  }

  /// Throws [ApiException] on failure so the login form can show it.
  Future<void> login({required LoginId id, required String password}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        id.field: id.value,
        'password': password,
        'device_id': await _store.deviceId(),
        'device_name': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim(),
        'platform': Platform.operatingSystem,
        'app_version': Env.appVersion,
      },
    );
    final user = res.data['user'] as Map<String, dynamic>;
    await _store.saveToken('${res.data['token']}');
    await _store.saveUser(jsonEncode(user));
    state = AsyncData(AppUser.fromJson(user));
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } on ApiException {
      // Signing out locally is enough if the server can't be reached.
    }
    await signedOut();
  }

  Future<void> signedOut() async {
    await _store.clearSession();
    state = const AsyncData(null);
  }
}
