"""
Booking Service.
Управление процессом бронирования, блокировкой мест, оплатой и регистрацией.
"""
import io
import re
import uuid
import base64
import secrets
import string
import qrcode
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session, joinedload
from fastapi import HTTPException, status

from app.models.announcement import Announcement
from app.models.booking import Booking, BookingStatus, SeatHold, Ticket, PaymentMethod
from app.models.flight import Flight
from app.models.payment import Payment, TransactionStatus
from app.models.user import User, UserRole
from app.schemas.announcement import Announcement as AnnouncementSchema
from app.schemas.booking import BookingCreate
from app.schemas.flight import Flight as FlightSchema, Trip as TripSchema
from app.schemas.seat import (
    SeatHoldRequest, 
    BookWithPassengersRequest, 
    BookSeatsResponse, 
    SeatHoldResponse
)
from app.services.payment_service import process_payment, refund_payment
from app.services.flight_service import get_flight_by_id, get_flight_seat_map



def generate_pnr(db: Session) -> str:
    """
    Generates a unique 6-character PNR (Passenger Name Record) code.
    Excludes confusing characters (0, O, 1, I) and filtered offensive patterns.
    """
    CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    PROHIBITED_PATTERNS = ["FUCK", "SHIT", "HELL", "COCK", "BULL"]
    
    for _ in range(50):
        pnr = "".join(secrets.choice(CHARSET) for _ in range(6))
        if any(pattern in pnr for pattern in PROHIBITED_PATTERNS):
            continue
            
        exists = db.query(Booking.id).filter(Booking.pnr == pnr).first() is not None
        if not exists:
            return pnr
            
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
        detail="Не удалось создать уникальный PNR после множества попыток."
    )


def check_passenger_profile(user: User) -> None:
    """Validates that a passenger has completed their mandatory profile fields."""
    if not user.passport_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Профиль пассажира должен содержать номер паспорта перед бронированием."
        )


def calculate_seat_price(base_price: float, seat_number: str) -> float:
    """Calculates final price of a seat based on its class (Row-based logic)."""
    match = re.match(r"(\d+)([A-Z])", seat_number)
    if not match: return base_price
    
    row = int(match.group(1))
    if row <= 3: # Rows 1-3 are generally Business Class
        return base_price * 2.5
    return base_price


def cleanup_expired_holds(db: Session) -> None:
    """
    Removes expired seat holds and clears associated pending 'CREATED' bookings.
    Should be called before querying availability or starting a new hold session.
    """
    try:
        now = datetime.utcnow()
        expired_holds = db.query(SeatHold).filter(SeatHold.expires_at <= now).all()
        
        if expired_holds:
            for hold in expired_holds:
                db.query(Booking).filter(
                    Booking.flight_id == hold.flight_id,
                    Booking.seat_number == hold.seat_number,
                    Booking.status == BookingStatus.CREATED
                ).delete()
                db.delete(hold)
            db.commit()
    except Exception:
        db.rollback()


