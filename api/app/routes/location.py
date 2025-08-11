from fastapi import APIRouter, HTTPException, Depends, WebSocket, WebSocketDisconnect
from app.schemas import LocationUpdate, PyObjectId
from app.database import locations_collection, rides_collection, drivers_collection
from app.auth import User
from fastapi_users import FastAPIUsers
from app.auth import auth_backend, get_user_db
import uuid
from typing import List
from bson import ObjectId
import json
from datetime import datetime, timedelta

router = APIRouter()

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    None,
    None,
    None,
)

# Store active WebSocket connections
active_connections: dict = {}

@router.post("/update", response_model=LocationUpdate)
async def update_location(
    location: LocationUpdate, 
    user: User = Depends(fastapi_users.current_user)
):
    """Update user's current location"""
    location.user_id = user.id
    location.timestamp = datetime.utcnow()
    
    location_dict = location.dict(by_alias=True, exclude_unset=True)
    result = await locations_collection.insert_one(location_dict)
    
    # Update driver's current location if they're online
    if location.ride_id:
        await drivers_collection.update_one(
            {"driver_id": user.id},
            {"$set": {"current_location": location.coordinates, "updated_at": datetime.utcnow()}}
        )
    
    # Broadcast location to connected clients if it's a ride
    if location.ride_id and str(location.ride_id) in active_connections:
        await broadcast_location_update(location)
    
    return location

@router.get("/user/{user_id}/recent", response_model=List[LocationUpdate])
async def get_user_recent_locations(
    user_id: str,
    limit: int = 10,
    user: User = Depends(fastapi_users.current_user)
):
    """Get recent location updates for a user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Only allow users to see their own locations or locations of users in the same ride
    if str(user.id) != user_id:
        # Check if they're in the same ride
        user_ride = await rides_collection.find_one({
            "$or": [
                {"driver_id": user.id, "status": {"$in": ["accepted", "picked_up", "in_progress"]}},
                {"passenger_id": user.id, "status": {"$in": ["accepted", "picked_up", "in_progress"]}}
            ]
        })
        
        if not user_ride or str(user_ride["_id"]) != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to view this user's location")
    
    locations = await locations_collection.find(
        {"user_id": ObjectId(user_id)},
        sort=[("timestamp", -1)]
    ).limit(limit).to_list(limit)
    
    return locations

@router.get("/ride/{ride_id}/participants", response_model=List[LocationUpdate])
async def get_ride_participants_locations(
    ride_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get current locations of all participants in a ride"""
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
    
    # Get the most recent location for each participant
    pipeline = [
        {
            "$match": {
                "ride_id": ObjectId(ride_id),
                "timestamp": {"$gte": datetime.utcnow() - timedelta(minutes=5)}  # Only recent locations
            }
        },
        {
            "$sort": {"timestamp": -1}
        },
        {
            "$group": {
                "_id": "$user_id",
                "latest_location": {"$first": "$$ROOT"}
            }
        },
        {
            "$replaceRoot": {"newRoot": "$latest_location"}
        }
    ]
    
    locations = await locations_collection.aggregate(pipeline).to_list(10)
    return locations

@router.websocket("/ws/ride/{ride_id}")
async def websocket_location_endpoint(websocket: WebSocket, ride_id: str):
    """WebSocket endpoint for real-time location updates during rides"""
    await websocket.accept()
    
    if ride_id not in active_connections:
        active_connections[ride_id] = []
    
    active_connections[ride_id].append(websocket)
    
    try:
        while True:
            # Keep connection alive and handle incoming messages
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
                # Handle any incoming location updates or commands
                if message.get("type") == "location_update":
                    await broadcast_location_update_to_ride(ride_id, message)
            except json.JSONDecodeError:
                # Keep connection alive
                pass
    except WebSocketDisconnect:
        # Remove connection when client disconnects
        if ride_id in active_connections:
            active_connections[ride_id].remove(websocket)
            if not active_connections[ride_id]:
                del active_connections[ride_id]

async def broadcast_location_update(location: LocationUpdate):
    """Broadcast location update to all connected clients for a specific ride"""
    if str(location.ride_id) in active_connections:
        await broadcast_location_update_to_ride(str(location.ride_id), {
            "type": "location_update",
            "user_id": str(location.user_id),
            "coordinates": location.coordinates,
            "timestamp": location.timestamp.isoformat(),
            "accuracy": location.accuracy,
            "speed": location.speed,
            "heading": location.heading
        })

async def broadcast_location_update_to_ride(ride_id: str, message: dict):
    """Broadcast message to all connected clients for a specific ride"""
    if ride_id in active_connections:
        disconnected = []
        for connection in active_connections[ride_id]:
            try:
                await connection.send_text(json.dumps(message))
            except:
                disconnected.append(connection)
        
        # Remove disconnected connections
        for connection in disconnected:
            active_connections[ride_id].remove(connection)
        
        # Clean up empty ride connections
        if not active_connections[ride_id]:
            del active_connections[ride_id]

@router.get("/nearby-drivers", response_model=List[dict])
async def get_nearby_drivers(
    latitude: float,
    longitude: float,
    radius_km: float = 5.0,
    user: User = Depends(fastapi_users.current_user)
):
    """Find nearby available drivers"""
    # Find drivers within the specified radius
    nearby_drivers = await drivers_collection.find({
        "is_online": True,
        "status": "active",
        "current_location": {
            "$near": {
                "$geometry": {
                    "type": "Point",
                    "coordinates": [longitude, latitude]  # MongoDB uses [lng, lat]
                },
                "$maxDistance": radius_km * 1000  # Convert km to meters
            }
        }
    }).limit(10).to_list(10)
    
    # Get the most recent location for each driver
    drivers_with_locations = []
    for driver in nearby_drivers:
        latest_location = await locations_collection.find_one(
            {"user_id": driver["driver_id"]},
            sort=[("timestamp", -1)]
        )
        
        if latest_location:
            drivers_with_locations.append({
                "driver_id": str(driver["driver_id"]),
                "current_location": latest_location["coordinates"],
                "last_seen": latest_location["timestamp"],
                "available_seats": driver.get("available_seats", 1)
            })
    
    return drivers_with_locations 