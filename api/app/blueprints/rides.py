from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from pymongo import ReturnDocument
from app.db_sync import rides_collection
from app.utils import serialize_with_renamed_id
from jose import jwt
from app.config import settings

bp = Blueprint("rides", __name__, url_prefix="/rides")


def _to_geojson_point(raw: dict | list | None):
    """Convert various coordinate inputs to a GeoJSON Point dict or return None.

    Accepts either:
    - {"latitude": <lat>, "longitude": <lng>}
    - [lng, lat]
    - {"type": "Point", "coordinates": [lng, lat]}
    """
    if not raw:
        return None
    # Already GeoJSON
    if isinstance(raw, dict) and raw.get("type") == "Point" and isinstance(raw.get("coordinates"), (list, tuple)):
        return {"type": "Point", "coordinates": [float(raw["coordinates"][0]), float(raw["coordinates"][1])]}  # type: ignore[index]
    # Lat/Lng object
    if isinstance(raw, dict) and "latitude" in raw and "longitude" in raw:
        try:
            return {"type": "Point", "coordinates": [float(raw["longitude"]), float(raw["latitude"])]}
        except Exception:
            return None
    # Coordinate array [lng, lat]
    if isinstance(raw, (list, tuple)) and len(raw) == 2:
        try:
            return {"type": "Point", "coordinates": [float(raw[0]), float(raw[1])]}  # type: ignore[index]
        except Exception:
            return None
    return None


def _ensure_indexes_once():
    """Create required indexes if they don't exist. Safe to call multiple times."""
    try:
        rides_collection.create_index([("pickup_location", "2dsphere")])
        rides_collection.create_index([("dropoff_location", "2dsphere")])
        rides_collection.create_index("status")
        rides_collection.create_index("created_at")
    except Exception:
        # Index creation is best-effort; ignore errors to avoid blocking requests
        pass


_ensure_indexes_once()


