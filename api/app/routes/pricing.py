from fastapi import APIRouter, HTTPException, Depends
from app.schemas import PricingEstimate, DriverEarnings, PyObjectId
from app.database import pricing_estimates_collection, driver_earnings_collection, rides_collection
from app.auth import User, fastapi_users
from bson import ObjectId
from typing import List
from datetime import datetime, timedelta
import uuid

router = APIRouter()

# Base pricing configuration
BASE_PRICE_PER_KM = 0.5  # £0.50 per km
BASE_PRICE_PER_MINUTE = 0.1  # £0.10 per minute
PLATFORM_FEE_PERCENTAGE = 0.15  # 15% platform fee

@router.post("/estimate", response_model=PricingEstimate)
async def estimate_ride_price(
    pickup_coords: List[float],
    dropoff_coords: List[float],
    ride_type: str = "standard",
    user: User = Depends(fastapi_users.current_user)
):
    """Estimate ride price based on distance and time"""
    # Calculate distance (simplified - in production, use proper routing service)
    import math
    
    def calculate_distance(lat1, lon1, lat2, lon2):
        R = 6371  # Earth's radius in kilometers
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2) * math.sin(dlon/2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c
    
    distance_km = calculate_distance(pickup_coords[0], pickup_coords[1], dropoff_coords[0], dropoff_coords[1])
    
    # Estimate duration (simplified - assume average speed of 30 km/h)
    estimated_duration_minutes = int((distance_km / 30) * 60)
    
    # Calculate base price
    base_price = (distance_km * BASE_PRICE_PER_KM) + (estimated_duration_minutes * BASE_PRICE_PER_MINUTE)
    
    # Apply multipliers based on ride type
    multipliers = {
        "standard": 1.0,
        "premium": 1.5,
        "eco": 0.8,
        "luxury": 2.0
    }
    
    ride_multiplier = multipliers.get(ride_type, 1.0)
    
    # Calculate surge pricing (simplified)
    current_hour = datetime.utcnow().hour
    surge_multiplier = 1.0
    
    # Peak hours (7-9 AM, 5-7 PM)
    if current_hour in [7, 8, 9, 17, 18, 19]:
        surge_multiplier = 1.3
    
    # Weekend nights
    if datetime.utcnow().weekday() >= 5 and current_hour >= 22:
        surge_multiplier = 1.5
    
    # Calculate final price
    final_price = base_price * ride_multiplier * surge_multiplier
    
    # Create pricing estimate
    estimate_data = {
        "ride_id": ObjectId(),  # Temporary ID for estimate
        "base_price": base_price,
        "distance_km": distance_km,
        "estimated_duration_minutes": estimated_duration_minutes,
        "surge_multiplier": surge_multiplier,
        "time_multiplier": ride_multiplier,
        "demand_multiplier": 1.0,  # Could be calculated based on demand
        "final_price": final_price,
        "breakdown": {
            "base_price": base_price,
            "distance_price": distance_km * BASE_PRICE_PER_KM,
            "time_price": estimated_duration_minutes * BASE_PRICE_PER_MINUTE,
            "ride_type_multiplier": ride_multiplier,
            "surge_multiplier": surge_multiplier,
            "final_price": final_price
        },
        "estimated_at": datetime.utcnow()
    }
    
    result = await pricing_estimates_collection.insert_one(estimate_data)
    estimate_data["id"] = result.inserted_id
    
    return estimate_data

@router.get("/earnings", response_model=List[DriverEarnings])
async def get_driver_earnings(
    start_date: datetime = None,
    end_date: datetime = None,
    user: User = Depends(fastapi_users.current_user)
):
    """Get driver earnings"""
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can view earnings")
    
    query = {"driver_id": user.id}
    
    if start_date and end_date:
        query["created_at"] = {"$gte": start_date, "$lte": end_date}
    elif start_date:
        query["created_at"] = {"$gte": start_date}
    elif end_date:
        query["created_at"] = {"$lte": end_date}
    
    earnings = await driver_earnings_collection.find(query).sort("created_at", -1).to_list(100)
    return earnings

@router.get("/earnings/summary", response_model=dict)
async def get_earnings_summary(
    period: str = "month",  # week, month, year
    user: User = Depends(fastapi_users.current_user)
):
    """Get earnings summary for a period"""
    if not user.is_driver:
        raise HTTPException(status_code=403, detail="Only drivers can view earnings")
    
    now = datetime.utcnow()
    
    if period == "week":
        start_date = now - timedelta(weeks=1)
    elif period == "month":
        start_date = now - timedelta(days=30)
    elif period == "year":
        start_date = now - timedelta(days=365)
    else:
        start_date = now - timedelta(days=30)
    
    # Get earnings for the period
    earnings = await driver_earnings_collection.find({
        "driver_id": user.id,
        "created_at": {"$gte": start_date}
    }).to_list(1000)
    
    total_gross = sum(earning["gross_earnings"] for earning in earnings)
    total_platform_fee = sum(earning["platform_fee"] for earning in earnings)
    total_net = sum(earning["net_earnings"] for earning in earnings)
    
    # Get ride count
    ride_count = await rides_collection.count_documents({
        "driver_id": user.id,
        "status": "completed",
        "created_at": {"$gte": start_date}
    })
    
    return {
        "period": period,
        "start_date": start_date.isoformat(),
        "end_date": now.isoformat(),
        "total_gross_earnings": total_gross,
        "total_platform_fees": total_platform_fee,
        "total_net_earnings": total_net,
        "total_rides": ride_count,
        "average_per_ride": total_net / ride_count if ride_count > 0 else 0,
        "platform_fee_percentage": PLATFORM_FEE_PERCENTAGE * 100
    }

@router.post("/earnings/calculate", response_model=dict)
async def calculate_ride_earnings(
    ride_id: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Calculate earnings for a completed ride"""
    if not ObjectId.is_valid(ride_id):
        raise HTTPException(status_code=400, detail="Invalid ride ID")
    
    ride = await rides_collection.find_one({"_id": ObjectId(ride_id), "driver_id": user.id})
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    if ride["status"] != "completed":
        raise HTTPException(status_code=400, detail="Ride must be completed to calculate earnings")
    
    # Check if earnings already calculated
    existing_earnings = await driver_earnings_collection.find_one({"ride_id": ObjectId(ride_id)})
    if existing_earnings:
        raise HTTPException(status_code=400, detail="Earnings already calculated for this ride")
    
    # Calculate earnings
    total_price = ride.get("total_price", 0)
    if total_price == 0:
        # Calculate from distance if total_price not set
        distance_km = ride.get("total_distance_km", 0)
        total_price = distance_km * BASE_PRICE_PER_KM
    
    platform_fee = total_price * PLATFORM_FEE_PERCENTAGE
    net_earnings = total_price - platform_fee
    
    # Create earnings record
    earnings_data = {
        "driver_id": user.id,
        "ride_id": ObjectId(ride_id),
        "gross_earnings": total_price,
        "platform_fee": platform_fee,
        "net_earnings": net_earnings,
        "payment_status": "pending",
        "created_at": datetime.utcnow()
    }
    
    result = await driver_earnings_collection.insert_one(earnings_data)
    
    return {
        "message": "Earnings calculated successfully",
        "earnings_id": str(result.inserted_id),
        "gross_earnings": total_price,
        "platform_fee": platform_fee,
        "net_earnings": net_earnings
    }

@router.put("/earnings/{earnings_id}/payout", response_model=dict)
async def process_payout(
    earnings_id: str,
    payment_method: str,
    user: User = Depends(fastapi_users.current_user)
):
    """Process payout for driver earnings"""
    if not ObjectId.is_valid(earnings_id):
        raise HTTPException(status_code=400, detail="Invalid earnings ID")
    
    earnings = await driver_earnings_collection.find_one({
        "_id": ObjectId(earnings_id),
        "driver_id": user.id
    })
    
    if not earnings:
        raise HTTPException(status_code=404, detail="Earnings not found")
    
    if earnings["payment_status"] != "pending":
        raise HTTPException(status_code=400, detail="Earnings already processed")
    
    # Update earnings status
    result = await driver_earnings_collection.update_one(
        {"_id": ObjectId(earnings_id)},
        {
            "$set": {
                "payment_status": "paid",
                "payout_date": datetime.utcnow(),
                "payment_method": payment_method
            }
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to process payout")
    
    return {
        "message": "Payout processed successfully",
        "amount": earnings["net_earnings"],
        "payment_method": payment_method
    }

@router.get("/pricing/rules", response_model=dict)
async def get_pricing_rules():
    """Get current pricing rules and multipliers"""
    return {
        "base_pricing": {
            "price_per_km": BASE_PRICE_PER_KM,
            "price_per_minute": BASE_PRICE_PER_MINUTE
        },
        "ride_type_multipliers": {
            "standard": 1.0,
            "premium": 1.5,
            "eco": 0.8,
            "luxury": 2.0
        },
        "surge_pricing": {
            "peak_hours": {
                "hours": [7, 8, 9, 17, 18, 19],
                "multiplier": 1.3
            },
            "weekend_nights": {
                "hours": [22, 23, 0, 1, 2, 3, 4, 5, 6],
                "multiplier": 1.5
            }
        },
        "platform_fee_percentage": PLATFORM_FEE_PERCENTAGE * 100
    }
