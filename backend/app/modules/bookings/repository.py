"""
Bookings Repository.
Data access layer для бронирований.
"""
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session, joinedload

from app.models.booking import Booking, BookingStatus, Ticket, SeatHold


class BookingRepository:
    """Репозиторий для работы с бронированиями."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_by_id(self, booking_id: int) -> Optional[Booking]:
        """Получить бронирование по ID."""
        return self.db.query(Booking).options(
            joinedload(Booking.flight)
        ).filter(Booking.id == booking_id).first()
    
    def get_by_pnr(self, pnr: str) -> List[Booking]:
        """Получить бронирования по PNR."""
        return self.db.query(Booking).filter(Booking.pnr == pnr).all()
    
    def get_user_bookings(self, user_id: int) -> List[Booking]:
        """Получить все бронирования пользователя."""
        return self.db.query(Booking).options(
            joinedload(Booking.flight)
        ).filter(
            Booking.passenger_id == user_id
        ).order_by(Booking.created_at.desc()).all()
    
    def get_flight_bookings(self, flight_id: int, status: BookingStatus = None) -> List[Booking]:
        """Получить бронирования на рейс."""
        query = self.db.query(Booking).filter(Booking.flight_id == flight_id)
        if status:
            query = query.filter(Booking.status == status)
        return query.all()
    
    def get_occupied_seats(self, flight_id: int) -> set:
        """Множество занятых мест."""
        bookings = self.db.query(Booking.seat_number).filter(
            Booking.flight_id == flight_id,
            Booking.status == BookingStatus.CONFIRMED
        ).all()
        return {b[0] for b in bookings}
    
    def create(self, data: dict) -> Booking:
        """Создать бронирование."""
        booking = Booking(**data)
        self.db.add(booking)
        self.db.commit()
        self.db.refresh(booking)
        return booking
    
    def update_status(self, booking: Booking, status: BookingStatus) -> Booking:
        """Обновить статус бронирования."""
        booking.status = status
        self.db.commit()
        self.db.refresh(booking)
        return booking
    
    def delete(self, booking: Booking) -> bool:
        """Удалить бронирование."""
        self.db.delete(booking)
        self.db.commit()
        return True


class SeatHoldRepository:
    """Репозиторий для временных резервов мест."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_active_holds(self, flight_id: int) -> List[SeatHold]:
        """Получить активные резервы на рейс."""
        return self.db.query(SeatHold).filter(
            SeatHold.flight_id == flight_id,
            SeatHold.expires_at > datetime.utcnow()
        ).all()
    
    def get_held_seats(self, flight_id: int) -> set:
        """Множество зарезервированных мест."""
        holds = self.db.query(SeatHold.seat_number).filter(
            SeatHold.flight_id == flight_id,
            SeatHold.expires_at > datetime.utcnow()
        ).all()
        return {h[0] for h in holds}
    
    def create(self, data: dict) -> SeatHold:
        """Создать резерв."""
        hold = SeatHold(**data)
        self.db.add(hold)
        self.db.commit()
        self.db.refresh(hold)
        return hold
    
    def cleanup_expired(self) -> int:
        """Удалить просроченные резервы."""
        count = self.db.query(SeatHold).filter(
            SeatHold.expires_at <= datetime.utcnow()
        ).delete()
        self.db.commit()
        return count