def _get_current_user_id():
    """Extract current user ObjectId from JWT Authorization header."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    token = auth_header.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        if user_id and ObjectId.is_valid(user_id):
            return ObjectId(user_id)
    except Exception:
        return None
    return None

@bp.post("/")
@bp.post("")
def create_ride():
    payload = request.get_json(force=True)
    print(f"Create ride request: {payload}")
    now = datetime.utcnow()
    payload.setdefault("created_at", now)
    payload.setdefault("updated_at", now)
    # Normalize coordinates and legacy field names
    # Support either 'origin'/'destination' or 'pickup_location'/'dropoff_location'
    pickup_raw = payload.get("pickup_location") or payload.get("origin")
    dropoff_raw = payload.get("dropoff_location") or payload.get("destination")
    pickup_point = _to_geojson_point(pickup_raw)
    dropoff_point = _to_geojson_point(dropoff_raw)
    if pickup_point:
        payload["pickup_location"] = pickup_point
    if dropoff_point:
        payload["dropoff_location"] = dropoff_point

    # Default status if missing
    payload.setdefault("status", "active")

    # Convert reference IDs if provided
    for ref_field in ["driver_id", "passenger_id"]:
        if payload.get(ref_field) and ObjectId.is_valid(payload[ref_field]):
            payload[ref_field] = ObjectId(payload[ref_field])

    # If driver_id not provided, attempt to infer from JWT (offer ride flow)
    if not payload.get("driver_id"):
        current_user_id = _get_current_user_id()
        if current_user_id is None:
            return jsonify({"detail": "Authentication required"}), 401
        payload["driver_id"] = current_user_id
    print(f"Final payload before insert: {payload}")
    res = rides_collection.insert_one(payload)
    doc = rides_collection.find_one({"_id": res.inserted_id})
    print(f"Created ride: {serialize_with_renamed_id(doc)}")
    return jsonify(serialize_with_renamed_id(doc)), 201


@bp.get("/test-search")
def test_search():
    """Test endpoint to debug search functionality"""
    print("Test search endpoint called")
    
    # Get all rides
    all_rides = list(rides_collection.find({}))
    print(f"Total rides in database: {len(all_rides)}")
    
    # Get rides with pickup_location
    rides_with_location = list(rides_collection.find({"pickup_location": {"$exists": True}}))
    print(f"Rides with pickup_location: {len(rides_with_location)}")
    
    # Get rides with status
    rides_with_status = list(rides_collection.find({"status": {"$exists": True}}))
    print(f"Rides with status: {len(rides_with_status)}")
    
    # Sample ride structure
    sample_ride = all_rides[0] if all_rides else None
    print(f"Sample ride structure: {sample_ride}")
    
    return jsonify({
        "total_rides": len(all_rides),
        "rides_with_location": len(rides_with_location),
        "rides_with_status": len(rides_with_status),
        "sample_ride": serialize_with_renamed_id(sample_ride) if sample_ride else None
    })


@bp.get("/")
def list_rides():
    query = {}
    passenger_id = request.args.get("passenger_id")
    driver_id = request.args.get("driver_id")
    status = request.args.get("status")
    if passenger_id and ObjectId.is_valid(passenger_id):
        query["passenger_id"] = ObjectId(passenger_id)
    if driver_id and ObjectId.is_valid(driver_id):
        query["driver_id"] = ObjectId(driver_id)
    if status:
        query["status"] = status
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [serialize_with_renamed_id(d) for d in rides_collection.find(query).limit(limit)]
    return jsonify(docs)


@bp.get("/<ride_id>")
def get_ride(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    doc = rides_collection.find_one({"_id": ObjectId(ride_id)})
    if not doc:
        return jsonify({"detail": "Ride not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.put("/<ride_id>")
def update_ride(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    updates = request.get_json(force=True)
    updates["updated_at"] = datetime.utcnow()
    for ref_field in ["driver_id", "passenger_id"]:
        if updates.get(ref_field) and ObjectId.is_valid(updates[ref_field]):
            updates[ref_field] = ObjectId(updates[ref_field])
    doc = rides_collection.find_one_and_update(
        {"_id": ObjectId(ride_id)},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return jsonify({"detail": "Ride not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.delete("/<ride_id>")
def delete_ride(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    result = rides_collection.delete_one({"_id": ObjectId(ride_id)})
    if result.deleted_count == 0:
        return jsonify({"detail": "Ride not found"}), 404
    return jsonify({"message": "Ride deleted successfully"})


@bp.get("/search")
def search_rides():
    # Simple filter-based search via query params (non-geo)
    query = {}
    passenger_id = request.args.get("passenger_id")
    driver_id = request.args.get("driver_id")
    status = request.args.get("status")
    if passenger_id and ObjectId.is_valid(passenger_id):
        query["passenger_id"] = ObjectId(passenger_id)
    if driver_id and ObjectId.is_valid(driver_id):
        query["driver_id"] = ObjectId(driver_id)
    if status:
        query["status"] = status
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [
        serialize_with_renamed_id(d)
        for d in rides_collection.find(query).limit(limit)
    ]
    return jsonify({"rides": docs})


@bp.post("/find")
def find_rides():
    """Enhanced geo search for nearby rides with multiple location format support."""
    try:
        body = request.get_json(silent=True) or {}
        print(f"Find rides request: {body}")
        
        pickup_point = _to_geojson_point(body.get("pickup_location"))
        if not pickup_point:
            print("Error: pickup_location is required")
            return jsonify({"detail": "pickup_location is required"}), 400
        
        try:
            radius_km = float(body.get("radius_km", 10.0))  # Increased default radius
        except Exception:
            radius_km = 10.0

        limit = min(int(body.get("limit", 50)), 200)

        print(f"Searching by pickup: {pickup_point} within {radius_km}km")
        print(f"Database connection status: {rides_collection.database.client.admin.command('ping')}")
    except Exception as e:
        print(f"Error processing request: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"detail": f"Request processing error: {str(e)}"}), 400
    
    try:
        # Get all active rides first, then filter by proximity
        all_rides = []
        
        # Get all active rides from database
        try:
            all_rides = list(rides_collection.find({"status": {"$in": ["active"]}}).limit(100))
            print(f"Found {len(all_rides)} active rides in database")
        except Exception as e:
            print(f"Error fetching active rides: {e}")
            # Fallback to get any rides
            try:
                all_rides = list(rides_collection.find({}).limit(50))
                print(f"Fallback: Found {len(all_rides)} total rides")
            except Exception as e2:
                print(f"Fallback query also failed: {e2}")
                return jsonify({"rides": []})
        
        # Filter rides by pickup location proximity
        nearby_rides = []
        user_lat = pickup_point["coordinates"][1]  # latitude
        user_lng = pickup_point["coordinates"][0]  # longitude
        
        print(f"User location: lat={user_lat}, lng={user_lng}")
        
        for ride in all_rides:
            try:
                ride_pickup = ride.get("pickup_location")
                if not ride_pickup:
                    continue
                
                # Handle different pickup location formats
                ride_lat = None
                ride_lng = None
                
                # GeoJSON format: {"type": "Point", "coordinates": [lng, lat]}
                if isinstance(ride_pickup, dict) and ride_pickup.get("type") == "Point":
                    coords = ride_pickup.get("coordinates", [])
                    if len(coords) >= 2:
                        ride_lng = float(coords[0])
                        ride_lat = float(coords[1])
                
                # Object format: {"latitude": lat, "longitude": lng}
                elif isinstance(ride_pickup, dict) and "latitude" in ride_pickup and "longitude" in ride_pickup:
                    ride_lat = float(ride_pickup["latitude"])
                    ride_lng = float(ride_pickup["longitude"])
                
                if ride_lat is None or ride_lng is None:
                    print(f"Skipping ride {ride.get('_id')} - invalid pickup location format: {ride_pickup}")
                    continue
                
                # Calculate distance using Haversine formula (approximate)
                import math
                
                def haversine_distance(lat1, lng1, lat2, lng2):
                    """Calculate distance between two points in kilometers"""
                    R = 6371  # Earth's radius in kilometers
                    
                    lat1_rad = math.radians(lat1)
                    lng1_rad = math.radians(lng1)
                    lat2_rad = math.radians(lat2)
                    lng2_rad = math.radians(lng2)
                    
                    dlat = lat2_rad - lat1_rad
                    dlng = lng2_rad - lng1_rad
                    
                    a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng/2)**2
                    c = 2 * math.asin(math.sqrt(a))
                    
                    return R * c
                
                distance_km = haversine_distance(user_lat, user_lng, ride_lat, ride_lng)
                print(f"Ride {ride.get('_id')} distance: {distance_km:.2f}km (pickup: {ride_lat}, {ride_lng})")
                
                # Include rides within the specified radius
                if distance_km <= radius_km:
                    ride["distance_km"] = round(distance_km, 2)  # Add distance for sorting
                    nearby_rides.append(ride)
                    print(f"✓ Included ride {ride.get('_id')} - {distance_km:.2f}km away")
                else:
                    print(f"✗ Excluded ride {ride.get('_id')} - {distance_km:.2f}km away (outside {radius_km}km radius)")
                    
            except Exception as e:
                print(f"Error processing ride {ride.get('_id', 'unknown')}: {e}")
                continue
        
        # Sort by distance (closest first)
        nearby_rides.sort(key=lambda r: r.get("distance_km", 999))
        
        # Convert to API format
        docs = []
        for ride in nearby_rides[:limit]:
            try:
                doc = serialize_with_renamed_id(ride)
                docs.append(doc)
            except Exception as e:
                print(f"Error serializing ride: {e}")
                continue
        
        print(f"Returning {len(docs)} nearby rides within {radius_km}km")
        return jsonify({"rides": docs})
        
    except Exception as e:
        print(f"Error in ride search: {e}")
        import traceback
        traceback.print_exc()
        # Return empty result instead of error to prevent app crash
        return jsonify({
            "rides": [],
            "error": f"Search failed: {str(e)}",
            "debug_info": "Check server logs for details"
        })


@bp.get("/test/db-status")
def test_db_status():
    """Test database connectivity"""
    try:
        count = rides_collection.count_documents({})
        return jsonify({
            "status": "success",
            "total_rides": count,
            "database": "connected"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e),
            "database": "disconnected"
        }), 500

@bp.get("/test/list-rides")
def test_list_rides():
    """List all rides with their pickup locations for debugging"""
    try:
        rides = list(rides_collection.find({}).limit(10))
        rides_info = []
        
        for ride in rides:
            ride_info = {
                "id": str(ride.get("_id")),
                "status": ride.get("status"),
                "pickup_location": ride.get("pickup_location"),
                "pickup_address": ride.get("pickup_address"),
                "created_at": ride.get("created_at")
            }
            rides_info.append(ride_info)
        
        return jsonify({
            "status": "success",
            "total_rides": len(rides_info),
            "rides": rides_info
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 500

@bp.post("/test/create-sample")
def create_sample_ride():
    """Create a sample ride for testing"""
    sample_ride = {
        "driver_id": ObjectId(),  # Random driver ID for testing
        "pickup_location": {
            "type": "Point",
            "coordinates": [-74.006, 40.7128]  # NYC coordinates
        },
        "dropoff_location": {
            "type": "Point", 
            "coordinates": [-73.9857, 40.7484]  # NYC coordinates
        },
        "pickup_address": "Times Square, New York, NY",
        "dropoff_address": "Central Park, New York, NY",
        "price": 15.50,
        "seats_available": 3,
        "status": "active",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    result = rides_collection.insert_one(sample_ride)
    created_ride = rides_collection.find_one({"_id": result.inserted_id})
    
    return jsonify({
        "message": "Sample ride created",
        "ride": serialize_with_renamed_id(created_ride)
    })


@bp.get("/user")
def get_user_rides():
    user_id = request.args.get("user_id")
    if not user_id or not ObjectId.is_valid(user_id):
        return jsonify({"detail": "user_id query param required"}), 400
    query = {"$or": [{"passenger_id": ObjectId(user_id)}, {"driver_id": ObjectId(user_id)}]}
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [serialize_with_renamed_id(d) for d in rides_collection.find(query).limit(limit)]
    return jsonify({"rides": docs})

@bp.get("/user/<user_id>")
def get_user_rides_by_id(user_id: str):
    """Get rides for a specific user by ID in the URL path"""
    if not ObjectId.is_valid(user_id):
        return jsonify({"detail": "Invalid user ID"}), 400
    query = {"$or": [{"passenger_id": ObjectId(user_id)}, {"driver_id": ObjectId(user_id)}]}
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [serialize_with_renamed_id(d) for d in rides_collection.find(query).limit(limit)]
    return jsonify({"rides": docs})


@bp.post("/<ride_id>/request")
def request_ride_route(ride_id: str):
    """Passenger requests to join a ride"""
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    
    body = request.get_json(silent=True) or {}
    passenger_id = body.get("passenger_id")
    
    if not passenger_id or not ObjectId.is_valid(passenger_id):
        return jsonify({"detail": "Valid passenger_id is required"}), 400
    
    # Check if ride exists and is available
    ride = rides_collection.find_one({"_id": ObjectId(ride_id), "status": "active"})
    if not ride:
        return jsonify({"detail": "Ride not found or not available"}), 404
    
    # Update ride to pending status with passenger_id
    update = {
        "passenger_id": ObjectId(passenger_id),
        "status": "pending",
        "updated_at": datetime.utcnow()
    }
    
    result = rides_collection.update_one(
        {"_id": ObjectId(ride_id), "status": "active"},
        {"$set": update}
    )
    
    if result.modified_count == 0:
        return jsonify({"detail": "Ride not found or already has a passenger"}), 404
    
    return jsonify({"success": True, "message": "Ride request sent successfully"})


@bp.post("/<ride_id>/accept_passenger")
def accept_passenger_request_route(ride_id: str):
    """Driver accepts a passenger's ride request"""
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    
    body = request.get_json(silent=True) or {}
    passenger_id = body.get("passenger_id")
    
    if not passenger_id or not ObjectId.is_valid(passenger_id):
        return jsonify({"detail": "Valid passenger_id is required"}), 400
    
    # Check if ride exists and is pending
    ride = rides_collection.find_one({
        "_id": ObjectId(ride_id), 
        "status": "pending",
        "passenger_id": ObjectId(passenger_id)
    })
    
    if not ride:
        return jsonify({"detail": "Ride request not found or already processed"}), 404
    
    # Update ride to accepted status
    update = {
        "status": "accepted",
        "updated_at": datetime.utcnow()
    }
    
    result = rides_collection.update_one(
        {"_id": ObjectId(ride_id), "status": "pending", "passenger_id": ObjectId(passenger_id)},
        {"$set": update}
    )
    
    if result.modified_count == 0:
        return jsonify({"detail": "Failed to accept passenger request"}), 404
    
    return jsonify({"success": True, "message": "Passenger request accepted successfully"})


