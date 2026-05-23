"""
Unit tests for the Flask API.
Each test gets a fresh in-memory SQLite database so there is no
shared state between tests and execution order does not matter.
"""
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../src"))

from app import app, db


@pytest.fixture
def client():
    """Fresh in-memory DB for every test."""
    app.config["TESTING"] = True
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"
    with app.app_context():
        db.create_all()
        with app.test_client() as c:
            yield c
        db.drop_all()


# ── Health / readiness ────────────────────────────────────────────────────────

def test_health_check(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert "version" in data


def test_readiness_check(client):
    resp = client.get("/ready")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ready"


def test_index(client):
    resp = client.get("/")
    assert resp.status_code == 200
    data = resp.get_json()
    assert "message" in data
    assert "endpoints" in data


# ── Items CRUD ────────────────────────────────────────────────────────────────

def test_get_items_empty(client):
    resp = client.get("/api/items")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["items"] == []
    assert data["count"] == 0


def test_create_item(client):
    resp = client.post("/api/items", json={"name": "test-item"})
    assert resp.status_code == 201
    data = resp.get_json()
    assert data["name"] == "test-item"
    assert "id" in data
    assert "created_at" in data


def test_create_item_missing_name(client):
    resp = client.post("/api/items", json={})
    assert resp.status_code == 400
    assert "error" in resp.get_json()


def test_create_item_no_body(client):
    resp = client.post("/api/items", content_type="application/json", data="")
    assert resp.status_code == 400


def test_get_items_after_create(client):
    client.post("/api/items", json={"name": "item-a"})
    client.post("/api/items", json={"name": "item-b"})
    resp = client.get("/api/items")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["count"] == 2
    names = [i["name"] for i in data["items"]]
    assert "item-a" in names
    assert "item-b" in names


def test_get_item_by_id(client):
    create = client.post("/api/items", json={"name": "specific"})
    item_id = create.get_json()["id"]
    resp = client.get(f"/api/items/{item_id}")
    assert resp.status_code == 200
    assert resp.get_json()["name"] == "specific"


def test_get_item_not_found(client):
    resp = client.get("/api/items/9999")
    assert resp.status_code == 404


def test_delete_item(client):
    create = client.post("/api/items", json={"name": "to-delete"})
    item_id = create.get_json()["id"]
    resp = client.delete(f"/api/items/{item_id}")
    assert resp.status_code == 200
    # Confirm it's gone
    assert client.get(f"/api/items/{item_id}").status_code == 404


def test_delete_item_not_found(client):
    resp = client.delete("/api/items/9999")
    assert resp.status_code == 404
