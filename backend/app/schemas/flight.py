from pydantic import BaseModel, validator, field_validator
from datetime import datetime, date
from typing import Optional, List
from .airport_base import Airport
from .announcement import Announcement
from app.models.flight import FlightStatus

class Flight(BaseModel):
    """Flight schema for API responses"""
    id: int
    flight_number: str
    departure_city: str
    arrival_city: str
    departure_time: datetime
    arrival_time: datetime
    scheduled_departure: Optional[datetime] = None
    scheduled_arrival: Optional[datetime] = None
    status: FlightStatus
    available_seats: int
    total_seats: int
    base_price: float
    aircraft_id: Optional[int] = None
    origin_airport_id: int
    destination_airport_id: int
    origin_airport: Optional[Airport] = None
    destination_airport: Optional[Airport] = None
    gate: Optional[str] = None
    terminal: str = "A"
    
    @validator('departure_time', 'arrival_time', 'scheduled_departure', 'scheduled_arrival', pre=True)
    def handle_datetime(cls, v):
        if v is None:
            return v
        if isinstance(v, str):
            # Parse but don't force UTC
            return datetime.fromisoformat(v.replace('Z', ''))
        return v
    
    class Config:
        from_attributes = True


class FlightDetail(BaseModel):
    """Detailed flight information"""
    id: int
    flight_number: str
    departure_city: str
    arrival_city: str
    departure_time: datetime
    arrival_time: datetime
    status: FlightStatus
    available_seats: int
    total_seats: int
    base_price: float
    aircraft_type: str
    aircraft_model: str
    aircraft_id: Optional[int] = None
    origin_airport_id: int
    destination_airport_id: int
    gate: Optional[str] = None
    terminal: str
    duration_minutes: int
    
    class Config:
        from_attributes = True


class FlightSearch(BaseModel):
    """Schema for flight search request"""
    origin_code: str  # departure airport code
    destination_code: str  # arrival airport code
    departure_date: datetime  # departure date


class FlightSearchResponse(BaseModel):
    """Response with list of flights"""
    flights: list[Flight]


class BookTicketRequest(BaseModel):
    """Request to book a ticket"""
    passenger_count: int  # количество пассажиров
    
    @validator('passenger_count')
    def validate_passenger_count(cls, v):
        if v <= 0:
            raise ValueError('Passenger count must be greater than 0')
        if v > 10:
            raise ValueError('Cannot book more than 10 seats at once')
        return v


class BookTicketResponse(BaseModel):
    """Response after booking a ticket"""
    success: bool
    message: str
    booking_id: Optional[int] = None


class Trip(BaseModel):
    """Trip information for user profile aligned with Booking model"""
    id: int  # maps to booking_id
    passenger_id: int
    flight_id: int
    flight: Flight
    seat_number: str  # Representative seat
    price: float
    status: str  # Confirming status
    created_at: datetime
    pnr: str
    gate: Optional[str] = None
    terminal: str = "A"
    payment_method: Optional[str] = 'CARD'
    expires_at: Optional[datetime] = None
    checked_in: bool = False
    qr_code: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    passport_number: Optional[str] = None
    date_of_birth: Optional[date] = None
    confirmed_at: Optional[datetime] = None
    checked_in_at: Optional[datetime] = None
    transaction_id: Optional[str] = None
    history: List[Announcement] = []  # Added history field
    
    class Config:
        from_attributes = True


class FlightCreate(BaseModel):
    """Schema for creating a new flight"""
    flight_number: str
    aircraft_id: int
    origin_airport_id: int
    destination_airport_id: int
    scheduled_departure: datetime
    scheduled_arrival: datetime
    base_price: float
    gate: Optional[str] = None
    terminal: str = "A"
    status: FlightStatus = FlightStatus.SCHEDULED


class FlightUpdate(BaseModel):
    """Schema for updating a flight"""
    flight_number: Optional[str] = None
    scheduled_departure: Optional[datetime] = None
    scheduled_arrival: Optional[datetime] = None
    status: Optional[FlightStatus] = None
    gate: Optional[str] = None
    terminal: Optional[str] = None
    base_price: Optional[float] = None
    aircraft_id: Optional[int] = None


class CheckInRequest(BaseModel):
    """Request for online check-in"""
    ticket_id: int


class CheckInResponse(BaseModel):
    """Response after check-in"""
    success: bool
    message: str
    boarding_pass: Optional[str] = None

