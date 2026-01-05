"""
Репозиторий бронирований.
Специализированные методы для работы с Booking и связанными моделями.
"""
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_

from app.repositories.base import BaseRepository
from app.models.booking import Booking, BookingStatus, Ticket, SeatHold


class BookingRepository(BaseRepository[Booking]):
    """
    Репозиторий для работы с бронированиями.
    
    Включает методы для управления билетами, временными резервами и статистикой.
    """
    
    def __init__(self, db: Session):
        super().__init__(Booking, db)
    
    def get_by_pnr(self, pnr: str) -> List[Booking]:
        """Получить все бронирования по PNR коду."""
        return self.db.query(Booking).filter(Booking.pnr == pnr).all()
    
    def get_user_bookings(self, user_id: int) -> List[Booking]:
        """Получить все бронирования пользователя."""
        return self.db.query(Booking).options(
            joinedload(Booking.flight)
        ).filter(
            Booking.passenger_id == user_id
        ).order_by(Booking.created_at.desc()).all()
    
    def get_flight_bookings(
        self, 
        flight_id: int, 
        status: Optional[BookingStatus] = None
    ) -> List[Booking]:
        """Получить бронирования на рейс."""
        query = self.db.query(Booking).filter(Booking.flight_id == flight_id)
        if status:
            query = query.filter(Booking.status == status)
        return query.all()
    
    def get_confirmed_bookings(self, flight_id: int) -> List[Booking]:
        """Получить подтверждённые бронирования на рейс."""
        return self.get_flight_bookings(flight_id, BookingStatus.CONFIRMED)
    
    def get_occupied_seats(self, flight_id: int) -> set:
        """Получить множество занятых мест на рейсе."""
        bookings = self.db.query(Booking.seat_number).filter(
            Booking.flight_id == flight_id,
            Booking.status == BookingStatus.CONFIRMED
        ).all()
        return {b[0] for b in bookings}
    
    def is_seat_available(self, flight_id: int, seat_number: str) -> bool:
        """Проверить доступность места."""
        occupied = self.get_occupied_seats(flight_id)
        held = self.get_held_seats(flight_id)
        return seat_number not in occupied and seat_number not in held
    
    # ─────────────────────────────────────────
    # Работа с Ticket
    # ─────────────────────────────────────────
    
    def get_ticket(self, ticket_id: int) -> Optional[Ticket]:
        """Получить билет по ID."""
        return self.db.query(Ticket).filter(Ticket.id == ticket_id).first()
    
    def get_user_tickets(self, user_id: int) -> List[Ticket]:
        """Получить все билеты пользователя."""
        return self.db.query(Ticket).options(
            joinedload(Ticket.booking).joinedload(Booking.flight)
        ).filter(
            Ticket.passenger_id == user_id,
            Ticket.is_valid == True
        ).all()
    
    def create_ticket(self, booking_id: int, passenger_id: int) -> Ticket:
        """Создать билет для бронирования."""
        ticket = Ticket(
            booking_id=booking_id,
            passenger_id=passenger_id,
            issued_at=datetime.utcnow(),
            is_valid=True
        )
        self.db.add(ticket)
        self.db.flush()
        return ticket
    
    def invalidate_ticket(self, ticket_id: int) -> bool:
        """Аннулировать билет."""
        ticket = self.get_ticket(ticket_id)
        if ticket:
            ticket.is_valid = False
            self.db.commit()
            return True
        return False
    
    # ─────────────────────────────────────────
    # Работа с SeatHold (временные резервы)
    # ─────────────────────────────────────────
    
    def get_held_seats(self, flight_id: int) -> set:
        """Получить множество временно зарезервированных мест."""
        holds = self.db.query(SeatHold.seat_number).filter(
            SeatHold.flight_id == flight_id,
            SeatHold.expires_at > datetime.utcnow()
        ).all()
        return {h[0] for h in holds}
    
    def create_seat_hold(
        self, 
        flight_id: int, 
        seat_number: str, 
        user_id: int,
        expires_at: datetime
    ) -> SeatHold:
        """Создать временный резерв места."""
        hold = SeatHold(
            flight_id=flight_id,
            seat_number=seat_number,
            user_id=user_id,
            expires_at=expires_at
        )
        self.db.add(hold)
        self.db.flush()
        return hold
    
    def release_user_holds(self, flight_id: int, user_id: int) -> int:
        """Освободить все резервы пользователя на рейсе."""
        count = self.db.query(SeatHold).filter(
            SeatHold.flight_id == flight_id,
            SeatHold.user_id == user_id
        ).delete()
        self.db.commit()
        return count
    
    def cleanup_expired_holds(self) -> int:
        """Удалить все просроченные резервы."""
        count = self.db.query(SeatHold).filter(
            SeatHold.expires_at <= datetime.utcnow()
        ).delete()
        self.db.commit()
        return count
    
    # ─────────────────────────────────────────
    # Статистика
    # ─────────────────────────────────────────
    
    def count_by_status(self, status: BookingStatus) -> int:
        """Подсчитать бронирования по статусу."""
        return self.db.query(Booking).filter(Booking.status == status).count()
    
    def get_revenue_by_flight(self, flight_id: int) -> float:
        """Получить выручку по рейсу."""
        from sqlalchemy import func
        result = self.db.query(func.sum(Booking.total_price)).filter(
            Booking.flight_id == flight_id,
            Booking.status == BookingStatus.CONFIRMED
        ).scalar()
        return result or 0.0
