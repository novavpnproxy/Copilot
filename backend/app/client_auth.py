import os
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Header, HTTPException
from jose import JWTError, jwt
from pydantic import BaseModel, Field

ALGORITHM = "HS256"
ISSUER = "nova-vpn-api"


class RegisterClientPayload(BaseModel):
    device_id: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[a-f0-9]{64}$",
    )


def create_client_token(device_id: str, jwt_secret: str, ttl_minutes: int) -> dict:
    if len(jwt_secret) < 32:
        raise RuntimeError("JWT_SECRET must contain at least 32 characters")

    now = datetime.now(timezone.utc)
    expiry = now + timedelta(minutes=ttl_minutes)
    token = jwt.encode(
        {
            "sub": device_id,
            "scope": "client",
            "iat": now,
            "exp": expiry,
            "iss": ISSUER,
            "jti": secrets.token_urlsafe(16),
        },
        jwt_secret,
        algorithm=ALGORITHM,
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": ttl_minutes * 60,
    }


def decode_client_token(token: str, jwt_secret: str) -> dict:
    try:
        claims = jwt.decode(
            token,
            jwt_secret,
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
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc

    if claims.get("scope") != "client":
        raise HTTPException(status_code=403, detail="Insufficient privileges")

    device_id = claims.get("sub")
    if not isinstance(device_id, str) or len(device_id) != 64:
        raise HTTPException(status_code=401, detail="Invalid device identity")
    return claims
