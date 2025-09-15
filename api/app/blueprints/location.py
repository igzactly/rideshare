from flask import Blueprint, request, jsonify
from datetime import datetime, timedelta
from bson import ObjectId
from pymongo import GEOSPHERE
from app.db_sync import locations_collection, rides_collection, drivers_collection
from app.utils import serialize_with_renamed_id
from app.config import settings
from jose import jwt

bp = Blueprint("location", __name__, url_prefix="/location")

def _get_current_user():
    """Extract current user from JWT token"""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    
    token = auth_header.split(" ")[1]
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        if user_id and ObjectId.is_valid(user_id):
            return ObjectId(user_id)
    except:
        pass
    return None

def _ensure_location_indexes():
    """Create required indexes if they don't exist"""
    try:
        locations_collection.create_index([("coordinates", GEOSPHERE)])
        locations_collection.create_index("user_id")
        locations_collection.create_index("ride_id")
        locations_collection.create_index("timestamp")
    except Exception:
        pass

_ensure_location_indexes()

@bp.post("/update")
def update_location():
    """Update user's current location with enhanced live tracking"""
    user_id = _get_current_user()
    if not user_id:
        return jsonify({"detail": "Authentication required"}), 401
    
    try:
        data = request.get_json(force=True)
        
        # Validate required fields
        coordinates = data.get("coordinates")
        if not coordinates or len(coordinates) != 2:
            return jsonify({"detail": "coordinates [lat, lng] required"}), 400
        
        lat, lng = float(coordinates[0]), float(coordinates[1])
        
        location_data = {
            "user_id": user_id,
            "coordinates": {
                "type": "Point",
                "coordinates": [lng, lat]  # MongoDB uses [lng, lat]
            },
            "timestamp": datetime.utcnow(),
            "accuracy": float(data.get("accuracy", 10.0)),
            "speed": float(data.get("speed", 0.0)),
            "heading": float(data.get("heading", 0.0)),
        }
        
        # Add ride_id if provided
        ride_id = data.get("ride_id")
        if ride_id and ObjectId.is_valid(ride_id):
            location_data["ride_id"] = ObjectId(ride_id)
            
            # Update driver's current location if they're online
            drivers_collection.update_one(
                {"driver_id": user_id},
                {"$set": {"current_location": location_data["coordinates"], "updated_at": datetime.utcnow()}}
            )
            
            # Update ride's last known location
            rides_collection.update_one(
                {"_id": ObjectId(ride_id)},
                {"$set": {"last_known_location": location_data["coordinates"], "last_location_update": location_data["timestamp"]}}
            )
        
        # Store location
        result = locations_collection.insert_one(location_data)
        
        return jsonify({
            "message": "Location updated successfully",
            "location_id": str(result.inserted_id),
            "timestamp": location_data["timestamp"].isoformat()
        }), 200
        
    except Exception as e:
        return jsonify({"detail": f"Error updating location: {str(e)}"}), 400

@bp.get("/user/<user_id>/recent")
def get_user_recent_locations(user_id: str):
    """Get recent location updates for a user"""
    current_user = _get_current_user()
    if not current_user:
        return jsonify({"detail": "Authentication required"}), 401
    
    if not ObjectId.is_valid(user_id):
        return jsonify({"detail": "Invalid user ID"}), 400
    
    # Only allow users to see their own locations or locations of users in the same ride
    if str(current_user) != user_id:
        # Check if they're in the same ride
        user_ride = rides_collection.find_one({
            "$or": [
                {"driver_id": current_user, "status": {"$in": ["accepted", "picked_up", "in_progress"]}},
                {"passenger_id": current_user, "status": {"$in": ["accepted", "picked_up", "in_progress"]}}
            ]
        })
        
        if not user_ride:
            return jsonify({"detail": "Not authorized to view this user's location"}), 403
    
    limit = min(int(request.args.get("limit", 10)), 50)
    locations = list(locations_collection.find(
        {"user_id": ObjectId(user_id)},
        sort=[("timestamp", -1)]
    ).limit(limit))
    
    return jsonify([serialize_with_renamed_id(loc) for loc in locations])

@bp.get("/ride/<ride_id>/participants")
def get_ride_participants_locations(ride_id: str):
    """Get current locations of all participants in a ride"""
    current_user = _get_current_user()
    if not current_user:
        return jsonify({"detail": "Authentication required"}), 401
    
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    
    # Verify user is part of this ride
    ride = rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": current_user},
            {"passenger_id": current_user}
        ]
    })
    
    if not ride:
        return jsonify({"detail": "Ride not found or user not authorized"}), 404
    
    # Get the most recent location for each participant
    pipeline = [
        {
            "$match": {
                "ride_id": ObjectId(ride_id),
                "timestamp": {"$gte": datetime.utcnow() - timedelta(minutes=5)}  # Only recent locations
            }
        },
        {
            "$sort": {"timestamp": -1}
        },
        {
            "$group": {
                "_id": "$user_id",
                "latest_location": {"$first": "$$ROOT"}
            }
        },
        {
            "$replaceRoot": {"newRoot": "$latest_location"}
        }
    ]
    
    locations = list(locations_collection.aggregate(pipeline))
    return jsonify([serialize_with_renamed_id(loc) for loc in locations])

