from fastapi import APIRouter, HTTPException, Depends
from app.schemas import RideAnalytics, PyObjectId
from app.database import ride_analytics_collection, rides_collection, locations_collection, environmental_metrics_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
from datetime import datetime, timedelta
import uuid

router = APIRouter()

@router.get("/dashboard", response_model=dict)
async def get_user_dashboard(
    period: str = "month",  # week, month, year, all
    user: User = Depends(fastapi_users.current_user)
):
    """Get user analytics dashboard"""
    now = datetime.utcnow()
    
    if period == "week":
        start_date = now - timedelta(weeks=1)
    elif period == "month":
        start_date = now - timedelta(days=30)
    elif period == "year":
        start_date = now - timedelta(days=365)
    else:
        start_date = datetime(2020, 1, 1)  # All time
    
    # Get rides for the period
    rides_query = {
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ],
        "created_at": {"$gte": start_date}
    }
    
    rides = await rides_collection.find(rides_query).to_list(1000)
    
    # Calculate basic stats
    total_rides = len(rides)
    completed_rides = len([r for r in rides if r.get("status") == "completed"])
    
    # Calculate distance
    total_distance = sum(r.get("total_distance_km", 0) for r in rides)
    
    # Calculate CO2 saved
    total_co2_saved = sum(r.get("co2_saved", 0) for r in rides)
    
    # Calculate money saved (estimate)
    total_money_saved = sum(r.get("total_price", 0) for r in rides if r.get("status") == "completed")
    
    # Get favorite routes
    route_counts = {}
    for ride in rides:
        route_key = f"{ride.get('pickup', '')} -> {ride.get('dropoff', '')}"
        route_counts[route_key] = route_counts.get(route_key, 0) + 1
    
    favorite_routes = sorted(route_counts.items(), key=lambda x: x[1], reverse=True)[:5]
    
    # Get peak usage times
    hour_counts = {}
    for ride in rides:
        hour = ride.get("created_at", now).hour
        hour_counts[hour] = hour_counts.get(hour, 0) + 1
    
    peak_hours = sorted(hour_counts.items(), key=lambda x: x[1], reverse=True)[:5]
    
    # Calculate average rating (if available)
    ratings = []
    for ride in rides:
        if ride.get("rating"):
            ratings.append(ride["rating"])
    
    average_rating = sum(ratings) / len(ratings) if ratings else 0
    
    return {
        "period": period,
        "start_date": start_date.isoformat(),
        "end_date": now.isoformat(),
        "total_rides": total_rides,
        "completed_rides": completed_rides,
        "completion_rate": (completed_rides / total_rides * 100) if total_rides > 0 else 0,
        "total_distance_km": total_distance,
        "total_co2_saved_kg": total_co2_saved,
        "total_money_saved": total_money_saved,
        "average_rating": round(average_rating, 2),
        "favorite_routes": [{"route": route, "count": count} for route, count in favorite_routes],
        "peak_usage_times": [{"hour": hour, "count": count} for hour, count in peak_hours],
        "environmental_impact": {
            "co2_saved_kg": total_co2_saved,
            "trees_equivalent": total_co2_saved / 22,  # Average tree absorbs 22kg CO2 per year
            "fuel_saved_liters": total_co2_saved * 2.3  # Rough conversion
        }
    }

@router.get("/environmental", response_model=dict)
async def get_environmental_analytics(
    period: str = "month",
    user: User = Depends(fastapi_users.current_user)
):
    """Get environmental impact analytics"""
    now = datetime.utcnow()
    
    if period == "week":
        start_date = now - timedelta(weeks=1)
    elif period == "month":
        start_date = now - timedelta(days=30)
    elif period == "year":
        start_date = now - timedelta(days=365)
    else:
        start_date = datetime(2020, 1, 1)
    
    # Get environmental metrics
    metrics = await environmental_metrics_collection.find({
        "user_id": user.id,
        "timestamp": {"$gte": start_date}
    }).to_list(1000)
    
    total_co2_saved = sum(m.get("co2_saved_kg", 0) for m in metrics)
    total_distance = sum(m.get("distance_km", 0) for m in metrics)
    total_fuel_saved = sum(m.get("fuel_saved_liters", 0) for m in metrics)
    
    # Calculate daily breakdown
    daily_breakdown = {}
    for metric in metrics:
        date_key = metric["timestamp"].date().isoformat()
        if date_key not in daily_breakdown:
            daily_breakdown[date_key] = {
                "co2_saved": 0,
                "distance": 0,
                "fuel_saved": 0,
                "rides": 0
            }
        daily_breakdown[date_key]["co2_saved"] += metric.get("co2_saved_kg", 0)
        daily_breakdown[date_key]["distance"] += metric.get("distance_km", 0)
        daily_breakdown[date_key]["fuel_saved"] += metric.get("fuel_saved_liters", 0)
        daily_breakdown[date_key]["rides"] += 1
    
    return {
        "period": period,
        "total_co2_saved_kg": total_co2_saved,
        "total_distance_km": total_distance,
        "total_fuel_saved_liters": total_fuel_saved,
        "trees_equivalent": total_co2_saved / 22,
        "daily_breakdown": daily_breakdown,
        "environmental_score": min(100, int(total_co2_saved * 10))  # Score out of 100
    }

