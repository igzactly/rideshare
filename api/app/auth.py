import uuid
from typing import Optional

from fastapi_users import schemas
from fastapi_users.db import BeanieBaseUser, BeanieUserDatabase
from fastapi_users.authentication import (
    AuthenticationBackend,
    BearerTransport,
    JWTStrategy,
)
from motor.motor_asyncio import AsyncIOMotorClient

DATABASE_URL = "mongodb://localhost:27017"
client = AsyncIOMotorClient(DATABASE_URL, uuidRepresentation="standard")
db = client["rideshare"]
collection = db["users"]

SECRET = "SECRET"

class User(BeanieBaseUser[uuid.UUID]):
    is_driver: bool = False
    is_verified_driver: bool = False

async def get_user_db():
    yield BeanieUserDatabase(User, collection)

class UserRead(schemas.BaseUser[uuid.UUID]):
    is_driver: bool
    is_verified_driver: bool

class UserCreate(schemas.BaseUserCreate):
    is_driver: bool = False

class UserUpdate(schemas.BaseUserUpdate):
    is_driver: bool
    is_verified_driver: bool

bearer_transport = BearerTransport(tokenUrl="auth/jwt/login")

def get_jwt_strategy() -> JWTStrategy:
    return JWTStrategy(secret=SECRET, lifetime_seconds=3600)

auth_backend = AuthenticationBackend(
    name="jwt",
    transport=bearer_transport,
    get_strategy=get_jwt_strategy,
)
