"""
Bookings Routes (Perfection Level 10/10).
HTTP слой, делегирующий работу Use Cases из Application Layer.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.db.session import get_db, SessionLocal
from app.domain.interfaces import IUnitOfWork
from app.infrastructure.unit_of_work import SqlAlchemyUnitOfWork
from app.application.booking_use_cases import (
    CancelBookingUseCase, CancelBookingRequest,
    GetUserTripsUseCase, GetUserTripsRequest,
    HoldSeatsUseCase, HoldSeatsRequest,
    GetSeatAvailabilityUseCase, GetSeatAvailabilityRequest
)
from app.modules.auth.dependencies import get_current_active_user
from app.models.user import User

router = APIRouter(prefix="/bookings", tags=["Bookings"])

# 1. Dependency: Unit of Work
def get_uow() -> IUnitOfWork:
    return SqlAlchemyUnitOfWork(SessionLocal)

# 2. Use Case Factories (DI)
def get_cancel_booking_use_case(uow: IUnitOfWork = Depends(get_uow)) -> CancelBookingUseCase:
    return CancelBookingUseCase(uow)

def get_user_trips_use_case(uow: IUnitOfWork = Depends(get_uow)) -> GetUserTripsUseCase:
    return GetUserTripsUseCase(uow)

def get_hold_seats_use_case(uow: IUnitOfWork = Depends(get_uow)) -> HoldSeatsUseCase:
    return HoldSeatsUseCase(uow)

def get_seat_availability_use_case(uow: IUnitOfWork = Depends(get_uow)) -> GetSeatAvailabilityUseCase:
    return GetSeatAvailabilityUseCase(uow)


@router.get("/my-trips")
def get_my_trips(
    current_user: User = Depends(get_current_active_user),
    use_case: GetUserTripsUseCase = Depends(get_user_trips_use_case)
):
    """[Clean Architecture] Получить мои поездки через Use Case."""
    request = GetUserTripsRequest(user_id=current_user.id)
    return use_case.execute(request)


@router.get("/{flight_id}/seats")
def get_seat_availability(
    flight_id: int,
    use_case: GetSeatAvailabilityUseCase = Depends(get_seat_availability_use_case)
):
    """[Clean Architecture] Получить доступность мест через Use Case."""
    request = GetSeatAvailabilityRequest(flight_id=flight_id)
    return use_case.execute(request)


@router.post("/{flight_id}/hold-seats")
def hold_seats(
    flight_id: int,
    seat_numbers: List[str],
    current_user: User = Depends(get_current_active_user),
    use_case: HoldSeatsUseCase = Depends(get_hold_seats_use_case)
):
    """[Clean Architecture] Зарезервировать места через Use Case."""
    request = HoldSeatsRequest(
        flight_id=flight_id, 
        user_id=current_user.id, 
        seat_numbers=seat_numbers
    )
    result = use_case.execute(request)
    if not result.success:
        raise HTTPException(status_code=400, detail="Не удалось заблокировать места")
    return result


@router.post("/{booking_id}/cancel")
def cancel_booking(
    booking_id: int,
    current_user: User = Depends(get_current_active_user),
    use_case: CancelBookingUseCase = Depends(get_cancel_booking_use_case)
):
    """[Clean Architecture] Отменить бронирование через Use Case."""
    request = CancelBookingRequest(booking_id=booking_id, user_id=current_user.id)
    result = use_case.execute(request)
    if not result.success:
        raise HTTPException(status_code=400, detail=result.message)
    return result
