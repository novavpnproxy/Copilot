# Secure owner panel and VPN profile delivery

## Owner-only management

The owner dashboard is served at `/admin`, separately from the Flutter app. Use it only through HTTPS with a unique administrator username/password. Configure `ADMIN_USERNAME`, a randomly generated `ADMIN_PASSWORD` (at least 16 characters), and a random `JWT_SECRET` (at least 32 characters) as deployment secrets; never put them in the mobile app or source control. The dashboard uses a short-lived bearer token and the API returns `no-store` for admin responses. Login throttling in this single-process app is a basic defense; configure rate limiting at the trusted reverse proxy/WAF too, especially for multi-worker or multi-instance deployments. Do not trust forwarded client-IP headers unless the proxy is explicitly configured as trusted.

The URL itself is not a security boundary. Protect `/admin` using HTTPS, the credentials above, network restrictions or an identity-aware proxy where possible, and routine secret rotation. Do not expose the development server directly to the internet.

## User app and profiles

The app client should contain only the server directory and Connect/Disconnect controls. Public server responses do not include raw configuration. Profile delivery is intentionally `503` until real user/device authorization and abuse controls are deployed. Do not replace this with an API key embedded in the APK: a mobile app binary is inspectable, and a public profile endpoint would expose every active profile.

Once an authorization design is provisioned, the app should request a profile just in time over HTTPS, keep it only in memory as long as needed, and pass it to the native VPN engine. The device owner can still inspect data delivered to their device; no client-side design can guarantee that a delivered profile is impossible to extract. Replacing a profile in the owner panel takes effect on the next connection without a new APK.

## Validation and tests

Run `pytest -q` from `backend/`. Tests verify that the directory omits profiles, admin routes require authenticated tokens, login attempts are throttled, the profile endpoint fails closed, and profile validation checks supported schemes and protocol matching. The login limiter is process-local and is not a substitute for production edge rate limiting.
