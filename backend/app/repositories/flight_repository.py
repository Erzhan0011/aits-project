"""
Репозиторий рейсов.
Специализированные методы для работы с Flight моделью.
"""
from typing import Optional, List
from datetime import datetime, timedelta
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_

from app.repositories.base import BaseRepository
from app.models.flight import Flight, FlightStatus
from app.models.airport import Airport


class FlightRepository(BaseRepository[Flight]):
    """
    Репозиторий для работы с рейсами.
    
    Включает методы для поиска, фильтрации и управления статусами.
    """
    
    def __init__(self, db: Session):
        super().__init__(Flight, db)
    
    def get_with_relations(self, flight_id: int) -> Optional[Flight]:
        """Получить рейс со всеми связями (аэропорты, самолёт)."""
        return self.db.query(Flight).options(
            joinedload(Flight.aircraft),
            joinedload(Flight.origin_airport),
            joinedload(Flight.destination_airport)
        ).filter(Flight.id == flight_id).first()
    
    def get_by_flight_number(self, flight_number: str) -> Optional[Flight]:
        """Найти рейс по номеру."""
        return self.db.query(Flight).filter(
            Flight.flight_number == flight_number
        ).first()
    
    def get_by_status(self, statuses: List[FlightStatus]) -> List[Flight]:
        """Получить рейсы по статусам."""
        return self.db.query(Flight).options(
            joinedload(Flight.origin_airport),
            joinedload(Flight.destination_airport)
        ).filter(
            Flight.status.in_(statuses)
        ).order_by(Flight.scheduled_departure.asc()).all()
    
    def get_available_flights(
        self,
        origin_id: int,
        destination_id: int,
        departure_date: datetime,
        booking_cutoff_hours: int = 2
    ) -> List[Flight]:
        """
        Получить доступные для бронирования рейсы.
        
        Args:
            origin_id: ID аэропорта отправления
            destination_id: ID аэропорта прибытия
            departure_date: Дата вылета
            booking_cutoff_hours: За сколько часов до вылета закрывается бронирование
        """
        now = datetime.utcnow()
        cutoff = now + timedelta(hours=booking_cutoff_hours)
        
        start_of_day = departure_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = start_of_day + timedelta(days=1)
        
        actual_start = max(start_of_day, cutoff)
        
        return self.db.query(Flight).options(
            joinedload(Flight.aircraft)
        ).filter(
            and_(
                Flight.origin_airport_id == origin_id,
                Flight.destination_airport_id == destination_id,
                Flight.scheduled_departure >= actual_start,
                Flight.scheduled_departure < end_of_day,
                Flight.status != FlightStatus.CANCELLED
            )
        ).all()
    
    def get_upcoming_flights(self, hours: int = 24) -> List[Flight]:
        """Получить рейсы в ближайшие N часов."""
        now = datetime.utcnow()
        end = now + timedelta(hours=hours)
        
        return self.db.query(Flight).filter(
            and_(
                Flight.scheduled_departure >= now,
                Flight.scheduled_departure <= end,
                Flight.status.in_([
                    FlightStatus.SCHEDULED,
                    FlightStatus.BOARDING,
                    FlightStatus.DELAYED
                ])
            )
        ).order_by(Flight.scheduled_departure.asc()).all()
    
    def check_aircraft_availability(
        self,
        aircraft_id: int,
        departure: datetime,
        arrival: datetime,
        exclude_flight_id: Optional[int] = None
    ) -> bool:
        """
        Проверить доступность самолёта на указанное время.
        
        Returns:
            True если самолёт свободен, False если занят
        """
        query = self.db.query(Flight).filter(
            Flight.aircraft_id == aircraft_id,
            Flight.status != FlightStatus.CANCELLED,
            and_(
                Flight.scheduled_departure < arrival,
                Flight.scheduled_arrival > departure
            )
        )
        
        if exclude_flight_id:
            query = query.filter(Flight.id != exclude_flight_id)
        
        return query.first() is None
    
    def get_flights_for_airport(self, airport_id: int) -> List[Flight]:
        """Получить все рейсы, связанные с аэропортом."""
        from sqlalchemy import or_
        return self.db.query(Flight).filter(
            or_(
                Flight.origin_airport_id == airport_id,
                Flight.destination_airport_id == airport_id
            )
        ).all()
    
    def update_status(self, flight_id: int, new_status: FlightStatus) -> bool:
        """Обновить статус рейса."""
        flight = self.get(flight_id)
        if flight:
            flight.status = new_status
            self.db.commit()
            return True
        return False
