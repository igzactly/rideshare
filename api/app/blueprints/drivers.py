from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from app.db_sync import drivers_collection, rides_collection
from app.utils import serialize_doc

bp = Blueprint("drivers", __name__, url_prefix="/driver")


@bp.post("/routes")
def create_driver_route():
    payload = request.get_json(force=True)
    payload["created_at"] = datetime.utcnow()
    res = drivers_collection.insert_one(payload)
    doc = drivers_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_doc(doc)), 201


@bp.get("/routes")
def get_driver_routes():
    user_id = request.args.get("user_id")
    query = {"driver_id": ObjectId(user_id)} if user_id and ObjectId.is_valid(user_id) else {}
    routes = [serialize_doc(d) for d in drivers_collection.find(query).limit(100)]
    return jsonify(routes)


@bp.post("/rides/<ride_id>/accept")
def accept_ride(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    body = request.get_json(silent=True) or {}
    driver_id = body.get("driver_id")
    if not driver_id or not ObjectId.is_valid(driver_id):
        return jsonify({"detail": "driver_id required"}), 400
    result = rides_collection.update_one(
        {"_id": ObjectId(ride_id), "status": {"$in": ["active", "pending_driver_acceptance"]}},
        {"$set": {"driver_id": ObjectId(driver_id), "status": "accepted", "updated_at": datetime.utcnow()}}
    )
    if result.modified_count == 0:
        return jsonify({"detail": "Ride not found or cannot accept"}), 404
    return jsonify({"message": "Ride accepted"})


@bp.put("/rides/<ride_id>/status")
def update_ride_status(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    body = request.get_json(force=True)
    status = body.get("status")
    if status not in ["picked_up", "dropped_off", "completed", "cancelled", "in_progress"]:
        return jsonify({"detail": "Invalid status"}), 400
    result = rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": status, "updated_at": datetime.utcnow()}}
    )
    if result.modified_count == 0:
        return jsonify({"detail": "Ride not found"}), 404
    return jsonify({"message": "Status updated"})


