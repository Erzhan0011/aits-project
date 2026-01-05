"""
Flights Repository.
Единственная точка доступа к БД для рейсов.
"""
from typing import Optional, List
from datetime import datetime, timedelta
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_, or_

from app.models.flight import Flight, FlightStatus
from app.models.airport import Airport
from app.models.aircraft import Aircraft


class FlightRepository:
    """Репозиторий для работы с рейсами."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_by_id(self, flight_id: int) -> Optional[Flight]:
        """Получить рейс по ID с загрузкой связей."""
        return self.db.query(Flight).options(
            joinedload(Flight.aircraft),
            joinedload(Flight.origin_airport),
            joinedload(Flight.destination_airport)
        ).filter(Flight.id == flight_id).first()
    
    def get_all(self) -> List[Flight]:
        """Получить все рейсы."""
        return self.db.query(Flight).options(
            joinedload(Flight.origin_airport),
            joinedload(Flight.destination_airport)
        ).order_by(Flight.scheduled_departure.desc()).all()
    
    def get_by_status(self, statuses: List[FlightStatus]) -> List[Flight]:
        """Получить рейсы по статусам."""
        return self.db.query(Flight).filter(
            Flight.status.in_(statuses)
        ).order_by(Flight.scheduled_departure.asc()).all()
    
    def search(
        self,
        origin_id: int,
        destination_id: int,
        departure_date: datetime,
        cutoff_hours: int = 2
    ) -> List[Flight]:
        """Поиск доступных рейсов."""
        now = datetime.utcnow()
        cutoff = now + timedelta(hours=cutoff_hours)
        
        start_of_day = departure_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = start_of_day + timedelta(days=1)
        
        actual_start = max(start_of_day, cutoff)
        
        return self.db.query(Flight).options(
            joinedload(Flight.aircraft),
            joinedload(Flight.origin_airport),
            joinedload(Flight.destination_airport)
        ).filter(
            and_(
                Flight.origin_airport_id == origin_id,
                Flight.destination_airport_id == destination_id,
                Flight.scheduled_departure >= actual_start,
                Flight.scheduled_departure < end_of_day,
                Flight.status != FlightStatus.CANCELLED
            )
        ).all()
    
    def create(self, data: dict) -> Flight:
        """Создать новый рейс."""
        flight = Flight(**data)
        self.db.add(flight)
        self.db.commit()
        self.db.refresh(flight)
        return flight
    
    def update(self, flight: Flight, data: dict) -> Flight:
        """Обновить рейс."""
        for key, value in data.items():
            if hasattr(flight, key) and value is not None:
                setattr(flight, key, value)
        self.db.commit()
        self.db.refresh(flight)
        return flight
    
    def delete(self, flight: Flight) -> bool:
        """Удалить рейс."""
        self.db.delete(flight)
        self.db.commit()
        return True


class AirportRepository:
    """Репозиторий для работы с аэропортами."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_all(self) -> List[Airport]:
        """Получить все аэропорты."""
        return self.db.query(Airport).all()
    
    def get_by_id(self, airport_id: int) -> Optional[Airport]:
        """Получить аэропорт по ID."""
        return self.db.query(Airport).filter(Airport.id == airport_id).first()
    
    def get_by_code(self, code: str) -> Optional[Airport]:
        """Получить аэропорт по IATA коду."""
        return self.db.query(Airport).filter(Airport.code == code).first()
    
    def create(self, data: dict) -> Airport:
        """Создать аэропорт."""
        airport = Airport(**data)
        self.db.add(airport)
        self.db.commit()
        self.db.refresh(airport)
        return airport
