import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token and device id, kept in the platform keystore.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _tokenKey = 'auth_token';
  static const _deviceKey = 'device_id';
  static const _userKey = 'auth_user';

  String? _cachedToken;

  Future<String?> token() async => _cachedToken ??= await _s.read(key: _tokenKey);

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _s.write(key: _tokenKey, value: token);
  }

  /// Last `/auth/me` response, so the app can open offline.
  Future<String?> user() => _s.read(key: _userKey);

  Future<void> saveUser(String json) => _s.write(key: _userKey, value: json);

  Future<void> clearSession() async {
    _cachedToken = null;
    await _s.delete(key: _tokenKey);
    await _s.delete(key: _userKey);
  }

  /// Stable id for this install, sent at login so an admin can approve
  /// the device. Created once.
  Future<String> deviceId() async {
    final existing = await _s.read(key: _deviceKey);
    if (existing != null) return existing;
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _s.write(key: _deviceKey, value: id);
    return id;
  }
}
