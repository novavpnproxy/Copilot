# VPN server fallback behavior

When the user taps Connect, NOVA attempts the selected server first, then each other active server at most once in the order returned by the API. Each attempt fetches its profile just in time and waits for the native engine to emit `CONNECTED`. A timeout or engine failure stops that attempt and moves to the next server. VPN permission denial and backend profile-fetch failure stop the sequence because trying another server cannot fix those global failures. Each native attempt has a finite timeout; the overall attempt count is finite too.

The candidate loop is implemented as a small isolated helper with automated tests for success-after-failure, fatal errors, exhaustion, and empty lists. No exception text or profile is retained in failover errors.

This policy uses managed active server records; it does not embed or scan a public proxy list. There is no infinite retry loop. Once a tunnel succeeds, auto-failover is not attempted during that session; recovery from later network changes remains a separate feature requiring device testing.

The backend currently returns 503 for profile requests until client authorization and abuse controls are implemented, so this path cannot complete an actual tunnel test yet. Do not put public/shared proxy credentials in Git, app assets, or an APK. Profiles pasted in chat should be treated as exposed; use only owner-controlled test infrastructure and rotate any credentials you control.
