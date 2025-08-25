from datetime import datetime
from bson import ObjectId


def to_serializable(value):
    if isinstance(value, ObjectId):
        return str(value)
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, list):
        return [to_serializable(v) for v in value]
    if isinstance(value, dict):
        return {k: to_serializable(v) for k, v in value.items()}
    return value


def serialize_doc(doc: dict) -> dict:
    return to_serializable(doc or {})
