# NOVA VPN

NOVA VPN is an Android VPN client and a separately deployed server-management backend for JEYRAN GROUP.

## Status

The repository is being built incrementally. The backend database starts with **zero servers**. It does not claim that a server is online or that a VPN connection exists unless a real VPN engine confirms it. Raw profile delivery is intentionally disabled until end-user authorization and abuse controls are implemented.

## Layout

- `app/` — Flutter Android client.
- `backend/` — FastAPI service, SQLite persistence, and authenticated administrator UI/API.
- `docs/` — architecture and deployment/security notes.

## Development

See `backend/README.md` and `app/README.md` for setup. Do not put real server profiles, credentials, signing keys, or passwords in Git.

## Security notes

- Never commit administrator passwords, signing keys, API secrets, or real server configurations.
- The backend must be deployed behind HTTPS in production.
- A VPN profile delivered to a client device can potentially be extracted from that device. Hiding it in the UI does not make it secret.
- No production VPN engine or server is configured yet. The Flutter client does not present a pretend connection control.
