import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, status
from jose import JWTError, jwt
from pydantic import BaseModel, Field

ALGORITHM = "HS256"
ISSUER = "nova-vpn-api"
JWT_SECRET = os.getenv("JWT_SECRET", "")


class DeviceRegisterPayload(BaseModel):
    device_id: str = Field(min_length=64, max_length=64, pattern=r"^[a-f0-9]{64}$")


def create_client_token(device_id: str, ttl_minutes: int = 30) -> dict:
    if len(JWT_SECRET) < 32:
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
        JWT_SECRET,
        algorithm=ALGORITHM,
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": ttl_minutes * 60,
    }


def client_claims(
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

    return claims
