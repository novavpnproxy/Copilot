from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app import main


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "DB_PATH", str(tmp_path / "test.sqlite3"))
    monkeypatch.setattr(main, "ADMIN_USERNAME", "owner")
    monkeypatch.setattr(main, "ADMIN_PASSWORD", "correct-horse-battery-staple")
    monkeypatch.setattr(main, "JWT_SECRET", "a-test-secret-that-is-long-enough-for-hmac-signing")
    monkeypatch.setattr(main, "TOKEN_TTL_MINUTES", 30)
    main._login_attempts.clear()
    with TestClient(main.app) as test_client:
        yield test_client


def admin_headers(client: TestClient) -> dict[str, str]:
    response = client.post("/api/v1/admin/login", json={
        "username": "owner",
        "password": "correct-horse-battery-staple",
    })
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def server_payload(**overrides):
    return {
        "name": "Managed server",
        "protocol": "VLESS",
        "country_code": None,
        "country_name_fa": None,
        "country_name_en": None,
        "location_verified": False,
        "enabled": True,
        "config": "vless://example-profile",
        **overrides,
    }


def test_database_starts_empty_and_public_api_has_no_fake_servers(client):
    response = client.get("/api/v1/servers")
    assert response.status_code == 200
    assert response.json() == {"servers": []}


def test_admin_server_management_never_returns_config_in_public_directory(client):
    headers = admin_headers(client)
    created = client.post("/api/v1/admin/servers", headers=headers, json=server_payload())
    assert created.status_code == 201
    server_id = created.json()["id"]

    public_response = client.get("/api/v1/servers")
    assert public_response.status_code == 200
    assert len(public_response.json()["servers"]) == 1
    assert "config" not in public_response.json()["servers"][0]
    assert "example-profile" not in public_response.text

    admin_detail = client.get(f"/api/v1/admin/servers/{server_id}", headers=headers)
    assert admin_detail.status_code == 200
    assert admin_detail.json()["config"] == "vless://example-profile"


def test_raw_profile_delivery_is_disabled_until_client_access_controls_exist(client):
    response = client.get("/api/v1/servers/server-id/config")
    assert response.status_code == 503
    assert response.headers["cache-control"] == "no-store"
    assert "config" not in response.json()


def test_admin_routes_require_authentication(client):
    response = client.get("/api/v1/admin/servers")
    assert response.status_code == 401


def test_profile_protocol_must_match_declared_protocol(client):
    headers = admin_headers(client)
    response = client.post("/api/v1/admin/servers", headers=headers, json=server_payload(
        protocol="VMESS",
        config="vless://not-vmess",
    ))
    assert response.status_code == 422


def test_verified_location_requires_country_metadata(client):
    headers = admin_headers(client)
    response = client.post("/api/v1/admin/servers", headers=headers, json=server_payload(
        location_verified=True,
    ))
    assert response.status_code == 422


def test_disabled_server_is_not_public(client):
    headers = admin_headers(client)
    created = client.post("/api/v1/admin/servers", headers=headers, json=server_payload(enabled=False))
    assert created.status_code == 201
    assert client.get("/api/v1/servers").json() == {"servers": []}
