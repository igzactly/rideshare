from fastapi import APIRouter, HTTPException, Depends, Query
from app.schemas import RouteOptimizationRequest, DriverRoute
from app.database import drivers_collection, rides_collection, locations_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import math
import requests

router = APIRouter()

OSRM_URL = "http://router.project-osrm.org"

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

@router.post("/route", response_model=dict)
async def optimize_route(
    request: RouteOptimizationRequest,
    user: User = Depends(fastapi_users.current_user)
):
    """Optimize a driver's route with multiple stops"""
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can optimize routes")
    
    # Validate coordinates
    if len(request.stops) < 2:
        raise HTTPException(status_code=400, detail="Route must have at least 2 stops")
    
    # Get current driver location
    current_location = await get_driver_current_location(user.id)
    if not current_location:
        raise HTTPException(status_code=400, detail="Driver location not available")
    
    # Add current location as starting point if not already included
    all_stops = [current_location] + request.stops
    
    # Optimize route using different algorithms
    optimized_routes = {}
    
    # 1. Nearest Neighbor (greedy approach)
    nn_route = nearest_neighbor_optimization(all_stops)
    optimized_routes["nearest_neighbor"] = nn_route
    
    # 2. OSRM optimization (if available)
    try:
        osrm_route = await osrm_route_optimization(all_stops)
        optimized_routes["osrm"] = osrm_route
    except Exception as e:
        print(f"OSRM optimization failed: {e}")
        optimized_routes["osrm"] = {"error": "OSRM service unavailable"}
    
    # 3. Time-based optimization
    time_route = time_based_optimization(all_stops, request.time_constraints)
    optimized_routes["time_based"] = time_route
    
    # 4. Fuel-efficient optimization
    fuel_route = fuel_efficient_optimization(all_stops, request.vehicle_info)
    optimized_routes["fuel_efficient"] = fuel_route
    
    # Select best route based on criteria
    best_route = select_best_route(optimized_routes, request.optimization_criteria)
    
    return {
        "optimized_routes": optimized_routes,
        "best_route": best_route,
        "optimization_criteria": request.optimization_criteria,
        "total_distance": best_route["total_distance"],
        "estimated_duration": best_route["estimated_duration"],
        "fuel_consumption": best_route.get("fuel_consumption", 0)
    }

@router.post("/multi-ride", response_model=dict)
async def optimize_multi_ride_route(
    ride_ids: List[str],
    user: User = Depends(fastapi_users.current_user)
):
    """Optimize route for multiple rides to maximize efficiency"""
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can optimize multi-ride routes")
    
    # Validate ride IDs
    if not ride_ids:
        raise HTTPException(status_code=400, detail="No ride IDs provided")
    
    # Get ride details
    rides = []
    for ride_id in ride_ids:
        if not ObjectId.is_valid(ride_id):
            raise HTTPException(status_code=400, detail=f"Invalid ride ID: {ride_id}")
        
        ride = await rides_collection.find_one({
            "_id": ObjectId(ride_id),
            "driver_id": user.id,
            "status": {"$in": ["active", "confirmed"]}
        })
        
        if not ride:
            raise HTTPException(status_code=404, detail=f"Ride not found or not authorized: {ride_id}")
        
        rides.append(ride)
    
    if not rides:
        raise HTTPException(status_code=404, detail="No valid rides found")
    
    # Extract pickup and dropoff points
    stops = []
    for ride in rides:
        if ride.get("pickup_coords"):
            stops.append({
                "type": "pickup",
                "ride_id": str(ride["_id"]),
                "coordinates": ride["pickup_coords"],
                "address": ride.get("pickup", "Unknown"),
                "priority": "high"
            })
        
        if ride.get("dropoff_coords"):
            stops.append({
                "type": "dropoff",
                "ride_id": str(ride["_id"]),
                "coordinates": ride["dropoff_coords"],
                "address": ride.get("dropoff", "Unknown"),
                "priority": "high"
            })
    
    # Get current driver location
    current_location = await get_driver_current_location(user.id)
    if current_location:
        stops.insert(0, current_location)
    
    # Optimize route
    optimized_route = await optimize_route_with_constraints(stops, rides)
    
    return {
        "rides": [{"id": str(r["_id"]), "pickup": r.get("pickup"), "dropoff": r.get("dropoff")} for r in rides],
        "optimized_route": optimized_route,
        "total_distance": optimized_route["total_distance"],
        "estimated_duration": optimized_route["estimated_duration"],
        "efficiency_gain": optimized_route.get("efficiency_gain", 0)
    }

