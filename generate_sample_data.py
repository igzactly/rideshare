import asyncio
from datetime import datetime, timedelta
import random
from faker import Faker
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.server_api import ServerApi
from bson import ObjectId

# Configuration
MONGO_URI = "mongodb://localhost:27017"
DB_NAME = "rideshare"

async def generate_sample_data():
    client = AsyncIOMotorClient(MONGO_URI, server_api=ServerApi('1'))
    db = client[DB_NAME]

    # Clear existing data (optional, for fresh generation)
    await db["users"].delete_many({})
    await db["drivers"].delete_many({})
    await db["rides"].delete_many({})
    await db["payments"].delete_many({})
    print("Cleared existing data.")

    fake = Faker()

    # Generate Users
    users = []
    for _ in range(20): # 20 regular users
        users.append({
            "_id": ObjectId(),
            "email": fake.email(),
            "hashed_password": fake.sha256(), # In a real app, use proper hashing
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "is_driver": False,
            "is_verified_driver": False,
        })
    
    drivers = []
    for _ in range(5): # 5 driver users
        drivers.append({
            "_id": ObjectId(),
            "email": fake.email(),
            "hashed_password": fake.sha256(),
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "is_driver": True,
            "is_verified_driver": random.choice([True, False]), # Some drivers might not be verified yet
        })
    
    all_users = users + drivers
    await db["users"].insert_many(all_users)
    print(f"Generated {len(all_users)} users.")

    # Generate Driver Routes (for verified drivers)
    driver_routes = []
    for driver_user in drivers:
        if driver_user["is_verified_driver"]:
            for _ in range(random.randint(1, 3)): # 1 to 3 routes per driver
                driver_routes.append({
                    "_id": ObjectId(),
                    "driver_id": driver_user["_id"],
                    "start_location": [fake.latitude(), fake.longitude()],
                    "end_location": [fake.latitude(), fake.longitude()],
                    "departure_time": fake.date_time_between(start_date="now", end_date="+7d"),
                    "available_seats": random.randint(1, 4),
                    "status": "active",
                    "created_at": fake.date_time_between(start_date="-30d", end_date="now"),
                })
    if driver_routes:
        await db["drivers"].insert_many(driver_routes)
        print(f"Generated {len(driver_routes)} driver routes.")
    else:
        print("No driver routes generated (no verified drivers).")

    # Generate Rides
    rides = []
    for _ in range(30): # 30 sample rides
        passenger = random.choice(users)
        driver = random.choice(drivers) if random.random() > 0.3 else None # Some rides might not have a driver yet
        
        status = "active"
        if driver:
            status = random.choice(["accepted", "completed", "cancelled"])

        rides.append({
            "_id": ObjectId(),
            "driver_id": driver["_id"] if driver else None,
            "pickup": fake.address(),
            "dropoff": fake.address(),
            "pickup_coords": [float(fake.latitude()), float(fake.longitude())],
            "dropoff_coords": [float(fake.latitude()), float(fake.longitude())],
            "passenger_id": passenger["_id"],
            "detour_km": round(random.uniform(0.5, 10.0), 2) if driver else None,
            "status": status,
            "created_at": fake.date_time_between(start_date="-60d", end_date="now"),
            "updated_at": fake.date_time_between(start_date="-59d", end_date="now") if status != "active" else None,
        })
    await db["rides"].insert_many(rides)
    print(f"Generated {len(rides)} rides.")

    # Generate Payments (for completed rides)
    payments = []
    for ride in rides:
        if ride["status"] == "completed":
            payments.append({
                "_id": ObjectId(),
                "ride_id": ride["_id"],
                "user_id": ride["passenger_id"],
                "amount": round(random.uniform(5.0, 50.0), 2),
                "currency": "USD",
                "status": "completed",
                "created_at": ride["updated_at"] + timedelta(minutes=random.randint(5, 30)),
            })
    if payments:
        await db["payments"].insert_many(payments)
        print(f"Generated {len(payments)} payments.")
    else:
        print("No payments generated (no completed rides).")

    client.close()

if __name__ == "__main__":
    asyncio.run(generate_sample_data())
