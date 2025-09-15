from fastapi import FastAPI, Depends, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from beanie import init_beanie
from app import database
from app.routes import rides, driver, payments, location, safety, environmental, feedback, scheduled_rides, notifications, pricing, preferences, analytics
from app.auth import auth_backend, User, UserCreate, UserRead, UserUpdate, get_user_db
from fastapi_users import FastAPIUsers
import uuid

app = FastAPI(
    title="RideShare API",
    description="A comprehensive ride-sharing platform API with real-time location tracking, safety features, environmental impact calculation, community matching, analytics, notifications, and route optimization",
    version="1.0.0"
)

# CORS for Flutter app and local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    UserCreate,
    UserUpdate,
    UserRead,
)

@app.on_event("startup")
async def startup_db_client():
    # Initialize collections and indexes
    await database.create_indexes()
    # Initialize Beanie ODM for FastAPI-Users models
    from app.auth import User  # local import to avoid circular
    await init_beanie(database.database, document_models=[User])

# Include all API routers
app.include_router(rides.router, prefix="/rides", tags=["Rides"])
app.include_router(driver.router, prefix="/driver", tags=["Driver"])
app.include_router(payments.router, prefix="/payments", tags=["Payments"])
app.include_router(location.router, prefix="/location", tags=["Location"])
app.include_router(safety.router, prefix="/safety", tags=["Safety"])
app.include_router(environmental.router, prefix="/environmental", tags=["Environmental"])
app.include_router(feedback.router, prefix="/feedback", tags=["Feedback"])
app.include_router(scheduled_rides.router, prefix="/scheduled-rides", tags=["Scheduled Rides"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
app.include_router(pricing.router, prefix="/pricing", tags=["Pricing & Earnings"])
app.include_router(preferences.router, prefix="/preferences", tags=["Ride Preferences"])
app.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])

# Authentication routes
app.include_router(
    fastapi_users.get_auth_router(auth_backend),
    prefix="/auth/jwt",
    tags=["auth"],
)
app.include_router(
    fastapi_users.get_register_router(UserRead, UserCreate),
    prefix="/auth",
    tags=["auth"],
)
app.include_router(
    fastapi_users.get_users_router(UserRead, UserUpdate),
    prefix="/users",
    tags=["users"],
)

# Additional auth endpoints for Flutter compatibility
@app.post("/auth/login")
async def login_for_flutter(request: dict):
    """Login endpoint compatible with Flutter app"""
    # Redirect to the proper JWT auth endpoint
    from fastapi_users import FastAPIUsers
    from app.auth import auth_backend, User, UserCreate, UserRead, UserUpdate, get_user_db
    import uuid
    
    fastapi_users = FastAPIUsers[User, uuid.UUID](
        get_user_db,
        [auth_backend],
        User,
        UserCreate,
        UserUpdate,
        UserRead,
    )
    
    # This should be handled by the existing auth router
    return {"message": "Use /auth/jwt/login endpoint"}

@app.post("/auth/register")
async def register_for_flutter(request: dict):
    """Register endpoint compatible with Flutter app"""
    # Redirect to the proper register endpoint
    return {"message": "Use /auth/register endpoint"}

@app.get("/auth/validate")
async def validate_token_for_flutter(user: User = Depends(fastapi_users.current_user)):
    """Token validation endpoint for Flutter app"""
    return {
        "valid": True,
        "user_id": str(user.id),
        "email": user.email,
        "is_driver": user.is_driver,
        "is_verified_driver": user.is_verified_driver
    }

@app.websocket("/ws/{ride_id}")
async def websocket_endpoint(websocket: WebSocket, ride_id: str):
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        # For now, just echo the data back
        await websocket.send_text(f"Message text was: {data}")

@app.get("/")
async def root():
    return {
        "message": "Welcome to RideShare API",
        "version": "1.0.0",
        "features": [
            "Real-time ride management",
            "Location tracking and WebSocket support",
            "Safety features and emergency alerts",
            "Environmental impact calculation",
            "User feedback and rating system",
            "Payment processing",
            "Driver route optimization",
            "Community-based ride matching",
            "Comprehensive analytics and reporting",
            "Real-time notifications",
            "Advanced route optimization algorithms"
        ]
    }
