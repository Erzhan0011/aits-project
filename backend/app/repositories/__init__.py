"""
Repository модуль.
Содержит все репозитории для работы с данными.
"""
from app.repositories.base import BaseRepository
from app.repositories.user_repository import UserRepository
from app.repositories.flight_repository import FlightRepository
from app.repositories.booking_repository import BookingRepository

__all__ = [
    "BaseRepository",
    "UserRepository", 
    "FlightRepository",
    "BookingRepository",
]