def hold_seats(db: Session, flight_id: int, request: SeatHoldRequest, user_id: int) -> SeatHoldResponse:
    """
    Reserves specific seats for 10 minutes to allow the user to complete payment.
    Creates 'CREATED' booking drafts.
    """
    # 1. Proactive cleanup
    cleanup_expired_holds(db)
    
    # 2. Lock flight for modification
    flight = db.query(Flight).filter(Flight.id == flight_id).with_for_update().first()
    if not flight:
        raise HTTPException(status_code=404, detail="Рейс не найден")
        
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    batch_pnr = generate_pnr(db)
    
    try:
        for seat_number in request.seat_numbers:
            # Check confirmed bookings
            existing = db.query(Booking).filter(
                Booking.flight_id == flight_id,
                Booking.seat_number == seat_number,
                Booking.status == BookingStatus.CONFIRMED
            ).first()
            if existing:
                raise HTTPException(status_code=400, detail=f"Место {seat_number} уже занято")
                
            # Check active holds
            existing_hold = db.query(SeatHold).filter(
                SeatHold.flight_id == flight_id, 
                SeatHold.seat_number == seat_number
            ).first()
            
            if existing_hold:
                if existing_hold.passenger_id != user_id:
                    raise HTTPException(status_code=400, detail=f"Место {seat_number} уже заблокировано другим пользователем")
                else:
                    # User is holding it again? Refresh it.
                    db.delete(existing_hold)
                    db.query(Booking).filter(
                        Booking.flight_id == flight_id,
                        Booking.seat_number == seat_number,
                        Booking.passenger_id == user_id,
                        Booking.status == BookingStatus.CREATED
                    ).delete()

            # Create hold and draft
            db.add(SeatHold(
                flight_id=flight_id,
                seat_number=seat_number,
                passenger_id=user_id,
                expires_at=expires_at
            ))
            
            seat_price = calculate_seat_price(flight.base_price, seat_number)
            
            db.add(Booking(
                pnr=batch_pnr,
                passenger_id=user_id,
                flight_id=flight_id,
                seat_number=seat_number,
                price=seat_price,
                status=BookingStatus.CREATED,
                created_at=datetime.utcnow()
            ))
        
        db.add(Announcement(
            title="Ожидание оплаты",
            message=f"Места {', '.join(request.seat_numbers)} временно заблокированы за вами. Пожалуйста, завершите бронирование в течение 10 минут.",
            flight_id=flight_id,
            created_by=user_id
        ))
        
        db.commit()
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Ошибка при выполнении блокировки мест: {str(e)}")
    
    return SeatHoldResponse(
        success=True,
        message="Места успешно заблокированы",
        expires_at=expires_at.replace(tzinfo=timezone.utc),
        seat_numbers=request.seat_numbers
    )


def create_bookings_with_passengers(
    db: Session,
    flight_id: int,
    request: BookWithPassengersRequest,
    user_id: int
) -> BookSeatsResponse:
    """
    Converts 'CREATED' drafts into 'CONFIRMED' bookings with passenger identity validation.
    Performs critical payment processing steps.
    """
    try:
        flight = get_flight_by_id(db, flight_id)
        now = datetime.utcnow()
        booked_seats = []
        first_id = None
        
        # 1. Verify all holds are still valid
        for p in request.passengers:
            hold = db.query(SeatHold).filter(
                SeatHold.flight_id == flight_id,
                SeatHold.seat_number == p.seat_number,
                SeatHold.passenger_id == user_id,
                SeatHold.expires_at > now
            ).first()
            if not hold:
                raise HTTPException(status_code=400, detail=f"Блокировка места {p.seat_number} истекла или не существует")
                
        # 2. Gather and update booking objects
        bookings_to_confirm = []
        for p in request.passengers:
            booking = db.query(Booking).filter(
                Booking.flight_id == flight_id,
                Booking.seat_number == p.seat_number,
                Booking.status == BookingStatus.CREATED
            ).first()
            
            if not booking:
                continue
                
            booking.first_name = p.first_name
            booking.last_name = p.last_name
            booking.passport_number = p.passport_number
            booking.date_of_birth = p.date_of_birth
            booking.payment_method = PaymentMethod(request.payment_method)
            bookings_to_confirm.append(booking)

        if not bookings_to_confirm:
             raise HTTPException(status_code=404, detail="Активные черновики бронирования не найдены")

        # 3. Synchronous Payment and Ticket Generation
        payment_method = PaymentMethod(request.payment_method)
        
        for b in bookings_to_confirm:
            # Mock Processing
            process_payment(
                db=db,
                booking_id=b.id,
                passenger_id=user_id,
                amount=b.price,
                method=payment_method,
                card_info="4242 4242 4242 4242" if payment_method == PaymentMethod.CARD else None
            )
            
            b.status = BookingStatus.CONFIRMED
            b.confirmed_at = datetime.utcnow()
            
            # Generate permanent Ticket entry
            ticket = Ticket(
                booking_id=b.id,
                passenger_id=user_id,
                flight_id=flight_id,
                seat_number=b.seat_number
            )
            db.add(ticket)
            booked_seats.append(b.seat_number)
            if not first_id: first_id = b.id

        # 4. Final Cleanup of the hold session
        db.query(SeatHold).filter(SeatHold.flight_id == flight_id, SeatHold.passenger_id == user_id).delete()
        
        db.add(Announcement(
            title="Билеты оформлены",
            message=f"Рейс {flight.flight_number}: Оплата прошла успешно. Ваши билеты (PNR: {bookings_to_confirm[0].pnr}) доступны в профиле.",
            flight_id=flight_id,
            created_by=user_id
        ))
        
        db.commit()
        
        return BookSeatsResponse(
            success=True,
            message="Бронирование успешно завершено",
            booking_id=first_id,
            booked_seats=booked_seats
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Booking transaction failed: {str(e)}")


def create_booking(db: Session, booking_data: BookingCreate, user_id: int) -> Booking:
    """Creates a single direct booking (Legacy / Internal support)."""
    try:
        user = db.query(User).filter(User.id == user_id).first()
        check_passenger_profile(user)
        flight = get_flight_by_id(db, booking_data.flight_id)
        
        seat_price = calculate_seat_price(flight.base_price, booking_data.seat_number)
        
        booking = Booking(
            pnr=generate_pnr(db),
            passenger_id=user_id,
            flight_id=booking_data.flight_id,
            seat_number=booking_data.seat_number,
            price=seat_price,
            payment_method=booking_data.payment_method,
            status=BookingStatus.CONFIRMED,
            confirmed_at=datetime.utcnow()
        )
        db.add(booking)
        db.add(Ticket(booking_id=booking.id, passenger_id=user_id, flight_id=booking_data.flight_id, seat_number=booking_data.seat_number))
        db.commit()
        db.refresh(booking)
        return booking
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))


