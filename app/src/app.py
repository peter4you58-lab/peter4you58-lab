from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import os

app = Flask(__name__)

# ── Database configuration ────────────────────────────────────────────────────
# Reads DATABASE_URL from env (injected via Kubernetes Secret).
# Falls back to SQLite for local / test runs so no Postgres is required locally.
DB_URL = os.getenv("DATABASE_URL", "sqlite:///dev.db")
app.config["SQLALCHEMY_DATABASE_URI"] = DB_URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


class Item(db.Model):
    __tablename__ = "items"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "created_at": self.created_at.isoformat(),
        }


with app.app_context():
    db.create_all()


# ── Health / readiness endpoints ──────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    """Liveness probe — checks the app process is alive."""
    return jsonify({
        "status":      "healthy",
        "timestamp":   datetime.utcnow().isoformat(),
        "version":     os.getenv("APP_VERSION", "1.0.0"),
        "environment": os.getenv("ENVIRONMENT", "dev"),
    }), 200


@app.route("/ready", methods=["GET"])
def ready():
    """Readiness probe — checks DB connectivity before accepting traffic."""
    try:
        db.session.execute(db.text("SELECT 1"))
        return jsonify({"status": "ready"}), 200
    except Exception as exc:
        return jsonify({"status": "unavailable", "reason": str(exc)}), 503


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "message":     "DevOps Portfolio API",
        "version":     os.getenv("APP_VERSION", "1.0.0"),
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "endpoints":   ["/health", "/ready", "/api/items"],
    }), 200


# ── CRUD API ──────────────────────────────────────────────────────────────────

@app.route("/api/items", methods=["GET"])
def get_items():
    items = Item.query.order_by(Item.id).all()
    return jsonify({"items": [i.to_dict() for i in items], "count": len(items)}), 200


@app.route("/api/items", methods=["POST"])
def create_item():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "name is required"}), 400

    item = Item(name=data["name"])
    db.session.add(item)
    db.session.commit()
    return jsonify(item.to_dict()), 201


@app.route("/api/items/<int:item_id>", methods=["GET"])
def get_item(item_id):
    item = db.session.get(Item, item_id)
    if not item:
        return jsonify({"error": "Item not found"}), 404
    return jsonify(item.to_dict()), 200


@app.route("/api/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    item = db.session.get(Item, item_id)
    if not item:
        return jsonify({"error": "Item not found"}), 404
    db.session.delete(item)
    db.session.commit()
    return jsonify({"message": "Item deleted"}), 200


# ── Entry point (local dev only — gunicorn does not call this) ─────────────────
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
