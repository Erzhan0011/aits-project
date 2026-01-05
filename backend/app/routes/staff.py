from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session, selectinload, joinedload
from typing import List, Optional

from app.core.database import get_db
from app.core.dependencies import get_current_staff
from app.models.user import User
from app.models.aircraft import Aircraft as AircraftModel
from app.models.flight import Flight as FlightModel, FlightStatus
from app.models.booking import Booking as BookingModel, BookingStatus
from app.models.payment import TransactionStatus

from app.schemas.airport import Airport, AirportCreate, AirportDetail
from app.schemas.aircraft import Aircraft, AircraftCreate, SeatTemplate, SeatTemplateCreate, AircraftDetail
from app.schemas.flight import Flight, FlightCreate, FlightUpdate
from app.schemas.booking import Booking, SeatConflict
from app.schemas.announcement import Announcement, AnnouncementCreate
from app.schemas.seat import StaffSeatMap
from app.schemas.payment import StaffPayment
from app.schemas.user import UserProfile
from app.services import (
    aircraft_service,
    flight_service,
    announcement_service,
    booking_service,
    user_service
)

router = APIRouter(prefix="/staff", tags=["Staff"])

# ===================== АЭРОПОРТЫ =====================

@router.get("/airports", response_model=List[Airport], tags=["Staff - Airports"])
def list_airports(db: Session = Depends(get_db)):
    """Список аэропортов"""
    return flight_service.get_airports(db)

