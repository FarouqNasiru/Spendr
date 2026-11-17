/// App-wide configuration resolved at build time via --dart-define.
///
/// Usage (local dev):
///   flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000
///
/// Usage (production build):
///   flutter build apk --release --dart-define=BACKEND_URL=https://spendr-backend-1.onrender.com
///
/// In CI, set the value via a GitHub Actions secret and pass it with
///   --dart-define=BACKEND_URL=${{ secrets.BACKEND_URL }}
class AppConfig {
  AppConfig._(); // prevent instantiation

  /// Base URL of the Spendr Node.js backend.
  /// Falls back to the production Render URL if not explicitly defined.
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://spendr-backend-1.onrender.com',
  );

  /// Convenience URLs for common local dev targets:
  ///   Android emulator  → http://10.0.2.2:3000
  ///   iOS simulator     → http://localhost:3000
  ///   Physical device   → http://<your-machine-LAN-IP>:3000
}

