from fastapi import APIRouter, HTTPException, Depends
from app.schemas import Notification, PyObjectId
from app.database import notifications_collection, rides_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
from datetime import datetime, timedelta
import uuid

router = APIRouter()

@router.get("/", response_model=List[Notification])
async def get_user_notifications(
    limit: int = 50,
    unread_only: bool = False,
    user: User = Depends(fastapi_users.current_user)
):
    """Get notifications for the current user"""
    query = {"to_user_id": user.id}
    if unread_only:
        query["is_read"] = False
    
    notifications = await notifications_collection.find(query).sort("created_at", -1).limit(limit).to_list(limit)
    return notifications

@router.get("/unread-count", response_model=dict)
async def get_unread_count(user: User = Depends(fastapi_users.current_user)):
    """Get count of unread notifications"""
    count = await notifications_collection.count_documents({
        "to_user_id": user.id,
        "is_read": False
    })
    return {"unread_count": count}

@router.put("/{notification_id}/read", response_model=dict)
async def mark_notification_read(notification_id: str, user: User = Depends(fastapi_users.current_user)):
    """Mark a notification as read"""
    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    result = await notifications_collection.update_one(
        {"_id": ObjectId(notification_id), "to_user_id": user.id},
        {"$set": {"is_read": True, "read_at": datetime.utcnow()}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    return {"message": "Notification marked as read"}

@router.put("/mark-all-read", response_model=dict)
async def mark_all_notifications_read(user: User = Depends(fastapi_users.current_user)):
    """Mark all notifications as read for the current user"""
    result = await notifications_collection.update_many(
        {"to_user_id": user.id, "is_read": False},
        {"$set": {"is_read": True, "read_at": datetime.utcnow()}}
    )
    
    return {"message": f"Marked {result.modified_count} notifications as read"}

@router.delete("/{notification_id}", response_model=dict)
async def delete_notification(notification_id: str, user: User = Depends(fastapi_users.current_user)):
    """Delete a notification"""
    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    result = await notifications_collection.delete_one({
        "_id": ObjectId(notification_id),
        "to_user_id": user.id
    })
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    return {"message": "Notification deleted successfully"}

@router.delete("/clear-old", response_model=dict)
async def clear_old_notifications(days: int = 30, user: User = Depends(fastapi_users.current_user)):
    """Clear notifications older than specified days"""
    cutoff_date = datetime.utcnow() - timedelta(days=days)
    
    result = await notifications_collection.delete_many({
        "to_user_id": user.id,
        "created_at": {"$lt": cutoff_date}
    })
    
    return {"message": f"Cleared {result.deleted_count} old notifications"}

@router.post("/send", response_model=dict)
async def send_notification(
    to_user_id: str,
    notification_type: str,
    title: str,
    message: str,
    priority: str = "normal",
    ride_id: str = None,
    data: dict = None,
    user: User = Depends(fastapi_users.current_user)
):
    """Send a notification to another user"""
    if not ObjectId.is_valid(to_user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    notification_data = {
        "to_user_id": ObjectId(to_user_id),
        "from_user_id": user.id,
        "notification_type": notification_type,
        "title": title,
        "message": message,
        "priority": priority,
        "is_read": False,
        "created_at": datetime.utcnow()
    }
    
    if ride_id and ObjectId.is_valid(ride_id):
        notification_data["ride_id"] = ObjectId(ride_id)
    
    if data:
        notification_data["data"] = data
    
    result = await notifications_collection.insert_one(notification_data)
    
    return {"message": "Notification sent successfully", "notification_id": str(result.inserted_id)}

@router.get("/types", response_model=dict)
async def get_notification_types():
    """Get available notification types"""
    return {
        "notification_types": [
            "ride_request",
            "ride_accepted",
            "ride_rejected",
            "ride_started",
            "ride_completed",
            "ride_cancelled",
            "payment_received",
            "payment_failed",
            "driver_arrived",
            "pickup_reminder",
            "safety_alert",
            "emergency_alert",
            "rating_received",
            "feedback_received",
            "earnings_update",
            "payout_processed",
            "system_update",
            "promotion"
        ]
    }

# Helper function to create notifications
async def create_notification(
    to_user_id: ObjectId,
    notification_type: str,
    title: str,
    message: str,
    priority: str = "normal",
    ride_id: ObjectId = None,
    from_user_id: ObjectId = None,
    data: dict = None
):
    """Helper function to create notifications"""
    notification_data = {
        "to_user_id": to_user_id,
        "notification_type": notification_type,
        "title": title,
        "message": message,
        "priority": priority,
        "is_read": False,
        "created_at": datetime.utcnow()
    }
    
    if from_user_id:
        notification_data["from_user_id"] = from_user_id
    
    if ride_id:
        notification_data["ride_id"] = ride_id
    
    if data:
        notification_data["data"] = data
    
    await notifications_collection.insert_one(notification_data)