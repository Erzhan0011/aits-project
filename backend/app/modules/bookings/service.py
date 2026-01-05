"""
Bookings Service.
Бизнес-логика бронирований.
"""
from typing import List
from datetime import datetime, timedelta

from app.modules.bookings.repository import BookingRepository, SeatHoldRepository
from app.models.booking import Booking, BookingStatus
from app.core.exceptions import BookingNotFound, SeatNotAvailable, BookingNotAllowed


class BookingService:
    """Сервис управления бронированиями."""
    
    def __init__(self, booking_repo: BookingRepository, hold_repo: SeatHoldRepository):
        self.booking_repo = booking_repo
        self.hold_repo = hold_repo
    
    def get_user_trips(self, user_id: int) -> List[Booking]:
        """Получить поездки пользователя."""
        return self.booking_repo.get_user_bookings(user_id)
    
    def get_booking(self, booking_id: int) -> Booking:
        """Получить бронирование по ID."""
        booking = self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise BookingNotFound()
        return booking
    
    def get_seat_availability(self, flight_id: int) -> dict:
        """Получить информацию о занятости мест."""
        self.hold_repo.cleanup_expired()
        
        occupied = self.booking_repo.get_occupied_seats(flight_id)
        held = self.hold_repo.get_held_seats(flight_id)
        
        return {
            "occupied_seats": list(occupied),
            "held_seats": list(held),
        }
    
    def hold_seats(self, flight_id: int, seat_numbers: List[str], user_id: int) -> dict:
        """Временно зарезервировать места."""
        self.hold_repo.cleanup_expired()
        
        occupied = self.booking_repo.get_occupied_seats(flight_id)
        held = self.hold_repo.get_held_seats(flight_id)
        unavailable = occupied | held
        
        for seat in seat_numbers:
            if seat in unavailable:
                raise SeatNotAvailable(seat)
        
        expires_at = datetime.utcnow() + timedelta(minutes=10)
        
        for seat in seat_numbers:
            self.hold_repo.create({
                "flight_id": flight_id,
                "seat_number": seat,
                "user_id": user_id,
                "expires_at": expires_at,
            })
        
        return {
            "seats": seat_numbers,
            "expires_at": expires_at.isoformat(),
        }
    
    def cancel_booking(self, booking_id: int, user_id: int) -> dict:
        """Отменить бронирование."""
        booking = self.get_booking(booking_id)
        
        if booking.passenger_id != user_id:
            raise BookingNotAllowed("Вы не можете отменить чужое бронирование")
        
        if booking.status == BookingStatus.CANCELLED:
            raise BookingNotAllowed("Бронирование уже отменено")
        
        self.booking_repo.update_status(booking, BookingStatus.CANCELLED)
        
        return {"success": True, "message": "Бронирование отменено"}
