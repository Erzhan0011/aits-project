from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Enum as SQLEnum, CheckConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.core.database import Base


class FlightStatus(str, enum.Enum):
    SCHEDULED = "ПО РАСПИСАНИЮ"
    BOARDING = "ПОСАДКА"
    DEPARTED = "ВЫЛЕТЕЛ"
    ARRIVED = "ПРИБЫЛ"
    DELAYED = "ЗАДЕРЖАН"
    CANCELLED = "ОТМЕНЕН"


class Flight(Base):
    __tablename__ = "flights"

    id = Column(Integer, primary_key=True, index=True)
    flight_number = Column(String, unique=True, index=True, nullable=False)
    aircraft_id = Column(Integer, ForeignKey("aircrafts.id"), nullable=True)
    origin_airport_id = Column(Integer, ForeignKey("airports.id"), index=True, nullable=False)
    destination_airport_id = Column(Integer, ForeignKey("airports.id"), index=True, nullable=False)
    scheduled_departure = Column(DateTime, index=True, nullable=False)
    scheduled_arrival = Column(DateTime, nullable=False)
    actual_departure = Column(DateTime, nullable=True)
    actual_arrival = Column(DateTime, nullable=True)
    status = Column(SQLEnum(FlightStatus), default=FlightStatus.SCHEDULED, nullable=False)
    base_price = Column(Float, nullable=False)
    gate = Column(String, nullable=True)
    terminal = Column(String, default="A", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint('base_price >= 0', name='check_base_price_positive'),
    )

    # Relationships
    aircraft = relationship("Aircraft", back_populates="flights")
    origin_airport = relationship("Airport", foreign_keys=[origin_airport_id], back_populates="origin_flights")
    destination_airport = relationship("Airport", foreign_keys=[destination_airport_id], back_populates="destination_flights")
    bookings = relationship("Booking", back_populates="flight", cascade="all, delete-orphan")
    seat_holds = relationship("SeatHold", back_populates="flight", cascade="all, delete-orphan")
    tickets = relationship("Ticket", back_populates="flight", cascade="all, delete-orphan")
    announcements = relationship("Announcement", back_populates="flight", cascade="all, delete-orphan")

    @property
    def departure_city(self):
        try:
            return self.origin_airport.city if self.origin_airport else "Unknown"
        except Exception:
            return "Unknown"

    @property
    def arrival_city(self):
        try:
            return self.destination_airport.city if self.destination_airport else "Unknown"
        except Exception:
            return "Unknown"

    @property
    def departure_time(self):
        return self.scheduled_departure

    @property
    def arrival_time(self):
        return self.scheduled_arrival

    @property
    def total_seats(self):
        if self.aircraft:
            return self.aircraft.capacity
        return 0

    @property
    def available_seats(self):
        total = self.total_seats
        if total <= 0:
            return 0
        
        try:
            from app.models.booking import BookingStatus
            # Считаем подтверждённые и ожидающие оплаты бронирования
            # Используем генератор для эффективности и проверяем наличие атрибутов
            occupied = sum(1 for b in self.bookings if b.status in [BookingStatus.CONFIRMED, BookingStatus.CREATED])
            return max(0, total - occupied)
        except Exception:
            # Если возникла любая ошибка (например, DetachedInstanceError при ленивой загрузке),
            # возвращаем общее число мест как запасной вариант.
            return total

    @property
    def aircraft_type(self):
        return "Boeing 737"

    @property
    def aircraft_model(self):
        if self.aircraft:
            return self.aircraft.model
        return "Unknown"

    @property
    def duration_minutes(self):
        if self.scheduled_arrival and self.scheduled_departure:
            delta = self.scheduled_arrival - self.scheduled_departure
            return int(delta.total_seconds() / 60)
        return 0



