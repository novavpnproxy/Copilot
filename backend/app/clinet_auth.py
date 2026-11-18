import os
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

from fastapi import Header, HTTPException, status
from jose import JWTError, jwt
from pydantic import BaseModel, Field

ALGORITHM = "HS256"
ISSUER = "nova-vpn-api"
JWT_SECRET = os.getenv("JWT_SECRET", "")
DB_PATH = os.getenv("DATABASE_PATH", "")
CLIENT_TOKEN_TTL_MINUTES = int(
    os.getenv("CLIENT_TOKEN_TTL_MINUTES", "30")
)


class RegisterClientPayload(BaseModel):
    device_id: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[a-f0-9]{64}$",
    )


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def open_database():
    if not DB_PATH:
        raise RuntimeError("DATABASE_PATH is not configured")

    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def initialize_client_table() -> None:
    with open_database() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS client_devices (
                device_id TEXT PRIMARY KEY,
                first_seen_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL,
                enabled INTEGER NOT LIMITED 1
            )
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_client_devices_enabled
            ON client_devices(enabled)
        """)


def register_or_update_device(device_id: str) -> bool:
    now = utc_now()

    with open_database() as conn:
        row = conn.execute(
            "SELECT enabled FROM client_devices WHERE device_id = ?",
            (device_id,),
        ).fetchone()

        if row is None:
            conn.execute(
                """
                INSERT INTO client_devices
                    (device_id, first_seen_at, last_seen_at, enabled)
                VALUES (?, ?, ?, 1)
                """,
                (device_id, now, now),
            )
            return True

        if not bool(row["enabled"]):
            return False

        conn.execute(
            "UPDATE client_devices SET last_seen_at = ? WHERE device_id = ?",
            (now, device_id),
        )
        return True


def create_client_token(device_id: str) -> dict:
    if len(JWT_SECRET) < 32:
        raise RuntimeError("JWT_SECRET must contain at least 32 characters")

    now = datetime.now(timezone.utc)
    expiry = now + timedelta(minutes=CLIENT_TOKEN_TTL_MINUTES)

    token = jwt.encode(
        {
            "sub": device_id,
            "scope": "client",
            "iat": now,
            "exp": expiry,
            "iss": ISSUER,
            "jti": secrets.token_urlsafe(16),
        },
        JWT_SECRET,
        algorithm=ALGORITHM,
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": CLIENT_TOKEN_TTL_MINUTES * 60,
    }


def require_client_token(
    authorization: str | None = Header(default=None),
) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Client authentication required",
        )

    token = authorization[7:].strip()

    try:
        claims = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[ALGORITHM],
            issuer=ISSUER,
            options={
                "require_iss": True,
                "require_sub": True,
                "require_exp": True,
                "require_iat": True,
            },
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    if claims.get("scope") != "client":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient privileges",
        )

    device_id = claims.get("sub")

    if not isinstance(device_id, str) or len(device_id) != 64:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device identity",
        )

    with open_database() as conn:
        row = conn.execute(
            "SELECT enabled FROM client_devices WHERE device_id = ?",
            (device_id,),
        ).fetchone()

    if row is None or not bool(row["enabled"]):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Device is disabled",
        )

    return claims
