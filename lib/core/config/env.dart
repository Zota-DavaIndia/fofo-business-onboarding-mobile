/// Build-time settings, passed with `--dart-define-from-file=env/<name>.json`.
abstract final class Env {
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'local');

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://davaindiafofo.gitcsdemoserver.online/api/v1',
  );

  /// `version.json` attached to the latest GitHub release.
  static const releasesUrl = String.fromEnvironment(
    'RELEASES_URL',
    defaultValue:
        'https://github.com/Zota-DavaIndia/fofo-business-onboarding-mobile/releases/latest/download/version.json',
  );

  /// Set by the release build from pubspec.yaml.
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static const isProduction = appEnv == 'production';

  /// True when the build has a Google Maps key (MAPS_API_KEY); otherwise maps fall back to a link.
  static const mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');
}