@router.get("/earnings", response_model=dict)
async def get_earnings_analytics(
    period: str = "month",
    user: User = Depends(fastapi_users.current_user)
):
    """Get earnings analytics for drivers"""
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can view earnings analytics")
    
    now = datetime.utcnow()
    
    if period == "week":
        start_date = now - timedelta(weeks=1)
    elif period == "month":
        start_date = now - timedelta(days=30)
    elif period == "year":
        start_date = now - timedelta(days=365)
    else:
        start_date = datetime(2020, 1, 1)
    
    # Get completed rides
    rides = await rides_collection.find({
        "driver_id": user.id,
        "status": "completed",
        "created_at": {"$gte": start_date}
    }).to_list(1000)
    
    total_earnings = sum(r.get("total_price", 0) for r in rides)
    total_rides = len(rides)
    average_earnings_per_ride = total_earnings / total_rides if total_rides > 0 else 0
    
    # Calculate daily earnings
    daily_earnings = {}
    for ride in rides:
        date_key = ride["created_at"].date().isoformat()
        if date_key not in daily_earnings:
            daily_earnings[date_key] = {"earnings": 0, "rides": 0}
        daily_earnings[date_key]["earnings"] += ride.get("total_price", 0)
        daily_earnings[date_key]["rides"] += 1
    
    # Calculate hourly earnings
    hourly_earnings = {}
    for ride in rides:
        hour = ride["created_at"].hour
        if hour not in hourly_earnings:
            hourly_earnings[hour] = {"earnings": 0, "rides": 0}
        hourly_earnings[hour]["earnings"] += ride.get("total_price", 0)
        hourly_earnings[hour]["rides"] += 1
    
    return {
        "period": period,
        "total_earnings": total_earnings,
        "total_rides": total_rides,
        "average_earnings_per_ride": average_earnings_per_ride,
        "daily_earnings": daily_earnings,
        "hourly_earnings": hourly_earnings,
        "best_day": max(daily_earnings.items(), key=lambda x: x[1]["earnings"])[0] if daily_earnings else None,
        "best_hour": max(hourly_earnings.items(), key=lambda x: x[1]["earnings"])[0] if hourly_earnings else None
    }

@router.get("/route-analysis", response_model=dict)
async def get_route_analysis(
    pickup: str = None,
    dropoff: str = None,
    user: User = Depends(fastapi_users.current_user)
):
    """Analyze specific routes"""
    query = {
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ],
        "status": "completed"
    }
    
    if pickup:
        query["pickup"] = {"$regex": pickup, "$options": "i"}
    if dropoff:
        query["dropoff"] = {"$regex": dropoff, "$options": "i"}
    
    rides = await rides_collection.find(query).to_list(1000)
    
    if not rides:
        return {"message": "No rides found for the specified route"}
    
    # Analyze the route
    total_distance = sum(r.get("total_distance_km", 0) for r in rides)
    total_duration = sum(r.get("estimated_duration", 0) for r in rides)
    average_price = sum(r.get("total_price", 0) for r in rides) / len(rides)
    
    # Calculate frequency
    route_frequency = {}
    for ride in rides:
        route_key = f"{ride.get('pickup', '')} -> {ride.get('dropoff', '')}"
        route_frequency[route_key] = route_frequency.get(route_key, 0) + 1
    
    return {
        "route": f"{pickup or 'Any'} -> {dropoff or 'Any'}",
        "total_rides": len(rides),
        "average_distance_km": total_distance / len(rides),
        "average_duration_minutes": total_duration / len(rides),
        "average_price": average_price,
        "route_frequency": route_frequency,
        "most_common_route": max(route_frequency.items(), key=lambda x: x[1])[0] if route_frequency else None
    }

@router.post("/generate-report", response_model=dict)
async def generate_analytics_report(
    period: str = "month",
    report_type: str = "comprehensive",  # comprehensive, environmental, earnings
    user: User = Depends(fastapi_users.current_user)
):
    """Generate a comprehensive analytics report"""
    now = datetime.utcnow()
    
    if period == "week":
        start_date = now - timedelta(weeks=1)
    elif period == "month":
        start_date = now - timedelta(days=30)
    elif period == "year":
        start_date = now - timedelta(days=365)
    else:
        start_date = datetime(2020, 1, 1)
    
    # Generate report data
    report_data = {
        "user_id": user.id,
        "period_start": start_date,
        "period_end": now,
        "report_type": report_type,
        "generated_at": now,
        "data": {}
    }
    
    if report_type in ["comprehensive", "environmental"]:
        env_data = await get_environmental_analytics(period, user)
        report_data["data"]["environmental"] = env_data
    
    if report_type in ["comprehensive", "earnings"] and user.is_driver:
        earnings_data = await get_earnings_analytics(period, user)
        report_data["data"]["earnings"] = earnings_data
    
    if report_type == "comprehensive":
        dashboard_data = await get_user_dashboard(period, user)
        report_data["data"]["dashboard"] = dashboard_data
    
    # Store report
    result = await ride_analytics_collection.insert_one(report_data)
    
    return {
        "message": "Analytics report generated successfully",
        "report_id": str(result.inserted_id),
        "period": period,
        "report_type": report_type,
        "data": report_data["data"]
    }

@router.get("/reports", response_model=List[dict])
async def get_analytics_reports(user: User = Depends(fastapi_users.current_user)):
    """Get all generated analytics reports"""
    reports = await ride_analytics_collection.find({"user_id": user.id}).sort("generated_at", -1).to_list(50)
    
    # Return simplified report list
    report_list = []
    for report in reports:
        report_list.append({
            "id": str(report["_id"]),
            "period_start": report["period_start"].isoformat(),
            "period_end": report["period_end"].isoformat(),
            "report_type": report["report_type"],
            "generated_at": report["generated_at"].isoformat()
        })
    
    return report_list