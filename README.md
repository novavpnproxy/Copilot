# NOVA VPN

## Current work

- Flutter Android client with bilingual server directory, refresh, saved selection, and a real Xray/V2Ray engine adapter.
- Admin-managed backend with an empty-by-default server catalog. Public profile delivery remains disabled until end-user authorization and abuse controls are ready.
- Connection attempt order: selected server first, then other active servers once each. Each candidate must produce an explicit engine `CONNECTED` event within the timeout; failures move on. Permission and backend access failures stop the sequence.
- No public/shared proxy credentials are committed or bundled.

## Security and test status

The profile links pasted in conversation should be treated as exposed public credentials. They have not been copied into this repository. A test profile must not be stored in a public repo or APK. No actual Android build, successful tunnel, or server health check has been claimed. See `docs/FAILOVER.md`, `docs/ENGINE_INTEGRATION.md`, and `docs/TESTING_PLAN.md`.
