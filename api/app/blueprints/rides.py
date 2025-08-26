from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from pymongo import ReturnDocument
from app.db_sync import rides_collection
from app.utils import serialize_with_renamed_id

bp = Blueprint("rides", __name__, url_prefix="/rides")


@bp.post("/")
@bp.post("")
def create_ride():
    payload = request.get_json(force=True)
    now = datetime.utcnow()
    payload.setdefault("created_at", now)
    payload.setdefault("updated_at", now)
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
    return jsonify({"deleted": True})


@bp.get("/search")
def search_rides():
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


@bp.post("/<ride_id>/accept")
def accept_ride_route(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    body = request.get_json(silent=True) or {}
    driver_id = body.get("driver_id") or request.args.get("driver_id")
    if not driver_id or not ObjectId.is_valid(driver_id):
        return jsonify({"detail": "driver_id required"}), 400
    result = rides_collection.update_one(
        {"_id": ObjectId(ride_id), "status": {"$in": ["active", "pending_driver_acceptance", "pending"]}},
        {"$set": {"driver_id": ObjectId(driver_id), "status": "accepted", "updated_at": datetime.utcnow()}},
    )
    if result.modified_count == 0:
        return jsonify({"detail": "Ride not found or cannot accept"}), 404
    return jsonify({"message": "Ride accepted"})


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
    return jsonify(serialize_with_renamed_id(doc))


