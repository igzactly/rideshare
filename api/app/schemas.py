from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from bson import ObjectId
from datetime import datetime
from enum import Enum
from pydantic_core import core_schema


# Support for ObjectId in Pydantic models
class PyObjectId(ObjectId):
    @classmethod
    def __get_pydantic_core_schema__(
        cls, source_type: Any, handler
    ) -> core_schema.CoreSchema:
        return core_schema.json_or_python_schema(
            python_schema=core_schema.union_schema(
                [
                    core_schema.is_instance_schema(ObjectId),
                    core_schema.chain_schema(
                        [
                            core_schema.str_schema(),
                            core_schema.no_info_plain_validator_function(
                                cls.validate
                            ),
                        ]
                    ),
                ]
            ),
            json_schema=core_schema.str_schema(),
            serialization=core_schema.plain_serializer_function_ser_schema(
                lambda x: str(x)
            ),
        )

    @classmethod
    def validate(cls, v):
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid ObjectId")
        return ObjectId(v)


# Enums for status fields
class RideStatus(str, Enum):
    ACTIVE = "active"
    PENDING_DRIVER_ACCEPTANCE = "pending_driver_acceptance"
    ACCEPTED = "accepted"
    PICKED_UP = "picked_up"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class PaymentStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"

class EmergencyType(str, Enum):
    PANIC_BUTTON = "panic_button"
    ACCIDENT = "accident"
    MEDICAL = "medical"
    SAFETY_CONCERN = "safety_concern"


### Enhanced User Schema ###
class UserProfile(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    user_id: PyObjectId
    first_name: str
    last_name: str
    phone: Optional[str]
    emergency_contact: Optional[str]
    profile_picture: Optional[str]
    rating: float = 0.0
    total_rides: int = 0
    is_verified: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime]

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


### Enhanced Ride Schema ###
class Ride(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    driver_id: PyObjectId
    pickup: str
    dropoff: str
    pickup_coords: Optional[List[float]]  # [latitude, longitude]
    dropoff_coords: Optional[List[float]]
    passenger_id: Optional[PyObjectId]
    detour_km: Optional[float]
    detour_time_seconds: Optional[int]
    original_distance_km: Optional[float]
    total_distance_km: Optional[float]
    co2_saved: Optional[float]  # in kg
    status: RideStatus = RideStatus.ACTIVE
    pickup_time: Optional[datetime]
    dropoff_time: Optional[datetime]
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime]

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


### Ride Request Schema ###
class RideRequest(BaseModel):
    pickup_coords: List[float]
    dropoff_coords: List[float]
    radius_km: float = 5.0
    max_detour_minutes: int = 10
    community_filter: bool = False  # For community-based matching
    preferred_driver_id: Optional[PyObjectId] = None


### Driver Route Schema ###
class DriverRoute(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    driver_id: PyObjectId
    start_location: List[float]
    end_location: List[float]
    departure_time: datetime
    available_seats: int = 1
    status: str = "active"
    current_location: Optional[List[float]] = None
    is_online: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime]

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


### Real-time Location Tracking ###
class LocationUpdate(BaseModel):
    user_id: PyObjectId
    ride_id: Optional[PyObjectId]
    coordinates: List[float]  # [latitude, longitude]
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    accuracy: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None


### Safety and Emergency ###
class EmergencyAlert(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    user_id: PyObjectId
    ride_id: Optional[PyObjectId]
    emergency_type: EmergencyType
    location: List[float]
    description: Optional[str]
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    status: str = "active"  # active, resolved, false_alarm
    resolved_by: Optional[PyObjectId] = None
    resolved_at: Optional[datetime] = None

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


### Payment Schema ###
class Payment(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    ride_id: PyObjectId
    user_id: PyObjectId
    amount: float
    currency: str = "GBP"
    status: PaymentStatus = PaymentStatus.PENDING
    payment_method: Optional[str]
    transaction_id: Optional[str]
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime]

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


### Feedback and Rating ###
class Feedback(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    ride_id: PyObjectId
    from_user_id: PyObjectId
    to_user_id: PyObjectId
    rating: int = Field(ge=1, le=5)
    comment: Optional[str]
    category: str = "general"  # safety, cleanliness, punctuality, etc.
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


### Route Optimization ###
class RouteOptimizationRequest(BaseModel):
    waypoints: List[List[float]]  # List of [lat, lng] coordinates
    optimize: str = "time"  # time, distance, eco
    vehicle_type: str = "car"
    avoid_tolls: bool = False
    avoid_highways: bool = False


### Environmental Impact ###
class EnvironmentalMetrics(BaseModel):
    ride_id: PyObjectId
    distance_km: float
    co2_saved_kg: float
    fuel_saved_liters: float
    trees_equivalent: float  # Number of trees needed to absorb CO2
    timestamp: datetime = Field(default_factory=datetime.utcnow)


### Analytics and Reporting ###
class RideAnalytics(BaseModel):
    total_rides: int
    total_distance_km: float
    total_co2_saved_kg: float
    average_rating: float
    total_users: int
    active_drivers: int
    period_start: datetime
    period_end: datetime


### Community Features ###
class CommunityFilter(BaseModel):
    user_id: PyObjectId
    preferred_communities: List[str]  # e.g., ["university", "workplace", "neighborhood"]
    max_distance_km: float = 10.0
    trust_score_threshold: float = 3.0
    created_at: datetime = Field(default_factory=datetime.utcnow)
