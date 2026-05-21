import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as c:
        yield c


def test_health_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_returns_json(client):
    response = client.get("/health")
    data = response.get_json()
    assert data is not None
    assert data["status"] == "ok"


def test_index_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200
