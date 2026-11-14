from __future__ import annotations

import hmac
import os
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterator, Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.responses import FileResponse
from jose import JWTError, jwt
from pydantic import BaseModel, Field, field_validator

APP_DIR = Path(__file__).resolve().parent
DB_PATH = os.getenv("DATABASE_PATH", str(APP_DIR.parent / "nova.sqlite3"))
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")
JWT_SECRET = os.getenv("JWT_SECRET", "")
TOKEN_TTL_MINUTES = int(os.getenv("TOKEN_TTL_MINUTES", "30"))
ALGORITHM = "HS256"
SUPPORTED_PROTOCOLS = {"VLESS", "VMESS", "TROJAN", "SHADOWSOCKS", "HYSTERIA", "HYSTERIA2"}
COUNTRY_CODE = re.compile(r"^[A-Z]{2}$")

app = FastAPI(title="NOVA VPN API", version="0.1.0", docs_url=None, redoc_url=None)
_login_attempts: dict[str, list[float]] = {}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def check_runtime_secrets() -> None:
    if len(ADMIN_USERNAME) < 1 or len(ADMIN_PASSWORD) < 16:
        raise RuntimeError("Set ADMIN_USERNAME and a unique ADMIN_PASSWORD of at least 16 characters")
    if len(JWT_SECRET) < 32 or "replace-with" in JWT_SECRET:
        raise RuntimeError("Set JWT_SECRET to at least 32 random characters")
    if not 5 <= TOKEN_TTL_MINUTES <= 240:
        raise RuntimeError("TOKEN_TTL_MINUTES must be between 5 and 240")


@contextmanager
def database() -> Iterator[sqlite3.Connection]:
    path = Path(DB_PATH)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, timeout=10)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def initialize_database() -> None:
    with database() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS servers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                protocol TEXT NOT NULL,
                country_code TEXT,
                country_name_fa TEXT,
                country_name_en TEXT,
                location_verified INTEGER NOT NULL DEFAULT 0,
                enabled INTEGER NOT NULL DEFAULT 0,
                config TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)


@app.on_event("startup")
def startup() -> None:
    check_runtime_secrets()
    initialize_database()


class LoginPayload(BaseModel):
    username: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=1, max_length=512)