def get_user_bookings(db: Session, user_id: int) -> List[Booking]:
    """Returns all bookings associated with a specific user ID."""
    return db.query(Booking).filter(Booking.passenger_id == user_id).all()


def check_in(db: Session, ticket_id: int, user_id: int) -> dict:
    """
    Performs online check-in for a passenger.
    Validates the 24h-1h window (or 48h for specific test flights).
    Generates a boarding pass QR string.
    """
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id, Ticket.passenger_id == user_id).first()
    if not ticket:
        # Fallback to search by booking ID
        booking = db.query(Booking).filter(Booking.id == ticket_id, Booking.passenger_id == user_id).first()
        if booking and booking.ticket: ticket = booking.ticket
        
    if not ticket: 
        raise HTTPException(status_code=404, detail="Билет не найден")
    
    if ticket.checked_in: 
        return {"ticket": ticket, "boarding_pass": ticket.qr_code}
    
    # Check-in Window Validation
    departure = ticket.flight.scheduled_departure
    now = datetime.utcnow()
    diff = departure - now
    
    # Window: 1h to 24h (48h for SU506 for testing)
    max_hours = 48 if ticket.flight.flight_number == "SU506" else 24
    if not (timedelta(hours=1) <= diff <= timedelta(hours=max_hours)):
        raise HTTPException(
            status_code=400, 
            detail=f"Регистрация открывается за {max_hours}ч и закрывается за 1ч до вылета."
        )
        
    try:
        ticket.checked_in = True
        ticket.checked_in_at = now
        # Standardized QR Code string
        last_name = ticket.booking.last_name or "PASSENGER"
        ticket.qr_code = f"BP|{ticket.flight.flight_number}|{ticket.seat_number}|{ticket.id}|{last_name}"
        db.commit()
        db.refresh(ticket)
        return {"ticket": ticket, "boarding_pass": ticket.qr_code}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Check-in failed: {str(e)}")


