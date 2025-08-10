from fastapi import APIRouter, HTTPException
from app.schemas import Ride, PyObjectId
from app.database import rides_collection
from bson import ObjectId
from typing import List

router = APIRouter()

@router.post("/", response_model=Ride)
async def create_ride(ride: Ride, user: User = Depends(fastapi_users.current_user)):
    ride.driver_id = user.id
    ride_dict = ride.dict(by_alias=True, exclude_unset=True)
    result = await rides_collection.insert_one(ride_dict)
    created_ride = await rides_collection.find_one({"_id": result.inserted_id})
    if created_ride is None:
        raise HTTPException(status_code=404, detail="Ride creation failed")
    return created_ride

# ✅ GET all rides
@router.get("/", response_model=List[Ride])
async def get_all_rides():
    rides = await rides_collection.find().to_list(100)
    return rides

# ✅ GET one ride by ID
@router.get("/{ride_id}", response_model=Ride)
async def get_ride_by_id(ride_id: str):
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id)})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    return ride

@router.post("/find", response_model=List[Ride])
async def find_rides(request: RideRequest, user: User = Depends(fastapi_users.current_user)):
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

        # Set a threshold for the maximum acceptable detour (e.g., 600 seconds)
        if detour <= 600:
            ride.detour_km = detour  # Storing detour time in seconds for now
            matched_rides.append(ride)

    return matched_rides

@router.post("/rides/{ride_id}/accept_passenger", response_model=dict)
async def accept_ride_passenger(ride_id: str, user: User = Depends(fastapi_users.current_user)):
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

@router.get("/my_rides", response_model=List[Ride])
async def get_my_rides(user: User = Depends(fastapi_users.current_user)):
    rides_as_passenger = await rides_collection.find({"passenger_id": user.id}).to_list(100)
    rides_as_driver = await rides_collection.find({"driver_id": user.id}).to_list(100)
    return rides_as_passenger + rides_as_driver


import requests

OSRM_URL = "http://router.project-osrm.org"

async def get_detour(driver_route, passenger_pickup, passenger_dropoff):
    # This is a simplified example. A real implementation would need to handle errors
    # and potentially more complex routing scenarios.
    url = f"{OSRM_URL}/route/v1/driving/{driver_route[0][0]},{driver_route[0][1]};{passenger_pickup[0]},{passenger_pickup[1]};{passenger_dropoff[0]},{passenger_dropoff[1]};{driver_route[1][0]},{driver_route[1][1]}?overview=false"
    response = requests.get(url)
    if response.status_code != 200:
        return float('inf')  # Indicate an error or unreachable route

    data = response.json()
    detour_duration = data['routes'][0]['duration']

    # Calculate original route duration
    url_original = f"{OSRM_URL}/route/v1/driving/{driver_route[0][0]},{driver_route[0][1]};{driver_route[1][0]},{driver_route[1][1]}?overview=false"
    response_original = requests.get(url_original)
    if response_original.status_code != 200:
        return float('inf')
    
    data_original = response_original.json()
    original_duration = data_original['routes'][0]['duration']

    return detour_duration - original_duration

@router.post("/find", response_model=List[Ride])
async def find_rides(request: RideRequest):
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

        # Set a threshold for the maximum acceptable detour (e.g., 600 seconds)
        if detour <= 600:
            ride.detour_km = detour  # Storing detour time in seconds for now
            matched_rides.append(ride)

    return matched_rides
