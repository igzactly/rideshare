from fastapi import FastAPI, Depends
from app import database
from app.routes import rides
from app.auth import auth_backend, User, UserCreate, UserRead, UserUpdate, get_user_db
from fastapi_users import FastAPIUsers
import uuid

app = FastAPI()

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
    await database.create_indexes()

app.include_router(rides.router, prefix="/rides", tags=["Rides"])
app.include_router(driver.router, prefix="/driver", tags=["Driver"])
app.include_router(payments.router, prefix="/payments", tags=["Payments"])
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

@app.websocket("/ws/{ride_id}")
async def websocket_endpoint(websocket: WebSocket, ride_id: str):
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        # For now, just echo the data back
        await websocket.send_text(f"Message text was: {data}")
