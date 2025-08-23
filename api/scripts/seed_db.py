
import os
import sys
from pymongo import MongoClient
from dotenv import load_dotenv

# Add the parent directory to the path to allow imports from the `api` module
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from generate_sample_data import generate_users, generate_rides, generate_driver_locations

load_dotenv()

def seed_database():
    mongodb_url = os.getenv("MONGODB_URL")
    mongodb_db = os.getenv("MONGODB_DB")

    if not mongodb_url or not mongodb_db:
        print("MONGODB_URL and MONGODB_DB environment variables must be set.")
        return

    client = MongoClient(mongodb_url)
    db = client[mongodb_db]

    # Drop existing collections
    db.users.drop()
    db.rides.drop()
    db.driver_locations.drop()

    print("Cleared existing data.")

    # Generate and insert users
    users_data = generate_users(20)
    result = db.users.insert_many(users_data)
    user_ids = result.inserted_ids
    for i, user_id in enumerate(user_ids):
        users_data[i]["_id"] = user_id

    print(f"Inserted {len(user_ids)} users.")

    # Generate and insert rides
    rides_data = generate_rides(users_data, 50)
    db.rides.insert_many(rides_data)
    print(f"Inserted {len(rides_data)} rides.")

    # Generate and insert driver locations
    driver_locations_data = generate_driver_locations(users_data)
    if driver_locations_data:
        db.driver_locations.insert_many(driver_locations_data)
        print(f"Inserted {len(driver_locations_data)} driver locations.")

        # Create 2dsphere index for geospatial queries
        db.driver_locations.create_index([("location", "2dsphere")])
        print("Created 2dsphere index on driver_locations.")

    client.close()
    print("Database seeding complete.")

if __name__ == "__main__":
    seed_database()
