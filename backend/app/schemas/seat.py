from pydantic import BaseModel, validator
from typing import List, Optional
from datetime import datetime, date


class Seat(BaseModel):
    """Seat schema"""
    seat_number: str
    row: int
    column: str
    seat_type: str  # "standard", "legroom", "window", "aisle"
    status: str     # "available", "occupied", "reserved"
    is_emergency_exit: bool = False
    price: Optional[float] = None
    
    class Config:
        from_attributes = True


class SeatMap(BaseModel):
    """Seat map schema"""
    flight_id: int
    seats: List[Seat]
    total_seats: int
    available_seats: int
    occupied_seats: int


class StaffSeat(Seat):
    """Detailed seat info for staff"""
    passenger_name: Optional[str] = None
    booking_id: Optional[int] = None


class StaffSeatMap(BaseModel):
    """Detailed seat map for staff"""
    flight_id: int
    seats: List[StaffSeat]
    total_seats: int
    available_seats: int
    occupied_seats: int


class BookSeatsRequest(BaseModel):
    """Request to book specific seats"""
    seat_numbers: List[str]  # Список номеров мест для бронирования
    
    @validator('seat_numbers')
    def validate_seat_numbers(cls, v):
        if not v:
            raise ValueError('At least one seat must be selected')
        if len(v) > 10:
            raise ValueError('Cannot book more than 10 seats at once')
        # Валидация формата номеров мест
        for seat in v:
            if not isinstance(seat, str) or len(seat) > 10:
                raise ValueError(f'Invalid seat number format: {seat}')
        return v


class BookSeatsResponse(BaseModel):
    """Response after booking seats"""
    success: bool
    message: str
    booking_id: int
    booked_seats: List[str]


class PassengerInfo(BaseModel):
    """Information about a passenger for a specific seat."""
    seat_number: str
    first_name: str
    last_name: str
    passport_number: Optional[str] = None
    date_of_birth: Optional[date] = None


class BookWithPassengersRequest(BaseModel):
    """Request to book seats with passenger information."""
    passengers: List[PassengerInfo]
    payment_method: str  # "CARD", "APPLE_PAY", "GOOGLE_PAY"
    # Optional payment details
    card_number: Optional[str] = None
    card_holder: Optional[str] = None
    card_expiry: Optional[str] = None
    card_cvv: Optional[str] = None
    payment_data: Optional[str] = None  # For other methods like Apple/Google Pay ID
    
    @validator('passengers')
    def validate_passengers(cls, v):
        if not v:
            raise ValueError('At least one passenger must be provided')
        if len(v) > 10:
            raise ValueError('Cannot book for more than 10 passengers at once')
        return v
    
    @validator('payment_method')
    def validate_payment_method(cls, v):
        allowed = ['CARD', 'APPLE_PAY', 'GOOGLE_PAY']
        if v not in allowed:
            raise ValueError(f'Payment method must be one of: {", ".join(allowed)}')
        return v


class SeatHoldRequest(BaseModel):
    """Request to hold specific seats for 10 minutes"""
    seat_numbers: List[str]


class SeatHoldResponse(BaseModel):
    """Response after holding seats"""
    success: bool
    message: str
    expires_at: datetime
    seat_numbers: List[str]
