# NOVA VPN Flutter client

The user-facing app has a single Connect/Disconnect control; it does not display raw profiles or provide configuration-management UI. The owner manages profiles through the separate backend `/admin` dashboard.

## Android setup

Install Flutter and the Android SDK. From this directory:

```sh
flutter create --platforms=android --org=com.jeyrangroup --project-name=nova_vpn_app --no-pub .
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example
```

On Connect the app refreshes the active server directory, tries the last successful server first, then each other active server at most once. Profiles are requested just in time and held only in memory. The app considers a tunnel connected only after a native `CONNECTED` event. Connection attempts have a finite timeout.

## Important security and test status

The backend profile endpoint currently returns HTTP 503 until real user/device authorization and abuse controls are deployed. Do not remove that fail-closed behavior or embed a shared key in the APK. The Connect/Disconnect UI is ready, but a real managed-profile connection is not available until the backend authorization work is completed. A profile delivered to a user device cannot be guaranteed to be impossible to extract.

Build and test on an Android device before release. Never commit profiles or use public profiles pasted in chats for private traffic; consider those credentials disclosed. No build or real tunnel test is claimed from repository edits alone.
