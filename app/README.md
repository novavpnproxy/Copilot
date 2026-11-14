# NOVA VPN Flutter client

The user-facing client shows a single Connect/Disconnect control and no raw profile editor. It fetches active server metadata and requests a server profile only when connecting. The selected/last successful server is tried first, then each other active server once. A native `CONNECTED` status event is required before displaying success.

## Android setup

Install Flutter and the Android SDK. If platform scaffolding is absent, from this directory run:

```sh
flutter create --platforms=android --org=com.jeyrangroup --project-name=nova_vpn_app --no-pub .
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

The app requires `flutter_v2ray_client` for Android VPN permission and the Xray/V2Ray native engine. Build and verify on a real Android device; emulator/device tunnel behavior and each profile type require acceptance testing.

## Security boundary

The owner manages profiles separately at the backend `/admin` page. Public server metadata never includes raw configs. Profile delivery currently remains disabled (HTTP 503) until real user/device authorization and abuse controls are deployed. Do not replace this with a secret embedded in the APK. Profiles delivered to a user's device cannot be guaranteed to be impossible to extract; keep their lifetime/access limited and rotate them from the owner panel when needed.

Do not commit profiles or put them in the APK, UI, or logs. Use only test profiles you are authorized to use. The profiles pasted into chat should be treated as disclosed and unsuitable for private traffic.
