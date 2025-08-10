from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from bson import ObjectId
from datetime import datetime


# Support for ObjectId in Pydantic models
class PyObjectId(ObjectId):
    @classmethod
    def __get_validators__(cls):
        yield cls.validate

    @classmethod
    def validate(cls, v):
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid ObjectId")
        return ObjectId(v)

    @classmethod
    def __modify_schema__(cls, field_schema):
        field_schema.update(type="string")


### Ride Schema (MVP version — one driver, one passenger) ###
class Ride(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    driver_id: PyObjectId
    pickup: str
    dropoff: str
    pickup_coords: Optional[List[float]]  # [latitude, longitude]
    dropoff_coords: Optional[List[float]]
    passenger_id: Optional[PyObjectId]  # one passenger for MVP
    detour_km: Optional[float]
    status: str = "active"  # active, completed, cancelled
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime]

    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

class RideRequest(BaseModel):
    pickup_coords: List[float]
    dropoff_coords: List[float]
    radius_km: float = 5.0  # Search radius in kilometers

class DriverRoute(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    driver_id: PyObjectId
    start_location: List[float]
    end_location: List[float]
    departure_time: datetime
    available_seats: int = 1
    status: str = "active"  # active, inactive
    created_at: datetime = Field(default_factory=datetime.utcnow)

class Payment(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    ride_id: PyObjectId
    user_id: PyObjectId
    amount: float
    currency: str
    status: str = "pending"  # pending, completed, failed
    created_at: datetime = Field(default_factory=datetime.utcnow)
