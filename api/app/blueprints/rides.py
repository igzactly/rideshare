from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from app.db_sync import rides_collection

bp = Blueprint("rides", __name__, url_prefix="/rides")


@bp.post("/")
def create_ride():
    payload = request.get_json(force=True)
    payload["created_at"] = datetime.utcnow()
    res = rides_collection.insert_one(payload)
    doc = rides_collection.find_one({"_id": res.inserted_id})
    doc["_id"] = str(doc["_id"])  # naive serialization
    return jsonify(doc), 201


@bp.get("/<ride_id>")
def get_ride(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        return jsonify({"detail": "Invalid ride ID"}), 400
    doc = rides_collection.find_one({"_id": ObjectId(ride_id)})
    if not doc:
        return jsonify({"detail": "Ride not found"}), 404
    doc["_id"] = str(doc["_id"])  # naive serialization
    return jsonify(doc)