def staff_cancel_booking(db: Session, booking_id: int) -> Booking:
    """Administrative cancellation of a booking."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking or booking.status == BookingStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Бронирование не найдено или уже отменено")
    
    try:
        flight = get_flight_by_id(db, booking.flight_id)
        booking.status = BookingStatus.CANCELLED
        
        db.add(Announcement(
            title="Бронирование отменено",
            message=f"Ваше бронирование на рейс {flight.flight_number} было отменено администратором системы.",
            flight_id=booking.flight_id,
            created_by=booking.passenger_id
        ))
        db.commit()
        db.refresh(booking)
        return booking
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Admin cancellation failed: {str(e)}")


def staff_block_seat(db: Session, flight_id: int, seat_number: str, staff_id: int) -> Booking:
    """Blocks a seat for system use (Maintenance, Staff use, etc)."""
    existing = db.query(Booking).filter(
        Booking.flight_id == flight_id,
        Booking.seat_number == seat_number,
        Booking.status == BookingStatus.CONFIRMED
    ).first()
    if existing: raise HTTPException(status_code=400, detail="Это место уже занято подтвержденным бронированием")
    
    try:
        flight = get_flight_by_id(db, flight_id)
        
        booking = Booking(
            pnr="SYSTEM",
            passenger_id=staff_id,
            flight_id=flight_id,
            seat_number=seat_number,
            price=0.0,
            status=BookingStatus.CONFIRMED,
            first_name="SYSTEM",
            last_name="BLOCK",
            confirmed_at=datetime.utcnow(),
            payment_method=PaymentMethod.CARD
        )
        db.add(booking)
        
        db.add(Announcement(
            title="Место заблокировано",
            message=f"Рейс {flight.flight_number}: Место {seat_number} заблокировано для служебных целей.",
            flight_id=flight_id,
            created_by=1, # System
            created_at=datetime.utcnow()
        ))
        
        db.commit()
        db.refresh(booking)
        return booking
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Seat block failed: {str(e)}")


def staff_reassign_seat(db: Session, booking_id: int, new_seat_number: str) -> Booking:
    """Moves a passenger to a different seat on the same flight."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")
    
    if booking.status != BookingStatus.CONFIRMED:
        raise HTTPException(status_code=400, detail="Можно изменять место только для подтвержденных бронирований")
        
    old_seat = booking.seat_number
    if old_seat == new_seat_number:
        return booking

    # Check for destination overlap
    overlap = db.query(Booking).filter(
        Booking.flight_id == booking.flight_id,
        Booking.seat_number == new_seat_number,
        Booking.status == BookingStatus.CONFIRMED
    ).first()
    if overlap:
        raise HTTPException(status_code=400, detail=f"Место {new_seat_number} уже занято другим пассажиром")
        
    # Template validation
    seat_map = get_flight_seat_map(db, booking.flight_id)
    if not any(s.seat_number == new_seat_number for s in seat_map.seats):
         raise HTTPException(status_code=400, detail=f"Места {new_seat_number} не существует в конфигурации самолета")
    
    try:
        # Update records
        booking.seat_number = new_seat_number
        if booking.ticket:
            booking.ticket.seat_number = new_seat_number
            # Update boarding pass QR
            last_name = booking.last_name or (booking.user.last_name if booking.user else "PASSENGER")
            booking.ticket.qr_code = f"BP|{booking.flight.flight_number}|{new_seat_number}|{booking.ticket.id}|{last_name}"
        
        msg = f"Место пассажира {booking.first_name} {booking.last_name} изменено с {old_seat} на {new_seat_number}"
        
        # 1. Personal alert
        db.add(Announcement(
            title="Изменение места",
            message=msg + ". Пожалуйста, используйте обновленный посадочный талон.",
            flight_id=booking.flight_id,
            created_by=booking.passenger_id,
            created_at=datetime.utcnow()
        ))
        
        # 2. System audit log
        db.add(Announcement(
            title="Переназначение (Staff)",
            message=f"Рейс {booking.flight.flight_number}: {msg}",
            flight_id=booking.flight_id,
            created_by=1,
            created_at=datetime.utcnow()
        ))
        
        db.commit()
        db.refresh(booking)
        return booking
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Reassignment failed: {str(e)}")



