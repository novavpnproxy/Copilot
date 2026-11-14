# Architecture and release gates

## Data flow

1. The owner uses the separate `/admin` site and authenticated admin API to add, change, disable, or remove server records.
2. The Android app requests active display metadata from `GET /api/v1/servers`. Configurations are not part of this response.
3. A future VPN-engine integration will request `GET /api/v1/servers/{id}/config` only on connection. The app must keep profiles out of logs and UI, and clear in-memory copies when no longer needed.
4. The engine's actual Android VPN service status—not the API request succeeding—must be the source of connected/disconnected UI state.

## Real-world status

This initial implementation has an empty database. It contains no sample server, no inferred location, no synthetic ping, no traffic statistics, and no operational VPN engine. Admin-set location is only shown after the owner marks it verified; this is not automatic geolocation validation.

## Production gates

- Integrate and verify a maintained Android VPN engine and its license/protocol support.
- Add Android VPN permission/service setup, lifecycle handling, connection timeout/error states, and device-level tests with owner-provided servers.
- Design end-user authorization and abuse controls before exposing profile delivery publicly. A token embedded in an APK is extractable; profiles delivered to a device cannot be kept secret from its owner.
- Deploy behind HTTPS, configure backups and database migrations, rotate credentials, protect admin access, and perform security review.
- Add a privacy policy and only then consider advertising SDKs; no ad/analytics code is included.
