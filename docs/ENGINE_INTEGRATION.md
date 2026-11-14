# Android engine integration status

The client now depends on `flutter_v2ray_client` 3.5.0 and has an adapter that initializes the engine, requests Android VPN permission, starts/stops a tunnel, and listens to engine status callbacks. The UI only enters the Connected state after receiving the plugin's `CONNECTED` event.

The backend profile endpoint currently returns HTTP 503 by design until end-user authorization and abuse controls are deployed. Consequently the connect action reports that profiles are unavailable and does not start the engine yet. This avoids shipping a public, unauthenticated endpoint that reveals managed VPN credentials. No actual server/profile has been provided, and no device build or live tunnel test has been performed.

Before enabling profile delivery, implement server-side user/device authorization, revocable short-lived access, rate limiting, and HTTPS deployment. Then test every profile against the selected engine with owner-provided infrastructure and Android devices. The plugin documents VLESS, VMess, Trojan, Shadowsocks, and Hysteria URL parsing; a protocol label in the admin panel alone does not guarantee profile compatibility.
