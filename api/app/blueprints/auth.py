from datetime import datetime, timedelta

from flask import Blueprint, request, jsonify
from jose import jwt
from passlib.hash import bcrypt
from pymongo.errors import DuplicateKeyError
from bson import ObjectId

from app.config import settings
from app.db_sync import users_collection
from app.utils import serialize_with_renamed_id


# Ensure unique index on email (safe if already exists)
try:
    users_collection.create_index("email", unique=True)
except Exception:
    pass


bp = Blueprint("auth", __name__, url_prefix="/auth")


def _generate_access_token(user_id: ObjectId, email: str) -> str:
    expire_minutes = int(getattr(settings, "ACCESS_TOKEN_EXPIRE_MINUTES", 30))
    expire = datetime.utcnow() + timedelta(minutes=expire_minutes)
    payload = {"sub": str(user_id), "email": email, "exp": expire}
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")
    return token


@bp.post("/register")
def register():
    body = request.get_json(force=True)
    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip().lower()
    password = body.get("password") or ""
    phone = (body.get("phone") or "").strip()

    if not email or not password:
        return jsonify({"detail": "email and password are required"}), 400

    now = datetime.utcnow()
    user_doc = {
        "name": name,
        "email": email,
        "phone": phone,
        "profile_image": None,
        "is_driver": False,
        "is_verified": False,
        "preferences": {},
        "hashed_password": bcrypt.hash(password),
        "created_at": now,
        "updated_at": now,
    }

    try:
        res = users_collection.insert_one(user_doc)
    except DuplicateKeyError:
        return jsonify({"detail": "Email already registered"}), 409

    created = users_collection.find_one({"_id": res.inserted_id})
    if created:
        created.pop("hashed_password", None)
    token = _generate_access_token(res.inserted_id, email)
    return (
        jsonify({
            "access_token": token,
            "token_type": "bearer",
            "user": serialize_with_renamed_id(created),
        }),
        201,
    )


@bp.post("/login")
def login():
    body = request.get_json(force=True)
    email = (body.get("email") or "").strip().lower()
    password = body.get("password") or ""

    if not email or not password:
        return jsonify({"detail": "email and password are required"}), 400

    user = users_collection.find_one({"email": email})
    if not user or not user.get("hashed_password") or not bcrypt.verify(password, user["hashed_password"]):
        return jsonify({"detail": "Invalid credentials"}), 401

    token = _generate_access_token(user["_id"], user["email"])
    user_out = dict(user)
    user_out.pop("hashed_password", None)
    return jsonify({
        "access_token": token,
        "token_type": "bearer",
        "user": serialize_with_renamed_id(user_out),
    })


