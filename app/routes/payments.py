from fastapi import APIRouter, HTTPException, Depends
from app.schemas import Payment, PyObjectId
from app.database import payments_collection
from bson import ObjectId
from typing import List
from app.auth import User
from fastapi_users import FastAPIUsers
from app.auth import auth_backend, get_user_db
import uuid

router = APIRouter()

fastapi_users = FastAPIUsers[User, uuid.UUID](
    get_user_db,
    [auth_backend],
    User,
    None,  # No UserCreate model needed here
    None,  # No UserUpdate model needed here
    None,  # No UserRead model needed here
)

@router.post("/", response_model=Payment)
async def create_payment(payment: Payment, user: User = Depends(fastapi_users.current_user)):
    payment.user_id = user.id
    payment_dict = payment.dict(by_alias=True, exclude_unset=True)
    result = await payments_collection.insert_one(payment_dict)
    created_payment = await payments_collection.find_one({"_id": result.inserted_id})
    if created_payment is None:
        raise HTTPException(status_code=404, detail="Payment creation failed")
    return created_payment

@router.get("/{payment_id}", response_model=Payment)
async def get_payment_by_id(payment_id: str, user: User = Depends(fastapi_users.current_user)):
    if not ObjectId.is_valid(payment_id):
        raise HTTPException(status_code=400, detail="Invalid payment ID")
    
    payment = await payments_collection.find_one({"_id": ObjectId(payment_id), "user_id": user.id})
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found or not authorized")
    
    return payment

@router.put("/{payment_id}/status", response_model=Payment)
async def update_payment_status(payment_id: str, status: str, user: User = Depends(fastapi_users.current_user)):
    if not ObjectId.is_valid(payment_id):
        raise HTTPException(status_code=400, detail="Invalid payment ID")
    
    valid_statuses = ["pending", "completed", "failed"]
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
    
    result = await payments_collection.update_one(
        {"_id": ObjectId(payment_id), "user_id": user.id},
        {"$set": {"status": status}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="Failed to update payment status or not authorized")
    
    updated_payment = await payments_collection.find_one({"_id": ObjectId(payment_id)})
    return updated_payment