@bp.get("/nearby-drivers")
def get_nearby_drivers():
    """Find nearby available drivers"""
    current_user = _get_current_user()
    if not current_user:
        return jsonify({"detail": "Authentication required"}), 401
    
    latitude = request.args.get("latitude", type=float)
    longitude = request.args.get("longitude", type=float)
    radius_km = request.args.get("radius_km", 5.0, type=float)
    
    if not latitude or not longitude:
        return jsonify({"detail": "latitude and longitude required"}), 400
    
    # Find drivers within the specified radius
    nearby_drivers = list(drivers_collection.find({
        "is_online": True,
        "status": "active",
        "current_location": {
            "$near": {
                "$geometry": {
                    "type": "Point",
                    "coordinates": [longitude, latitude]  # MongoDB uses [lng, lat]
                },
                "$maxDistance": radius_km * 1000  # Convert km to meters
            }
        }
    }).limit(10))
    
    # Get the most recent location for each driver
    drivers_with_locations = []
    for driver in nearby_drivers:
        latest_location = locations_collection.find_one(
            {"user_id": driver["driver_id"]},
            sort=[("timestamp", -1)]
        )
        
        if latest_location:
            drivers_with_locations.append({
                "driver_id": str(driver["driver_id"]),
                "current_location": latest_location["coordinates"],
                "last_seen": latest_location["timestamp"],
                "available_seats": driver.get("available_seats", 1)
            })
    
    return jsonify(drivers_with_locations)

@bp.post("/live-tracking/start")
def start_live_tracking():
    """Start live location tracking for a ride"""
    current_user = _get_current_user()
    if not current_user:
        return jsonify({"detail": "Authentication required"}), 401
    
    data = request.get_json(force=True)
    ride_id = data.get("ride_id")
    
    if not ride_id or not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    
    # Verify user is part of this ride
    ride = rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": current_user},
            {"passenger_id": current_user}
        ]
    })
    
    if not ride:
        return jsonify({"detail": "Ride not found or user not authorized"}), 404
    
    # Update ride status to indicate live tracking is active
    rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"live_tracking_active": True, "tracking_started_at": datetime.utcnow()}}
    )
    
    return jsonify({"message": "Live tracking started successfully", "ride_id": ride_id})

@bp.post("/live-tracking/stop")
def stop_live_tracking():
    """Stop live location tracking for a ride"""
    current_user = _get_current_user()
    if not current_user:
        return jsonify({"detail": "Authentication required"}), 401
    
    data = request.get_json(force=True)
    ride_id = data.get("ride_id")
    
    if not ride_id or not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    
    # Verify user is part of this ride
    ride = rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": current_user},
            {"passenger_id": current_user}
        ]
    })
    
    if not ride:
        return jsonify({"detail": "Ride not found or user not authorized"}), 404
    
    # Update ride status to indicate live tracking is stopped
    rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"live_tracking_active": False, "tracking_stopped_at": datetime.utcnow()}}
    )
    
    return jsonify({"message": "Live tracking stopped successfully", "ride_id": ride_id})

@bp.get("/live-tracking/<ride_id>/status")
def get_live_tracking_status(ride_id: str):
    """Get live tracking status for a ride"""
    current_user = _get_current_user()
    if not current_user:
        return jsonify({"detail": "Authentication required"}), 401
    
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    
    # Verify user is part of this ride
    ride = rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": current_user},
            {"passenger_id": current_user}
        ]
    })
    
    if not ride:
        return jsonify({"detail": "Ride not found or user not authorized"}), 404
    
    # Get the most recent location updates for this ride
    recent_locations = list(locations_collection.find(
        {"ride_id": ObjectId(ride_id)},
        sort=[("timestamp", -1)]
    ).limit(5))
    
    return jsonify({
        "ride_id": ride_id,
        "live_tracking_active": ride.get("live_tracking_active", False),
        "tracking_started_at": ride.get("tracking_started_at"),
        "tracking_stopped_at": ride.get("tracking_stopped_at"),
        "last_location_update": ride.get("last_location_update"),
        "recent_locations": [serialize_with_renamed_id(loc) for loc in recent_locations]
    })
