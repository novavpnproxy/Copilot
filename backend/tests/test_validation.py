from pydantic import ValidationError
import pytest
from app.main import ServerInput


def test_valid_protocol_uri_matches_protocol():
    value = ServerInput(name="Node", protocol="VLESS", config="vless://profile")
    assert value.protocol == "VLESS"


def test_protocol_uri_mismatch_is_rejected():
    with pytest.raises(ValidationError):
        ServerInput(name="Node", protocol="VLESS", config="vmess://profile")


def test_json_profile_must_be_valid_object():
    with pytest.raises(ValidationError):
        ServerInput(name="Node", protocol="VLESS", config="{broken")


def test_verified_location_needs_code_and_name():
    with pytest.raises(ValidationError):
        ServerInput(name="Node", protocol="VLESS", location_verified=True, config="vless://profile")
