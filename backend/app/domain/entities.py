"""
Domain Entities.
Сущности с идентичностью и жизненным циклом.

Entity отличается от Value Object наличием уникального ID.
Две сущности с одинаковыми данными, но разными ID — разные сущности.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, List
from enum import Enum


class BookingStatus(str, Enum):
    """Статусы бронирования."""
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class FlightStatus(str, Enum):
    """Статусы рейса."""
    SCHEDULED = "scheduled"
    BOARDING = "boarding"
    DEPARTED = "departed"
    ARRIVED = "arrived"
    CANCELLED = "cancelled"
    DELAYED = "delayed"


class UserRole(str, Enum):
    """Роли пользователей."""
    PASSENGER = "passenger"
    STAFF = "staff"
    ADMIN = "admin"


@dataclass
class UserEntity:
    """
    Domain Entity: Пользователь.
    
    Содержит бизнес-правила, связанные с пользователем.
    Не зависит от ORM или HTTP.
    """
    id: Optional[int]
    email: str
    hashed_password: str
    first_name: str
    last_name: str
    role: UserRole
    is_active: bool = True
    created_at: Optional[datetime] = None
    
    @property
    def full_name(self) -> str:
        """Полное имя пользователя."""
        return f"{self.first_name} {self.last_name}"
    
    def can_book_flights(self) -> bool:
        """Может ли пользователь бронировать рейсы."""
        return self.is_active
    
    def can_manage_flights(self) -> bool:
        """Может ли пользователь управлять рейсами."""
        return self.role in (UserRole.STAFF, UserRole.ADMIN)
    
    def can_manage_users(self) -> bool:
        """Может ли пользователь управлять другими пользователями."""
        return self.role == UserRole.ADMIN
    
    def deactivate(self) -> None:
        """Деактивировать аккаунт."""
        self.is_active = False


@dataclass
class BookingEntity:
    """
    Domain Entity: Бронирование.
    
    Агрегат с бизнес-правилами бронирования.
    """
    id: Optional[int]
    pnr: str
    flight_id: int
    passenger_id: int
    seat_number: str
    status: BookingStatus
    total_price: float
    created_at: Optional[datetime] = None
    
    def can_cancel(self) -> bool:
        """Можно ли отменить бронирование."""
        return self.status in (BookingStatus.PENDING, BookingStatus.CONFIRMED)
    
    def cancel(self) -> None:
        """
        Отменить бронирование.
        
        Raises:
            ValueError: Если отмена невозможна
        """
        if not self.can_cancel():
            raise ValueError(f"Нельзя отменить бронирование в статусе {self.status}")
        self.status = BookingStatus.CANCELLED
    
    def confirm(self) -> None:
        """Подтвердить бронирование после оплаты."""
        if self.status != BookingStatus.PENDING:
            raise ValueError("Можно подтвердить только pending бронирование")
        self.status = BookingStatus.CONFIRMED
    
    def complete(self) -> None:
        """Завершить бронирование после полёта."""
        if self.status != BookingStatus.CONFIRMED:
            raise ValueError("Можно завершить только confirmed бронирование")
        self.status = BookingStatus.COMPLETED


@dataclass
class FlightEntity:
    """
    Domain Entity: Рейс.
    
    Содержит бизнес-правила управления рейсом.
    """
    id: Optional[int]
    flight_number: str
    origin_airport_id: int
    destination_airport_id: int
    aircraft_id: int
    scheduled_departure: datetime
    scheduled_arrival: datetime
    status: FlightStatus
    base_price: float
    gate: Optional[str] = None
    terminal: Optional[str] = None
    
    def is_bookable(self) -> bool:
        """Можно ли забронировать этот рейс."""
        return self.status == FlightStatus.SCHEDULED
    
    def can_check_in(self) -> bool:
        """Открыта ли регистрация."""
        return self.status in (FlightStatus.SCHEDULED, FlightStatus.BOARDING)
    
    def start_boarding(self) -> None:
        """Начать посадку."""
        if self.status != FlightStatus.SCHEDULED:
            raise ValueError("Посадка возможна только для scheduled рейса")
        self.status = FlightStatus.BOARDING
    
    def depart(self) -> None:
        """Отправить рейс."""
        if self.status not in (FlightStatus.SCHEDULED, FlightStatus.BOARDING):
            raise ValueError("Нельзя отправить рейс в текущем статусе")
        self.status = FlightStatus.DEPARTED
    
    def arrive(self) -> None:
        """Прибытие рейса."""
        if self.status != FlightStatus.DEPARTED:
            raise ValueError("Прибытие возможно только для departed рейса")
        self.status = FlightStatus.ARRIVED
    
    def cancel(self, reason: str = "") -> None:
        """Отменить рейс."""
        if self.status in (FlightStatus.DEPARTED, FlightStatus.ARRIVED):
            raise ValueError("Нельзя отменить уже выполненный рейс")
        self.status = FlightStatus.CANCELLED
    
    @property
    def duration_hours(self) -> float:
        """Продолжительность полёта в часах."""
        delta = self.scheduled_arrival - self.scheduled_departure
        return delta.total_seconds() / 3600
