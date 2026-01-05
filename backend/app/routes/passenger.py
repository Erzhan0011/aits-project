from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.dependencies import get_current_passenger
from app.models.user import User
from app.schemas.seat import SeatMap, BookWithPassengersRequest, BookSeatsResponse, SeatHoldRequest, SeatHoldResponse
from app.schemas.user import UserProfile, UserUpdate
from app.schemas.flight import Flight, FlightDetail, FlightSearch, Trip, CheckInRequest, CheckInResponse
from app.schemas.airport import Airport
from app.schemas.announcement import Announcement
from app.schemas.payment import PaymentTransaction
from app.services import flight_service, booking_service, announcement_service, user_service

router = APIRouter(prefix="/passenger", tags=["Passenger"])

# ===================== PUBLIC ENDPOINTS =====================

@router.get("/flights/public", response_model=List[Flight], tags=["Passenger - Search & Flights"])
def get_flights_public(from_city: str = None, to_city: str = None, date: str = None, db: Session = Depends(get_db)):
    """Публичный список рейсов (доступен без логина)"""
    return [Flight.model_validate(f) for f in flight_service.filter_flights(db, from_city, to_city, date)]

@router.get("/public/flight/{flight_id}", response_model=Flight, tags=["Passenger - Search & Flights"])
def get_flight_details_public(flight_id: int, db: Session = Depends(get_db)):
    """Публичные детали рейса"""
    return Flight.model_validate(flight_service.get_flight_by_id(db, flight_id))

@router.get("/airports", response_model=List[Airport], tags=["Passenger - Search & Flights"])
def get_airports(db: Session = Depends(get_db)):
    """Публичный список аэропортов"""
    return [Airport.model_validate(a) for a in flight_service.get_airports(db)]

# ===================== PROTECTED ENDPOINTS =====================

@router.get("/flights", response_model=List[Flight], tags=["Passenger - Search & Flights"])
def get_flights(from_city: str = None, to_city: str = None, date: str = None, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Список рейсов для авторизованных пользователей"""
    return [Flight.model_validate(f) for f in flight_service.filter_flights(db, from_city, to_city, date)]

@router.get("/flights/{flight_id}", response_model=FlightDetail, tags=["Passenger - Search & Flights"])
def get_flight_details(flight_id: int, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Детали рейса (защищенный)"""
    return FlightDetail.model_validate(flight_service.get_flight_by_id(db, flight_id))

@router.get("/flights/{flight_id}/seats", response_model=SeatMap, tags=["Passenger - Booking Flow"])
def get_flight_seats(flight_id: int, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Карта мест (выбор мест)"""
    return flight_service.get_flight_seat_map(db, flight_id)

@router.post("/flights/{flight_id}/hold-seats", response_model=SeatHoldResponse, tags=["Passenger - Booking Flow"])
def hold_seats(flight_id: int, request: SeatHoldRequest, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Зарезервировать места (на 10 минут)"""
    return booking_service.hold_seats(db, flight_id, request, current_user.id)

@router.post("/flights/{flight_id}/book-with-passengers", response_model=BookSeatsResponse, tags=["Passenger - Booking Flow"])
def book_seats_with_passengers(flight_id: int, request: BookWithPassengersRequest, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Подтвердить бронирование с данными пассажиров"""
    return booking_service.create_bookings_with_passengers(db, flight_id, request, current_user.id)

@router.get("/profile/trips", response_model=List[Trip], tags=["Passenger - My Trips & Tickets"])
def get_my_trips(current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Список моих поездок (включая попутчиков)"""
    return booking_service.get_user_trips(db, current_user)

@router.get("/payments", response_model=List[PaymentTransaction], tags=["Passenger - Account & Profile"])
def get_payment_history(current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """История транзакций пассажира"""
    payments = booking_service.get_user_payments(db, current_user.id)
    return [PaymentTransaction(**g) for g in payments]

@router.post("/flights/search", response_model=List[Flight], tags=["Passenger - Search & Flights"])
def search_flights(search_data: FlightSearch, db: Session = Depends(get_db)):
    """Поиск рейсов"""
    flights = flight_service.search_flights(db, search_data.origin_code, search_data.destination_code, search_data.departure_date)
    return [Flight.model_validate(f) for f in flights]

@router.get("/announcements", response_model=List[Announcement], tags=["Passenger - Notifications"])
def get_announcements(current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Список объявлений и уведомлений"""
    announcements = announcement_service.get_user_announcements(db, current_user)
    return [Announcement.model_validate(a) for a in announcements]

@router.post("/check-in", response_model=CheckInResponse, tags=["Passenger - My Trips & Tickets"])
def check_in(request: CheckInRequest, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Пройти онлайн-регистрацию"""
    res = booking_service.check_in(db, request.ticket_id, current_user.id)
    return CheckInResponse(success=True, message="Регистрация прошла успешно", boarding_pass=res["boarding_pass"])

@router.post("/bookings/{booking_id}/cancel", response_model=dict, tags=["Passenger - My Trips & Tickets"])
def cancel_booking(booking_id: int, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Отмена бронирования (возврат места)"""
    return booking_service.cancel_booking_full(db, booking_id, current_user.id)

@router.put("/profile", response_model=UserProfile, tags=["Passenger - Account & Profile"])
def update_profile(user_data: UserUpdate, current_user: User = Depends(get_current_passenger), db: Session = Depends(get_db)):
    """Обновить персональные данные"""
    user = user_service.update_user_profile(db, current_user.id, user_data)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    return user
