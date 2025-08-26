from flask import Flask, jsonify
from flask_cors import CORS
try:
    # Reuse existing settings for env variables
    from app.config import settings
    cors_origins = getattr(settings, "cors_origins_list", ["*"])
except Exception:
    cors_origins = ["*"]

app = Flask(__name__)

# CORS setup
CORS(
    app,
    resources={r"/*": {"origins": cors_origins}},
    supports_credentials=True
)


@app.route("/")
def root():
    return jsonify({
        "message": "Welcome to RideShare API (Flask)",
        "version": "1.0.0",
        "features": [
            "Health checks",
            "CORS enabled",
            "Ready for route migration from FastAPI",
        ]
    })


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.route("/health")
def health():
    return jsonify({"status": "ok"})

# Register blueprints (incrementally ported)
from app.blueprints.rides import bp as rides_bp
app.register_blueprint(rides_bp)
from app.blueprints.users import bp as users_bp
app.register_blueprint(users_bp)
from app.blueprints.auth import bp as auth_bp
app.register_blueprint(auth_bp)
from app.blueprints.drivers import bp as drivers_bp
app.register_blueprint(drivers_bp)
from app.blueprints.payments import bp as payments_bp
app.register_blueprint(payments_bp)
from app.blueprints.safety import bp as safety_bp
app.register_blueprint(safety_bp)

# Debug route to list endpoints (optional)
@app.route("/__routes__")
def list_routes():
    routes = []
    for rule in app.url_map.iter_rules():
        routes.append({"rule": str(rule), "endpoint": rule.endpoint, "methods": sorted(rule.methods)})
    return jsonify(routes)


