from fastapi import APIRouter, HTTPException, Depends
from app.schemas import Ride, RideRequest, PyObjectId
from app.database import rides_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
import requests
from datetime import datetime

router = APIRouter()

OSRM_URL = "http://router.project-osrm.org"

async def get_detour(driver_route, passenger_pickup, passenger_dropoff):
    """Calculate detour time when adding a passenger to an existing route"""
    try:
        # Route with passenger: driver_start -> passenger_pickup -> passenger_dropoff -> driver_end
        url = f"{OSRM_URL}/route/v1/driving/{driver_route[0][0]},{driver_route[0][1]};{passenger_pickup[0]},{passenger_pickup[1]};{passenger_dropoff[0]},{passenger_dropoff[1]};{driver_route[1][0]},{driver_route[1][1]}?overview=false"
        response = requests.get(url)
        if response.status_code != 200:
            return float('inf')  # Indicate an error or unreachable route

        data = response.json()
        detour_duration = data['routes'][0]['duration']

        # Calculate original route duration: driver_start -> driver_end
        url_original = f"{OSRM_URL}/route/v1/driving/{driver_route[0][0]},{driver_route[0][1]};{driver_route[1][0]},{driver_route[1][1]}?overview=false"
        response_original = requests.get(url_original)
        if response_original.status_code != 200:
            return float('inf')
        
        data_original = response_original.json()
        original_duration = data_original['routes'][0]['duration']

        return detour_duration - original_duration
    except Exception as e:
        print(f"Error calculating detour: {e}")
        return float('inf')

@router.post("/", response_model=Ride)
async def create_ride(ride: Ride, user: User = Depends(fastapi_users.current_user)):
    """Create a new ride"""
    ride.driver_id = user.id
    ride_dict = ride.dict(by_alias=True, exclude_unset=True)
    result = await rides_collection.insert_one(ride_dict)
    created_ride = await rides_collection.find_one({"_id": result.inserted_id})
    if created_ride is None:
        raise HTTPException(status_code=404, detail="Ride creation failed")
    return created_ride

@router.get("/", response_model=List[Ride])
async def get_all_rides():
    """Get all rides"""
    rides = await rides_collection.find().to_list(100)
    return rides

@router.get("/{ride_id}", response_model=Ride)
async def get_ride_by_id(ride_id: str):
    """Get a specific ride by ID"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id)})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    return ride

@router.post("/find", response_model=List[Ride])
async def find_rides(request: RideRequest, user: User = Depends(fastapi_users.current_user)):
    """Find available rides based on passenger request"""
    # Find active rides within the specified radius of the passenger's pickup location
    rides = await rides_collection.find({
        "status": "active",
        "passenger_id": None,  # Only find rides that don't have a passenger yet
        "pickup_coords": {
            "$near": {
                "$geometry": {
                    "type": "Point",
                    "coordinates": request.pickup_coords
                },
                "$maxDistance": request.radius_km * 1000  # Convert km to meters
            }
        }
    }).to_list(10)

    # Filter rides based on detour
    matched_rides = []
    for ride_data in rides:
        ride = Ride(**ride_data)
        driver_route = [ride.pickup_coords, ride.dropoff_coords]
        detour = await get_detour(driver_route, request.pickup_coords, request.dropoff_coords)

        # Set a threshold for the maximum acceptable detour (e.g., 600 seconds = 10 minutes)
        if detour <= 600:
            ride.detour_time_seconds = detour
            matched_rides.append(ride)

    return matched_rides

@router.post("/{ride_id}/accept_passenger", response_model=dict)
async def accept_ride_passenger(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Accept a ride as a passenger"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "status": "active", "passenger_id": None})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or already accepted by a passenger")
    
    result = await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"passenger_id": user.id, "status": "pending_driver_acceptance"}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to accept ride as passenger")
    
    return {"message": "Ride accepted by passenger successfully"}

@router.post("/{ride_id}/driver_accept", response_model=dict)
async def driver_accept_passenger(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Driver accepts a passenger's ride request"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id, "status": "pending_driver_acceptance"})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or not pending driver acceptance")
    
    result = await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": "confirmed"}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to confirm ride")
    
    return {"message": "Ride confirmed by driver successfully"}

@router.put("/{ride_id}/start", response_model=dict)
async def start_ride(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Start a confirmed ride"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "status": "confirmed"})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or not confirmed")
    
    # Check if user is driver or passenger
    if ride.get("driver_id") != user.id and ride.get("passenger_id") != user.id:
        raise HTTPException(status_code=403, detail="Not authorized to start this ride")
    
    result = await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": "in_progress", "pickup_time": datetime.utcnow()}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to start ride")
    
    return {"message": "Ride started successfully"}

@router.put("/{ride_id}/complete", response_model=dict)
async def complete_ride(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    """Complete a ride in progress"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "status": "in_progress"})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or not in progress")
    
    # Check if user is driver or passenger
    if ride.get("driver_id") != user.id and ride.get("passenger_id") != user.id:
        raise HTTPException(status_code=403, detail="Not authorized to complete this ride")
    
    result = await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": "completed", "dropoff_time": datetime.utcnow()}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to complete ride")
    
    return {"message": "Ride completed successfully"}

@router.get("/my_rides", response_model=List[Ride])
async def get_my_rides(user: User = Depends(fastapi_users.current_user)):
    """Get all rides for the current user (as driver or passenger)"""
    rides_as_passenger = await rides_collection.find({"passenger_id": user.id}).to_list(100)
    rides_as_driver = await rides_collection.find({"driver_id": user.id}).to_list(100)
    return rides_as_passenger + rides_as_driver

@router.get("/active", response_model=List[Ride])
async def get_active_rides(user: User = Depends(fastapi_users.current_user)):
    """Get active rides for the current user"""
    active_rides = await rides_collection.find({
        "$or": [
            {"driver_id": user.id, "status": {"$in": ["active", "confirmed", "in_progress"]}},
            {"passenger_id": user.id, "status": {"$in": ["confirmed", "in_progress"]}}
        ]
    }).to_list(100)
    return active_rides
