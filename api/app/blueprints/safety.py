from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from app.db_sync import emergency_alerts_collection, rides_collection
from app.utils import serialize_doc

bp = Blueprint("safety", __name__, url_prefix="/safety")


@bp.post("/emergency")
def create_emergency():
    payload = request.get_json(force=True)
    payload["timestamp"] = datetime.utcnow()
    payload.setdefault("status", "active")
    res = emergency_alerts_collection.insert_one(payload)
    doc = emergency_alerts_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_doc(doc)), 201


@bp.get("/emergency/<alert_id>")
def get_emergency(alert_id: str):
    if not ObjectId.is_valid(alert_id):
        return jsonify({"detail": "Invalid alert ID"}), 400
    doc = emergency_alerts_collection.find_one({"_id": ObjectId(alert_id)})
    if not doc:
        return jsonify({"detail": "Alert not found"}), 404
    return jsonify(serialize_doc(doc))


@bp.put("/emergency/<alert_id>/resolve")
def resolve_emergency(alert_id: str):
    if not ObjectId.is_valid(alert_id):
        return jsonify({"detail": "Invalid alert ID"}), 400
    result = emergency_alerts_collection.update_one(
        {"_id": ObjectId(alert_id)},
        {"$set": {"status": "resolved", "resolved_at": datetime.utcnow()}}
    )
    if result.modified_count == 0:
        return jsonify({"detail": "Alert not found"}), 404
    doc = emergency_alerts_collection.find_one({"_id": ObjectId(alert_id)})
    return jsonify(serialize_doc(doc))


@bp.get("/emergency/active")
def active_emergencies():
    alerts = [serialize_doc(d) for d in emergency_alerts_collection.find({"status": "active"}).limit(100)]
    return jsonify(alerts)


