"""
Flights Service.
Бизнес-логика управления рейсами.
"""
from typing import List, Optional
from datetime import datetime, timedelta

from app.modules.flights.repository import FlightRepository, AirportRepository
from app.models.flight import Flight, FlightStatus
from app.models.airport import Airport
from app.core.exceptions import FlightNotFound, AirportNotFound, FlightConflict


class FlightService:
    """Сервис управления рейсами."""
    
    def __init__(self, flight_repo: FlightRepository, airport_repo: AirportRepository):
        self.flight_repo = flight_repo
        self.airport_repo = airport_repo
    
    def get_all_flights(self) -> List[Flight]:
        """Получить все рейсы."""
        self._update_statuses()
        return self.flight_repo.get_all()
    
    def get_flight(self, flight_id: int) -> Flight:
        """Получить рейс по ID."""
        self._update_statuses()
        flight = self.flight_repo.get_by_id(flight_id)
        if not flight:
            raise FlightNotFound()
        return flight
    
    def search_flights(
        self,
        origin_code: str,
        destination_code: str,
        departure_date: datetime
    ) -> List[Flight]:
        """Поиск доступных рейсов."""
        origin = self.airport_repo.get_by_code(origin_code)
        if not origin:
            raise AirportNotFound()
        
        destination = self.airport_repo.get_by_code(destination_code)
        if not destination:
            raise AirportNotFound()
        
        self._update_statuses()
        return self.flight_repo.search(origin.id, destination.id, departure_date)
    
    def get_flights_by_status(self, statuses: List[FlightStatus]) -> List[Flight]:
        """Получить рейсы по статусам."""
        self._update_statuses()
        return self.flight_repo.get_by_status(statuses)
    
    def get_all_airports(self) -> List[Airport]:
        """Получить все аэропорты."""
        return self.airport_repo.get_all()
    
    def _update_statuses(self) -> None:
        """
        Обновление статусов рейсов на основе текущего времени.
        SCHEDULED -> BOARDING (за 2ч) -> DEPARTED (в время вылета) -> ARRIVED (в время прибытия)
        """
        now = datetime.utcnow()
        
        flights = self.flight_repo.db.query(Flight).filter(
            Flight.status.in_([
                FlightStatus.SCHEDULED,
                FlightStatus.BOARDING,
                FlightStatus.DEPARTED
            ])
        ).all()
        
        for flight in flights:
            new_status = None
            
            if flight.scheduled_arrival and now >= flight.scheduled_arrival:
                new_status = FlightStatus.ARRIVED
            elif now >= flight.scheduled_departure:
                new_status = FlightStatus.DEPARTED
            elif now >= flight.scheduled_departure - timedelta(hours=2):
                new_status = FlightStatus.BOARDING
            
            if new_status and flight.status != new_status:
                flight.status = new_status
        
        self.flight_repo.db.commit()
