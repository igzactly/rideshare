from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from app.schemas import EmergencyAlert, EmergencyType, PyObjectId
from app.database import emergency_alerts_collection, rides_collection, user_profiles_collection
from app.auth import User
from fastapi_users import FastAPIUsers
from app.auth import auth_backend, get_user_db
import uuid
from typing import List
from bson import ObjectId
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
import os

router = APIRouter()

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    None,
    None,
    None,
)

@router.post("/emergency", response_model=EmergencyAlert)
async def create_emergency_alert(
    emergency: EmergencyAlert,
    background_tasks: BackgroundTasks,
    user: User = Depends(fastapi_users.current_user)
):
    """Create an emergency alert (panic button, accident, etc.)"""
    emergency.user_id = user.id
    emergency.timestamp = datetime.utcnow()
    emergency.status = "active"
    
    emergency_dict = emergency.dict(by_alias=True, exclude_unset=True)
    result = await emergency_alerts_collection.insert_one(emergency_dict)
    
    created_alert = await emergency_alerts_collection.find_one({"_id": result.inserted_id})
    
    # Trigger background tasks for emergency response
    background_tasks.add_task(notify_emergency_contacts, emergency)
    background_tasks.add_task(notify_authorities, emergency)
    
    return created_alert

@router.get("/emergency/{alert_id}", response_model=EmergencyAlert)
async def get_emergency_alert(
    alert_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get emergency alert details"""
    if not ObjectId.is_valid(alert_id):
        raise HTTPException(status_code=400, detail="Invalid alert ID")
    
    alert = await emergency_alerts_collection.find_one({"_id": ObjectId(alert_id)})
    if not alert:
        raise HTTPException(status_code=404, detail="Emergency alert not found")
    
    # Only allow users to see their own alerts or alerts from rides they're part of
    if str(alert["user_id"]) != str(user.id):
        if alert.get("ride_id"):
            ride = await rides_collection.find_one({
                "_id": alert["ride_id"],
                "$or": [
                    {"driver_id": user.id},
                    {"passenger_id": user.id}
                ]
            })
            if not ride:
                raise HTTPException(status_code=403, detail="Not authorized to view this alert")
        else:
            raise HTTPException(status_code=403, detail="Not authorized to view this alert")
    
    return alert

@router.put("/emergency/{alert_id}/resolve", response_model=EmergencyAlert)
async def resolve_emergency_alert(
    alert_id: str,
    resolution_notes: str = "",
    user: User = Depends(fastapi_users.current_user)
):
    """Resolve an emergency alert"""
    if not ObjectId.is_valid(alert_id):
        raise HTTPException(status_code=400, detail="Invalid alert ID")
    
    alert = await emergency_alerts_collection.find_one({"_id": ObjectId(alert_id)})
    if not alert:
        raise HTTPException(status_code=404, detail="Emergency alert not found")
    
    # Only allow users to resolve their own alerts or alerts from rides they're part of
    if str(alert["user_id"]) != str(user.id):
        if alert.get("ride_id"):
            ride = await rides_collection.find_one({
                "_id": alert["ride_id"],
                "$or": [
                    {"driver_id": user.id},
                    {"passenger_id": user.id}
                ]
            })
            if not ride:
                raise HTTPException(status_code=403, detail="Not authorized to resolve this alert")
        else:
            raise HTTPException(status_code=403, detail="Not authorized to resolve this alert")
    
    result = await emergency_alerts_collection.update_one(
        {"_id": ObjectId(alert_id)},
        {
            "$set": {
                "status": "resolved",
                "resolved_by": user.id,
                "resolved_at": datetime.utcnow()
            }
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to resolve emergency alert")
    
    updated_alert = await emergency_alerts_collection.find_one({"_id": ObjectId(alert_id)})
    return updated_alert

@router.get("/emergency/active", response_model=List[EmergencyAlert])
async def get_active_emergency_alerts(
    user: User = Depends(fastapi_users.current_user)
):
    """Get all active emergency alerts for rides the user is part of"""
    # Find rides where the user is a participant
    user_rides = await rides_collection.find({
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ]
    }).to_list(100)
    
    ride_ids = [ride["_id"] for ride in user_rides]
    
    # Get active emergency alerts for these rides
    active_alerts = await emergency_alerts_collection.find({
        "ride_id": {"$in": ride_ids},
        "status": "active"
    }).to_list(100)
    
    return active_alerts

@router.post("/panic-button", response_model=EmergencyAlert)
async def trigger_panic_button(
    ride_id: str,
    location: List[float],
    description: str = "",
    background_tasks: BackgroundTasks = None,
    user: User = Depends(fastapi_users.current_user)
):
    """Trigger panic button for immediate emergency response"""
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
    
    # Create emergency alert
    emergency = EmergencyAlert(
        user_id=user.id,
        ride_id=ObjectId(ride_id),
        emergency_type=EmergencyType.PANIC_BUTTON,
        location=location,
        description=description or "Panic button activated"
    )
    
    emergency_dict = emergency.dict(by_alias=True, exclude_unset=True)
    result = await emergency_alerts_collection.insert_one(emergency_dict)
    
    created_alert = await emergency_alerts_collection.find_one({"_id": result.inserted_id})
    
    # Trigger immediate emergency response
    if background_tasks:
        background_tasks.add_task(immediate_emergency_response, emergency)
    
    return created_alert

@router.get("/safety-check/{ride_id}", response_model=dict)
async def perform_safety_check(
    ride_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Perform a safety check for a ride"""
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
    
    # Check for any active emergency alerts
    active_alerts = await emergency_alerts_collection.count_documents({
        "ride_id": ObjectId(ride_id),
        "status": "active"
    })
    
    # Get user profiles for safety verification
    driver_profile = await user_profiles_collection.find_one({"user_id": ride["driver_id"]})
    passenger_profile = None
    if ride.get("passenger_id"):
        passenger_profile = await user_profiles_collection.find_one({"user_id": ride["passenger_id"]})
    
    safety_status = {
        "ride_id": ride_id,
        "has_active_emergencies": active_alerts > 0,
        "driver_verified": driver_profile.get("is_verified", False) if driver_profile else False,
        "passenger_verified": passenger_profile.get("is_verified", False) if passenger_profile else False,
        "safety_score": calculate_safety_score(ride, driver_profile, passenger_profile),
        "recommendations": generate_safety_recommendations(ride, driver_profile, passenger_profile)
    }
    
    return safety_status

# Background task functions
async def notify_emergency_contacts(emergency: EmergencyAlert):
    """Notify emergency contacts about the emergency"""
    try:
        # Get user profile for emergency contact
        user_profile = await user_profiles_collection.find_one({"user_id": emergency.user_id})
        if user_profile and user_profile.get("emergency_contact"):
            # In a real implementation, this would send SMS/email
            print(f"Emergency contact notification sent to {user_profile['emergency_contact']}")
    except Exception as e:
        print(f"Failed to notify emergency contacts: {e}")

async def notify_authorities(emergency: EmergencyAlert):
    """Notify relevant authorities about the emergency"""
    try:
        # In a real implementation, this would integrate with emergency services
        print(f"Authorities notified about emergency: {emergency.emergency_type}")
    except Exception as e:
        print(f"Failed to notify authorities: {e}")

async def immediate_emergency_response(emergency: EmergencyAlert):
    """Immediate emergency response for panic button"""
    try:
        # In a real implementation, this would trigger immediate response protocols
        print(f"Immediate emergency response triggered for user {emergency.user_id}")
    except Exception as e:
        print(f"Failed to trigger immediate emergency response: {e}")

def calculate_safety_score(ride: dict, driver_profile: dict, passenger_profile: dict) -> float:
    """Calculate a safety score for the ride"""
    score = 100.0
    
    # Deduct points for various risk factors
    if driver_profile and not driver_profile.get("is_verified", False):
        score -= 20
    
    if passenger_profile and not passenger_profile.get("is_verified", False):
        score -= 10
    
    # Add points for positive factors
    if driver_profile and driver_profile.get("rating", 0) > 4.0:
        score += 10
    
    return max(0, min(100, score))

def generate_safety_recommendations(ride: dict, driver_profile: dict, passenger_profile: dict) -> List[str]:
    """Generate safety recommendations for the ride"""
    recommendations = []
    
    if driver_profile and not driver_profile.get("is_verified", False):
        recommendations.append("Driver verification recommended")
    
    if passenger_profile and not passenger_profile.get("is_verified", False):
        recommendations.append("Passenger verification recommended")
    
    if not recommendations:
        recommendations.append("Ride appears safe - enjoy your journey!")
    
    return recommendations 