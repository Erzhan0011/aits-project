"""
Flight Service.
Управление рейсами, аэропортами и картами мест.
"""
import math
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session, joinedload, selectinload
from fastapi import HTTPException, status

from app.models.flight import Flight, FlightStatus
from app.models.airport import Airport
from app.models.booking import Booking, BookingStatus, Ticket, SeatHold
from app.models.announcement import Announcement
from app.schemas.flight import FlightCreate, FlightUpdate, FlightSearch
from app.schemas.seat import SeatMap, Seat, StaffSeat, StaffSeatMap
from app.schemas.airport import AirportCreate



def get_airports(db: Session) -> List[Airport]:
    return db.query(Airport).all()


def delete_airport(db: Session, airport_id: int) -> bool:
    """
    Safely deletes an airport and all associated flights.
    Creates persistent history announcements for affected passengers.
    """
    airport = db.query(Airport).filter(Airport.id == airport_id).first()
    if not airport:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Аэропорт не найден"
        )
    
    try:
        
        # 1. Find all affected flights (Origin or Destination)
        flights = db.query(Flight).filter(
            or_(
                Flight.origin_airport_id == airport_id,
                Flight.destination_airport_id == airport_id
            )
        ).all()
        
        for flight in flights:
            # 2. Find confirmed bookings
            bookings = db.query(Booking).filter(
                Booking.flight_id == flight.id,
                Booking.status == BookingStatus.CONFIRMED
            ).all()
            
            # 3. Notify passengers and decouple announcements
            for booking in bookings:
                msg = f"Рейс {flight.flight_number} ({flight.departure_city} - {flight.arrival_city}) был отменен из-за закрытия аэропорта. Возврат будет произведен автоматически."
                
                ann = Announcement(
                    title="Рейс отменен (Закрытие аэропорта)",
                    message=msg,
                    flight_id=None, # Survives flight deletion
                    created_by=booking.passenger_id, # Targeted to user
                    created_at=datetime.utcnow()
                )
                db.add(ann)
            
            # Delete flight (and cascade delete bookings/tickets/seat_holds)
            db.delete(flight)
        
        # 4. Final removal
        db.delete(airport)
        db.commit()
        return True
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при удалении аэропорта: {str(e)}")


def search_flights(
    db: Session,
    origin_code: str,
    destination_code: str,
    departure_date: datetime
) -> List[Flight]:
    """
    Searches for available flights between two airports on a specific date.
    Validates airports, updates current flight statuses, and applies a 2-hour booking cutoff.
    """
    origin = db.query(Airport).filter(Airport.code == origin_code).first()
    destination = db.query(Airport).filter(Airport.code == destination_code).first()
    
    if not origin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Аэропорт отправления {origin_code} не найден"
        )
    if not destination:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Аэропорт прибытия {destination_code} не найден"
        )
    
    # 1. Ensure statuses are fresh
    update_flight_statuses(db)
    
    # 2. Define search window
    now = datetime.utcnow()
    booking_cutoff = now + timedelta(hours=2)
    start_of_day = departure_date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = start_of_day + timedelta(days=1)
    
    # Visibility: Must be after cutoff and within the requested day
    actual_search_start = max(start_of_day, booking_cutoff)
    
    return db.query(Flight).options(joinedload(Flight.aircraft)).filter(
        and_(
            Flight.origin_airport_id == origin.id,
            Flight.destination_airport_id == destination.id,
            Flight.scheduled_departure >= actual_search_start,
            Flight.scheduled_departure < end_of_day,
            Flight.status != FlightStatus.CANCELLED
        )
    ).all()


def update_flight_statuses(db: Session) -> None:
    """
    State machine for flight lifecycle.
    SCHEDULED -> BOARDING (2h) -> DEPARTED (0h) -> ARRIVED (End).
    Executed proactively by search and retrieval logic.
    """
    now = datetime.utcnow()
    affected = False
    
    try:
        # 1. Scheduled -> Boarding (2 hours before departure)
        boarding_limit = now + timedelta(hours=2)
        to_boarding = db.query(Flight).filter(
            Flight.status == FlightStatus.SCHEDULED,
            Flight.scheduled_departure <= boarding_limit,
            Flight.scheduled_departure > now
        ).all()
        for f in to_boarding:
            f.status = FlightStatus.BOARDING
            affected = True
            
        # 2. Boarding/Scheduled -> Departed (Departure time reached)
        to_departed = db.query(Flight).filter(
            Flight.status.in_([FlightStatus.SCHEDULED, FlightStatus.BOARDING]),
            Flight.scheduled_departure <= now,
            Flight.scheduled_arrival > now
        ).all()
        for f in to_departed:
            f.status = FlightStatus.DEPARTED
            affected = True
            
        # 3. Departed -> Arrived (Arrival time reached)
        to_arrived = db.query(Flight).filter(
            Flight.status == FlightStatus.DEPARTED,
            Flight.scheduled_arrival <= now
        ).all()
        for f in to_arrived:
            f.status = FlightStatus.ARRIVED
            affected = True
            
        if affected:
            db.commit()
    except Exception:
        db.rollback()


