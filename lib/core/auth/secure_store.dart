import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token and device id, kept in the platform keystore.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _tokenKey = 'auth_token';
  static const _deviceKey = 'device_id';
  static const _userKey = 'auth_user';
  static const _trackTokenKey = 'track_token';
  static const _trackKey = 'track_last';

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

  /// Token from the enquiry OTP sign-in. It can only read /partner/track.
  Future<String?> trackToken() => _s.read(key: _trackTokenKey);

  Future<void> saveTrackToken(String token) => _s.write(key: _trackTokenKey, value: token);

  /// Last /partner/track response, so the journey opens offline.
  Future<String?> lastTrack() => _s.read(key: _trackKey);

  Future<void> saveLastTrack(String json) => _s.write(key: _trackKey, value: json);

  Future<void> clearTrack() async {
    await _s.delete(key: _trackTokenKey);
    await _s.delete(key: _trackKey);
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
