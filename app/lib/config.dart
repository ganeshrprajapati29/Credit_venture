/// Build-time configuration.
///
/// Set the API URL when building the APK:
///   flutter build apk --release --dart-define=API_URL=https://api.yourdomain.com/api/v1
class AppConfig {
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.72.60.41.224.sslip.io/api/v1');

  static const String appName = 'Credit Ventures';
}
