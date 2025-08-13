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
from app.config import settings
from beanie import Document

client = AsyncIOMotorClient(settings.MONGODB_URL, uuidRepresentation="standard")
db = client[settings.MONGODB_DB]

class User(BeanieBaseUser[uuid.UUID], Document):
    is_driver: bool = False
    is_verified_driver: bool = False

    class Settings:
        name = "users"

async def get_user_db():
    yield BeanieUserDatabase(User)

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
    return JWTStrategy(secret=settings.SECRET_KEY, lifetime_seconds=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60)

auth_backend = AuthenticationBackend(
    name="jwt",
    transport=bearer_transport,
    get_strategy=get_jwt_strategy,
)
