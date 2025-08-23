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


