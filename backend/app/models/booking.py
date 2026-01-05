from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Enum as SQLEnum, Boolean, UniqueConstraint, CheckConstraint, Date
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.core.database import Base


class PaymentMethod(str, enum.Enum):
    """Payment methods supported by the system"""
    CARD = "CARD"
    APPLE_PAY = "APPLE_PAY"
    GOOGLE_PAY = "GOOGLE_PAY"


class BookingStatus(str, enum.Enum):
    """Status of a flight booking"""
    CREATED = "CREATED"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    pnr = Column(String, index=True, nullable=True) # Generated automatically. Shared by all seats in a booking.
    passenger_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), index=True, nullable=False)
    seat_number = Column(String, nullable=False)
    price = Column(Float, nullable=False)
    payment_method = Column(SQLEnum(PaymentMethod), nullable=True)
    status = Column(SQLEnum(BookingStatus), default=BookingStatus.CREATED, nullable=False)
    
    # Traveler details (can be different from the account holder)
    first_name = Column(String, nullable=True)
    last_name = Column(String, nullable=True)
    passport_number = Column(String, nullable=True)
    date_of_birth = Column(Date, nullable=True) # Changed from DateTime to Date for consistency
    
    created_at = Column(DateTime, default=datetime.utcnow)
    confirmed_at = Column(DateTime, nullable=True)

    # Relationships
    passenger = relationship("User", back_populates="bookings")
    flight = relationship("Flight", back_populates="bookings")
    ticket = relationship("Ticket", back_populates="booking", uselist=False, cascade="all, delete-orphan")
    payment = relationship("Payment", back_populates="booking", uselist=False)

    __table_args__ = (
        UniqueConstraint('flight_id', 'seat_number', name='_flight_seat_uc'),
        CheckConstraint('price >= 0', name='check_booking_price_positive'),
    )


class SeatHold(Base):
    __tablename__ = "seat_holds"

    id = Column(Integer, primary_key=True, index=True)
    flight_id = Column(Integer, ForeignKey("flights.id"), index=True, nullable=False)
    seat_number = Column(String, nullable=False)
    passenger_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=True)
    expires_at = Column(DateTime, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    flight = relationship("Flight", back_populates="seat_holds")

    __table_args__ = (
        UniqueConstraint('flight_id', 'seat_number', name='_hold_flight_seat_uc'),
    )


class Ticket(Base):
    __tablename__ = "tickets"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False, unique=True)
    passenger_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=False)
    seat_number = Column(String, nullable=False)
    qr_code = Column(String, nullable=True)
    checked_in = Column(Boolean, default=False)
    checked_in_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    booking = relationship("Booking", back_populates="ticket")
    passenger = relationship("User", back_populates="tickets")
    flight = relationship("Flight", back_populates="tickets")