def get_flights_by_status(db: Session, statuses: List[FlightStatus]) -> List[Flight]:
    """Retrieves all flights matching the provided operational statuses."""
    update_flight_statuses(db)
    return db.query(Flight).options(
        joinedload(Flight.origin_airport),
        joinedload(Flight.destination_airport)
    ).filter(Flight.status.in_(statuses)).order_by(Flight.scheduled_departure.asc()).all()


def create_airport(db: Session, airport_data: AirportCreate) -> Airport:
    """Administratively registers a new airport."""
    if db.query(Airport).filter(Airport.code == airport_data.code).first():
        raise HTTPException(status_code=400, detail="Аэропорт с таким IATA кодом уже существует")
    
    try:
        airport = Airport(**airport_data.model_dump())
        db.add(airport)
        db.commit()
        db.refresh(airport)
        return airport
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to create airport: {str(e)}")


def get_airport_detail(db: Session, airport_id: int) -> Airport:
    """Returns detailed airport info including its flight schedule."""
    airport = db.query(Airport).options(
        selectinload(Airport.origin_flights).selectinload(Flight.destination_airport),
        selectinload(Airport.destination_flights).selectinload(Flight.origin_airport)
    ).filter(Airport.id == airport_id).first()
    if not airport:
        raise HTTPException(status_code=404, detail="Аэропорт не найден")
    return airport



def get_flight_by_id(db: Session, flight_id: int) -> Flight:
    """Retrieves a flight by its ID, ensuring statuses are synchronized first."""
    update_flight_statuses(db)
    flight = db.query(Flight).options(
        joinedload(Flight.aircraft),
        joinedload(Flight.origin_airport),
        joinedload(Flight.destination_airport)
    ).filter(Flight.id == flight_id).first()
    
    if not flight:
        raise HTTPException(status_code=404, detail="Рейс не найден")
    return flight