def get_user_trips(db: Session, current_user: User) -> List[TripSchema]:
    """
    Complex retrieval of user trips. 
    Includes group bookings (where user is primary or companion).
    """
    # Pre-fetch staff IDs for announcement filtering (Optimization)
    staff_ids_subquery = db.query(User.id).filter(User.role.in_([UserRole.STAFF, UserRole.ADMIN])).all()
    staff_ids = [s[0] for s in staff_ids_subquery]

    # 1. Find all relevant bookings (Self or linked via PNR/Passport)
    user_bookings = db.query(Booking).filter(
        or_(
            Booking.passenger_id == current_user.id,
            and_(Booking.passport_number == current_user.passport_number, Booking.passport_number != None)
        )
    ).all()
    
    my_pnrs = {b.pnr for b in user_bookings if b.pnr}
    user_booking_ids = [b.id for b in user_bookings]
    
    transaction_ids = set()
    if user_booking_ids:
        tx_query = db.query(Payment.transaction_id).filter(Payment.booking_id.in_(user_booking_ids)).all()
        transaction_ids = {tx[0] for tx in tx_query if tx[0]}
    
    linked_by_tx_ids = set()
    if transaction_ids:
        linked_tx_query = db.query(Payment.booking_id).filter(Payment.transaction_id.in_(list(transaction_ids))).all()
        linked_by_tx_ids = {l[0] for l in linked_tx_query}
        
    # Full fetch with joins
    final_bookings = db.query(Booking).options(
        joinedload(Booking.flight).joinedload(Flight.aircraft),
        joinedload(Booking.flight).joinedload(Flight.origin_airport),
        joinedload(Booking.flight).joinedload(Flight.destination_airport),
        joinedload(Booking.ticket),
        joinedload(Booking.payment)
    ).filter(
        or_(
            Booking.pnr.in_(list(my_pnrs)) if my_pnrs else False,
            Booking.id.in_(list(linked_by_tx_ids)) if linked_by_tx_ids else False,
            Booking.passenger_id == current_user.id,
            and_(Booking.passport_number == current_user.passport_number, Booking.passport_number != None)
        )
    ).all()
    
    # Pre-fetch holds for the session
    now = datetime.utcnow()
    holds = db.query(SeatHold).filter(SeatHold.passenger_id == current_user.id, SeatHold.expires_at > now).all()
    active_holds = { (h.flight_id, h.seat_number): h for h in holds }
    
    trips = []
    for b in final_bookings:
        expires_at = None
        if b.status == BookingStatus.CREATED:
            hold = active_holds.get((b.flight_id, b.seat_number))
            if not hold: continue
            expires_at = hold.expires_at.replace(tzinfo=timezone.utc)
            
        # Get history (using pre-fetched staff_ids)
        history_announcements = db.query(Announcement).filter(
            Announcement.flight_id == b.flight_id,
            or_(
                Announcement.created_by == current_user.id,
                Announcement.created_by.in_(staff_ids)
            )
        ).order_by(Announcement.created_at.asc()).all()
        
        history = [AnnouncementSchema.model_validate(h) for h in history_announcements]

        trips.append(TripSchema(
            id=b.id, passenger_id=b.passenger_id, flight_id=b.flight_id, flight=FlightSchema.model_validate(b.flight),
            seat_number=b.seat_number, price=b.price, status=b.status.value, created_at=b.created_at,
            pnr=b.pnr or "-", gate=b.flight.gate, terminal=b.flight.terminal,
            payment_method=b.payment_method.value if b.payment_method else "CARD",
            expires_at=expires_at, checked_in=b.ticket.checked_in if b.ticket else False,
            qr_code=b.ticket.qr_code if b.ticket else None,
            first_name=b.first_name, last_name=b.last_name, passport_number=b.passport_number,
            date_of_birth=b.date_of_birth, confirmed_at=b.confirmed_at,
            checked_in_at=b.ticket.checked_in_at if b.ticket else None,
            transaction_id=b.payment.transaction_id if b.payment else None,
            history=history
        ))
    return trips


