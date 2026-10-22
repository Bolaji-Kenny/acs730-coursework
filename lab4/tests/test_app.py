from app import app


def test_index():
    client = app.test_client()
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.get_json()["message"] == "Hello from ACS730 Lab 4"


def test_health():
    client = app.test_client()
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_unknown_route_returns_404():
    client = app.test_client()
    assert client.get("/nope").status_code == 404


def test_deliberately_failing():
    assert False, "Deliberate failure to demonstrate the required status check"
