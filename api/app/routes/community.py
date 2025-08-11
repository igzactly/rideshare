from fastapi import APIRouter, HTTPException, Depends
from app.schemas import CommunityFilter, Ride, RideRequest
from app.database import community_filters_collection, rides_collection, user_profiles_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
from datetime import datetime, timedelta
import math

router = APIRouter()

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points using Haversine formula"""
    R = 6371  # Earth's radius in kilometers
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = (math.sin(delta_lat / 2) ** 2 + 
         math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

@router.post("/filters", response_model=CommunityFilter)
async def create_community_filter(
    filter_data: CommunityFilter,
    user: User = Depends(fastapi_users.current_user)
):
    """Create or update community filter preferences for a user"""
    filter_data.user_id = user.id
    filter_data.created_at = datetime.utcnow()
    
    # Check if filter already exists for this user
    existing_filter = await community_filters_collection.find_one({"user_id": user.id})
    
    if existing_filter:
        # Update existing filter
        result = await community_filters_collection.update_one(
            {"user_id": user.id},
            {"$set": filter_data.dict(exclude={"user_id", "created_at"})}
        )
        if result.modified_count == 0:
            raise HTTPException(status_code=400, detail="Failed to update community filter")
        
        updated_filter = await community_filters_collection.find_one({"user_id": user.id})
        return updated_filter
    else:
        # Create new filter
        filter_dict = filter_data.dict(by_alias=True, exclude_unset=True)
        result = await community_filters_collection.insert_one(filter_dict)
        created_filter = await community_filters_collection.find_one({"_id": result.inserted_id})
        if created_filter is None:
            raise HTTPException(status_code=404, detail="Community filter creation failed")
        return created_filter

@router.get("/filters/{user_id}", response_model=CommunityFilter)
async def get_community_filter(
    user_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get community filter for a specific user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can only view their own filters or public community information
    if str(user.id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this filter")
    
    filter_data = await community_filters_collection.find_one({"user_id": ObjectId(user_id)})
    if not filter_data:
        raise HTTPException(status_code=404, detail="Community filter not found")
    
    return filter_data

@router.post("/match", response_model=List[Ride])
async def find_community_rides(
    request: RideRequest,
    user: User = Depends(fastapi_users.current_user)
):
    """Find rides with community-based matching"""
    # Get user's community filter
    user_filter = await community_filters_collection.find_one({"user_id": user.id})
    
    if not user_filter or not user_filter.get("preferred_communities"):
        # Fall back to regular ride finding if no community filter
        return await find_regular_rides(request)
    
    # Find rides within radius
    rides = await rides_collection.find({
        "status": "active",
        "passenger_id": None,
        "pickup_coords": {
            "$near": {
                "$geometry": {
                    "type": "Point",
                    "coordinates": request.pickup_coords
                },
                "$maxDistance": request.radius_km * 1000
            }
        }
    }).to_list(20)
    
    # Apply community filtering
    community_matched_rides = []
    for ride_data in rides:
        ride = Ride(**ride_data)
        
        # Get driver profile for community matching
        driver_profile = await user_profiles_collection.find_one({"user_id": ride.driver_id})
        if not driver_profile:
            continue
        
        # Check community compatibility
        community_score = calculate_community_score(user_filter, driver_profile, ride)
        
        if community_score >= user_filter.get("trust_score_threshold", 3.0):
            # Calculate detour
            driver_route = [ride.pickup_coords, ride.dropoff_coords]
            detour = await calculate_detour(driver_route, request.pickup_coords, request.dropoff_coords)
            
            if detour <= request.max_detour_minutes * 60:  # Convert minutes to seconds
                ride.detour_time_seconds = detour
                ride.community_score = community_score
                community_matched_rides.append(ride)
    
    # Sort by community score and detour time
    community_matched_rides.sort(key=lambda x: (x.community_score, -x.detour_time_seconds), reverse=True)
    
    return community_matched_rides[:10]

async def find_regular_rides(request: RideRequest) -> List[Ride]:
    """Fallback to regular ride finding without community filtering"""
    rides = await rides_collection.find({
        "status": "active",
        "passenger_id": None,
        "pickup_coords": {
            "$near": {
                "$geometry": {
                    "type": "Point",
                    "coordinates": request.pickup_coords
                },
                "$maxDistance": request.radius_km * 1000
            }
        }
    }).to_list(10)
    
    matched_rides = []
    for ride_data in rides:
        ride = Ride(**ride_data)
        driver_route = [ride.pickup_coords, ride.dropoff_coords]
        detour = await calculate_detour(driver_route, request.pickup_coords, request.dropoff_coords)
        
        if detour <= request.max_detour_minutes * 60:
            ride.detour_time_seconds = detour
            matched_rides.append(ride)
    
    return matched_rides

def calculate_community_score(user_filter: dict, driver_profile: dict, ride: Ride) -> float:
    """Calculate community compatibility score between user and driver"""
    score = 0.0
    
    # Check for common communities
    user_communities = set(user_filter.get("preferred_communities", []))
    driver_communities = set(driver_profile.get("communities", []))
    
    common_communities = user_communities.intersection(driver_communities)
    if common_communities:
        score += len(common_communities) * 2.0
    
    # Factor in driver rating
    driver_rating = driver_profile.get("rating", 0)
    score += min(driver_rating, 5.0)
    
    # Factor in verification status
    if driver_profile.get("is_verified", False):
        score += 2.0
    
    # Factor in distance (closer is better)
    if ride.pickup_coords and user_filter.get("pickup_coords"):
        distance = calculate_distance(
            ride.pickup_coords[0], ride.pickup_coords[1],
            user_filter["pickup_coords"][0], user_filter["pickup_coords"][1]
        )
        if distance <= user_filter.get("max_distance_km", 10.0):
            score += (10.0 - distance) / 2.0
    
    return min(10.0, score)

async def calculate_detour(driver_route, passenger_pickup, passenger_dropoff) -> float:
    """Calculate detour time when adding a passenger to an existing route"""
    try:
        # This is a simplified calculation - in production, you'd use OSRM or similar
        # For now, we'll use a basic distance-based approximation
        
        # Calculate total distance with passenger
        total_distance = (
            calculate_distance(driver_route[0][0], driver_route[0][1], passenger_pickup[0], passenger_pickup[1]) +
            calculate_distance(passenger_pickup[0], passenger_pickup[1], passenger_dropoff[0], passenger_dropoff[1]) +
            calculate_distance(passenger_dropoff[0], passenger_dropoff[1], driver_route[1][0], driver_route[1][1])
        )
        
        # Calculate original distance
        original_distance = calculate_distance(driver_route[0][0], driver_route[0][1], driver_route[1][0], driver_route[1][1])
        
        # Estimate detour time (assuming 30 km/h average speed)
        detour_distance = total_distance - original_distance
        detour_time_hours = detour_distance / 30.0
        detour_time_seconds = detour_time_hours * 3600
        
        return detour_time_seconds
    except Exception as e:
        print(f"Error calculating detour: {e}")
        return float('inf')

@router.get("/communities", response_model=List[str])
async def get_available_communities():
    """Get list of available communities in the system"""
    # This would typically come from a configuration or be dynamically generated
    # For now, returning a predefined list
    return [
        "university",
        "workplace",
        "neighborhood",
        "gym",
        "shopping_center",
        "hospital",
        "airport",
        "train_station",
        "school",
        "church"
    ]

@router.get("/stats/{community_name}", response_model=dict)
async def get_community_stats(
    community_name: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get statistics for a specific community"""
    # Count users in this community
    community_users = await community_filters_collection.count_documents({
        "preferred_communities": community_name
    })
    
    # Count rides involving this community (this would need to be enhanced based on actual data structure)
    community_rides = await rides_collection.count_documents({
        "status": "completed",
        "created_at": {"$gte": datetime.utcnow() - timedelta(days=30)}
    })
    
    return {
        "community_name": community_name,
        "total_users": community_users,
        "monthly_rides": community_rides,
        "active_members": community_users  # Simplified for now
    } 