@router.get("/efficiency/{driver_id}", response_model=dict)
async def get_driver_efficiency_metrics(
    driver_id: str,
    days: int = Query(30, description="Number of days to analyze"),
    user: User = Depends(fastapi_users.current_user)
):
    """Get driver efficiency metrics and optimization suggestions"""
    if not ObjectId.is_valid(driver_id):
        raise HTTPException(status_code=400, detail="Invalid driver ID")
    
    # Users can only view their own efficiency metrics
    if str(user.id) != driver_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this driver's metrics")
    
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can view efficiency metrics")
    
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Get completed rides
    completed_rides = await rides_collection.find({
        "driver_id": ObjectId(driver_id),
        "status": "completed",
        "created_at": {"$gte": start_date, "$lt": end_date}
    }).to_list(1000)
    
    if not completed_rides:
        return {
            "driver_id": driver_id,
            "period": {"start_date": start_date.strftime("%Y-%m-%d"), "end_date": end_date.strftime("%Y-%m-%d")},
            "message": "No completed rides found in the specified period"
        }
    
    # Calculate efficiency metrics
    total_distance = sum(r.get("total_distance_km", 0) for r in completed_rides)
    total_earnings = sum(r.get("fare", 0) for r in completed_rides)
    total_duration = sum(r.get("duration_minutes", 0) for r in completed_rides)
    
    # Calculate efficiency ratios
    earnings_per_km = total_earnings / total_distance if total_distance > 0 else 0
    earnings_per_hour = total_earnings / (total_duration / 60) if total_duration > 0 else 0
    
    # Get route optimization suggestions
    optimization_suggestions = generate_optimization_suggestions(completed_rides)
    
    return {
        "driver_id": driver_id,
        "period": {
            "start_date": start_date.strftime("%Y-%m-%d"),
            "end_date": end_date.strftime("%Y-%m-%d"),
            "days": days
        },
        "metrics": {
            "total_rides": len(completed_rides),
            "total_distance_km": round(total_distance, 2),
            "total_earnings": round(total_earnings, 2),
            "total_duration_hours": round(total_duration / 60, 2),
            "earnings_per_km": round(earnings_per_km, 2),
            "earnings_per_hour": round(earnings_per_hour, 2)
        },
        "optimization_suggestions": optimization_suggestions
    }

async def get_driver_current_location(driver_id: ObjectId) -> Optional[Dict[str, Any]]:
    """Get driver's current location"""
    latest_location = await locations_collection.find_one(
        {"user_id": driver_id},
        sort=[("timestamp", -1)]
    )
    
    if latest_location:
        return {
            "type": "current_location",
            "coordinates": latest_location["coordinates"],
            "address": "Current Location",
            "priority": "highest"
        }
    return None

