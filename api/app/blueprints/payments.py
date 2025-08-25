from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from app.db_sync import payments_collection
from app.utils import serialize_doc

bp = Blueprint("payments", __name__, url_prefix="/payments")


@bp.post("/")
def create_payment():
    payload = request.get_json(force=True)
    payload["created_at"] = datetime.utcnow()
    res = payments_collection.insert_one(payload)
    doc = payments_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_doc(doc)), 201


@bp.get("/<payment_id>")
def get_payment(payment_id: str):
    if not ObjectId.is_valid(payment_id):
        return jsonify({"detail": "Invalid payment ID"}), 400
    doc = payments_collection.find_one({"_id": ObjectId(payment_id)})
    if not doc:
        return jsonify({"detail": "Payment not found"}), 404
    return jsonify(serialize_doc(doc))


@bp.put("/<payment_id>/status")
def update_payment_status(payment_id: str):
    if not ObjectId.is_valid(payment_id):
        return jsonify({"detail": "Invalid payment ID"}), 400
    body = request.get_json(force=True)
    status = body.get("status")
    if status not in ["pending", "completed", "failed"]:
        return jsonify({"detail": "Invalid status"}), 400
    result = payments_collection.update_one(
        {"_id": ObjectId(payment_id)},
        {"$set": {"status": status, "updated_at": datetime.utcnow()}}
    )
    if result.modified_count == 0:
        return jsonify({"detail": "Payment not found or no change"}), 404
    doc = payments_collection.find_one({"_id": ObjectId(payment_id)})
    return jsonify(serialize_doc(doc))


