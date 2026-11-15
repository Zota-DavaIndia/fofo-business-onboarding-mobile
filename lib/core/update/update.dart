import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../config/env.dart';

/// Build number of this app, set by the release workflow (0 in local builds).
const appBuild = int.fromEnvironment('APP_BUILD');

/// The latest release, from `version.json` on GitHub Releases.
class Release {
  const Release({required this.version, required this.build, required this.apkUrl, this.sha256, this.size});

  final String version;
  final int build;
  final String apkUrl;
  final String? sha256;
  final int? size;

  factory Release.fromJson(Map<String, dynamic> j) => Release(
    version: '${j['version']}',
    build: (j['build'] as num?)?.toInt() ?? 0,
    apkUrl: '${j['apk_url']}',
    sha256: j['sha256'] as String?,
    size: (j['size'] as num?)?.toInt(),
  );

  /// "58 MB"
  String? get sizeLabel => size == null ? null : '${(size! / (1024 * 1024)).round()} MB';
}

/// Compares dotted versions numerically: "1.10.0" is after "1.9.2". Missing parts count as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Reads `version.json`. GitHub serves release files as `application/octet-stream`, so Dio hands over
/// text (or bytes) rather than a decoded map; anything that isn't a release object gives null.
Release? releaseFrom(Object? data) {
  try {
    final decoded = switch (data) {
      final String text => jsonDecode(text),
      final List<int> bytes => jsonDecode(utf8.decode(bytes)),
      _ => data,
    };
    return decoded is Map<String, dynamic> && decoded['version'] != null && decoded['apk_url'] != null
        ? Release.fromJson(decoded)
        : null;
  } on FormatException {
    return null;
  }
}

/// True when [r] is newer than the running app.
bool isNewer(Release r, {String current = Env.appVersion, int currentBuild = appBuild}) {
  final c = compareVersions(r.version, current);
  return c > 0 || (c == 0 && currentBuild > 0 && r.build > currentBuild);
}

/// Updates install from GitHub Releases on Android only (iOS goes through the App Store or TestFlight).
bool get selfUpdates => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The latest release when it is newer than this app, else null. Checked on Android only.
final availableUpdateProvider = FutureProvider<Release?>((ref) async {
  if (!selfUpdates) return null;
  try {
    final res = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
      ),
    ).get<String>(Env.releasesUrl);
    final r = releaseFrom(res.data);
    return r != null && isNewer(r) ? r : null;
  } catch (_) {
    return null; // offline or no release yet
  }
});

/// Downloads the APK, checks it against the release's SHA-256, and hands it to the system installer
/// through the app's own Android code (`MainActivity`, channel `ff/updater`).
class Updater {
  static const _channel = MethodChannel('ff/updater');

  static Future<String>? _pending;
  static String? _pendingKey;
  static CancelToken? _cancel;

  /// Stops the running download; its partial file is deleted. The next check (or a tap on Update) starts over.
  static void cancel() => _cancel?.cancel('stopped');

  /// Whether [e] came from [cancel] rather than a failure, so callers can stay quiet about it.
  static bool cancelled(Object e) => e is DioException && CancelToken.isCancel(e);

  /// Download progress from 0 to 1 while a download runs, else null.
  static final progress = ValueNotifier<double?>(null);

  /// The checked APK once a download has finished, so screens can offer Install straight away.
  static final ready = ValueNotifier<({Release release, String path})?>(null);

  /// Whether Android lets this app install packages; false until the user allows it once.
  static Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Opens the "install unknown apps" setting for this app.
  static Future<void> openInstallSettings() => _channel.invokeMethod<void>('openInstallSettings');

  /// The checked APK for [r]. One download per release: a second call while it runs joins it, a call after
  /// it finished gets the same file, and an APK already on the phone from an earlier launch is reused.
  static Future<String> fetch(Release r) {
    final key = '${r.version}+${r.build}';
    if (_pending != null && _pendingKey == key) return _pending!;
    _pendingKey = key;
    final f = _download(r);
    _pending = f;
    f.then(
      (path) => ready.value = (release: r, path: path),
      onError: (_) {
        if (identical(_pending, f)) _pending = null; // let the next call try again
      },
    );
    return f;
  }

  static Future<String> _download(Release r) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    final path = '${dir.path}/davaindia-ff-${r.version}-${r.build}.apk';
    dir.createSync(recursive: true);
    for (final f in dir.listSync()) {
      if (f.path != path) f.deleteSync(recursive: true); // older releases
    }
    final file = File(path);
    if (file.existsSync() && (r.size == null || file.lengthSync() == r.size) && await _matches(r, path)) return path;
    progress.value = 0;
    final cancel = _cancel = CancelToken();
    try {
      await Dio().download(
        r.apkUrl,
        path,
        cancelToken: cancel,
        onReceiveProgress: (got, total) {
          final all = total > 0 ? total : (r.size ?? 0);
          if (all > 0) progress.value = got / all;
        },
      );
    } finally {
      progress.value = null;
      if (identical(_cancel, cancel)) _cancel = null;
    }
    if (!await _matches(r, path)) {
      file.deleteSync();
      throw const UpdateException("The download didn't match the release. Try again.");
    }
    return path;
  }

  static Future<bool> _matches(Release r, String path) async {
    if (r.sha256 == null) return true;
    final sum = await _channel.invokeMethod<String>('sha256', {'path': path});
    return sum != null && sum.toLowerCase() == r.sha256!.toLowerCase();
  }

  static Future<void> install(String path) => _channel.invokeMethod<void>('install', {'path': path});
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
