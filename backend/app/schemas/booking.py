from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
from app.models.booking import PaymentMethod, BookingStatus
from app.schemas.flight import Flight
from app.schemas.user import UserProfile


class BookingBase(BaseModel):
    flight_id: int
    seat_number: str


class BookingCreate(BookingBase):
    payment_method: PaymentMethod


class Booking(BookingBase):
    id: int
    pnr: Optional[str] = None
    passenger_id: int
    price: float
    payment_method: Optional[PaymentMethod] = None
    status: BookingStatus
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    passport_number: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    created_at: datetime
    confirmed_at: Optional[datetime] = None
    flight: Flight
    
    # Extra fields for staff view
    checked_in: bool = False
    qr_code: Optional[str] = None

    class Config:
        from_attributes = True

    @classmethod
    def model_validate(cls, obj, **kwargs):
        # Handle SQLAlchemy model
        instance = super().model_validate(obj, **kwargs)
        if hasattr(obj, 'ticket') and obj.ticket:
            instance.checked_in = obj.ticket.checked_in
            instance.qr_code = obj.ticket.qr_code
        return instance


class SeatConflict(BaseModel):
    seat_number: str
    bookings: List[Booking]


class SeatHoldRequest(BaseModel):
    flight_id: int
    seat_number: str


class SeatHoldResponse(BaseModel):
    id: int
    flight_id: int
    seat_number: str
    expires_at: datetime

    class Config:
        from_attributes = True


class Ticket(BaseModel):
    id: int
    booking_id: int
    passenger_id: int
    flight_id: int
    seat_number: str
    qr_code: Optional[str] = None
    checked_in: bool
    checked_in_at: Optional[datetime] = None
    flight: Flight
    created_at: datetime

    class Config:
        from_attributes = True


class CheckInRequest(BaseModel):
    ticket_id: int


class CheckInResponse(BaseModel):
    ticket: Ticket
    boarding_pass: str  # QR code string



