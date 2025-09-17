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

# Location endpoints (simplified for live tracking)
@app.route("/location/ride/<ride_id>/participants")
def get_ride_participants_locations(ride_id):
    """Get current locations of all participants in a ride - simplified version"""
    try:
        from app.db_sync import locations_collection
        from datetime import datetime, timedelta
        from bson import ObjectId
        
        # Get recent locations for ride participants (last 10 minutes)
        recent_locations = list(locations_collection.find({
            "ride_id": ObjectId(ride_id),
            "timestamp": {"$gte": datetime.utcnow() - timedelta(minutes=10)}
        }).sort("timestamp", -1).limit(10))
        
        # Convert ObjectId to string and format response
        result = []
        for loc in recent_locations:
            result.append({
                "user_id": str(loc.get("user_id", "")),
                "location": {
                    "type": "Point",
                    "coordinates": loc.get("coordinates", [0, 0])
                },
                "timestamp": loc.get("timestamp", datetime.utcnow()).isoformat(),
                "ride_id": str(loc.get("ride_id", ""))
            })
        
        return jsonify(result)
    except Exception as e:
        print(f"Error getting ride participants locations: {e}")
        return jsonify([])

@app.route("/location/update", methods=["POST"])
def update_location():
    """Update user location - simplified version"""
    try:
        from app.db_sync import locations_collection
        from datetime import datetime
        from bson import ObjectId
        
        data = request.get_json()
        if not data:
            return jsonify({"detail": "No data provided"}), 400
        
        # Basic location update
        location_data = {
            "user_id": data.get("user_id"),
            "coordinates": data.get("coordinates", [0, 0]),
            "timestamp": datetime.utcnow(),
            "accuracy": data.get("accuracy", 0),
            "speed": data.get("speed", 0),
            "heading": data.get("heading", 0)
        }
        
        # Add ride_id if provided
        if data.get("ride_id"):
            location_data["ride_id"] = ObjectId(data["ride_id"])
        
        result = locations_collection.insert_one(location_data)
        
        return jsonify({
            "success": True,
            "location_id": str(result.inserted_id),
            "timestamp": location_data["timestamp"].isoformat()
        })
    except Exception as e:
        print(f"Error updating location: {e}")
        return jsonify({"detail": f"Error updating location: {str(e)}"}), 400

@app.route("/location/live-tracking/start", methods=["POST"])
def start_live_tracking():
    """Start live location tracking for a ride"""
    try:
        data = request.get_json()
        ride_id = data.get("ride_id")
        if not ride_id:
            return jsonify({"detail": "ride_id is required"}), 400
        
        # For now, just return success - actual tracking logic can be added later
        return jsonify({
            "success": True,
            "message": "Live tracking started",
            "ride_id": ride_id
        })
    except Exception as e:
        print(f"Error starting live tracking: {e}")
        return jsonify({"detail": f"Error starting live tracking: {str(e)}"}), 400

@app.route("/location/live-tracking/stop", methods=["POST"])
def stop_live_tracking():
    """Stop live location tracking for a ride"""
    try:
        data = request.get_json()
        ride_id = data.get("ride_id")
        if not ride_id:
            return jsonify({"detail": "ride_id is required"}), 400
        
        # For now, just return success - actual tracking logic can be added later
        return jsonify({
            "success": True,
            "message": "Live tracking stopped",
            "ride_id": ride_id
        })
    except Exception as e:
        print(f"Error stopping live tracking: {e}")
        return jsonify({"detail": f"Error stopping live tracking: {str(e)}"}), 400

try:
    from app.blueprints.location import bp as location_bp
    app.register_blueprint(location_bp)
    print("Location blueprint loaded successfully")
except Exception as e:
    print(f"Failed to load location blueprint: {e}")
    print("Using simplified location endpoints instead")

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


