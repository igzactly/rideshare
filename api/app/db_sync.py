from pymongo import MongoClient
from app.config import settings

client = MongoClient(settings.MONGODB_URL)
db = client[settings.MONGODB_DB]

users_collection = db.users
rides_collection = db.rides
drivers_collection = db.drivers
payments_collection = db.payments
locations_collection = db.locations
emergency_alerts_collection = db.emergency_alerts
user_profiles_collection = db.user_profiles
environmental_metrics_collection = db.environmental_metrics
community_filters_collection = db.community_filters
feedback_collection = db.feedback
notifications_collection = db.notifications

def create_indexes():
    """Create database indexes for optimal performance"""
    print("Creating database indexes...")
    
    # Rides collection indexes - CRITICAL for geospatial queries
    rides_collection.create_index("driver_id")
    rides_collection.create_index("passenger_id")
    rides_collection.create_index("status")
    rides_collection.create_index("created_at")
    rides_collection.create_index([("pickup_location", "2dsphere")])
    rides_collection.create_index([("dropoff_location", "2dsphere")])
    rides_collection.create_index("pickup_time")
    rides_collection.create_index("dropoff_time")
    
    # Locations collection indexes
    locations_collection.create_index("user_id")
    locations_collection.create_index([("coordinates", "2dsphere")])
    locations_collection.create_index("timestamp")
    locations_collection.create_index("ride_id")
    
    # Drivers collection indexes
    drivers_collection.create_index("driver_id")
    drivers_collection.create_index("is_online")
    drivers_collection.create_index("status")
    drivers_collection.create_index([("current_location", "2dsphere")])
    
    # Users collection indexes
    users_collection.create_index("email", unique=True)
    users_collection.create_index("is_driver")
    
    print("Database indexes created successfully")

# Create indexes when this module is imported
create_indexes()