@router.post("/airports", response_model=Airport, status_code=status.HTTP_201_CREATED, tags=["Staff - Airports"])
def create_airport(airport_data: AirportCreate, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Создать аэропорт"""
    return flight_service.create_airport(db, airport_data)

@router.get("/airports/{airport_id}", response_model=AirportDetail, tags=["Staff - Airports"])
def get_airport_detail(airport_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Детали аэропорта"""
    return flight_service.get_airport_detail(db, airport_id)

# ===================== САМОЛЁТЫ / ШАБЛОНЫ =====================

@router.post("/seat-templates", response_model=SeatTemplate, status_code=status.HTTP_201_CREATED)
def create_seat_template_endpoint(template_data: SeatTemplateCreate, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return aircraft_service.create_seat_template(db, template_data)

@router.get("/seat-templates", response_model=List[SeatTemplate])
def list_seat_templates(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return aircraft_service.get_seat_templates(db)

@router.delete("/seat-templates/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_seat_template_endpoint(template_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    aircraft_service.delete_seat_template(db, template_id)
    return None

@router.post("/aircrafts", response_model=Aircraft, status_code=status.HTTP_201_CREATED, tags=["Staff - Aircrafts"])
def create_aircraft_endpoint(aircraft_data: AircraftCreate, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return aircraft_service.create_aircraft(db, aircraft_data)

@router.get("/aircrafts", response_model=List[Aircraft], tags=["Staff - Aircrafts"])
def list_aircrafts(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return aircraft_service.get_aircrafts(db)

@router.delete("/aircrafts/{aircraft_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Staff - Aircrafts"])
def delete_aircraft_endpoint(aircraft_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    aircraft_service.delete_aircraft(db, aircraft_id)
    return None

@router.get("/aircrafts/{aircraft_id}", response_model=AircraftDetail, tags=["Staff - Aircrafts"])
def get_aircraft_detail(aircraft_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    aircraft = db.query(AircraftModel).options(
        selectinload(AircraftModel.flights).selectinload(FlightModel.origin_airport),
        selectinload(AircraftModel.flights).selectinload(FlightModel.destination_airport)
    ).filter(AircraftModel.id == aircraft_id).first()
    if not aircraft: raise HTTPException(status_code=404, detail="Самолёт не найден")
    return aircraft

# ===================== РЕЙСЫ =====================

@router.get("/flights/upcoming", response_model=List[Flight], tags=["Staff - Flights: Upcoming & Active"])
def list_upcoming_flights(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Рейсы: По расписанию, Задержан, Посадка"""
    return flight_service.get_flights_by_status(db, [FlightStatus.SCHEDULED, FlightStatus.DELAYED, FlightStatus.BOARDING])

@router.get("/flights/active", response_model=List[Flight], tags=["Staff - Flights: In Air"])
def list_active_flights(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Рейсы: В полете (Вылетел)"""
    return flight_service.get_flights_by_status(db, [FlightStatus.DEPARTED])

@router.get("/flights/past", response_model=List[Flight], tags=["Staff - Flights: Archive"])
def list_past_flights(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Рейсы: Прибыл, Отменен"""
    return flight_service.get_flights_by_status(db, [FlightStatus.ARRIVED, FlightStatus.CANCELLED])

@router.post("/flights", response_model=Flight, status_code=status.HTTP_201_CREATED, tags=["Staff - Flights: Management"])
def create_flight_endpoint(flight_data: FlightCreate, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Создать рейс"""
    return flight_service.create_flight(db, flight_data)

@router.get("/flights", response_model=List[Flight], tags=["Staff - Flights: Management"])
def list_flights_all(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Полный список всех рейсов для управления"""
    flight_service.update_flight_statuses(db)
    return db.query(FlightModel).all()

@router.get("/flights/{flight_id}", response_model=Flight, tags=["Staff - Flights: Management"])
def get_flight(flight_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Детали конкретного рейса"""
    return flight_service.get_flight_by_id(db, flight_id)

@router.put("/flights/{flight_id}", response_model=Flight, tags=["Staff - Flights: Management"])
def update_flight_endpoint(flight_id: int, flight_data: FlightUpdate, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Изменить параметры рейса (время, статус, гейт)"""
    return flight_service.update_flight(db, flight_id, flight_data)

@router.delete("/flights/{flight_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Staff - Flights: Management"])
def delete_flight_endpoint(flight_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Удалить рейс из системы"""
    flight_service.delete_flight(db, flight_id)
    return None

@router.get("/flights/{flight_id}/seats", response_model=StaffSeatMap, tags=["Staff - Flights: Management"])
def get_flight_seats_staff(flight_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Карта мест рейса с именами пассажиров (админ)"""
    return flight_service.get_staff_flight_seat_map(db, flight_id)

# ===================== БРОНИРОВАНИЯ =====================

@router.get("/bookings", response_model=List[Booking], tags=["Staff - Bookings: Generic"])
def list_bookings(
    flight_id: Optional[int] = None, 
    pnr: Optional[str] = None,
    current_user: User = Depends(get_current_staff), 
    db: Session = Depends(get_db)
):
    """Общий список всех бронирований (для совместимости с фронтендом)"""
    query = db.query(BookingModel).options(
        joinedload(BookingModel.flight).joinedload(FlightModel.origin_airport),
        joinedload(BookingModel.flight).joinedload(FlightModel.destination_airport),
        joinedload(BookingModel.ticket)
    )
    if flight_id: query = query.filter(BookingModel.flight_id == flight_id)
    if pnr: query = query.filter(BookingModel.pnr == pnr)
    bookings = query.order_by(BookingModel.created_at.desc()).all()
    return [Booking.model_validate(b) for b in bookings]

@router.get("/bookings/confirmed", response_model=List[Booking], tags=["Staff - Bookings: Confirmed"])
def list_confirmed_bookings(flight_id: Optional[int] = None, pnr: Optional[str] = None, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Список всех оплаченных и подтвержденных бронирований"""
    return booking_service.list_bookings_by_status(db, BookingStatus.CONFIRMED, flight_id, pnr)

@router.get("/bookings/pending", response_model=List[Booking], tags=["Staff - Bookings: Pending/Created"])
def list_pending_bookings(flight_id: Optional[int] = None, pnr: Optional[str] = None, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Список временных бронирований (ожидают оплаты 10 мин)"""
    return booking_service.list_bookings_by_status(db, BookingStatus.CREATED, flight_id, pnr)

@router.get("/bookings/cancelled", response_model=List[Booking], tags=["Staff - Bookings: Cancelled"])
def list_cancelled_bookings(flight_id: Optional[int] = None, pnr: Optional[str] = None, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Список отмененных бронирований"""
    return booking_service.list_bookings_by_status(db, BookingStatus.CANCELLED, flight_id, pnr)

@router.get("/bookings/{booking_id}", response_model=Booking, tags=["Staff - Bookings: Generic"])
def get_booking(booking_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Детальная информация о конкретном бронировании"""
    booking = db.query(BookingModel).options(
        joinedload(BookingModel.flight).joinedload(FlightModel.origin_airport),
        joinedload(BookingModel.flight).joinedload(FlightModel.destination_airport),
        joinedload(BookingModel.ticket)
    ).filter(BookingModel.id == booking_id).first()
    if not booking: raise HTTPException(status_code=404, detail="Бронирование не найдено")
    return Booking.model_validate(booking)

class SeatReassignRequest(BaseModel):
    new_seat_number: str

@router.post("/bookings/{booking_id}/reassign", response_model=Booking, tags=["Staff - Bookings: Operations"])
def reassign_seat_endpoint(booking_id: int, request: SeatReassignRequest, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Переназначить место пассажира (с уведомлением в историю)"""
    return booking_service.staff_reassign_seat(db, booking_id, request.new_seat_number)

@router.post("/bookings/{booking_id}/cancel", response_model=Booking, tags=["Staff - Bookings: Operations"])
def cancel_booking_endpoint(booking_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Отменить бронирование администратором"""
    return booking_service.staff_cancel_booking(db, booking_id)

class SeatBlockRequest(BaseModel):
    seat_number: str

@router.post("/flights/{flight_id}/block-seat", response_model=Booking, tags=["Staff - Bookings: Operations"])
def block_seat_endpoint(flight_id: int, request: SeatBlockRequest, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Заблокировать место (системная блокировка)"""
    return booking_service.staff_block_seat(db, flight_id, request.seat_number, current_user.id)

@router.get("/flights/{flight_id}/conflicts", response_model=List[SeatConflict], tags=["Staff - Bookings: Operations"])
def get_seat_conflicts(flight_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Найти конфликты мест на рейсе"""
    return booking_service.get_seat_conflicts(db, flight_id)

# ===================== ОБЪЯВЛЕНИЯ =====================

@router.post("/announcements", response_model=Announcement, status_code=status.HTTP_201_CREATED, tags=["Staff - Announcements"])
def create_announcement_endpoint(announcement_data: AnnouncementCreate, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return Announcement.model_validate(announcement_service.create_announcement(db, announcement_data, current_user.id))

@router.get("/flights/{flight_id}/announcements", response_model=List[Announcement], tags=["Staff - Announcements"])
def get_flight_announcements_endpoint(flight_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return announcement_service.get_flight_announcements(db, flight_id)

@router.delete("/announcements/{announcement_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Staff - Announcements"])
def delete_announcement_endpoint(announcement_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    announcement_service.delete_announcement(db, announcement_id)
    return None

@router.get("/announcements", response_model=List[Announcement], tags=["Staff - Announcements"])
def list_all_announcements(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    return announcement_service.list_all_announcements(db)

# ===================== ПОЛЬЗОВАТЕЛИ =====================

@router.get("/users", response_model=List[UserProfile], tags=["Staff - Users"])
def list_all_users(current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Список всех зарегистрированных пользователей"""
    return user_service.list_all_users(db)

@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Staff - Users"])
def delete_user(user_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Удалить пассажира (запрещено удалять сотрудников)"""
    user_service.delete_user_staff(db, user_id, current_user.id)
    return None

@router.post("/users/{user_id}/block", response_model=UserProfile, summary="Заблокировать/Разблокировать пассажира", tags=["Staff - Users"])
def toggle_block_user(user_id: int, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Переключает статус активности аккаунта пассажира"""
    return user_service.toggle_block_user_staff(db, user_id)

# ===================== ПЛАТЕЖИ =====================

@router.get("/payments", response_model=List[StaffPayment], tags=["Staff - Payments"])
def list_payments(status: Optional[TransactionStatus] = None, current_user: User = Depends(get_current_staff), db: Session = Depends(get_db)):
    """Список всех платежей"""
    return booking_service.get_all_payments_staff(db, status)
