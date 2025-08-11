from fastapi import APIRouter, HTTPException, Depends
from app.schemas import EnvironmentalMetrics, RideAnalytics, PyObjectId
from app.database import environmental_metrics_collection, rides_collection, environmental_metrics_collection
from app.auth import User
from fastapi_users import FastAPIUsers
from app.auth import auth_backend, get_user_db
import uuid
from typing import List, Dict, Any
from bson import ObjectId
from datetime import datetime, timedelta
import math

router = APIRouter()

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    None,
    None,
    None,
)

# Environmental constants (DEFRA 2024 factors)
CO2_PER_KM_CAR = 0.171  # kg CO2 per km for average car
CO2_PER_KM_BUS = 0.105  # kg CO2 per km for bus
CO2_PER_KM_TRAIN = 0.041  # kg CO2 per km for train
CO2_PER_KM_WALKING = 0.0  # kg CO2 per km for walking
CO2_PER_KM_CYCLING = 0.0  # kg CO2 per km for cycling

# Fuel efficiency constants
FUEL_EFFICIENCY_CAR = 7.0  # km per liter for average car
FUEL_EFFICIENCY_BUS = 2.5  # km per liter for bus

# Tree absorption constants
CO2_PER_TREE_PER_YEAR = 22.0  # kg CO2 absorbed per tree per year
TREES_PER_HECTARE = 1000  # trees per hectare

