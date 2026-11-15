import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../config/env.dart';

/// Firebase settings for this build, from `--dart-define`s. Empty means push is off
/// and the app relies on the live alert check while it's open.
abstract final class PushConfig {
  /// Firebase makes one API key per platform, each locked to its app; this one is Android's.
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static String get appId => _ios ? iosAppId : androidAppId;

  static String get key => _ios && iosApiKey.isNotEmpty ? iosApiKey : apiKey;

  static bool get enabled => key.isNotEmpty && projectId.isNotEmpty && senderId.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: key,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: _ios ? 'com.gitcs.davaindia.ff' : null,
  );
}

/// The data part of a push: `{type, entity, entity_id, notification_id}` plus its title and body.
typedef PushMessage = ({String? type, String? entity, int? entityId, String? title, String? body});

PushMessage _parse(RemoteMessage m) => (
  type: m.data['type'] as String?,
  entity: (m.data['entity'] as String?)?.isEmpty ?? true ? null : m.data['entity'] as String?,
  entityId: int.tryParse('${m.data['entity_id'] ?? ''}'),
  title: m.notification?.title,
  body: m.notification?.body,
);

/// Registers this phone for pushes after sign-in and turns arriving pushes into callbacks.
/// Does nothing when the build has no Firebase settings.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _ready = false;
  final _subs = <StreamSubscription<Object?>>[];

  /// A push arrived while the app was on screen.
  void Function(PushMessage message)? onForeground;

  /// The user tapped a push (app in the background or closed).
  void Function(PushMessage message)? onOpened;

  Future<void> start() async {
    if (!PushConfig.enabled || _ready) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: PushConfig.options);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      _ready = true;
      // The CRM sends to registration tokens (FCM HTTP v1 `message.token`); register()/onRegistered
      // give installation IDs for the newer direct-send API, so the token calls stay until the server moves.
      // ignore: deprecated_member_use
      final token = await fm.getToken();
      if (token != null) await _register(token);
      _subs
        // ignore: deprecated_member_use
        ..add(fm.onTokenRefresh.listen(_register))
        ..add(FirebaseMessaging.onMessage.listen((m) => onForeground?.call(_parse(m))))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpened?.call(_parse(m))));
      final initial = await fm.getInitialMessage();
      if (initial != null) onOpened?.call(_parse(initial));
    } catch (_) {
      // No Play services, no APNs set up, or offline: the live check still covers the open app.
    }
  }

  Future<void> _register(String token) async {
    final store = _ref.read(secureStoreProvider);
    await _ref
        .read(apiClientProvider)
        .post<Object?>(
          '/devices',
          body: {
            'device_id': await store.deviceId(),
            'fcm_token': token,
            'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
            'app_version': Env.appVersion,
          },
        );
  }

  /// On sign-out: stop listening and drop the token so the next user starts fresh.
  /// The server also clears it when the session signs out.
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (_ready) {
      try {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    _ready = false;
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