def _build_seats(
    capacity: int,
    seats_per_row: int,
    occupied_map: dict,  # seat_number -> (passenger_name, booking_id) or None
    held_seats: list,
    base_price: float,
    is_staff: bool = False
) -> list:
    """Internal engine to generate virtual seat layouts for legacy/dynamic aircraft."""
    needed_rows = math.ceil(capacity / seats_per_row)
    seats = []
    
    for row in range(1, needed_rows + 1):
        for seat_idx in range(1, seats_per_row + 1):
            if len(seats) >= capacity:
                break
                
            column = chr(64 + seat_idx)
            seat_number = f"{row}{column}"
            
            # 1. Status Check
            p_name, b_id = None, None
            if seat_number in occupied_map:
                seat_status = "occupied"
                if is_staff: p_name, b_id = occupied_map[seat_number]
            elif seat_number in held_seats:
                seat_status = "reserved"
            else:
                seat_status = "available"
            
            # 2. Type & Pricing
            price_multiplier = 1.0
            if row <= 2:
                seat_type = "business"
                price_multiplier = 2.0
            elif seat_idx == 1 or seat_idx == seats_per_row:
                seat_type = "window"
            elif seat_idx == 3 or seat_idx == (seats_per_row // 2 + (1 if seats_per_row % 2 == 0 else 0)):
                seat_type = "aisle"
            else:
                seat_type = "standard"
            
            seat_price = base_price * price_multiplier
            is_exit = (row == 12) # Generic emergency row

            if is_staff:
                seats.append(StaffSeat(
                    seat_number=seat_number, row=row, column=column,
                    seat_type=seat_type, status=seat_status,
                    passenger_name=p_name, booking_id=b_id,
                    is_emergency_exit=is_exit, price=seat_price
                ))
            else:
                seats.append(Seat(
                    seat_number=seat_number, row=row, column=column,
                    seat_type=seat_type, status=seat_status,
                    is_emergency_exit=is_exit, price=seat_price
                ))
        if len(seats) >= capacity: break
    return seats


def get_flight_seat_map(db: Session, flight_id: int) -> SeatMap:
    """Generates a visual seat map for passengers with real-time occupancy."""
    from app.services.booking_service import cleanup_expired_holds
    cleanup_expired_holds(db)
    
    flight = get_flight_by_id(db, flight_id)
    if not flight.aircraft or not flight.aircraft.seat_template:
        return SeatMap(flight_id=flight_id, seats=[], total_seats=0, available_seats=0, occupied_seats=0)
        
    confirmed = db.query(Booking.seat_number).filter(
        Booking.flight_id == flight_id, Booking.status == BookingStatus.CONFIRMED
    ).all()
    occupied_seats = {c[0] for c in confirmed}
    
    active_holds = db.query(SeatHold.seat_number).filter(
        SeatHold.flight_id == flight_id, SeatHold.expires_at > datetime.utcnow()
    ).all()
    held_seats = {h[0] for h in active_holds}
    
    template_map = flight.aircraft.seat_template.seat_map or {"seats": []}
    seats_list = []
    
    for s_data in template_map.get("seats", []):
        seat_num = s_data["seat_number"]
        
        status = "available"
        if seat_num in occupied_seats: status = "occupied"
        elif seat_num in held_seats: status = "reserved"
            
        multiplier = 2.0 if s_data.get("class") == "BUSINESS" else 1.0
        
        seats_list.append(Seat(
            seat_number=seat_num, row=s_data["row"], column=s_data["letter"],
            seat_type=s_data["class"].lower(), status=status,
            is_emergency_exit=s_data.get("is_emergency_exit", False),
            price=flight.base_price * multiplier
        ))
        
    return SeatMap(
        flight_id=flight_id,
        seats=seats_list,
        total_seats=len(seats_list),
        available_seats=len([s for s in seats_list if s.status == "available"]),
        occupied_seats=len([s for s in seats_list if s.status == "occupied"])
    )


def get_staff_flight_seat_map(db: Session, flight_id: int) -> StaffSeatMap:
    """Generates an administrative seat map with passenger details."""
    flight = get_flight_by_id(db, flight_id)
    if not flight.aircraft or not flight.aircraft.seat_template:
        return StaffSeatMap(flight_id=flight_id, seats=[], total_seats=0, available_seats=0, occupied_seats=0)
        
    confirmed = db.query(Booking).filter(
        Booking.flight_id == flight_id, Booking.status == BookingStatus.CONFIRMED
    ).all()
    
    occupied_info = {
        b.seat_number: (f"{b.first_name or ''} {b.last_name or ''}".strip() or "BLOCK", b.id)
        for b in confirmed
    }
    
    active_holds = db.query(SeatHold.seat_number).filter(
        SeatHold.flight_id == flight_id, SeatHold.expires_at > datetime.utcnow()
    ).all()
    held_seats = {h[0] for h in active_holds}
    
    template_map = flight.aircraft.seat_template.seat_map or {"seats": []}
    seats_list = []
    
    for s_data in template_map.get("seats", []):
        seat_num = s_data["seat_number"]
        status, p_name, b_id = "available", None, None
        
        if seat_num in occupied_info:
            status = "occupied"
            p_name, b_id = occupied_info[seat_num]
        elif seat_num in held_seats:
            status = "reserved"
            
        multiplier = 2.0 if s_data.get("class") == "BUSINESS" else 1.0
        
        seats_list.append(StaffSeat(
            seat_number=seat_num, row=s_data["row"], column=s_data["letter"],
            seat_type=s_data["class"].lower(), status=status,
            passenger_name=p_name, booking_id=b_id,
            is_emergency_exit=s_data.get("is_emergency_exit", False),
            price=flight.base_price * multiplier
        ))
    
    return StaffSeatMap(
        flight_id=flight_id,
        seats=seats_list,
        total_seats=len(seats_list),
        available_seats=len([s for s in seats_list if s.status == "available"]),
        occupied_seats=len([s for s in seats_list if s.status == "occupied"])
    )


def create_flight(db: Session, flight_data: FlightCreate) -> Flight:
    """Creates a new flight with extensive aircraft overlap protection."""
    if flight_data.scheduled_arrival <= flight_data.scheduled_departure:
        raise HTTPException(status_code=400, detail="Время прибытия должно быть позже времени отправления")

    try:
        # Aircraft collision check
        overlapping = db.query(Flight).filter(
            Flight.aircraft_id == flight_data.aircraft_id,
            Flight.status != FlightStatus.CANCELLED,
            and_(
                Flight.scheduled_departure < flight_data.scheduled_arrival,
                Flight.scheduled_arrival > flight_data.scheduled_departure
            )
        ).first()
        
        if overlapping:
            raise HTTPException(
                status_code=400, 
                detail=f"Самолёт №{flight_data.aircraft_id} уже занят на рейсе {overlapping.flight_number}."
            )

        if db.query(Flight).filter(Flight.flight_number == flight_data.flight_number).first():
            raise HTTPException(status_code=400, detail="Рейс с таким номером уже существует")
        
        # Advance planning check (24h)
        min_dep = datetime.utcnow() + timedelta(hours=24)
        if flight_data.scheduled_departure < min_dep:
            raise HTTPException(status_code=400, detail="Рейс можно создать только за 24 часа до вылета.")
            
        flight = Flight(**flight_data.model_dump())
        db.add(flight)
        
        db.add(Announcement(

            title="Новый рейс доступен",
            message=f"Рейс {flight_data.flight_number} добавлен в расписание.",
            flight_id=None,
            created_at=datetime.utcnow(),
            created_by=1
        ))
        
        db.commit()
        db.refresh(flight)
        return flight
    except HTTPException: raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


def update_flight(db: Session, flight_id: int, flight_data: FlightUpdate) -> Flight:
    """Updates flight details and sends targeted announcements for significant changes."""
    flight = get_flight_by_id(db, flight_id)
    try:
        update_dict = flight_data.model_dump(exclude_unset=True)
        
        # 1. Operational Conflicts Check
        new_dep = update_dict.get('scheduled_departure', flight.scheduled_departure)
        new_arr = update_dict.get('scheduled_arrival', flight.scheduled_arrival)
        new_aid = update_dict.get('aircraft_id', flight.aircraft_id)
        
        if any(f in update_dict for f in ['scheduled_departure', 'scheduled_arrival', 'aircraft_id']):
            if new_arr <= new_dep:
                raise HTTPException(status_code=400, detail="Ошибка: время прибытия <= вылета.")
            
            overlap = db.query(Flight).filter(
                Flight.id != flight_id, Flight.aircraft_id == new_aid,
                Flight.status != FlightStatus.CANCELLED,
                and_(Flight.scheduled_departure < new_arr, Flight.scheduled_arrival > new_dep)
            ).first()
            if overlap:
                raise HTTPException(status_code=400, detail=f"Конфликт: самолет занят на {overlap.flight_number}.")

        # 2. Tracking changes for notification
        old_vals = (flight.status, flight.gate, flight.terminal, flight.scheduled_departure)
        for field, value in update_dict.items(): setattr(flight, field, value)
        
        # 3. Notification Logic
        changes = []
        if 'status' in update_dict and update_dict['status'] != old_vals[0]:
            changes.append(f"Статус: {old_vals[0]} -> {update_dict['status']}")
        if 'gate' in update_dict and update_dict['gate'] != old_vals[1]:
            changes.append(f"Гейт: {old_vals[1] or '?'} -> {update_dict['gate']}")
        if 'scheduled_departure' in update_dict and update_dict['scheduled_departure'] != old_vals[3]:
            changes.append(f"Вылет: {old_vals[3].strftime('%H:%M')} -> {update_dict['scheduled_departure'].strftime('%H:%M')}")

        if changes:

            msg = f"Рейс {flight.flight_number} обновлен: " + ", ".join(changes)
            # Global
            db.add(Announcement(title="Обновление рейса", message=msg, flight_id=flight.id, created_by=1))
            # Individual History
            bookings = db.query(Booking).filter(Booking.flight_id == flight_id, Booking.status != BookingStatus.CANCELLED).all()
            for b in bookings:
                db.add(Announcement(title="Ваш рейс изменен", message=msg, flight_id=flight.id, created_by=b.passenger_id))

        db.commit()
        db.refresh(flight)
        return flight
    except HTTPException: raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


def delete_flight(db: Session, flight_id: int) -> bool:
    """Permanently removes a flight record."""
    flight = get_flight_by_id(db, flight_id)
    try:
        db.delete(flight)
        db.commit()
        return True
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


def filter_flights(db: Session, from_city: Optional[str] = None, to_city: Optional[str] = None, date: Optional[str] = None) -> List[Flight]:
    """Lightweight filtering for passenger UI (mobile list)."""
    update_flight_statuses(db)
    now = datetime.utcnow()
    booking_cutoff = now + timedelta(hours=2)
    
    query = db.query(Flight).options(joinedload(Flight.aircraft)).filter(
        Flight.scheduled_departure >= booking_cutoff,
        Flight.status != FlightStatus.CANCELLED
    )
    
    if date:
        try:
            target = datetime.fromisoformat(date.replace('Z', '+00:00')) if 'T' in date else datetime.strptime(date, "%Y-%m-%d")
            start = target.replace(hour=0, minute=0, second=0)
            query = query.filter(Flight.scheduled_departure >= start, Flight.scheduled_departure < start + timedelta(days=1))
        except: pass

    flights = query.all()
    if from_city: flights = [f for f in flights if f.departure_city.lower() == from_city.lower().strip()]
    if to_city: flights = [f for f in flights if f.arrival_city.lower() == to_city.lower().strip()]
    return flights

