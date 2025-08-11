from fastapi import APIRouter, HTTPException, Depends, Query
from app.schemas import RideAnalytics, EnvironmentalMetrics
from app.database import (
    rides_collection, payments_collection, feedback_collection,
    environmental_metrics_collection, user_profiles_collection
)
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List, Optional
from datetime import datetime, timedelta
import math

router = APIRouter()

@router.get("/rides", response_model=dict)
async def get_ride_analytics(
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    user: User = Depends(fastapi_users.current_user)
):
    """Get comprehensive ride analytics"""
    # Parse dates
    if start_date:
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")
    else:
        start_dt = datetime.utcnow() - timedelta(days=30)
    
    if end_date:
        end_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
    else:
        end_dt = datetime.utcnow()
    
    # Build date filter
    date_filter = {"created_at": {"$gte": start_dt, "$lt": end_dt}}
    
    # Get ride statistics
    total_rides = await rides_collection.count_documents(date_filter)
    completed_rides = await rides_collection.count_documents({**date_filter, "status": "completed"})
    active_rides = await rides_collection.count_documents({**date_filter, "status": "in_progress"})
    cancelled_rides = await rides_collection.count_documents({**date_filter, "status": "cancelled"})
    
    # Calculate completion rate
    completion_rate = (completed_rides / total_rides * 100) if total_rides > 0 else 0
    
    # Get average ride duration
    pipeline = [
        {"$match": {**date_filter, "status": "completed"}},
        {"$addFields": {
            "duration_minutes": {
                "$divide": [
                    {"$subtract": ["$dropoff_time", "$pickup_time"]},
                    60000  # Convert milliseconds to minutes
                ]
            }
        }},
        {"$group": {
            "_id": None,
            "avg_duration": {"$avg": "$duration_minutes"},
            "min_duration": {"$min": "$duration_minutes"},
            "max_duration": {"$max": "$duration_minutes"}
        }}
    ]
    
    duration_stats = await rides_collection.aggregate(pipeline).to_list(1)
    duration_data = duration_stats[0] if duration_stats else {}
    
    # Get rides by status
    status_pipeline = [
        {"$match": date_filter},
        {"$group": {"_id": "$status", "count": {"$sum": 1}}}
    ]
    status_distribution = await rides_collection.aggregate(status_pipeline).to_list(100)
    
    # Get rides by hour of day
    hour_pipeline = [
        {"$match": date_filter},
        {"$addFields": {"hour": {"$hour": "$created_at"}}},
        {"$group": {"_id": "$hour", "count": {"$sum": 1}}},
        {"$sort": {"_id": 1}}
    ]
    hourly_distribution = await rides_collection.aggregate(hour_pipeline).to_list(24)
    
    return {
        "period": {
            "start_date": start_dt.strftime("%Y-%m-%d"),
            "end_date": (end_dt - timedelta(days=1)).strftime("%Y-%m-%d")
        },
        "overview": {
            "total_rides": total_rides,
            "completed_rides": completed_rides,
            "active_rides": active_rides,
            "cancelled_rides": cancelled_rides,
            "completion_rate": round(completion_rate, 2)
        },
        "duration_stats": {
            "average_minutes": round(duration_data.get("avg_duration", 0), 2),
            "min_minutes": round(duration_data.get("min_duration", 0), 2),
            "max_minutes": round(duration_data.get("max_duration", 0), 2)
        },
        "status_distribution": {item["_id"]: item["count"] for item in status_distribution},
        "hourly_distribution": {item["_id"]: item["count"] for item in hourly_distribution}
    }

