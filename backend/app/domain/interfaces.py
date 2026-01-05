"""
Domain Interfaces (Ports).
Абстракции для инверсии зависимостей.

Интерфейсы определяют контракт, который должны реализовать репозитории.
Domain Layer зависит только от этих интерфейсов, не от конкретных реализаций.
"""
from abc import ABC, abstractmethod
from typing import Optional, List

from app.domain.entities import UserEntity, BookingEntity, FlightEntity


class IUserRepository(ABC):
    """Интерфейс репозитория пользователей."""
    
    @abstractmethod
    def get_by_id(self, user_id: int) -> Optional[UserEntity]:
        """Получить пользователя по ID."""
        pass
    
    @abstractmethod
    def get_by_email(self, email: str) -> Optional[UserEntity]:
        """Получить пользователя по email."""
        pass
    
    @abstractmethod
    def save(self, user: UserEntity) -> UserEntity:
        """Сохранить пользователя (создать или обновить)."""
        pass
    
    @abstractmethod
    def delete(self, user_id: int) -> bool:
        """Удалить пользователя."""
        pass


class IBookingRepository(ABC):
    """Интерфейс репозитория бронирований."""
    
    @abstractmethod
    def get_by_id(self, booking_id: int) -> Optional[BookingEntity]:
        """Получить бронирование по ID."""
        pass
    
    @abstractmethod
    def get_by_pnr(self, pnr: str) -> List[BookingEntity]:
        """Получить бронирования по PNR."""
        pass
    
    @abstractmethod
    def get_by_user(self, user_id: int) -> List[BookingEntity]:
        """Получить бронирования пользователя."""
        pass
    
    @abstractmethod
    def get_by_flight(self, flight_id: int) -> List[BookingEntity]:
        """Получить бронирования на рейс."""
        pass
    
    @abstractmethod
    def save(self, booking: BookingEntity) -> BookingEntity:
        """Сохранить бронирование."""
        pass


class IFlightRepository(ABC):
    """Интерфейс репозитория рейсов."""
    
    @abstractmethod
    def get_by_id(self, flight_id: int) -> Optional[FlightEntity]:
        """Получить рейс по ID."""
        pass
    
    @abstractmethod
    def get_available(
        self,
        origin_id: int,
        destination_id: int,
        date: str
    ) -> List[FlightEntity]:
        """Получить доступные рейсы."""
        pass
    
    @abstractmethod
    def save(self, flight: FlightEntity) -> FlightEntity:
        """Сохранить рейс."""
        pass


class IUnitOfWork(ABC):
    """
    Интерфейс Unit of Work.
    
    Управляет транзакциями и координирует работу репозиториев.
    """
    
    @abstractmethod
    def __enter__(self) -> "IUnitOfWork":
        pass
    
    @abstractmethod
    def __exit__(self, exc_type, exc_val, exc_tb):
        pass
    
    @abstractmethod
    def commit(self) -> None:
        """Зафиксировать транзакцию."""
        pass
    
    @abstractmethod
    def rollback(self) -> None:
        """Откатить транзакцию."""
        pass
    
    @property
    @abstractmethod
    def users(self) -> IUserRepository:
        """Репозиторий пользователей."""
        pass
    
    @property
    @abstractmethod
    def bookings(self) -> IBookingRepository:
        """Репозиторий бронирований."""
        pass
    
    @property
    @abstractmethod
    def flights(self) -> IFlightRepository:
        """Репозиторий рейсов."""
        pass
