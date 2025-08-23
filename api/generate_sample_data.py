import random
from faker import Faker
from passlib.context import CryptContext

fake = Faker()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

def generate_users(num_users):
    users = []
    for _ in range(num_users):
        password = fake.password()
        user = {
            "email": fake.email(),
            "full_name": fake.name(),
            "hashed_password": get_password_hash(password),
            "is_active": True,
            "is_superuser": False,
            "is_verified": True,
            "trust_score": round(random.uniform(3.0, 5.0), 2),
            "role": random.choice(["passenger", "driver"])
        }
        users.append(user)
    return users

def generate_rides(users, num_rides):
    rides = []
    passengers = [u for u in users if u['role'] == 'passenger']
    for _ in range(num_rides):
        ride = {
            "passenger_id": random.choice(passengers)['_id'],
            "start_location": {
                "type": "Point",
                "coordinates": [float(fake.longitude()), float(fake.latitude())]
            },
            "end_location": {
                "type": "Point",
                "coordinates": [float(fake.longitude()), float(fake.latitude())]
            },
            "status": random.choice(["pending", "accepted", "in_progress", "completed", "cancelled"]),
            "created_at": fake.date_time_this_year(),
        }
        rides.append(ride)
    return rides

def generate_driver_locations(users):
    driver_locations = []
    drivers = [u for u in users if u['role'] == 'driver']
    for driver in drivers:
        location = {
            "driver_id": driver['_id'],
            "location": {
                "type": "Point",
                "coordinates": [float(fake.longitude()), float(fake.latitude())]
            },
            "updated_at": fake.date_time_this_month()
        }
        driver_locations.append(location)
    return driver_locations