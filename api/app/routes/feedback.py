from fastapi import APIRouter, HTTPException, Depends
from app.schemas import Feedback, PyObjectId
from app.database import feedback_collection, rides_collection, user_profiles_collection
from app.auth import User
from fastapi_users import FastAPIUsers
from app.auth import auth_backend, get_user_db
import uuid
from typing import List, Dict, Any
from bson import ObjectId
from datetime import datetime
import statistics
from datetime import timedelta

router = APIRouter()

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    None,
    None,
    None,
)

@router.post("/", response_model=Feedback)
async def create_feedback(
    feedback: Feedback,
    user: User = Depends(fastapi_users.current_user)
):
    """Create feedback for a ride"""
    feedback.from_user_id = user.id
    feedback.created_at = datetime.utcnow()
    
    # Verify the ride exists and user is part of it
    ride = await rides_collection.find_one({
        "_id": feedback.ride_id,
        "$or": [
            {"driver_id": user.id},
            {"passenger_id": user.id}
        ]
    })
    
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found or user not authorized")
    
    # Verify the ride is completed
    if ride.get("status") != "completed":
        raise HTTPException(status_code=400, detail="Can only provide feedback for completed rides")
    
    # Check if user has already provided feedback for this ride
    existing_feedback = await feedback_collection.find_one({
        "ride_id": feedback.ride_id,
        "from_user_id": user.id
    })
    
    if existing_feedback:
        raise HTTPException(status_code=400, detail="You have already provided feedback for this ride")
    
    # Validate rating
    if feedback.rating < 1 or feedback.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5")
    
    feedback_dict = feedback.dict(by_alias=True, exclude_unset=True)
    result = await feedback_collection.insert_one(feedback_dict)
    
    # Update user's average rating
    await update_user_rating(feedback.to_user_id)
    
    created_feedback = await feedback_collection.find_one({"_id": result.inserted_id})
    return created_feedback

