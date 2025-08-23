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

# Register blueprints (incrementally ported)
try:
    from app.blueprints.rides import bp as rides_bp
    app.register_blueprint(rides_bp)
except Exception:
    pass