class ServerInput(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    protocol: str = Field(min_length=2, max_length=24)
    country_code: str | None = None
    country_name_fa: str | None = Field(default=None, max_length=80)
    country_name_en: str | None = Field(default=None, max_length=80)
    location_verified: bool = False
    enabled: bool = False
    config: str = Field(min_length=1, max_length=200_000)

    @field_validator("protocol")
    @classmethod
    def protocol_supported(cls, value: str) -> str:
        normalized = value.strip().upper()
        if normalized not in SUPPORTED_PROTOCOLS:
            raise ValueError("Unsupported protocol")
        return normalized

    @field_validator("country_code")
    @classmethod
    def country_code_format(cls, value: str | None) -> str | None:
        if value is None or value.strip() == "":
            return None
        value = value.strip().upper()
        if not COUNTRY_CODE.fullmatch(value):
            raise ValueError("Country code must be a two-letter ISO code")
        return value

    @field_validator("config")
    @classmethod
    def config_not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Configuration cannot be blank")
        return value.strip()


def admin_claims(authorization: str | None = Header(default=None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Admin authentication required")
    token = authorization[7:].strip()
    try:
        claims = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
    if claims.get("sub") != ADMIN_USERNAME or claims.get("scope") != "admin":
        raise HTTPException(status_code=403, detail="Insufficient privileges")
    return claims


def public_server(row: sqlite3.Row) -> dict:
    location_valid = bool(row["location_verified"])
    return {
        "id": row["id"],
        "name": row["name"],
        "protocol": row["protocol"],
        "country_code": row["country_code"] if location_valid else None,
        "country_name_fa": row["country_name_fa"] if location_valid else None,
        "country_name_en": row["country_name_en"] if location_valid else None,
        "location_verified": location_valid,
    }


def admin_server(row: sqlite3.Row) -> dict:
    result = public_server(row)
    result.update({"enabled": bool(row["enabled"]), "updated_at": row["updated_at"]})
    return result


def login_is_limited(key: str) -> bool:
    now = time.monotonic()
    attempts = [t for t in _login_attempts.get(key, []) if now - t < 300]
    _login_attempts[key] = attempts
    return len(attempts) >= 8


@app.get("/health")
def health() -> dict:
    # Liveness only; it deliberately does not claim that a VPN server is reachable.
    return {"status": "ok"}


@app.post("/api/v1/admin/login")
def login(payload: LoginPayload, request: Request) -> dict:
    key = request.client.host if request.client else "unknown"
    if login_is_limited(key):
        raise HTTPException(status_code=429, detail="Too many login attempts")
    valid = hmac.compare_digest(payload.username, ADMIN_USERNAME) and hmac.compare_digest(
        payload.password, ADMIN_PASSWORD
    )
    if not valid:
        _login_attempts.setdefault(key, []).append(time.monotonic())
        raise HTTPException(status_code=401, detail="Invalid credentials")
    _login_attempts.pop(key, None)
    expiry = datetime.now(timezone.utc) + timedelta(minutes=TOKEN_TTL_MINUTES)
    token = jwt.encode({"sub": ADMIN_USERNAME, "scope": "admin", "exp": expiry}, JWT_SECRET, algorithm=ALGORITHM)
    return {"access_token": token, "token_type": "bearer", "expires_in": TOKEN_TTL_MINUTES * 60}


@app.get("/api/v1/servers")
def list_servers() -> dict:
    with database() as conn:
        rows = conn.execute("SELECT * FROM servers WHERE enabled = 1 ORDER BY name COLLATE NOCASE").fetchall()
    return {"servers": [public_server(row) for row in rows]}


@app.get("/api/v1/servers/{server_id}/config")
def get_server_config(server_id: str) -> dict:
    with database() as conn:
        row = conn.execute("SELECT id, protocol, config FROM servers WHERE id = ? AND enabled = 1", (server_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Server is unavailable")
    # This endpoint intentionally delivers a profile only when requested. A profile delivered to
    # a device is not secret from that device's owner; production deployments need an access and
    # abuse-control policy appropriate to the service.
    return {"server_id": row["id"], "protocol": row["protocol"], "config": row["config"]}


@app.get("/api/v1/admin/servers")
def admin_list_servers(_: dict = Depends(admin_claims)) -> dict:
    with database() as conn:
        rows = conn.execute("SELECT * FROM servers ORDER BY updated_at DESC").fetchall()
    return {"servers": [admin_server(row) for row in rows]}


@app.post("/api/v1/admin/servers", status_code=status.HTTP_201_CREATED)
def create_server(payload: ServerInput, _: dict = Depends(admin_claims)) -> dict:
    server_id = secrets.token_urlsafe(12)
    with database() as conn:
        conn.execute("""INSERT INTO servers
            (id, name, protocol, country_code, country_name_fa, country_name_en,
             location_verified, enabled, config, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (server_id, payload.name.strip(), payload.protocol, payload.country_code,
             payload.country_name_fa, payload.country_name_en, int(payload.location_verified),
             int(payload.enabled), payload.config, utc_now()))
        row = conn.execute("SELECT * FROM servers WHERE id = ?", (server_id,)).fetchone()
    return admin_server(row)


@app.get("/api/v1/admin/servers/{server_id}")
def admin_get_server(server_id: str, _: dict = Depends(admin_claims)) -> dict:
    with database() as conn:
        row = conn.execute("SELECT * FROM servers WHERE id = ?", (server_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Server not found")
    result = admin_server(row)
    result["config"] = row["config"]
    return result


@app.put("/api/v1/admin/servers/{server_id}")
def update_server(server_id: str, payload: ServerInput, _: dict = Depends(admin_claims)) -> dict:
    with database() as conn:
        cursor = conn.execute("""UPDATE servers SET name = ?, protocol = ?, country_code = ?,
            country_name_fa = ?, country_name_en = ?, location_verified = ?, enabled = ?,
            config = ?, updated_at = ? WHERE id = ?""",
            (payload.name.strip(), payload.protocol, payload.country_code, payload.country_name_fa,
             payload.country_name_en, int(payload.location_verified), int(payload.enabled),
             payload.config, utc_now(), server_id))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Server not found")
        row = conn.execute("SELECT * FROM servers WHERE id = ?", (server_id,)).fetchone()
    return admin_server(row)


@app.delete("/api/v1/admin/servers/{server_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_server(server_id: str, _: dict = Depends(admin_claims)) -> None:
    with database() as conn:
        cursor = conn.execute("DELETE FROM servers WHERE id = ?", (server_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Server not found")


@app.get("/admin", include_in_schema=False)
def admin_page() -> FileResponse:
    return FileResponse(APP_DIR / "admin.html")