@router.get("/ride/{ride_id}", response_model=List[Feedback])
async def get_ride_feedback(
    ride_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get all feedback for a specific ride"""
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
    
    feedback_list = await feedback_collection.find({
        "ride_id": ObjectId(ride_id)
    }).to_list(100)
    
    return feedback_list

@router.get("/user/{user_id}", response_model=List[Feedback])
async def get_user_feedback(
    user_id: str,
    limit: int = 50,
    user: User = Depends(fastapi_users.current_user)
):
    """Get feedback for a specific user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can see feedback for themselves or for users they've ridden with
    if str(user.id) != user_id:
        # Check if they've ridden together
        shared_rides = await rides_collection.find({
            "$or": [
                {"driver_id": user.id, "passenger_id": ObjectId(user_id)},
                {"driver_id": ObjectId(user_id), "passenger_id": user.id}
            ]
        }).to_list(10)
        
        if not shared_rides:
            raise HTTPException(status_code=403, detail="Not authorized to view this user's feedback")
    
    feedback_list = await feedback_collection.find({
        "to_user_id": ObjectId(user_id)
    }).sort([("created_at", -1)]).limit(limit).to_list(limit)
    
    return feedback_list

@router.get("/user/{user_id}/summary", response_model=Dict[str, Any])
async def get_user_feedback_summary(
    user_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Get a summary of feedback for a specific user"""
    if not ObjectId.is_valid(user_id):
        raise HTTPException(status_code=400, detail="Invalid user ID")
    
    # Users can see feedback summary for themselves or for users they've ridden with
    if str(user.id) != user_id:
        # Check if they've ridden together
        shared_rides = await rides_collection.find({
            "$or": [
                {"driver_id": user.id, "passenger_id": ObjectId(user_id)},
                {"driver_id": ObjectId(user_id), "passenger_id": user.id}
            ]
        }).to_list(10)
        
        if not shared_rides:
            raise HTTPException(status_code=403, detail="Not authorized to view this user's feedback summary")
    
    # Get all feedback for the user
    feedback_list = await feedback_collection.find({
        "to_user_id": ObjectId(user_id)
    }).to_list(1000)
    
    if not feedback_list:
        return {
            "user_id": user_id,
            "total_feedback": 0,
            "average_rating": 0.0,
            "rating_distribution": {},
            "category_breakdown": {},
            "recent_feedback": []
        }
    
    # Calculate statistics
    ratings = [f.get("rating", 0) for f in feedback_list]
    average_rating = statistics.mean(ratings) if ratings else 0.0
    
    # Rating distribution
    rating_distribution = {}
    for rating in range(1, 6):
        rating_distribution[rating] = ratings.count(rating)
    
    # Category breakdown
    category_breakdown = {}
    for feedback in feedback_list:
        category = feedback.get("category", "general")
        if category not in category_breakdown:
            category_breakdown[category] = {"count": 0, "average_rating": 0.0}
        
        category_breakdown[category]["count"] += 1
        category_breakdown[category]["average_rating"] += feedback.get("rating", 0)
    
    # Calculate average rating per category
    for category in category_breakdown:
        count = category_breakdown[category]["count"]
        if count > 0:
            category_breakdown[category]["average_rating"] /= count
    
    # Get recent feedback (last 5)
    recent_feedback = await feedback_collection.find({
        "to_user_id": ObjectId(user_id)
    }).sort([("created_at", -1)]).limit(5).to_list(5)
    
    return {
        "user_id": user_id,
        "total_feedback": len(feedback_list),
        "average_rating": round(average_rating, 2),
        "rating_distribution": rating_distribution,
        "category_breakdown": category_breakdown,
        "recent_feedback": recent_feedback
    }

@router.put("/{feedback_id}", response_model=Feedback)
async def update_feedback(
    feedback_id: str,
    rating: int,
    comment: str = "",
    category: str = "general",
    user: User = Depends(fastapi_users.current_user)
):
    """Update existing feedback"""
    if not ObjectId.is_valid(feedback_id):
        raise HTTPException(status_code=400, detail="Invalid feedback ID")
    
    # Find the feedback
    feedback = await feedback_collection.find_one({"_id": ObjectId(feedback_id)})
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    
    # Only allow the author to update their feedback
    if str(feedback["from_user_id"]) != str(user.id):
        raise HTTPException(status_code=403, detail="Not authorized to update this feedback")
    
    # Validate rating
    if rating < 1 or rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5")
    
    # Update the feedback
    result = await feedback_collection.update_one(
        {"_id": ObjectId(feedback_id)},
        {
            "$set": {
                "rating": rating,
                "comment": comment,
                "category": category,
                "updated_at": datetime.utcnow()
            }
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to update feedback")
    
    # Update user's average rating
    await update_user_rating(feedback["to_user_id"])
    
    updated_feedback = await feedback_collection.find_one({"_id": ObjectId(feedback_id)})
    return updated_feedback

@router.delete("/{feedback_id}")
async def delete_feedback(
    feedback_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Delete feedback"""
    if not ObjectId.is_valid(feedback_id):
        raise HTTPException(status_code=400, detail="Invalid feedback ID")
    
    # Find the feedback
    feedback = await feedback_collection.find_one({"_id": ObjectId(feedback_id)})
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    
    # Only allow the author to delete their feedback
    if str(feedback["from_user_id"]) != str(user.id):
        raise HTTPException(status_code=403, detail="Not authorized to delete this feedback")
    
    # Delete the feedback
    result = await feedback_collection.delete_one({"_id": ObjectId(feedback_id)})
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=400, detail="Failed to delete feedback")
    
    # Update user's average rating
    await update_user_rating(feedback["to_user_id"])
    
    return {"message": "Feedback deleted successfully"}

@router.get("/analytics/platform", response_model=Dict[str, Any])
async def get_platform_feedback_analytics(
    period_days: int = 30,
    user: User = Depends(fastapi_users.current_user)
):
    """Get platform-wide feedback analytics"""
    # Only allow verified users to access analytics
    if not user.is_verified_driver:
        raise HTTPException(status_code=403, detail="Only verified users can access analytics")
    
    # Calculate period
    period_start = datetime.utcnow() - timedelta(days=period_days)
    
    # Get all feedback in the period
    feedback_list = await feedback_collection.find({
        "created_at": {"$gte": period_start}
    }).to_list(1000)
    
    if not feedback_list:
        return {
            "period_days": period_days,
            "total_feedback": 0,
            "average_rating": 0.0,
            "rating_distribution": {},
            "category_breakdown": {},
            "top_rated_users": []
        }
    
    # Calculate statistics
    ratings = [f.get("rating", 0) for f in feedback_list]
    average_rating = statistics.mean(ratings) if ratings else 0.0
    
    # Rating distribution
    rating_distribution = {}
    for rating in range(1, 6):
        rating_distribution[rating] = ratings.count(rating)
    
    # Category breakdown
    category_breakdown = {}
    for feedback in feedback_list:
        category = feedback.get("category", "general")
        if category not in category_breakdown:
            category_breakdown[category] = {"count": 0, "average_rating": 0.0}
        
        category_breakdown[category]["count"] += 1
        category_breakdown[category]["average_rating"] += feedback.get("rating", 0)
    
    # Calculate average rating per category
    for category in category_breakdown:
        count = category_breakdown[category]["count"]
        if count > 0:
            category_breakdown[category]["average_rating"] /= count
    
    # Get top-rated users
    pipeline = [
        {
            "$match": {
                "created_at": {"$gte": period_start}
            }
        },
        {
            "$group": {
                "_id": "$to_user_id",
                "total_feedback": {"$sum": 1},
                "average_rating": {"$avg": "$rating"}
            }
        },
        {
            "$match": {
                "total_feedback": {"$gte": 3}  # At least 3 feedback entries
            }
        },
        {
            "$sort": {"average_rating": -1}
        },
        {
            "$limit": 10
        }
    ]
    
    top_rated_users = await feedback_collection.aggregate(pipeline).to_list(10)
    
    return {
        "period_days": period_days,
        "total_feedback": len(feedback_list),
        "average_rating": round(average_rating, 2),
        "rating_distribution": rating_distribution,
        "category_breakdown": category_breakdown,
        "top_rated_users": top_rated_users
    }

async def update_user_rating(user_id: PyObjectId):
    """Update a user's average rating based on all feedback"""
    try:
        # Get all feedback for the user
        feedback_list = await feedback_collection.find({
            "to_user_id": user_id
        }).to_list(1000)
        
        if not feedback_list:
            return
        
        # Calculate average rating
        ratings = [f.get("rating", 0) for f in feedback_list]
        average_rating = statistics.mean(ratings) if ratings else 0.0
        
        # Update user profile
        await user_profiles_collection.update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "rating": round(average_rating, 2),
                    "total_rides": len(feedback_list),
                    "updated_at": datetime.utcnow()
                }
            }
        )
    except Exception as e:
        print(f"Failed to update user rating: {e}") 