@bp.post("/<ride_id>/accept")
def accept_ride_route(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    body = request.get_json(silent=True) or {}
    driver_id = body.get("driver_id") or request.args.get("driver_id")
    update = {"status": "accepted", "updated_at": datetime.utcnow()}
    query = {"_id": ObjectId(ride_id), "status": {"$in": ["active", "pending_driver_acceptance", "pending", "in_progress"]}}
    if driver_id and ObjectId.is_valid(driver_id):
        update["driver_id"] = ObjectId(driver_id)
    result = rides_collection.update_one(query, {"$set": update})
    if result.modified_count == 0:
        return jsonify({"detail": "Ride not found or cannot accept"}), 404
    doc = rides_collection.find_one({"_id": ObjectId(ride_id)})
    return jsonify({"message": "Ride accepted successfully"})


@bp.put("/<ride_id>/status")
def update_ride_status_route(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    body = request.get_json(force=True)
    status = body.get("status")
    if status not in ["picked_up", "dropped_off", "completed", "cancelled", "in_progress", "accepted", "pending"]:
        return jsonify({"detail": "Invalid status"}), 400
    result = rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": status, "updated_at": datetime.utcnow()}},
    )
    if result.modified_count == 0:
        return jsonify({"detail": "Ride not found or no change"}), 404
    doc = rides_collection.find_one({"_id": ObjectId(ride_id)})
    return jsonify({"message": "Ride status updated successfully"})


@bp.get("/my_rides")
def get_my_rides():
    """Get all rides for the current user (as driver or passenger)."""
    # Prefer JWT token; fallback to query param for backward compatibility
    current_user_id = _get_current_user_id()
    if current_user_id is None:
        user_id_param = request.args.get("user_id")
        if not user_id_param or not ObjectId.is_valid(user_id_param):
            return jsonify({"detail": "Authentication required or user_id param missing"}), 401
        current_user_id = ObjectId(user_id_param)

    query = {"$or": [{"passenger_id": current_user_id}, {"driver_id": current_user_id}]}
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [serialize_with_renamed_id(d) for d in rides_collection.find(query).limit(limit)]
    return jsonify(docs)


