from fastapi import APIRouter, HTTPException, Depends
from app.schemas import DriverRoute
from app.database import drivers_collection, rides_collection
from bson import ObjectId
from typing import List
from app.auth import User
from fastapi_users import FastAPIUsers
from app.auth import auth_backend, get_user_db
import uuid

router = APIRouter()

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    None,  # No UserCreate model needed here
    None,  # No UserUpdate model needed here
    None,  # No UserRead model needed here
)

@router.post("/routes", response_model=DriverRoute)
async def create_driver_route(route: DriverRoute, user: User = Depends(fastapi_users.current_user)):
    if not user.is_driver or not user.is_verified_driver:
        raise HTTPException(status_code=403, detail="Only verified drivers can create routes")
    route.driver_id = user.id
    route_dict = route.dict(by_alias=True, exclude_unset=True)
    result = await drivers_collection.insert_one(route_dict)
    created_route = await drivers_collection.find_one({"_id": result.inserted_id})
    if created_route is None:
        raise HTTPException(status_code=404, detail="Driver route creation failed")
    return created_route

@router.get("/routes", response_model=List[DriverRoute])
async def get_driver_routes(user: User = Depends(fastapi_users.current_user)):
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can view their routes")
    routes = await drivers_collection.find({"driver_id": user.id}).to_list(100)
    return routes

@router.post("/rides/{ride_id}/accept", response_model=dict)
async def accept_ride(ride_id: str, user: User = Depends(fastapi_users.current_user)):
    if not user.is_driver or not user.is_verified_driver:
        raise HTTPException(status_code=403, detail="Only verified drivers can accept rides")
    
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "status": "active", "passenger_id": None})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or already accepted")
    
    result = await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"driver_id": user.id, "status": "accepted"}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to accept ride")
    
    return {"message": "Ride accepted successfully"}

@router.put("/rides/{ride_id}/status", response_model=dict)
async def update_ride_status(ride_id: str, status: str, user: User = Depends(fastapi_users.current_user)):
    if not user.is_driver or not user.is_verified_driver:
        raise HTTPException(status_code=403, detail="Only verified drivers can update ride status")
    
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    valid_statuses = ["picked_up", "dropped_off", "completed", "cancelled"]
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or not assigned to this driver")
    
    result = await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {"$set": {"status": status}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to update ride status")
    
    return {"message": "Ride status updated successfully"}