def get_user_payments(db: Session, user_id: int) -> list:
    """Retrieves payment history for a user, grouped by transaction ID."""
    payments = db.query(Payment).options(
        joinedload(Payment.booking).joinedload(Booking.flight)
    ).filter(Payment.passenger_id == user_id).order_by(Payment.created_at.desc()).all()
    
    grouped = {}
    for p in payments:
        if p.transaction_id not in grouped:
            grouped[p.transaction_id] = {
                "transaction_id": p.transaction_id,
                "amount": 0,
                "currency": p.currency,
                "method": p.method,
                "status": p.status,
                "created_at": p.created_at,
                "flight_info": f"{p.booking.flight.flight_number if p.booking else ''}",
                "items": []
            }
        
        grouped[p.transaction_id]["amount"] += p.amount
        grouped[p.transaction_id]["items"].append({
            "pnr": p.booking.pnr if p.booking else "-",
            "booking_id": p.booking_id,
            "amount": p.amount,
            "seat_number": p.booking.seat_number if p.booking else "?"
        })
    return list(grouped.values())


def cancel_booking_full(db: Session, booking_id: int, user_id: int) -> dict:
    """User-initiated complete cancellation with hold cleanup."""
    booking = db.query(Booking).filter(Booking.id == booking_id, Booking.passenger_id == user_id).first()
    if not booking or booking.status == BookingStatus.CANCELLED:
        raise HTTPException(status_code=404, detail="Бронирование не найдено или уже отменено")
    
    try:
        seat_number = booking.seat_number
        flight_id = booking.flight_id
        
        booking.status = BookingStatus.CANCELLED
        
        # Cleanup any active holds to free up the seat immediately
        db.query(SeatHold).filter(
            SeatHold.flight_id == flight_id, 
            SeatHold.seat_number == seat_number, 
            SeatHold.passenger_id == user_id
        ).delete()
        
        # Invalidate ticket
        db.query(Ticket).filter(Ticket.booking_id == booking_id).delete()
        
        db.add(Announcement(
            title="Бронирование отменено", 
            message=f"Ваша бронь места {seat_number} на рейс {booking.flight.flight_number} была успешно отменена.", 
            flight_id=flight_id, 
            created_by=user_id
        ))
        
        db.commit()
        return {"success": True, "message": f"Бронирование места {seat_number} отменено."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Cancellation failed: {str(e)}")


def get_all_payments_staff(db: Session, status: Optional[TransactionStatus] = None) -> List[dict]:
    """Staff view of all transactions in the system."""
    query = db.query(Payment).options(
        joinedload(Payment.booking).joinedload(Booking.flight),
        joinedload(Payment.passenger)
    )
    
    if status:
        query = query.filter(Payment.status == status)
        
    payments = query.order_by(Payment.created_at.desc()).all()
    
    return [{
        "id": p.id,
        "transaction_id": p.transaction_id,
        "booking_id": p.booking_id,
        "passenger_id": p.passenger_id,
        "passenger_name": p.passenger.full_name if p.passenger else "Unknown",
        "amount": p.amount,
        "currency": p.currency,
        "method": p.method,
        "status": p.status,
        "created_at": p.created_at,
        "pnr": p.booking.pnr if p.booking else "-",
        "flight_info": f"{p.booking.flight.flight_number if p.booking else ''}"
    } for p in payments]


def get_seat_conflicts(db: Session, flight_id: int) -> List[dict]:
    """Identifies any overbooked seats (multiple confirmed bookings for the same seat)."""
    bookings = db.query(Booking).filter(
        Booking.flight_id == flight_id,
        Booking.status == BookingStatus.CONFIRMED
    ).all()
    
    seat_groups = {}
    for b in bookings:
        seat_groups.setdefault(b.seat_number, []).append(b)
        
    conflicts = []
    for seat, group in seat_groups.items():
        if len(group) > 1:
            conflicts.append({
                "seat_number": seat,
                "bookings": [TripSchema.model_validate(b) for b in group]
            })
    return conflicts
