# Backend

FastAPI API plus a separate authenticated owner dashboard at `/admin`. The database begins empty: no sample or presumed-working VPN servers are inserted.

## Local run

Python 3.12 is recommended. From `backend/`:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Edit `.env`: set a unique administrator password (at least 16 characters) and a randomly generated `JWT_SECRET` (at least 32 random characters). Then run `set -a; . ./.env; set +a; uvicorn app.main:app --reload` on macOS/Linux. For PowerShell, set the environment variables separately. Never use the example values in a deployment.

The local dashboard is `http://127.0.0.1:8000/admin`; do not expose this development server to the public internet. `docker compose up --build` runs the container bound to loopback; put a properly configured HTTPS reverse proxy in front for any remote use.

## API

- `POST /api/v1/admin/login` — obtain a short-lived admin bearer token.
- `GET /api/v1/admin/servers` — authenticated list (no raw configurations).
- `POST /api/v1/admin/servers` — authenticated create.
- `GET /api/v1/admin/servers/{id}` — authenticated detail (includes raw configuration for owner editing).
- `PUT /api/v1/admin/servers/{id}` — authenticated update / configuration rotation.
- `DELETE /api/v1/admin/servers/{id}` — authenticated delete.
- `GET /api/v1/servers` — active server metadata only.
- `GET /api/v1/servers/{id}/config` — returns the active profile only when requested by the client.

Country metadata is shown to app clients only when the owner explicitly marks it verified. This is an administrative assertion, not automated IP geolocation. No ping, health, traffic, or user-count metrics are implemented or displayed.

## Production blockers

The configuration-fetch route currently has no end-user authentication/account/entitlement layer. It is not safe to treat an app-embedded key as a secret. Before public launch, add an abuse-control and user-access design, rate limiting at the reverse proxy, database backups, monitoring without secret logging, and independent security review. A profile delivered to a device can be extracted from that device. Configure HTTPS, secure backups, and credential rotation. SQLite is suitable only for a small single-instance deployment; use a managed database and migrations for scale.
