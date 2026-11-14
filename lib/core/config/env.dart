/// Build-time settings, passed with `--dart-define-from-file=env/<name>.json`.
abstract final class Env {
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'local');

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2/davaindia-crm/public/api/v1',
  );

  /// `version.json` attached to the latest GitHub release.
  static const releasesUrl = String.fromEnvironment(
    'RELEASES_URL',
    defaultValue:
        'https://github.com/Zota-DavaIndia/fofo-business-onboarding-mobile/releases/latest/download/version.json',
  );

  /// Set by the release build from pubspec.yaml.
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

  static const isProduction = appEnv == 'production';

  /// Sample data instead of the CRM, for trying the app in a simulator.
  static const isDemo = appEnv == 'demo';
}
