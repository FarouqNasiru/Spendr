<div align="center">
  <img src="lib/assets/images/spendr_logo.png" alt="Spendr Logo" height="80"/>

  # Spendr

  **Good finances, better life.**

  A personal finance tracker built with Flutter — track expenses, manage income, upload bank statements, and go premium with Paystack payments.

  [![Flutter](https://img.shields.io/badge/Flutter-3.41.7-02569B?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.8.1-0175C2?logo=dart)](https://dart.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
  [![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
  [![Release](https://img.shields.io/github/v/release/FarouqNasiru/Spendr?color=lime)](https://github.com/FarouqNasiru/Spendr/releases)

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 📊 **Dashboard** | Visual spending charts (weekly / monthly / yearly) with income vs expense breakdown |
| ➕ **Transactions** | Add, categorise, and delete income & expense entries |
| 🗂 **Custom Categories** | Create your own expense and income categories with icons |
| 📄 **Statement Upload** | Upload a bank statement PDF/image; AI extracts transactions automatically |
| 💳 **Transfers** | Log and review inter-account transfers |
| 🔐 **PIN / Biometric Lock** | Protect the app with a PIN and Face ID / Touch ID |
| 🌙 **Dark Mode** | Full light and dark theme support |
| 💱 **Multi-Currency** | Switch between USD, EUR, GBP, and NGN |
| 🔔 **Reminders** | Scheduled daily / weekly / monthly notification reminders |
| ☁️ **Cloud Sync** | Firebase Auth + Firestore sync across devices |
| 👑 **Premium (Paystack)** | Unlock monthly/yearly Pro or buy single statement uploads |

---

## 🏗 Architecture

```
Spendr (Flutter — frontend)
│
├── lib/
│   ├── core/
│   │   ├── config/          ← Build-time config (AppConfig, --dart-define)
│   │   ├── constants/       ← Colors, text styles, assets
│   │   ├── providers/       ← State management (Provider)
│   │   ├── routes/          ← Named route definitions
│   │   ├── services/        ← Firebase, Ads, IAP, Notifications, Paystack
│   │   ├── theme/           ← Light/dark ThemeData
│   │   └── utils/           ← Formatters, validators, helpers
│   ├── models/              ← Data models (TransactionModel)
│   ├── screens/             ← Full-page UI screens
│   └── widgets/             ← Reusable UI components
│
└── android / ios / web / windows / macos / linux

spendr-backend (Node.js — separate repo)
│   https://github.com/FarouqNasiru/spendr-backend
│
└── Paystack payment init & verification, Firebase Admin SDK
    Deployed on: https://spendr-backend-1.onrender.com
```

> **Why split?**  
> The Paystack **secret key** must never live in the app bundle. All payment operations go through the backend. Firebase Auth and Firestore are accessed directly from the Flutter SDK (the standard pattern — Firebase client keys are not secret).

---

## 📂 File Structure

```
Spendr/
├── .github/
│   └── workflows/
│       └── android-release.yml     # CI: builds & releases APK on git tag
├── android/
│   └── app/
│       └── google-services.json    # Firebase Android config
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist # Firebase iOS config
├── lib/
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart     # Backend URL (--dart-define)
│   │   ├── constants/
│   │   │   ├── app_assets.dart
│   │   │   ├── app_colors.dart
│   │   │   └── app_text_styles.dart
│   │   ├── providers/
│   │   │   ├── auth_provider.dart          # Firebase Auth state
│   │   │   ├── category_provider.dart      # Custom categories
│   │   │   ├── category_mapping_provider.dart
│   │   │   ├── currency_provider.dart      # Selected currency
│   │   │   ├── premium_provider.dart       # Premium status
│   │   │   └── transaction_provider.dart   # Transaction list state
│   │   ├── routes/
│   │   │   └── app_routes.dart
│   │   ├── services/
│   │   │   ├── ad_service.dart             # Google Mobile Ads
│   │   │   ├── firestore_service.dart      # Cloud sync helpers
│   │   │   ├── iap_service.dart            # In-App Purchase
│   │   │   ├── notification_service.dart   # Local notifications
│   │   │   └── paystack_service.dart       # Payment checkout & verify
│   │   ├── theme/
│   │   │   ├── app_theme.dart              # Light & dark ThemeData
│   │   │   └── theme_provider.dart
│   │   └── utils/
│   │       ├── formatters.dart
│   │       ├── helpers.dart
│   │       └── validators.dart
│   ├── models/
│   │   └── transaction_model.dart
│   ├── screens/
│   │   ├── activitypage.dart           # Main dashboard
│   │   ├── add_category.dart
│   │   ├── add_transactions.dart
│   │   ├── auth_screen.dart            # Login / Sign-up
│   │   ├── billing_page.dart           # Premium plans
│   │   ├── enter_name.dart             # First-launch onboarding
│   │   ├── intro_screen.dart           # Splash / landing
│   │   ├── paystack_webview_screen.dart
│   │   ├── pin_lock_page.dart          # PIN setup & unlock
│   │   ├── review_transactions_page.dart
│   │   ├── settings.dart
│   │   ├── transfers_page.dart
│   │   └── upload_statement_page.dart
│   ├── utils/
│   │   ├── constants.dart              # Default categories
│   │   └── icon_mapper.dart
│   ├── widgets/
│   │   ├── button1.dart
│   │   └── cards_intro.dart
│   ├── firebase_options.dart           # Auto-generated by FlutterFire CLI
│   └── main.dart
├── firebase.json
├── pubspec.yaml
└── README.md
```

---

## 🚀 Running Locally

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | ≥ 3.41.7 | [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ≥ 3.8.1 | Bundled with Flutter |
| Android Studio / Xcode | Latest | For emulator / simulator |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| FlutterFire CLI | Latest | `dart pub global activate flutterfire_cli` |

### 1. Clone the repo

```bash
git clone https://github.com/FarouqNasiru/Spendr.git
cd Spendr
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Firebase setup

This project uses Firebase Auth and Firestore. The `firebase_options.dart` and `google-services.json` files are **not committed** to this repo (they contain project-specific identifiers).

To connect your own Firebase project:

```bash
# Login to Firebase
firebase login

# Configure FlutterFire (run from project root)
flutterfire configure
```

This generates `lib/firebase_options.dart` and places `google-services.json` / `GoogleService-Info.plist` in the correct platform folders.

> **Or**: if you have access to the original Firebase project, download `google-services.json` from Firebase Console → Project Settings → Android app, and place it at `android/app/google-services.json`.

### 4. Run the app

**Android emulator:**
```bash
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000
```

**iOS simulator:**
```bash
flutter run --dart-define=BACKEND_URL=http://localhost:3000
```

**Against production backend (default):**
```bash
flutter run
# BACKEND_URL defaults to https://spendr-backend-1.onrender.com
```

### 5. Backend (optional for local dev)

The backend only handles Paystack payments. If you're not testing payments, you can skip it. To run it locally:

```bash
git clone https://github.com/FarouqNasiru/spendr-backend.git
cd spendr-backend
npm install
cp .env.example .env   # fill in your keys
npm run dev            # starts on http://localhost:3000
```

---

## ⚙️ Environment & Configuration

All build-time config is handled via `--dart-define` flags. No `.env` file is needed for Flutter.

| Variable | Default | Description |
|---|---|---|
| `BACKEND_URL` | `https://spendr-backend-1.onrender.com` | Spendr Node.js backend URL |

Set it at build time:
```bash
flutter build apk --release --dart-define=BACKEND_URL=https://your-backend.onrender.com
```

---

## 🚢 Release & CI/CD

### Android APK

Releases are automated via GitHub Actions. On every git tag starting with `v`:

1. The workflow checks out the code
2. Builds a release APK (`flutter build apk --release`)
3. Creates a GitHub Release and attaches the APK

**To trigger a release:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

Download the latest APK from the [**Releases**](https://github.com/FarouqNasiru/Spendr/releases) page.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `BACKEND_URL` | Production backend URL passed to `--dart-define` |

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **UI Framework** | Flutter 3.x |
| **State Management** | Provider |
| **Authentication** | Firebase Auth (email/password + Google Sign-In) |
| **Database** | Cloud Firestore |
| **Payments** | Paystack (via Node.js backend) |
| **Charts** | fl_chart |
| **Local Storage** | shared_preferences, flutter_secure_storage |
| **Notifications** | flutter_local_notifications |
| **AI / Statement Parsing** | Google Generative AI (Gemini) |
| **Ads** | Google Mobile Ads |
| **In-App Purchase** | in_app_purchase |
| **Backend** | Node.js / Express (separate repo) |
| **Backend Hosting** | Render |

---

## 🔒 Security Notes

- Firebase API keys in `firebase_options.dart` are **not secret** — this is [the intended Firebase pattern](https://firebase.google.com/docs/projects/api-keys). Security is enforced by Firestore Security Rules.
- The Paystack **secret key** lives only on the backend — never in the app bundle.
- Firestore rules are scoped per authenticated user (`request.auth.uid == userId`).
- PIN and biometric data are stored using `flutter_secure_storage`.

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
  Built with ❤️ by <a href="https://github.com/FarouqNasiru">Farouq Nasiru</a>
</div>
