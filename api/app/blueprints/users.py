from flask import Blueprint, request, jsonify
from bson import ObjectId
from datetime import datetime
from pymongo import ReturnDocument

from app.db_sync import users_collection
from app.utils import serialize_with_renamed_id


bp = Blueprint("users", __name__, url_prefix="/users")


@bp.post("/")
@bp.post("")
def create_user():
    payload = request.get_json(force=True)
    now = datetime.utcnow()
    payload.setdefault("created_at", now)
    payload.setdefault("updated_at", now)
    res = users_collection.insert_one(payload)
    doc = users_collection.find_one({"_id": res.inserted_id})
    return jsonify(serialize_with_renamed_id(doc)), 201


@bp.get("/")
def list_users():
    limit = min(int(request.args.get("limit", 50)), 200)
    docs = [serialize_with_renamed_id(d) for d in users_collection.find().limit(limit)]
    return jsonify(docs)


@bp.get("/<user_id>")
def get_user(user_id: str):
    if not ObjectId.is_valid(user_id):
        return jsonify({"detail": "Invalid user ID"}), 400
    doc = users_collection.find_one({"_id": ObjectId(user_id)})
    if not doc:
        return jsonify({"detail": "User not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.put("/<user_id>")
def update_user(user_id: str):
    if not ObjectId.is_valid(user_id):
        return jsonify({"detail": "Invalid user ID"}), 400
    updates = request.get_json(force=True)
    updates["updated_at"] = datetime.utcnow()
    doc = users_collection.find_one_and_update(
        {"_id": ObjectId(user_id)},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return jsonify({"detail": "User not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.get("/profile")
def get_profile():
    user_id = request.args.get("user_id") or request.headers.get("X-User-Id")
    if not user_id or not ObjectId.is_valid(user_id):
        return jsonify({"detail": "user_id required"}), 400
    doc = users_collection.find_one({"_id": ObjectId(user_id)})
    if not doc:
        return jsonify({"detail": "User not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.put("/profile")
def update_profile():
    user_id = request.args.get("user_id") or request.headers.get("X-User-Id")
    if not user_id or not ObjectId.is_valid(user_id):
        return jsonify({"detail": "user_id required"}), 400
    updates = request.get_json(force=True)
    updates["updated_at"] = datetime.utcnow()
    doc = users_collection.find_one_and_update(
        {"_id": ObjectId(user_id)}, {"$set": updates}, return_document=ReturnDocument.AFTER
    )
    if not doc:
        return jsonify({"detail": "User not found"}), 404
    return jsonify(serialize_with_renamed_id(doc))


@bp.delete("/<user_id>")
def delete_user(user_id: str):
    if not ObjectId.is_valid(user_id):
        return jsonify({"detail": "Invalid user ID"}), 400
    result = users_collection.delete_one({"_id": ObjectId(user_id)})
    if result.deleted_count == 0:
        return jsonify({"detail": "User not found"}), 404
    return jsonify({"deleted": True})


