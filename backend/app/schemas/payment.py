from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
from app.models.booking import PaymentMethod
from app.models.payment import TransactionStatus

class PaymentBase(BaseModel):
    amount: float
    currency: str = "RUB"
    method: PaymentMethod
    status: TransactionStatus

class PaymentCreate(PaymentBase):
    booking_id: int
    transaction_id: str

class PaymentItem(BaseModel):
    """Individual item in a transaction (e.g. one seat)"""
    pnr: str
    booking_id: int
    amount: float
    seat_number: str

    class Config:
        from_attributes = True

class PaymentTransaction(BaseModel):
    """Aggregated Transaction"""
    transaction_id: str
    amount: float
    currency: str
    method: PaymentMethod
    status: TransactionStatus
    created_at: datetime
    flight_info: str
    items: List[PaymentItem]

    class Config:
        from_attributes = True

class StaffPayment(BaseModel):
    id: int
    transaction_id: str
    booking_id: int
    passenger_id: int
    passenger_name: Optional[str]
    amount: float
    currency: str
    method: PaymentMethod
    status: TransactionStatus
    created_at: datetime
    pnr: str
    flight_info: str

    class Config:
        from_attributes = True
