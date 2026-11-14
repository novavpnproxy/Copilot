# Flutter app

This folder starts the real client-side server directory. It fetches server metadata from the separate backend and does not bundle server profiles or invent entries.

## Run

Install Flutter for Android, then from this folder:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

The API URL is a deployment setting, not a credential. For local Android emulator development, use `http://10.0.2.2:8000` only with the Android cleartext-development setting enabled deliberately; do not ship HTTP in a release build.

## Current implementation boundary

The VPN engine is not yet integrated in this repository. Therefore this client does not show a pretend connect button or report a connection. Integration must use a supported Android `VpnService`-based engine, request Android VPN permission, consume the returned profile only at connection time, and update UI state only from engine status callbacks. Check the engine's exact package/API and supported protocol list before selecting its version. Real servers and profiles must be provided and tested by the owner; the app starts with an empty list.