@router.get("/user/{user_id}", response_model=dict)
async def get_user_analytics(
    user_id: str,
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    user: User = Depends(fastapi_users.current_user)
):
    """Get analytics for a specific user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can only view their own analytics
    if str(user.id) != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this user's analytics")
    
    # Parse dates
    if start_date:
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")
    else:
        start_dt = datetime.utcnow() - timedelta(days=30)
    
    if end_date:
        end_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
    else:
        end_dt = datetime.utcnow()
    
    date_filter = {"created_at": {"$gte": start_dt, "$lt": end_dt}}
    
    # Get rides as driver
    driver_rides = await rides_collection.find({
        **date_filter,
        "driver_id": ObjectId(user_id)
    }).to_list(1000)
    
    # Get rides as passenger
    passenger_rides = await rides_collection.find({
        **date_filter,
        "passenger_id": ObjectId(user_id)
    }).to_list(1000)
    
    # Calculate driver statistics
    driver_stats = calculate_user_ride_stats(driver_rides, "driver")
    
    # Calculate passenger statistics
    passenger_stats = calculate_user_ride_stats(passenger_rides, "passenger")
    
    # Get user profile
    user_profile = await user_profiles_collection.find_one({"user_id": ObjectId(user_id)})
    
    # Get feedback statistics
    feedback_stats = await get_user_feedback_stats(ObjectId(user_id), date_filter)
    
    return {
        "user_id": user_id,
        "period": {
            "start_date": start_dt.strftime("%Y-%m-%d"),
            "end_date": (end_dt - timedelta(days=1)).strftime("%Y-%m-%d")
        },
        "profile": {
            "rating": user_profile.get("rating", 0) if user_profile else 0,
            "total_rides": user_profile.get("total_rides", 0) if user_profile else 0,
            "is_verified": user_profile.get("is_verified", False) if user_profile else False
        },
        "driver_analytics": driver_stats,
        "passenger_analytics": passenger_stats,
        "feedback_analytics": feedback_stats
    }

def calculate_user_ride_stats(rides: List[dict], role: str) -> dict:
    """Calculate ride statistics for a user in a specific role"""
    if not rides:
        return {
            "total_rides": 0,
            "completed_rides": 0,
            "total_distance": 0,
            "total_earnings": 0,
            "average_rating": 0
        }
    
    total_rides = len(rides)
    completed_rides = len([r for r in rides if r.get("status") == "completed"])
    
    # Calculate total distance
    total_distance = sum(r.get("total_distance_km", 0) for r in rides)
    
    # Calculate total earnings (for drivers)
    total_earnings = 0
    if role == "driver":
        total_earnings = sum(r.get("fare", 0) for r in rides)
    
    # Calculate average rating
    ratings = [r.get("rating", 0) for r in rides if r.get("rating")]
    average_rating = sum(ratings) / len(ratings) if ratings else 0
    
    return {
        "total_rides": total_rides,
        "completed_rides": completed_rides,
        "completion_rate": round((completed_rides / total_rides * 100), 2) if total_rides > 0 else 0,
        "total_distance": round(total_distance, 2),
        "total_earnings": round(total_earnings, 2),
        "average_rating": round(average_rating, 2)
    }

async def get_user_feedback_stats(user_id: ObjectId, date_filter: dict) -> dict:
    """Get feedback statistics for a user"""
    # Get feedback given by user
    feedback_given = await feedback_collection.count_documents({
        **date_filter,
        "from_user_id": user_id
    })
    
    # Get feedback received by user
    feedback_received = await feedback_collection.count_documents({
        **date_filter,
        "to_user_id": user_id
    })
    
    # Get average rating received
    rating_pipeline = [
        {"$match": {**date_filter, "to_user_id": user_id}},
        {"$group": {"_id": None, "avg_rating": {"$avg": "$rating"}}}
    ]
    rating_stats = await feedback_collection.aggregate(rating_pipeline).to_list(1)
    avg_rating = rating_stats[0].get("avg_rating", 0) if rating_stats else 0
    
    return {
        "feedback_given": feedback_given,
        "feedback_received": feedback_received,
        "average_rating_received": round(avg_rating, 2)
    }

@router.get("/platform", response_model=dict)
async def get_platform_analytics(
    user: User = Depends(fastapi_users.current_user)
):
    """Get platform-wide analytics (admin only)"""
    # Check if user is admin (you might want to add an is_admin field to User model)
    # For now, allowing all authenticated users to access platform analytics
    
    # Get total users
    total_users = await user_profiles_collection.count_documents({})
    verified_users = await user_profiles_collection.count_documents({"is_verified": True})
    
    # Get total rides
    total_rides = await rides_collection.count_documents({})
    completed_rides = await rides_collection.count_documents({"status": "completed"})
    
    # Get total payments
    total_payments = await payments_collection.count_documents({})
    completed_payments = await payments_collection.count_documents({"status": "completed"})
    
    # Calculate total revenue
    revenue_pipeline = [
        {"$match": {"status": "completed"}},
        {"$group": {"_id": None, "total_revenue": {"$sum": "$amount"}}}
    ]
    revenue_stats = await payments_collection.aggregate(revenue_pipeline).to_list(1)
    total_revenue = revenue_stats[0].get("total_revenue", 0) if revenue_stats else 0
    
    # Get environmental impact
    env_pipeline = [
        {"$group": {"_id": None, "total_co2_saved": {"$sum": "$co2_saved_kg"}}}
    ]
    env_stats = await environmental_metrics_collection.aggregate(env_pipeline).to_list(1)
    total_co2_saved = env_stats[0].get("total_co2_saved", 0) if env_stats else 0
    
    # Get recent activity (last 7 days)
    week_ago = datetime.utcnow() - timedelta(days=7)
    recent_rides = await rides_collection.count_documents({"created_at": {"$gte": week_ago}})
    recent_users = await user_profiles_collection.count_documents({"created_at": {"$gte": week_ago}})
    
    return {
        "overview": {
            "total_users": total_users,
            "verified_users": verified_users,
            "verification_rate": round((verified_users / total_users * 100), 2) if total_users > 0 else 0
        },
        "rides": {
            "total_rides": total_rides,
            "completed_rides": completed_rides,
            "completion_rate": round((completed_rides / total_rides * 100), 2) if total_rides > 0 else 0
        },
        "payments": {
            "total_payments": total_payments,
            "completed_payments": completed_payments,
            "success_rate": round((completed_payments / total_payments * 100), 2) if total_payments > 0 else 0,
            "total_revenue": round(total_revenue, 2)
        },
        "environmental_impact": {
            "total_co2_saved_kg": round(total_co2_saved, 2)
        },
        "recent_activity": {
            "rides_last_7_days": recent_rides,
            "new_users_last_7_days": recent_users
        }
    }

@router.get("/trends", response_model=dict)
async def get_trend_analytics(
    days: int = Query(30, description="Number of days to analyze"),
    user: User = Depends(fastapi_users.current_user)
):
    """Get trend analytics over a specified period"""
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    # Get daily ride counts
    daily_rides_pipeline = [
        {"$match": {"created_at": {"$gte": start_date, "$lt": end_date}}},
        {"$addFields": {"date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$created_at"}}}},
        {"$group": {"_id": "$date", "count": {"$sum": 1}}},
        {"$sort": {"_id": 1}}
    ]
    daily_rides = await rides_collection.aggregate(daily_rides_pipeline).to_list(100)
    
    # Get daily user registrations
    daily_users_pipeline = [
        {"$match": {"created_at": {"$gte": start_date, "$lt": end_date}}},
        {"$addFields": {"date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$created_at"}}}},
        {"$group": {"_id": "$date", "count": {"$sum": 1}}},
        {"$sort": {"_id": 1}}
    ]
    daily_users = await user_profiles_collection.aggregate(daily_users_pipeline).to_list(100)
    
    # Get daily revenue
    daily_revenue_pipeline = [
        {"$match": {"status": "completed", "created_at": {"$gte": start_date, "$lt": end_date}}},
        {"$addFields": {"date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$created_at"}}}},
        {"$group": {"_id": "$date", "revenue": {"$sum": "$amount"}}},
        {"$sort": {"_id": 1}}
    ]
    daily_revenue = await payments_collection.aggregate(daily_revenue_pipeline).to_list(100)
    
    return {
        "period": {
            "start_date": start_date.strftime("%Y-%m-%d"),
            "end_date": end_date.strftime("%Y-%m-%d"),
            "days": days
        },
        "daily_rides": {item["_id"]: item["count"] for item in daily_rides},
        "daily_users": {item["_id"]: item["count"] for item in daily_users},
        "daily_revenue": {item["_id"]: round(item["revenue"], 2) for item in daily_revenue}
    } 