from fastapi import APIRouter, HTTPException, Depends
from app.schemas import RidePreferences, PyObjectId
from app.database import ride_preferences_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
from datetime import datetime
import uuid

router = APIRouter()

@router.get("/", response_model=RidePreferences)
async def get_user_preferences(user: User = Depends(fastapi_users.current_user)):
    """Get user's ride preferences"""
    preferences = await ride_preferences_collection.find_one({"user_id": user.id})
    
    if not preferences:
        # Create default preferences if none exist
        default_preferences = RidePreferences(user_id=user.id)
        preferences_dict = default_preferences.dict(by_alias=True, exclude_unset=True)
        result = await ride_preferences_collection.insert_one(preferences_dict)
        preferences = await ride_preferences_collection.find_one({"_id": result.inserted_id})
    
    return preferences

@router.put("/", response_model=RidePreferences)
async def update_user_preferences(
    preferences: RidePreferences,
    user: User = Depends(fastapi_users.current_user)
):
    """Update user's ride preferences"""
    preferences.user_id = user.id
    preferences.updated_at = datetime.utcnow()
    
    preferences_dict = preferences.dict(by_alias=True, exclude_unset=True)
    
    result = await ride_preferences_collection.update_one(
        {"user_id": user.id},
        {"$set": preferences_dict},
        upsert=True
    )
    
    updated_preferences = await ride_preferences_collection.find_one({"user_id": user.id})
    return updated_preferences

@router.post("/reset", response_model=RidePreferences)
async def reset_user_preferences(user: User = Depends(fastapi_users.current_user)):
    """Reset user's preferences to defaults"""
    default_preferences = RidePreferences(user_id=user.id)
    preferences_dict = default_preferences.dict(by_alias=True, exclude_unset=True)
    
    result = await ride_preferences_collection.update_one(
        {"user_id": user.id},
        {"$set": preferences_dict},
        upsert=True
    )
    
    updated_preferences = await ride_preferences_collection.find_one({"user_id": user.id})
    return updated_preferences

@router.get("/available-options", response_model=dict)
async def get_available_preference_options():
    """Get all available preference options"""
    return {
        "ride_types": [
            "standard",
            "premium",
            "eco",
            "luxury"
        ],
        "vehicle_types": [
            "car",
            "van",
            "motorcycle",
            "bicycle",
            "electric_car",
            "hybrid_car"
        ],
        "amenities": [
            "wifi",
            "charging_port",
            "air_conditioning",
            "music",
            "water",
            "snacks",
            "phone_charger",
            "car_seat",
            "wheelchair_accessible"
        ],
        "music_preferences": [
            "none",
            "classical",
            "pop",
            "rock",
            "jazz",
            "electronic",
            "country",
            "hip_hop",
            "user_choice"
        ],
        "max_detour_minutes_options": [5, 10, 15, 20, 30],
        "pickup_time_buffer_options": [0, 5, 10, 15, 30]
    }

@router.get("/recommendations", response_model=dict)
async def get_ride_recommendations(user: User = Depends(fastapi_users.current_user)):
    """Get personalized ride recommendations based on preferences"""
    preferences = await ride_preferences_collection.find_one({"user_id": user.id})
    
    if not preferences:
        return {"message": "No preferences set", "recommendations": []}
    
    recommendations = []
    
    # Generate recommendations based on preferences
    if preferences.get("preferred_ride_types"):
        recommendations.append({
            "type": "ride_type",
            "message": f"Based on your preferences, we recommend {', '.join(preferences['preferred_ride_types'])} rides",
            "priority": "high"
        })
    
    if preferences.get("max_price_per_km"):
        recommendations.append({
            "type": "pricing",
            "message": f"Your budget of £{preferences['max_price_per_km']}/km will help you find affordable rides",
            "priority": "medium"
        })
    
    if preferences.get("required_amenities"):
        recommendations.append({
            "type": "amenities",
            "message": f"Look for rides with: {', '.join(preferences['required_amenities'])}",
            "priority": "high"
        })
    
    if preferences.get("avoid_tolls"):
        recommendations.append({
            "type": "route",
            "message": "We'll prioritize routes that avoid tolls to save you money",
            "priority": "low"
        })
    
    return {
        "user_preferences": preferences,
        "recommendations": recommendations,
        "total_recommendations": len(recommendations)
    }

@router.post("/match-score", response_model=dict)
async def calculate_preference_match_score(
    ride_data: dict,
    user: User = Depends(fastapi_users.current_user)
):
    """Calculate how well a ride matches user preferences"""
    preferences = await ride_preferences_collection.find_one({"user_id": user.id})
    
    if not preferences:
        return {"match_score": 0, "message": "No preferences set"}
    
    score = 0
    max_score = 0
    details = []
    
    # Check ride type match
    if "ride_type" in ride_data:
        max_score += 20
        if ride_data["ride_type"] in preferences.get("preferred_ride_types", []):
            score += 20
            details.append("Ride type matches preference")
        else:
            details.append("Ride type doesn't match preference")
    
    # Check vehicle type match
    if "vehicle_type" in ride_data:
        max_score += 15
        if ride_data["vehicle_type"] in preferences.get("preferred_vehicle_types", []):
            score += 15
            details.append("Vehicle type matches preference")
        else:
            details.append("Vehicle type doesn't match preference")
    
    # Check amenities match
    if "amenities" in ride_data:
        required_amenities = preferences.get("required_amenities", [])
        if required_amenities:
            max_score += 25
            matched_amenities = set(ride_data["amenities"]) & set(required_amenities)
            amenity_score = (len(matched_amenities) / len(required_amenities)) * 25
            score += amenity_score
            details.append(f"Matched {len(matched_amenities)}/{len(required_amenities)} required amenities")
    
    # Check price match
    if "price_per_seat" in ride_data and preferences.get("max_price_per_km"):
        max_score += 20
        # Simplified price check (in production, calculate price per km)
        if ride_data["price_per_seat"] <= preferences["max_price_per_km"] * 10:  # Assume 10km ride
            score += 20
            details.append("Price within budget")
        else:
            details.append("Price exceeds budget")
    
    # Check detour time
    if "detour_time_seconds" in ride_data:
        max_score += 20
        max_detour_seconds = preferences.get("max_detour_minutes", 15) * 60
        if ride_data["detour_time_seconds"] <= max_detour_seconds:
            score += 20
            details.append("Detour time acceptable")
        else:
            details.append("Detour time exceeds preference")
    
    match_percentage = (score / max_score * 100) if max_score > 0 else 0
    
    return {
        "match_score": int(match_percentage),
        "score_breakdown": {
            "total_score": score,
            "max_possible_score": max_score,
            "percentage": match_percentage
        },
        "details": details,
        "recommendation": "excellent" if match_percentage >= 80 else "good" if match_percentage >= 60 else "fair" if match_percentage >= 40 else "poor"
    }
