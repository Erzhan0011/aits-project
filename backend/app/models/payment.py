from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Enum as SQLEnum, CheckConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.core.database import Base
from app.models.booking import PaymentMethod

class TransactionStatus(str, enum.Enum):
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"
    PENDING = "PENDING"

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    transaction_id = Column(String, index=True, nullable=False)
    booking_id = Column(Integer, ForeignKey("bookings.id"), index=True, nullable=False)
    passenger_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    amount = Column(Float, nullable=False)
    currency = Column(String, default="RUB", nullable=False)
    method = Column(SQLEnum(PaymentMethod), nullable=False)
    status = Column(SQLEnum(TransactionStatus), default=TransactionStatus.SUCCESS, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint('amount > 0', name='check_payment_amount_positive'),
    )
    
    # Relationships
    booking = relationship("Booking", back_populates="payment")
    passenger = relationship("User", back_populates="payments")

    # Convenience properties for history display
    @property
    def pnr(self):
        return self.booking.pnr if self.booking else "N/A"
    
    @property
    def flight_info(self):
        if not self.booking or not self.booking.flight:
            return "Unknown Flight"
        f = self.booking.flight
        return f"{f.flight_number}: {f.origin_airport.city} -> {f.destination_airport.city}"
