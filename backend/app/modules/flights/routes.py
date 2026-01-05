"""
Flights Routes.
HTTP слой для рейсов — только маршрутизация.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.db.session import get_db
from app.modules.flights.repository import FlightRepository, AirportRepository
from app.modules.flights.service import FlightService
from app.schemas.flight import Flight as FlightSchema, FlightDetail, FlightSearch
from app.schemas.airport import Airport as AirportSchema


router = APIRouter(prefix="/flights", tags=["Flights"])


def get_flight_service(db: Session = Depends(get_db)) -> FlightService:
    """Dependency для получения FlightService."""
    return FlightService(FlightRepository(db), AirportRepository(db))


# ─────────────────────────────────────────
# Публичные эндпоинты
# ─────────────────────────────────────────

@router.get("/public", response_model=List[FlightSchema])
def get_flights_public(
    from_city: str = None,
    to_city: str = None,
    date: str = None,
    service: FlightService = Depends(get_flight_service)
):
    """Публичный список рейсов."""
    flights = service.get_all_flights()
    return [FlightSchema.model_validate(f) for f in flights]


@router.get("/airports", response_model=List[AirportSchema])
def get_airports(service: FlightService = Depends(get_flight_service)):
    """Список всех аэропортов."""
    airports = service.get_all_airports()
    return [AirportSchema.model_validate(a) for a in airports]


@router.post("/search", response_model=List[FlightSchema])
def search_flights(
    search_data: FlightSearch,
    service: FlightService = Depends(get_flight_service)
):
    """Поиск рейсов по маршруту и дате."""
    flights = service.search_flights(
        search_data.origin_code,
        search_data.destination_code,
        search_data.departure_date
    )
    return [FlightSchema.model_validate(f) for f in flights]


@router.get("/{flight_id}", response_model=FlightDetail)
def get_flight_details(
    flight_id: int,
    service: FlightService = Depends(get_flight_service)
):
    """Детали рейса."""
    flight = service.get_flight(flight_id)
    return FlightDetail.model_validate(flight)
