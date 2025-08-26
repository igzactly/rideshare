from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from pymongo import ReturnDocument
from app.db_sync import drivers_collection, rides_collection
from app.utils import serialize_doc, serialize_with_renamed_id

bp = Blueprint("drivers", __name__, url_prefix="/driver")


@bp.post("/routes")
def create_driver_route():
    payload = request.get_json(force=True)
    payload["created_at"] = datetime.utcnow()
    res = drivers_collection.insert_one(payload)
    doc = drivers_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_with_renamed_id(doc)), 201


@bp.get("/routes")
def get_driver_routes():
    user_id = request.args.get("user_id")
    query = {"driver_id": ObjectId(user_id)} if user_id and ObjectId.is_valid(user_id) else {}
    routes = [serialize_with_renamed_id(d) for d in drivers_collection.find(query).limit(100)]
    return jsonify({"routes": routes})


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


# Basic CRUD for drivers collection (profiles/info)
@bp.post("/")
@bp.post("")
def create_driver():
    payload = request.get_json(force=True)
    now = datetime.utcnow()
    payload.setdefault("created_at", now)
    payload.setdefault("updated_at", now)
    # Normalize optional user reference
    if payload.get("user_id") and ObjectId.is_valid(payload["user_id"]):
        payload["user_id"] = ObjectId(payload["user_id"])
    res = drivers_collection.insert_one(payload)
    doc = drivers_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_with_renamed_id(doc)), 201


@bp.get("/")
def list_drivers():
    query = {}
    user_id = request.args.get("user_id")
    if user_id and ObjectId.is_valid(user_id):
        query["user_id"] = ObjectId(user_id)
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [serialize_with_renamed_id(d) for d in drivers_collection.find(query).limit(limit)]
    return jsonify(docs)


@bp.get("/<driver_id>")
def get_driver(driver_id: str):
    if not ObjectId.is_valid(driver_id):
        return jsonify({"detail": "Invalid driver ID"}), 400
    doc = drivers_collection.find_one({"_id": ObjectId(driver_id)})
    if not doc:
        return jsonify({"detail": "Driver not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.put("/<driver_id>")
def update_driver(driver_id: str):
    if not ObjectId.is_valid(driver_id):
        return jsonify({"detail": "Invalid driver ID"}), 400
    updates = request.get_json(force=True)
    updates["updated_at"] = datetime.utcnow()
    if updates.get("user_id") and ObjectId.is_valid(updates["user_id"]):
        updates["user_id"] = ObjectId(updates["user_id"])
    doc = drivers_collection.find_one_and_update(
        {"_id": ObjectId(driver_id)},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return jsonify({"detail": "Driver not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.delete("/<driver_id>")
def delete_driver(driver_id: str):
    if not ObjectId.is_valid(driver_id):
        return jsonify({"detail": "Invalid driver ID"}), 400
    result = drivers_collection.delete_one({"_id": ObjectId(driver_id)})
    if result.deleted_count == 0:
        return jsonify({"detail": "Driver not found"}), 404
    return jsonify({"deleted": True})


