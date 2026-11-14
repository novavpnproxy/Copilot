# NOVA VPN

NOVA VPN is an Android VPN client and a separately deployed server-management backend for JEYRAN GROUP.

## Status

The repository is being built incrementally. No real server configurations have been supplied, so the service starts with **zero servers**. It does not claim that a server is online or that a VPN connection exists unless a real VPN engine confirms it.

## Layout

- `app/` — Flutter Android client.
- `backend/` — FastAPI service, SQLite persistence, and authenticated administrator UI/API.
- `docs/` — architecture and deployment/security notes.

## Development

See `backend/README.md` and `app/README.md` for setup. Do not put real server profiles, credentials, signing keys, or passwords in Git.

## Important security limitation

A VPN profile delivered to a client device can potentially be extracted from that device. Hiding a profile from the UI does not make it secret. The admin interface and API must be served over HTTPS in production; the admin password and signing secret must be strong, unique, and stored outside the repository. No production VPN engine or server is configured by this initial commit.
