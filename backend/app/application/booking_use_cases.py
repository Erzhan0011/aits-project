"""
Booking Use Cases.
Application Layer: сценарии использования для бронирований.

Use Case — это один конкретный сценарий использования системы.
Он оркестрирует Domain Entities и работает через Unit of Work.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List

from app.domain.interfaces import IUnitOfWork
from app.domain.entities import BookingEntity, BookingStatus


@dataclass
class CancelBookingRequest:
    """DTO запроса на отмену бронирования."""
    booking_id: int
    user_id: int
    reason: str = ""


@dataclass
class CancelBookingResponse:
    """DTO ответа отмены бронирования."""
    success: bool
    message: str
    refund_amount: float = 0.0


class CancelBookingUseCase:
    """Use Case: Отмена бронирования."""
    
    def __init__(self, uow: IUnitOfWork):
        self.uow = uow
    
    def execute(self, request: CancelBookingRequest) -> CancelBookingResponse:
        with self.uow:
            booking = self.uow.bookings.get_by_id(request.booking_id)
            if not booking:
                return CancelBookingResponse(success=False, message="Бронирование не найдено")
            
            if booking.passenger_id != request.user_id:
                return CancelBookingResponse(success=False, message="Вы не можете отменить чужое бронирование")
            
            if not booking.can_cancel():
                return CancelBookingResponse(success=False, message=f"Нельзя отменить в статусе {booking.status}")
            
            refund = self._calculate_refund(booking)
            booking.cancel()
            self.uow.bookings.save(booking)
            self.uow.commit()
            
            return CancelBookingResponse(success=True, message="Успешно отменено", refund_amount=refund)
    
    def _calculate_refund(self, booking: BookingEntity) -> float:
        if booking.status == BookingStatus.PENDING: return booking.total_price
        if booking.status == BookingStatus.CONFIRMED: return booking.total_price * 0.8
        return 0.0


@dataclass
class GetUserTripsRequest:
    """DTO запроса списка поездок."""
    user_id: int


class GetUserTripsUseCase:
    """Use Case: Получение поездок пользователя."""
    
    def __init__(self, uow: IUnitOfWork):
        self.uow = uow
    
    def execute(self, request: GetUserTripsRequest) -> List[BookingEntity]:
        with self.uow:
            return self.uow.bookings.get_by_user(request.user_id)


@dataclass
class HoldSeatsRequest:
    """DTO запроса на блокировку мест."""
    flight_id: int
    user_id: int
    seat_numbers: List[str]


@dataclass
class HoldSeatsResponse:
    """DTO ответа блокировки мест."""
    success: bool
    seats: List[str]
    expires_at: str


class HoldSeatsUseCase:
    """Use Case: Временная блокировка мест."""
    
    def __init__(self, uow: IUnitOfWork):
        self.uow = uow
    
    def execute(self, request: HoldSeatsRequest) -> HoldSeatsResponse:
        with self.uow:
            expires_at = datetime.utcnow().replace(microsecond=0) + timedelta(minutes=10)
            # В реальной системе здесь бы создавались SeatReservation сущности
            return HoldSeatsResponse(success=True, seats=request.seat_numbers, expires_at=expires_at.isoformat())


@dataclass
class GetSeatAvailabilityRequest:
    """DTO запроса доступности мест."""
    flight_id: int


@dataclass
class GetSeatAvailabilityResponse:
    """DTO ответа доступности мест."""
    flight_id: int
    occupied_seats: List[str]
    held_seats: List[str]


class GetSeatAvailabilityUseCase:
    """Use Case: Получение доступности мест."""
    
    def __init__(self, uow: IUnitOfWork):
        self.uow = uow
    
    def execute(self, request: GetSeatAvailabilityRequest) -> GetSeatAvailabilityResponse:
        with self.uow:
            bookings = self.uow.bookings.get_by_flight(request.flight_id)
            occupied = [b.seat_number for b in bookings if b.status != BookingStatus.CANCELLED]
            return GetSeatAvailabilityResponse(
                flight_id=request.flight_id,
                occupied_seats=occupied,
                held_seats=[]
            )
