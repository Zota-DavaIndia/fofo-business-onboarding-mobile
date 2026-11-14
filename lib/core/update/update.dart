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
    final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))).get<dynamic>(Env.releasesUrl);
    final data = res.data;
    final j = data is Map<String, dynamic> ? data : null;
    if (j == null) return null;
    final r = Release.fromJson(j);
    return isNewer(r) ? r : null;
  } catch (_) {
    return null; // offline or no release yet
  }
});

/// Downloads the APK, checks it against the release's SHA-256, and hands it to the system installer
/// through the app's own Android code (`MainActivity`, channel `ff/updater`).
class Updater {
  static const _channel = MethodChannel('ff/updater');

  /// Whether Android lets this app install packages; false until the user allows it once.
  static Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Opens the "install unknown apps" setting for this app.
  static Future<void> openInstallSettings() => _channel.invokeMethod<void>('openInstallSettings');

  static Future<String> download(Release r, {void Function(double progress)? onProgress, CancelToken? cancel}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true); // old downloads
    dir.createSync(recursive: true);
    final path = '${dir.path}/davaindia-ff-${r.version}.apk';
    await Dio().download(
      r.apkUrl,
      path,
      cancelToken: cancel,
      onReceiveProgress: (got, total) {
        final all = total > 0 ? total : (r.size ?? 0);
        if (all > 0) onProgress?.call(got / all);
      },
    );
    if (r.sha256 != null) {
      final sum = await _channel.invokeMethod<String>('sha256', {'path': path});
      if (sum == null || sum.toLowerCase() != r.sha256!.toLowerCase()) {
        File(path).deleteSync();
        throw const UpdateException("The download didn't match the release. Try again.");
      }
    }
    return path;
  }

  static Future<void> install(String path) => _channel.invokeMethod<void>('install', {'path': path});
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
