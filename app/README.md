# Flutter app

Flutter Android client for NOVA VPN. It retrieves only active server metadata from the separate backend; the server directory contains no profile/configuration field. The initial database is empty, so the app does not invent available locations.

## Run

Install Flutter and Android SDK, then from this folder:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

The API URL is a deployment setting, not a credential. For local Android emulator development, use a local backend address only after explicitly enabling cleartext traffic in a debug-only Android manifest; never ship that setting in a release build.

## Current implementation boundary

The splash, server directory, refresh, saved selection, and basic settings UI exist. The VPN engine is **not integrated**. The app deliberately has no connect/disconnect button and does not report a connection until a maintained Android `VpnService`-based engine is selected, integrated, tested with owner-provided profiles, and its status callbacks are wired. Backend profile delivery is also disabled pending user authentication and abuse controls.

No ping, speed, traffic, user statistics, advertisements, unsupported settings, or sample servers are displayed.
