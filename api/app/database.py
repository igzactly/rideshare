from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings

client = AsyncIOMotorClient(settings.MONGODB_URL)
database = client[settings.MONGODB_DB]

# Collections
users_collection = database.users
rides_collection = database.rides
drivers_collection = database.drivers
payments_collection = database.payments
locations_collection = database.locations
emergency_alerts_collection = database.emergency_alerts
user_profiles_collection = database.user_profiles
environmental_metrics_collection = database.environmental_metrics
community_filters_collection = database.community_filters
feedback_collection = database.feedback
notifications_collection = database.notifications
scheduled_rides_collection = database.scheduled_rides
ride_preferences_collection = database.ride_preferences
pricing_estimates_collection = database.pricing_estimates
driver_earnings_collection = database.driver_earnings
ride_cancellations_collection = database.ride_cancellations
ride_analytics_collection = database.ride_analytics

async def create_indexes():
    """Create database indexes for optimal performance"""
    
    # Users collection indexes
    await users_collection.create_index("email", unique=True)
    await users_collection.create_index("is_driver")
    await users_collection.create_index("is_verified_driver")
    
    # Rides collection indexes
    await rides_collection.create_index("driver_id")
    await rides_collection.create_index("passenger_id")
    await rides_collection.create_index("status")
    await rides_collection.create_index("created_at")
    await rides_collection.create_index("pickup_coords", "2dsphere")
    await rides_collection.create_index("dropoff_coords", "2dsphere")
    await rides_collection.create_index("pickup_time")
    await rides_collection.create_index("dropoff_time")
    await rides_collection.create_index("rating")
    
    # Drivers collection indexes
    await drivers_collection.create_index("user_id", unique=True)
    await drivers_collection.create_index("is_online")
    await drivers_collection.create_index("start_location", "2dsphere")
    await drivers_collection.create_index("end_location", "2dsphere")
    await drivers_collection.create_index("rating")
    await drivers_collection.create_index("vehicle_type")
    
    # Payments collection indexes
    await payments_collection.create_index("ride_id")
    await payments_collection.create_index("user_id")
    await payments_collection.create_index("status")
    await payments_collection.create_index("created_at")
    await payments_collection.create_index("completed_at")
    await payments_collection.create_index("payment_method")
    await payments_collection.create_index("transaction_id", unique=True)
    
    # Locations collection indexes
    await locations_collection.create_index("user_id")
    await locations_collection.create_index("coordinates", "2dsphere")
    await locations_collection.create_index("timestamp")
    await locations_collection.create_index("ride_id")
    
    # Emergency alerts collection indexes
    await emergency_alerts_collection.create_index("user_id")
    await emergency_alerts_collection.create_index("ride_id")
    await emergency_alerts_collection.create_index("alert_type")
    await emergency_alerts_collection.create_index("status")
    await emergency_alerts_collection.create_index("created_at")
    await emergency_alerts_collection.create_index("resolved_at")
    
    # User profiles collection indexes
    await user_profiles_collection.create_index("user_id", unique=True)
    await user_profiles_collection.create_index("rating")
    await user_profiles_collection.create_index("is_verified")
    await user_profiles_collection.create_index("communities")
    await user_profiles_collection.create_index("current_location", "2dsphere")
    
    # Environmental metrics collection indexes
    await environmental_metrics_collection.create_index("ride_id")
    await environmental_metrics_collection.create_index("user_id")
    await environmental_metrics_collection.create_index("created_at")
    await environmental_metrics_collection.create_index("co2_saved_kg")
    
    # Community filters collection indexes
    await community_filters_collection.create_index("user_id", unique=True)
    await community_filters_collection.create_index("preferred_communities")
    await community_filters_collection.create_index("trust_score_threshold")
    await community_filters_collection.create_index("max_distance_km")
    await community_filters_collection.create_index("pickup_coords", "2dsphere")
    
    # Feedback collection indexes
    await feedback_collection.create_index("ride_id")
    await feedback_collection.create_index("from_user_id")
    await feedback_collection.create_index("to_user_id")
    await feedback_collection.create_index("rating")
    await feedback_collection.create_index("created_at")
    await feedback_collection.create_index("updated_at")
    
    # Notifications collection indexes
    await notifications_collection.create_index("to_user_id")
    await notifications_collection.create_index("from_user_id")
    await notifications_collection.create_index("notification_type")
    await notifications_collection.create_index("is_read")
    await notifications_collection.create_index("created_at")
    await notifications_collection.create_index("priority")
    await notifications_collection.create_index("ride_id")
    
    # Scheduled rides collection indexes
    await scheduled_rides_collection.create_index("driver_id")
    await scheduled_rides_collection.create_index("scheduled_time")
    await scheduled_rides_collection.create_index("is_recurring")
    await scheduled_rides_collection.create_index("recurring_pattern")
    await scheduled_rides_collection.create_index("status")
    await scheduled_rides_collection.create_index("pickup_coords", "2dsphere")
    await scheduled_rides_collection.create_index("dropoff_coords", "2dsphere")
    
    # Ride preferences collection indexes
    await ride_preferences_collection.create_index("user_id", unique=True)
    await ride_preferences_collection.create_index("preferred_ride_types")
    await ride_preferences_collection.create_index("max_price_per_km")
    await ride_preferences_collection.create_index("preferred_vehicle_types")
    
    # Pricing estimates collection indexes
    await pricing_estimates_collection.create_index("ride_id")
    await pricing_estimates_collection.create_index("estimated_at")
    await pricing_estimates_collection.create_index("surge_multiplier")
    
    # Driver earnings collection indexes
    await driver_earnings_collection.create_index("driver_id")
    await driver_earnings_collection.create_index("ride_id")
    await driver_earnings_collection.create_index("payment_status")
    await driver_earnings_collection.create_index("payout_date")
    await driver_earnings_collection.create_index("created_at")
    
    # Ride cancellations collection indexes
    await ride_cancellations_collection.create_index("ride_id")
    await ride_cancellations_collection.create_index("cancelled_by")
    await ride_cancellations_collection.create_index("cancellation_time")
    await ride_cancellations_collection.create_index("refund_status")
    
    # Ride analytics collection indexes
    await ride_analytics_collection.create_index("user_id")
    await ride_analytics_collection.create_index("period_start")
    await ride_analytics_collection.create_index("period_end")
    await ride_analytics_collection.create_index("created_at")
    
    print("Database indexes created successfully")
