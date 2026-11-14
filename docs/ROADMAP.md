# Continuation notes

The owner has granted general approval to continue routine implementation in this repository and development branch without asking for confirmation at each step. This does not imply that production credentials, real VPN server profiles, hosting, paid services, or release/signing actions are available or authorized. Do not invent server data or report unverified implementation/testing as complete.

## Current committed foundation

- Branch: `nova-vpn-foundation`
- Backend: authenticated admin login, SQLite server records, admin CRUD, public metadata endpoint, on-demand profile endpoint. Database starts empty.
- Flutter: metadata-only server directory, refresh, saved selected server, settings/language preference. VPN engine is not integrated.

## Immediate known issues to resolve

- `app/pubspec.yaml` indentation was corrected in the next commit; maintain valid YAML.
- Add unit/API tests; no test suite or build verification has yet been run.
- Hardening: enforce `location_verified` implies a country code and names; validate protocol/profile compatibility rather than trusting admin label; add rate limiting at proxy, audit events that never include secrets, and database migrations/backups.
- Improve Flutter localization: current language preference is saved but the whole app does not yet rebuild/localize when changed.
- Implement the VPN engine only after checking a maintained plugin's supported profiles and actual Android status callbacks. Never set Connected optimistically on start request.
- The backend public profile endpoint currently has no end-user auth/entitlement or effective request rate limit. Do not launch publicly until access/abuse controls and HTTPS are in place.
