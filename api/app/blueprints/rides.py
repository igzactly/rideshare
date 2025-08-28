from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from pymongo import ReturnDocument, GEOSPHERE
from app.db_sync import rides_collection
from app.utils import serialize_with_renamed_id

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
        rides_collection.create_index([("pickup_location", GEOSPHERE)])
        rides_collection.create_index([("dropoff_location", GEOSPHERE)])
        rides_collection.create_index("status")
        rides_collection.create_index("created_at")
    except Exception:
        # Index creation is best-effort; ignore errors to avoid blocking requests
        pass


_ensure_indexes_once()

@bp.post("/")
@bp.post("")
def create_ride():
    payload = request.get_json(force=True)
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
    res = rides_collection.insert_one(payload)
    doc = rides_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_with_renamed_id(doc)), 201


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
    """Geo search for nearby driver rides based on passenger request.

    Expected JSON body:
    {
      "pickup_location": {"latitude": <lat>, "longitude": <lng>} | {"type":"Point","coordinates":[lng,lat]},
      "radius_km": 5.0  # optional
    }
    """
    body = request.get_json(silent=True) or {}
    pickup_point = _to_geojson_point(body.get("pickup_location"))
    if not pickup_point:
        return jsonify({"detail": "pickup_location is required"}), 400
    try:
        radius_km = float(body.get("radius_km", 5.0))
    except Exception:
        radius_km = 5.0

    # Build geo query
    query = {
        "pickup_location": {
            "$near": {
                "$geometry": pickup_point,
                "$maxDistance": int(radius_km * 1000),
            }
        }
    }
    # Prefer active rides; if none present, this still returns empty which is OK
    # We do not strictly filter by status to avoid excluding legacy docs
    limit = min(int(body.get("limit", 50)), 200)
    docs = [
        serialize_with_renamed_id(d)
        for d in rides_collection.find(query).limit(limit)
    ]
    return jsonify({"rides": docs})


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


