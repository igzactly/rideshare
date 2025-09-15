from flask import Flask, jsonify, request
from flask_cors import CORS
from datetime import datetime
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
        "status": "active",
        "features": [
            "Authentication (/auth/*)",
            "Ride Management (/rides/*)",
            "User Management (/users/*)",
            "Driver Operations (/driver/*)",
            "Payment Handling (/payments/*)",
            "Safety Features (/safety/*)",
            "Health checks (/health)",
            "CORS enabled",
        ]
    })


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "RideShare API",
        "version": "1.0.0"
    })

@app.route("/test")
def test():
    return jsonify({"message": "Flask app is working", "endpoints": ["/", "/health", "/test"]})

# Register blueprints (incrementally ported)
try:
    from app.blueprints.rides import bp as rides_bp
    app.register_blueprint(rides_bp)
except Exception as e:
    print(f"Failed to load rides blueprint: {e}")

try:
    from app.blueprints.users import bp as users_bp
    app.register_blueprint(users_bp)
except Exception as e:
    print(f"Failed to load users blueprint: {e}")

try:
    from app.blueprints.auth import bp as auth_bp
    app.register_blueprint(auth_bp)
    print("Auth blueprint loaded successfully")
except Exception as e:
    print(f"Failed to load auth blueprint: {e}")

try:
    from app.blueprints.drivers import bp as drivers_bp
    app.register_blueprint(drivers_bp)
except Exception as e:
    print(f"Failed to load drivers blueprint: {e}")

try:
    from app.blueprints.payments import bp as payments_bp
    app.register_blueprint(payments_bp)
except Exception as e:
    print(f"Failed to load payments blueprint: {e}")

try:
    from app.blueprints.safety import bp as safety_bp
    app.register_blueprint(safety_bp)
except Exception as e:
    print(f"Failed to load safety blueprint: {e}")

try:
    from app.blueprints.location import bp as location_bp
    app.register_blueprint(location_bp)
    print("Location blueprint loaded successfully")
except Exception as e:
    print(f"Failed to load location blueprint: {e}")

# Debug route to list endpoints (optional)
@app.route("/__routes__")
def list_routes():
    routes = []
    for rule in app.url_map.iter_rules():
        routes.append({"rule": str(rule), "endpoint": rule.endpoint, "methods": sorted(rule.methods)})
    return jsonify(routes)

# Error handlers for consistent error responses
@app.errorhandler(404)
def not_found(error):
    return jsonify({"detail": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"detail": "Internal server error"}), 500

@app.errorhandler(400)
def bad_request(error):
    return jsonify({"detail": "Bad request"}), 400

@app.errorhandler(401)
def unauthorized(error):
    return jsonify({"detail": "Unauthorized"}), 401

@app.errorhandler(403)
def forbidden(error):
    return jsonify({"detail": "Forbidden"}), 403