@router.post("/calculate-ride-impact", response_model=EnvironmentalMetrics)
async def calculate_ride_environmental_impact(
    ride_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Calculate environmental impact for a specific ride"""
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
    
    # Calculate environmental impact
    distance_km = ride.get("total_distance_km", 0)
    if distance_km == 0:
        # Calculate distance if not provided
        if ride.get("pickup_coords") and ride.get("dropoff_coords"):
            distance_km = calculate_distance(
                ride["pickup_coords"],
                ride["dropoff_coords"]
            )
    
    # Calculate CO2 saved by sharing the ride
    co2_saved_kg = calculate_co2_savings(distance_km)
    fuel_saved_liters = calculate_fuel_savings(distance_km)
    trees_equivalent = calculate_trees_equivalent(co2_saved_kg)
    
    # Create environmental metrics
    environmental_metrics = EnvironmentalMetrics(
        ride_id=ObjectId(ride_id),
        distance_km=distance_km,
        co2_saved_kg=co2_saved_kg,
        fuel_saved_liters=fuel_saved_liters,
        trees_equivalent=trees_equivalent,
        timestamp=datetime.utcnow()
    )
    
    # Save to database
    metrics_dict = environmental_metrics.dict(by_alias=True, exclude_unset=True)
    result = await environmental_metrics_collection.insert_one(metrics_dict)
    
    # Update ride with environmental data
    await rides_collection.update_one(
        {"_id": ObjectId(ride_id)},
        {
            "$set": {
                "co2_saved": co2_saved_kg,
                "total_distance_km": distance_km
            }
        }
    )
    
    created_metrics = await environmental_metrics_collection.find_one({"_id": result.inserted_id})
    return created_metrics

@router.get("/ride/{ride_id}/impact", response_model=EnvironmentalMetrics)
async def get_ride_environmental_impact(
    ride_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get environmental impact for a specific ride"""
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
    
    metrics = await environmental_metrics_collection.find_one({"ride_id": ObjectId(ride_id)})
    if not metrics:
        raise HTTPException(status_code=404, detail="Environmental metrics not found for this ride")
    
    return metrics

@router.get("/user/{user_id}/total-impact", response_model=Dict[str, Any])
async def get_user_total_environmental_impact(
    user_id: str,
    period_days: int = 30,
    user: User = Depends(fastapi_users.current_user)
):
    """Get total environmental impact for a user over a specified period"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Only allow users to see their own impact
    if str(user.id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this user's impact")
    
    # Calculate period
    period_start = datetime.utcnow() - timedelta(days=period_days)
    
    # Get all rides for the user in the period
    user_rides = await rides_collection.find({
        "$or": [
            {"driver_id": ObjectId(user_id)},
            {"passenger_id": ObjectId(user_id)}
        ],
        "created_at": {"$gte": period_start}
    }).to_list(100)
    
    ride_ids = [ride["_id"] for ride in user_rides]
    
    # Get environmental metrics for these rides
    metrics = await environmental_metrics_collection.find({
        "ride_id": {"$in": ride_ids}
    }).to_list(100)
    
    # Calculate totals
    total_distance = sum(m.get("distance_km", 0) for m in metrics)
    total_co2_saved = sum(m.get("co2_saved_kg", 0) for m in metrics)
    total_fuel_saved = sum(m.get("fuel_saved_liters", 0) for m in metrics)
    total_trees_equivalent = sum(m.get("trees_equivalent", 0) for m in metrics)
    
    return {
        "user_id": user_id,
        "period_days": period_days,
        "period_start": period_start.isoformat(),
        "total_rides": len(metrics),
        "total_distance_km": total_distance,
        "total_co2_saved_kg": total_co2_saved,
        "total_fuel_saved_liters": total_fuel_saved,
        "total_trees_equivalent": total_trees_equivalent,
        "average_co2_per_ride": total_co2_saved / len(metrics) if metrics else 0
    }

@router.get("/analytics", response_model=RideAnalytics)
async def get_platform_environmental_analytics(
    period_days: int = 30,
    user: User = Depends(fastapi_users.current_user)
):
    """Get platform-wide environmental analytics"""
    # Only allow verified users to access analytics
    if not user.is_verified_driver:
        raise HTTPException(status_code=403, detail="Only verified users can access analytics")
    
    # Calculate period
    period_start = datetime.utcnow() - timedelta(days=period_days)
    period_end = datetime.utcnow()
    
    # Get all completed rides in the period
    completed_rides = await rides_collection.find({
        "status": "completed",
        "created_at": {"$gte": period_start}
    }).to_list(1000)
    
    # Get environmental metrics for these rides
    ride_ids = [ride["_id"] for ride in completed_rides]
    metrics = await environmental_metrics_collection.find({
        "ride_id": {"$in": ride_ids}
    }).to_list(1000)
    
    # Calculate totals
    total_rides = len(completed_rides)
    total_distance = sum(m.get("distance_km", 0) for m in metrics)
    total_co2_saved = sum(m.get("co2_saved_kg", 0) for m in metrics)
    
    # Calculate average rating
    total_rating = 0
    rated_rides = 0
    for ride in completed_rides:
        if ride.get("rating"):
            total_rating += ride["rating"]
            rated_rides += 1
    
    average_rating = total_rating / rated_rides if rated_rides > 0 else 0
    
    # Get user counts
    total_users = await rides_collection.distinct("driver_id")
    total_users.extend(await rides_collection.distinct("passenger_id"))
    total_users = len(set(total_users))
    
    active_drivers = await rides_collection.distinct("driver_id", {
        "created_at": {"$gte": period_start}
    })
    active_drivers = len(active_drivers)
    
    return RideAnalytics(
        total_rides=total_rides,
        total_distance_km=total_distance,
        total_co2_saved_kg=total_co2_saved,
        average_rating=average_rating,
        total_users=total_users,
        active_drivers=active_drivers,
        period_start=period_start,
        period_end=period_end
    )

@router.get("/comparison", response_model=Dict[str, Any])
async def compare_transport_modes(
    distance_km: float,
    passengers: int = 1
):
    """Compare environmental impact of different transport modes"""
    if distance_km <= 0:
        raise HTTPException(status_code=400, detail="Distance must be positive")
    
    if passengers <= 0:
        raise HTTPException(status_code=400, detail="Number of passengers must be positive")
    
    # Calculate CO2 emissions for different modes
    car_emission = CO2_PER_KM_CAR * distance_km
    bus_emission = CO2_PER_KM_BUS * distance_km
    train_emission = CO2_PER_KM_TRAIN * distance_km
    walking_emission = CO2_PER_KM_WALKING * distance_km
    cycling_emission = CO2_PER_KM_CYCLING * distance_km
    
    # Calculate shared car emissions (divide by number of passengers)
    shared_car_emission = car_emission / passengers if passengers > 0 else car_emission
    
    # Calculate savings compared to single car
    savings_vs_car = {
        "shared_car": car_emission - shared_car_emission,
        "bus": car_emission - bus_emission,
        "train": car_emission - train_emission,
        "walking": car_emission - walking_emission,
        "cycling": car_emission - cycling_emission
    }
    
    return {
        "distance_km": distance_km,
        "passengers": passengers,
        "emissions_kg_co2": {
            "single_car": car_emission,
            "shared_car": shared_car_emission,
            "bus": bus_emission,
            "train": train_emission,
            "walking": walking_emission,
            "cycling": cycling_emission
        },
        "savings_vs_single_car_kg_co2": savings_vs_car,
        "fuel_consumption_liters": {
            "car": distance_km / FUEL_EFFICIENCY_CAR,
            "bus": distance_km / FUEL_EFFICIENCY_BUS
        }
    }

# Helper functions
def calculate_distance(coord1: List[float], coord2: List[float]) -> float:
    """Calculate distance between two coordinates using Haversine formula"""
    lat1, lon1 = coord1[0], coord1[1]
    lat2, lon2 = coord2[0], coord2[1]
    
    # Convert to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    
    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    # Earth's radius in kilometers
    r = 6371
    
    return c * r

def calculate_co2_savings(distance_km: float) -> float:
    """Calculate CO2 savings from ride-sharing"""
    # Assume ride-sharing saves 50% of emissions compared to single occupancy
    single_car_emission = CO2_PER_KM_CAR * distance_km
    shared_car_emission = single_car_emission / 2  # 2 people sharing
    return single_car_emission - shared_car_emission

def calculate_fuel_savings(distance_km: float) -> float:
    """Calculate fuel savings from ride-sharing"""
    # Assume ride-sharing saves 50% of fuel compared to single occupancy
    single_car_fuel = distance_km / FUEL_EFFICIENCY_CAR
    shared_car_fuel = single_car_fuel / 2  # 2 people sharing
    return single_car_fuel - shared_car_fuel

def calculate_trees_equivalent(co2_kg: float) -> float:
    """Calculate number of trees needed to absorb the CO2"""
    # Convert annual tree absorption to daily equivalent
    daily_tree_absorption = CO2_PER_TREE_PER_YEAR / 365
    return co2_kg / daily_tree_absorption if daily_tree_absorption > 0 else 0 