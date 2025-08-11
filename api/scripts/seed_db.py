import asyncio
import os
from datetime import datetime, timedelta
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId
import uuid
import random

MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "rideshare")

async def seed():
    client = AsyncIOMotorClient(MONGODB_URL)
    db = client[MONGODB_DB]

    users = db["users"]
    user_profiles = db["user_profiles"]
    drivers = db["drivers"]
    rides = db["rides"]
    payments = db["payments"]
    feedback = db["feedback"]
    locations = db["locations"]

    # Clean existing
    for col in [users, user_profiles, drivers, rides, payments, feedback, locations]:
        await col.delete_many({})

    # Create users
    driver_id = ObjectId()
    passenger_id = ObjectId()

    await users.insert_many([
        {
            "_id": driver_id,
            "email": "driver@example.com",
            "hashed_password": "$2b$12$CwTycUXWue0Thq9StjUM0uJ8YH2u7o1uT5C2Xj8T0Weu3bXKj2p9C",  # bcrypt for 'password'
            "is_active": True,
            "is_superuser": False,
            "is_driver": True,
            "is_verified_driver": True,
        },
        {
            "_id": passenger_id,
            "email": "passenger@example.com",
            "hashed_password": "$2b$12$CwTycUXWue0Thq9StjUM0uJ8YH2u7o1uT5C2Xj8T0Weu3bXKj2p9C",
            "is_active": True,
            "is_superuser": False,
            "is_driver": False,
            "is_verified_driver": False,
        },
    ])

    # Profiles
    await user_profiles.insert_many([
        {
            "user_id": driver_id,
            "first_name": "Derek",
            "last_name": "Driver",
            "phone": "+441234567890",
            "rating": 4.8,
            "total_rides": 123,
            "is_verified": True,
            "created_at": datetime.utcnow(),
        },
        {
            "user_id": passenger_id,
            "first_name": "Paula",
            "last_name": "Passenger",
            "phone": "+441098765432",
            "rating": 4.6,
            "total_rides": 45,
            "is_verified": True,
            "created_at": datetime.utcnow(),
        },
    ])

    # Driver route/state
    await drivers.insert_one({
        "user_id": driver_id,
        "start_location": [51.5074, -0.1278],  # London
        "end_location": [51.509, -0.08],
        "departure_time": datetime.utcnow() + timedelta(hours=1),
        "available_seats": 3,
        "status": "active",
        "is_online": True,
        "rating": 4.8,
        "vehicle_type": "car",
        "created_at": datetime.utcnow(),
    })

    # Ride
    ride_id = ObjectId()
    await rides.insert_one({
        "_id": ride_id,
        "driver_id": driver_id,
        "passenger_id": passenger_id,
        "pickup": "Waterloo Station",
        "dropoff": "Canary Wharf",
        "pickup_coords": [51.5033, -0.1147],
        "dropoff_coords": [51.5054, -0.0235],
        "status": "active",
        "pickup_time": datetime.utcnow() + timedelta(minutes=30),
        "created_at": datetime.utcnow(),
        "fare": 12.5,
        "total_distance_km": 8.2,
        "duration_minutes": 25,
    })

    # Payment
    await payments.insert_one({
        "ride_id": ride_id,
        "user_id": passenger_id,
        "amount": 12.5,
        "currency": "GBP",
        "status": "pending",
        "created_at": datetime.utcnow(),
    })

    # Feedback
    await feedback.insert_one({
        "ride_id": ride_id,
        "from_user_id": passenger_id,
        "to_user_id": driver_id,
        "rating": 5,
        "comment": "Great ride, very punctual!",
        "category": "punctuality",
        "created_at": datetime.utcnow(),
    })

    # Location breadcrumbs
    now = datetime.utcnow()
    coords = [
        [51.5033, -0.1147],
        [51.5040, -0.1050],
        [51.5050, -0.0900],
        [51.5054, -0.0235],
    ]
    docs = []
    for i, c in enumerate(coords):
        docs.append({
            "user_id": driver_id,
            "ride_id": ride_id,
            "coordinates": c,
            "timestamp": now + timedelta(minutes=i*5),
            "accuracy": 5.0,
        })
    await locations.insert_many(docs)

    print("Seed completed. Users: driver@example.com / passenger@example.com (password: password)")

if __name__ == "__main__":
    asyncio.run(seed())