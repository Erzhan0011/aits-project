from datetime import datetime
import enum
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum, Date
from sqlalchemy.orm import relationship
from app.core.database import Base

class UserRole(str, enum.Enum):
    """User roles in the system"""
    PASSENGER = "PASSENGER"
    STAFF = "STAFF"
    ADMIN = "ADMIN"

class User(Base):
    """
    User model for database storage.
    Represents a passenger, staff member, or admin.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    
    # Profile fields
    first_name = Column(String, nullable=True)
    last_name = Column(String, nullable=True)
    full_name = Column(String, nullable=True) # Direct field for convenience
    phone = Column(String, nullable=True)
    
    # Passport/Travel Info
    passport_number = Column(String, index=True, nullable=True)
    nationality = Column(String, nullable=True)
    date_of_birth = Column(Date, nullable=True) # Changed from String to Date
    
    # System fields
    role = Column(Enum(UserRole), default=UserRole.PASSENGER, nullable=False)
    is_active = Column(Boolean, default=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    bookings = relationship("Booking", back_populates="passenger", cascade="all, delete-orphan")
    tickets = relationship("Ticket", back_populates="passenger", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="passenger", cascade="all, delete-orphan")

    # Note: SQLAlchemy handles __init__ automatically for columns
    # If we need dynamic full_name calculation, we can add a property, 
    # but initially we'll store what is passed.
    
    @property
    def is_passenger(self) -> bool:
        return self.role == UserRole.PASSENGER
        
    @property
    def is_staff(self) -> bool:
        return self.role == UserRole.STAFF
        
    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN
