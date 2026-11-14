# VPN server fallback behavior

When the user taps Connect, NOVA attempts the selected server first, then each other active server at most once in the order returned by the API. Each attempt fetches its profile just in time and waits up to 25 seconds for the engine's explicit `CONNECTED` event. A timeout or engine error stops that attempt and moves to the next server. VPN permission denial and backend profile-fetch failure stop the sequence because trying another server cannot fix those global failures. The app never reports Connected just because a start request returned.

This policy uses managed active server records; it does not embed a public proxy list. There is no infinite retry loop. Once a tunnel succeeds, auto-failover is not attempted during that session; recovery from later network changes remains a separate feature requiring device testing.

The current backend deliberately returns 503 for profile requests until client authorization and abuse controls are implemented, so this failover path cannot complete an actual tunnel test yet. Do not put the user's pasted public proxy profiles in Git or the APK. Public/shared credentials have been disclosed in this chat; treat them as exposed and do not rely on them for private traffic. Prefer owner-controlled test servers and rotate any credentials you control.
