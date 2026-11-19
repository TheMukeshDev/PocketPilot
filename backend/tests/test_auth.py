def test_register_login_me_and_isolation(client, auth_headers):
    me = client.get("/api/v1/auth/me", headers=auth_headers)
    assert me.status_code == 200
    assert me.json()["email"].endswith("@example.com")

    assert client.get("/api/v1/auth/me").status_code == 401
    assert (
        client.post(
            "/api/v1/auth/token", data={"username": me.json()["email"], "password": "wrong"}
        ).status_code
        == 401
    )

    dupe = client.post(
        "/api/v1/auth/register",
        json={"email": me.json()["email"], "password": "StrongPass123!"},
    )
    assert dupe.status_code == 409


def test_refresh_and_logout(client, auth_headers):
    login = client.post(
        "/api/v1/auth/token",
        data={
            "username": client.get("/api/v1/auth/me", headers=auth_headers).json()["email"],
            "password": "StrongPass123!",
        },
    )
    tokens = login.json()
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refreshed.status_code == 200
    assert refreshed.json()["access_token"]

    replay = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert replay.status_code == 401

    logout = client.post(
        "/api/v1/auth/logout",
        headers=auth_headers,
        json={"refresh_token": refreshed.json()["refresh_token"]},
    )
    assert logout.status_code == 200
    assert client.get("/api/v1/auth/me", headers=auth_headers).status_code == 401
