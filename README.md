# NOVA VPN

NOVA VPN is an Android VPN client and separately hosted server-management backend for JEYRAN GROUP.

## Project status

This repository is currently empty. The first implementation is being established on a dedicated development branch. No VPN servers or working configurations have been supplied, so none are bundled or shown as available. A connection is not reported as established until the VPN engine confirms it.

## Planned layout

- `app/` — Flutter Android client; server configuration is fetched only when needed and is never displayed in the user interface.
- `backend/` — separately deployed API and authenticated administrator interface for server metadata and configuration management.
- `docs/` — architecture, deployment, privacy, and release guidance.

## Security notes

- Never commit administrator passwords, signing keys, API secrets, or real server configurations.
- The backend must be deployed behind HTTPS before release.
- Any configuration delivered to a client device can potentially be extracted from that device. Hiding it in the UI is not equivalent to keeping it secret.
- Server locations and health are only shown when backed by verified metadata and real checks; no sample or placeholder servers are presented as functional.

See the project documentation as implementation is added.
