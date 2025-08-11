from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from app.schemas import Notification, NotificationType
from app.database import notifications_collection, rides_collection, user_profiles_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List, Optional
from datetime import datetime, timedelta
import json

router = APIRouter()

@router.post("/", response_model=Notification)
async def create_notification(
    notification: Notification,
    user: User = Depends(fastapi_users.current_user)
):
    """Create a new notification"""
    notification.from_user_id = user.id
    notification.created_at = datetime.utcnow()
    notification.is_read = False
    
    notification_dict = notification.dict(by_alias=True, exclude_unset=True)
    result = await notifications_collection.insert_one(notification_dict)
    created_notification = await notifications_collection.find_one({"_id": result.inserted_id})
    if created_notification is None:
        raise HTTPException(status_code=404, detail="Notification creation failed")
    return created_notification

@router.get("/user/{user_id}", response_model=List[Notification])
async def get_user_notifications(
    user_id: str,
    unread_only: bool = False,
    limit: int = 50,
    user: User = Depends(fastapi_users.current_user)
):
    """Get notifications for a specific user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can only view their own notifications
    if str(user.id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view these notifications")
    
    # Build query
    query = {"to_user_id": ObjectId(user_id)}
    if unread_only:
        query["is_read"] = False
    
    notifications = await notifications_collection.find(query).sort("created_at", -1).limit(limit).to_list(limit)
    return notifications

@router.put("/{notification_id}/read", response_model=dict)
async def mark_notification_read(
    notification_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Mark a notification as read"""
    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    notification = await notifications_collection.find_one({"_id": ObjectId(notification_id)})
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    # Check if user owns this notification
    if str(notification.get("to_user_id")) != str(user.id):
        raise HTTPException(status_code=403, detail="Not authorized to modify this notification")
    
    result = await notifications_collection.update_one(
        {"_id": ObjectId(notification_id)},
        {"$set": {"is_read": True, "read_at": datetime.utcnow()}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to mark notification as read")
    
    return {"message": "Notification marked as read"}

@router.put("/user/{user_id}/read-all", response_model=dict)
async def mark_all_notifications_read(
    user_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Mark all notifications for a user as read"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can only mark their own notifications as read
    if str(user.id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to modify these notifications")
    
    result = await notifications_collection.update_many(
        {"to_user_id": ObjectId(user_id), "is_read": False},
        {"$set": {"is_read": True, "read_at": datetime.utcnow()}}
    )
    
    return {"message": f"Marked {result.modified_count} notifications as read"}

@router.delete("/{notification_id}", response_model=dict)
async def delete_notification(
    notification_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Delete a notification"""
    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    notification = await notifications_collection.find_one({"_id": ObjectId(notification_id)})
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    # Check if user owns this notification
    if str(notification.get("to_user_id")) != str(user.id):
        raise HTTPException(status_code=403, detail="Not authorized to delete this notification")
    
    result = await notifications_collection.delete_one({"_id": ObjectId(notification_id)})
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=400, detail="Failed to delete notification")
    
    return {"message": "Notification deleted successfully"}

@router.get("/user/{user_id}/unread-count", response_model=dict)
async def get_unread_notification_count(
    user_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get count of unread notifications for a user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can only view their own notification count
    if str(user.id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this information")
    
    count = await notifications_collection.count_documents({
        "to_user_id": ObjectId(user_id),
        "is_read": False
    })
    
    return {"unread_count": count}

@router.post("/ride-update", response_model=dict)
async def send_ride_update_notification(
    ride_id: str,
    notification_type: str,
    message: str,
    background_tasks: BackgroundTasks,
    user: User = Depends(fastapi_users.current_user)
):
    """Send ride update notification to all participants"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    # Verify user is part of this ride
    ride = await rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ]
    })
    
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or user not authorized")
    
    # Get all participants
    participants = [ride["driver_id"]]
    if ride.get("passenger_id"):
        participants.append(ride["passenger_id"])
    
    # Create notifications for all participants
    notifications = []
    for participant_id in participants:
        if str(participant_id) != str(user.id):  # Don't notify the sender
            notification = Notification(
                to_user_id=participant_id,
                from_user_id=user.id,
                notification_type=NotificationType.RIDE_UPDATE,
                title=f"Ride Update - {notification_type.title()}",
                message=message,
                ride_id=ride_id,
                metadata={
                    "ride_id": ride_id,
                    "update_type": notification_type,
                    "sender_name": user.email  # You might want to get actual name from profile
                }
            )
            notifications.append(notification)
    
    # Insert notifications in background
    background_tasks.add_task(insert_notifications, notifications)
    
    return {"message": f"Notifications sent to {len(notifications)} participants"}

@router.post("/safety-alert", response_model=dict)
async def send_safety_alert_notification(
    ride_id: str,
    alert_type: str,
    message: str,
    background_tasks: BackgroundTasks,
    user: User = Depends(fastapi_users.current_user)
):
    """Send safety alert notification to emergency contacts and authorities"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    # Verify user is part of this ride
    ride = await rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ]
    })
    
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or user not authorized")
    
    # Get user profile for emergency contacts
    user_profile = await user_profiles_collection.find_one({"user_id": user.id})
    emergency_contacts = user_profile.get("emergency_contacts", []) if user_profile else []
    
    # Create safety alert notification
    safety_notification = Notification(
        to_user_id=user.id,  # Also notify the user themselves
        from_user_id=user.id,
        notification_type=NotificationType.SAFETY_ALERT,
        title=f"Safety Alert - {alert_type.title()}",
        message=message,
        ride_id=ride_id,
        priority="high",
        metadata={
            "ride_id": ride_id,
            "alert_type": alert_type,
            "emergency_contacts": emergency_contacts,
            "location": user_profile.get("current_location") if user_profile else None
        }
    )
    
    # Insert notification
    await notifications_collection.insert_one(safety_notification.dict(by_alias=True, exclude_unset=True))
    
    # Send to emergency contacts in background
    if emergency_contacts:
        background_tasks.add_task(send_emergency_notifications, emergency_contacts, safety_notification)
    
    return {"message": "Safety alert notification sent"}

@router.post("/payment-reminder", response_model=dict)
async def send_payment_reminder(
    ride_id: str,
    user_id: str,
    background_tasks: BackgroundTasks,
    user: User = Depends(fastapi_users.current_user)
):
    """Send payment reminder notification"""
    if not ObjectId.is_valid(ride_id) or not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid ride or user ID")
    
    # Verify user is authorized to send payment reminders
    ride = await rides_collection.find_one({
        "_id": ObjectId(ride_id),
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ]
    })
    
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or user not authorized")
    
    # Create payment reminder notification
    payment_notification = Notification(
        to_user_id=ObjectId(user_id),
        from_user_id=user.id,
        notification_type=NotificationType.PAYMENT_REMINDER,
        title="Payment Reminder",
        message="Please complete payment for your recent ride",
        ride_id=ride_id,
        priority="medium",
        metadata={
            "ride_id": ride_id,
            "amount": ride.get("fare", 0),
            "due_date": (datetime.utcnow() + timedelta(days=7)).isoformat()
        }
    )
    
    # Insert notification
    await notifications_collection.insert_one(payment_notification.dict(by_alias=True, exclude_unset=True))
    
    return {"message": "Payment reminder sent"}

async def insert_notifications(notifications: List[Notification]):
    """Background task to insert multiple notifications"""
    for notification in notifications:
        notification_dict = notification.dict(by_alias=True, exclude_unset=True)
        await notifications_collection.insert_one(notification_dict)

async def send_emergency_notifications(emergency_contacts: List[dict], notification: Notification):
    """Background task to send emergency notifications to contacts"""
    # This would integrate with external notification services (SMS, email, push notifications)
    # For now, we'll just log the action
    print(f"Emergency notification would be sent to {len(emergency_contacts)} contacts")
    print(f"Alert details: {notification.title} - {notification.message}")
    
    # In production, you would:
    # 1. Send SMS via Twilio or similar service
    # 2. Send email notifications
    # 3. Send push notifications to mobile apps
    # 4. Log the notification attempts
    # 5. Handle delivery confirmations

@router.get("/types", response_model=List[str])
async def get_notification_types():
    """Get available notification types"""
    return [nt.value for nt in NotificationType]

@router.get("/priorities", response_model=List[str])
async def get_notification_priorities():
    """Get available notification priorities"""
    return ["low", "medium", "high", "urgent"] 