def nearest_neighbor_optimization(stops: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Optimize route using nearest neighbor algorithm"""
    if len(stops) <= 2:
        return {
            "route": stops,
            "total_distance": calculate_route_distance(stops),
            "algorithm": "nearest_neighbor"
        }
    
    unvisited = stops[1:]  # Skip starting point
    current = stops[0]
    route = [current]
    total_distance = 0
    
    while unvisited:
        # Find nearest unvisited stop
        nearest = min(unvisited, key=lambda x: calculate_distance(
            current["coordinates"][0], current["coordinates"][1],
            x["coordinates"][0], x["coordinates"][1]
        ))
        
        distance = calculate_distance(
            current["coordinates"][0], current["coordinates"][1],
            nearest["coordinates"][0], nearest["coordinates"][1]
        )
        
        total_distance += distance
        route.append(nearest)
        unvisited.remove(nearest)
        current = nearest
    
    return {
        "route": route,
        "total_distance": round(total_distance, 2),
        "algorithm": "nearest_neighbor"
    }

async def osrm_route_optimization(stops: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Optimize route using OSRM service"""
    try:
        # Build coordinates string for OSRM
        coords = []
        for stop in stops:
            coords.append(f"{stop['coordinates'][1]},{stop['coordinates'][0]}")  # OSRM uses lng,lat
        
        coords_str = ";".join(coords)
        
        # Request optimized route from OSRM
        url = f"{OSRM_URL}/trip/v1/driving/{coords_str}?overview=false&source=first&destination=last"
        response = requests.get(url)
        
        if response.status_code != 200:
            raise Exception(f"OSRM request failed: {response.status_code}")
        
        data = response.json()
        
        # Extract route information
        waypoints = data.get("waypoints", [])
        trip = data.get("trips", [{}])[0]
        
        # Reorder stops based on OSRM optimization
        optimized_stops = []
        for waypoint in waypoints:
            waypoint_index = waypoint.get("waypoint_index", 0)
            if waypoint_index < len(stops):
                optimized_stops.append(stops[waypoint_index])
        
        return {
            "route": optimized_stops,
            "total_distance": round(trip.get("distance", 0) / 1000, 2),  # Convert meters to km
            "estimated_duration": round(trip.get("duration", 0) / 60, 2),  # Convert seconds to minutes
            "algorithm": "osrm"
        }
        
    except Exception as e:
        raise Exception(f"OSRM optimization failed: {str(e)}")

def time_based_optimization(stops: List[Dict[str, Any]], time_constraints: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Optimize route considering time constraints"""
    if not time_constraints:
        return nearest_neighbor_optimization(stops)
    
    # Simple time-based optimization - prioritize stops with time constraints
    prioritized_stops = sorted(stops, key=lambda x: x.get("priority", "medium"))
    
    return {
        "route": prioritized_stops,
        "total_distance": calculate_route_distance(prioritized_stops),
        "algorithm": "time_based",
        "time_constraints_applied": True
    }

def fuel_efficient_optimization(stops: List[Dict[str, Any]], vehicle_info: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Optimize route for fuel efficiency"""
    if not vehicle_info:
        return nearest_neighbor_optimization(stops)
    
    # Consider vehicle fuel efficiency and traffic patterns
    # This is a simplified version - in production, you'd integrate with traffic APIs
    
    optimized_stops = stops.copy()
    total_distance = calculate_route_distance(optimized_stops)
    
    # Estimate fuel consumption (simplified)
    fuel_efficiency = vehicle_info.get("fuel_efficiency_kmpl", 15)  # km per liter
    fuel_consumption = total_distance / fuel_efficiency
    
    return {
        "route": optimized_stops,
        "total_distance": round(total_distance, 2),
        "fuel_consumption": round(fuel_consumption, 2),
        "algorithm": "fuel_efficient"
    }

def calculate_route_distance(stops: List[Dict[str, Any]]) -> float:
    """Calculate total distance of a route"""
    if len(stops) < 2:
        return 0
    
    total_distance = 0
    for i in range(len(stops) - 1):
        current = stops[i]
        next_stop = stops[i + 1]
        
        distance = calculate_distance(
            current["coordinates"][0], current["coordinates"][1],
            next_stop["coordinates"][0], next_stop["coordinates"][1]
        )
        total_distance += distance
    
    return total_distance

def select_best_route(optimized_routes: Dict[str, Any], criteria: str) -> Dict[str, Any]:
    """Select the best route based on optimization criteria"""
    if criteria == "distance":
        return min(optimized_routes.values(), key=lambda x: x.get("total_distance", float('inf')))
    elif criteria == "time":
        return min(optimized_routes.values(), key=lambda x: x.get("estimated_duration", float('inf')))
    elif criteria == "fuel":
        return min(optimized_routes.values(), key=lambda x: x.get("fuel_consumption", float('inf')))
    else:
        # Default to nearest neighbor
        return optimized_routes.get("nearest_neighbor", list(optimized_routes.values())[0])

async def optimize_route_with_constraints(stops: List[Dict[str, Any]], rides: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Optimize route considering ride-specific constraints"""
    # Apply ride-specific constraints
    constrained_stops = apply_ride_constraints(stops, rides)
    
    # Optimize using nearest neighbor
    optimized_route = nearest_neighbor_optimization(constrained_stops)
    
    # Calculate efficiency gain
    original_distance = calculate_route_distance(stops)
    optimized_distance = optimized_route["total_distance"]
    efficiency_gain = ((original_distance - optimized_distance) / original_distance * 100) if original_distance > 0 else 0
    
    optimized_route["efficiency_gain"] = round(efficiency_gain, 2)
    optimized_route["estimated_duration"] = estimate_route_duration(optimized_route["route"])
    
    return optimized_route

def apply_ride_constraints(stops: List[Dict[str, Any]], rides: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Apply constraints based on ride requirements"""
    # This is a simplified version - in production, you'd implement more sophisticated constraint handling
    
    # Ensure pickup comes before dropoff for each ride
    constrained_stops = []
    ride_pickups = {}
    ride_dropoffs = {}
    
    for stop in stops:
        if stop.get("type") == "pickup":
            ride_id = stop.get("ride_id")
            if ride_id:
                ride_pickups[ride_id] = stop
        
        if stop.get("type") == "dropoff":
            ride_id = stop.get("ride_id")
            if ride_id:
                ride_dropoffs[ride_id] = stop
    
    # Add pickups first, then dropoffs
    for ride_id in ride_pickups:
        constrained_stops.append(ride_pickups[ride_id])
    
    for ride_id in ride_dropoffs:
        constrained_stops.append(ride_dropoffs[ride_id])
    
    return constrained_stops

def estimate_route_duration(route: List[Dict[str, Any]]) -> float:
    """Estimate total duration of a route"""
    if len(route) < 2:
        return 0
    
    total_duration = 0
    for i in range(len(route) - 1):
        current = route[i]
        next_stop = route[i + 1]
        
        distance = calculate_distance(
            current["coordinates"][0], current["coordinates"][1],
            next_stop["coordinates"][0], next_stop["coordinates"][1]
        )
        
        # Estimate time (assuming 30 km/h average speed)
        time_hours = distance / 30.0
        total_duration += time_hours
    
    return round(total_duration * 60, 2)  # Convert to minutes

def generate_optimization_suggestions(rides: List[Dict[str, Any]]) -> List[str]:
    """Generate optimization suggestions based on ride data"""
    suggestions = []
    
    if not rides:
        return suggestions
    
    # Analyze ride patterns
    total_distance = sum(r.get("total_distance_km", 0) for r in rides)
    total_earnings = sum(r.get("fare", 0) for r in rides)
    
    # Calculate efficiency metrics
    if total_distance > 0:
        earnings_per_km = total_earnings / total_distance
        
        if earnings_per_km < 2.0:
            suggestions.append("Consider increasing fares for longer distances")
        
        if earnings_per_km > 5.0:
            suggestions.append("Your pricing strategy appears effective")
    
    # Analyze time patterns
    morning_rides = [r for r in rides if r.get("created_at", datetime.utcnow()).hour < 12]
    evening_rides = [r for r in rides if r.get("created_at", datetime.utcnow()).hour >= 12]
    
    if len(morning_rides) > len(evening_rides) * 1.5:
        suggestions.append("Consider focusing on morning commute hours for better efficiency")
    
    if len(evening_rides) > len(morning_rides) * 1.5:
        suggestions.append("Consider focusing on evening commute hours for better efficiency")
    
    # Route optimization suggestions
    if len(rides) > 5:
        suggestions.append("Use multi-ride optimization to reduce empty miles")
        suggestions.append("Consider batch processing rides in the same area")
    
    return suggestions 