from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.server_api import ServerApi
import os

# Load from environment (or fallback to default)
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("MONGO_DB", "rideshare")

# Create the MongoDB client
client = AsyncIOMotorClient(MONGO_URI, server_api=ServerApi('1'))

# Reference to the database
db = client[DB_NAME]

# Optional: define collection references
rides_collection = db["rides"]
drivers_collection = db["drivers"]
passengers_collection = db["passengers"]
payments_collection = db["payments"]
feedback_collection = db["feedback"]
locations_collection = db["locations"]

# Create indexes
async def create_indexes():
    await rides_collection.create_index([("pickup_coords", "2dsphere")])

# In a real application, you would call this on startup.
# For example, in main.py:
# @app.on_event("startup")
# async def startup_db_client():
#     await create_indexes()
