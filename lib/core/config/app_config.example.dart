/// Example app-wide configuration template.
///
/// Copy this file to `lib/core/config/app_config.dart` and add your local values:
///   cp lib/core/config/app_config.example.dart lib/core/config/app_config.dart
///
/// You can also pass these at build time via --dart-define:
///   flutter run --dart-define=BACKEND_URL=...
class AppConfig {
  AppConfig._();

  /// Base URL of the Spendr Node.js backend.
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://spendr-backend-1.onrender.com',
  );
}

