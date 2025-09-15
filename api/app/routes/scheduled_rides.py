from fastapi import APIRouter, HTTPException, Depends
from app.schemas import ScheduledRide, PyObjectId
from app.database import scheduled_rides_collection, rides_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
from datetime import datetime, timedelta
import uuid

router = APIRouter()

@router.post("/", response_model=ScheduledRide)
async def create_scheduled_ride(scheduled_ride: ScheduledRide, user: User = Depends(fastapi_users.current_user)):
    """Create a new scheduled ride"""
    if not user.is_driver or not user.is_verified_driver:
        raise HTTPException(status_code=403, detail="Only verified drivers can create scheduled rides")
    
    scheduled_ride.driver_id = user.id
    scheduled_ride_dict = scheduled_ride.dict(by_alias=True, exclude_unset=True)
    result = await scheduled_rides_collection.insert_one(scheduled_ride_dict)
    created_ride = await scheduled_rides_collection.find_one({"_id": result.inserted_id})
    if created_ride is None:
        raise HTTPException(status_code=404, detail="Scheduled ride creation failed")
    return created_ride

@router.get("/", response_model=List[ScheduledRide])
async def get_scheduled_rides(user: User = Depends(fastapi_users.current_user)):
    """Get scheduled rides for the current user"""
    rides = await scheduled_rides_collection.find({"driver_id": user.id}).to_list(100)
    return rides

@router.get("/{ride_id}", response_model=ScheduledRide)
async def get_scheduled_ride_by_id(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Get a specific scheduled ride by ID"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await scheduled_rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not ride:
        raise HTTPException(status_code=404, detail="Scheduled ride not found")
    
    return ride

@router.put("/{ride_id}", response_model=ScheduledRide)
async def update_scheduled_ride(ride_id: str, updates: dict, user: User = Depends(fastapi_users.current_user)):
    """Update a scheduled ride"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await scheduled_rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not ride:
        raise HTTPException(status_code=404, detail="Scheduled ride not found")
    
    updates["updated_at"] = datetime.utcnow()
    result = await scheduled_rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": updates}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to update scheduled ride")
    
    updated_ride = await scheduled_rides_collection.find_one({"_id": ObjectId(ride_id)})
    return updated_ride

@router.delete("/{ride_id}", response_model=dict)
async def delete_scheduled_ride(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Delete a scheduled ride"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await scheduled_rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not ride:
        raise HTTPException(status_code=404, detail="Scheduled ride not found")
    
    result = await scheduled_rides_collection.delete_one({"_id": ObjectId(ride_id)})
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=400, detail="Failed to delete scheduled ride")
    
    return {"message": "Scheduled ride deleted successfully"}

@router.post("/{ride_id}/activate", response_model=dict)
async def activate_scheduled_ride(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Activate a scheduled ride (convert to active ride)"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    scheduled_ride = await scheduled_rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not scheduled_ride:
        raise HTTPException(status_code=404, detail="Scheduled ride not found")
    
    # Create an active ride from the scheduled ride
    active_ride_data = {
        "driver_id": scheduled_ride["driver_id"],
        "pickup": scheduled_ride["pickup"],
        "dropoff": scheduled_ride["dropoff"],
        "pickup_coords": scheduled_ride["pickup_coords"],
        "dropoff_coords": scheduled_ride["dropoff_coords"],
        "max_passengers": scheduled_ride["max_passengers"],
        "price_per_seat": scheduled_ride["price_per_seat"],
        "ride_type": scheduled_ride["ride_type"],
        "vehicle_type": scheduled_ride.get("vehicle_type"),
        "amenities": scheduled_ride.get("amenities", []),
        "status": "active",
        "scheduled_time": scheduled_ride["scheduled_time"],
        "created_at": datetime.utcnow()
    }
    
    result = await rides_collection.insert_one(active_ride_data)
    
    # Update scheduled ride status
    await scheduled_rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": "activated", "activated_at": datetime.utcnow()}}
    )
    
    return {"message": "Scheduled ride activated successfully", "ride_id": str(result.inserted_id)}

@router.get("/upcoming/{days}", response_model=List[ScheduledRide])
async def get_upcoming_scheduled_rides(days: int = 7, user: User = Depends(fastapi_users.current_user)):
    """Get upcoming scheduled rides for the next N days"""
    start_date = datetime.utcnow()
    end_date = start_date + timedelta(days=days)
    
    rides = await scheduled_rides_collection.find({
        "driver_id": user.id,
        "scheduled_time": {"$gte": start_date, "$lte": end_date},
        "status": "scheduled"
    }).sort("scheduled_time", 1).to_list(100)
    
    return rides

@router.post("/recurring/generate", response_model=dict)
async def generate_recurring_rides(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Generate recurring rides from a template"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    template_ride = await scheduled_rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not template_ride:
        raise HTTPException(status_code=404, detail="Scheduled ride not found")
    
    if not template_ride.get("is_recurring"):
        raise HTTPException(status_code=400, detail="Ride is not marked as recurring")
    
    pattern = template_ride.get("recurring_pattern")
    end_date = template_ride.get("recurring_end_date")
    
    if not pattern or not end_date:
        raise HTTPException(status_code=400, detail="Recurring pattern and end date must be specified")
    
    generated_count = 0
    current_time = template_ride["scheduled_time"]
    
    while current_time <= end_date:
        if pattern == "daily":
            current_time += timedelta(days=1)
        elif pattern == "weekly":
            current_time += timedelta(weeks=1)
        elif pattern == "monthly":
            # Simple monthly increment (30 days)
            current_time += timedelta(days=30)
        else:
            break
        
        if current_time <= end_date:
            # Create a new scheduled ride
            new_ride_data = template_ride.copy()
            del new_ride_data["_id"]
            new_ride_data["scheduled_time"] = current_time
            new_ride_data["created_at"] = datetime.utcnow()
            
            await scheduled_rides_collection.insert_one(new_ride_data)
            generated_count += 1
    
    return {"message": f"Generated {generated_count} recurring rides", "generated_count": generated_count}
