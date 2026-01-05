from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from typing import List, Any, Dict, Optional
from app.models.aircraft import Aircraft, SeatTemplate
from app.schemas.aircraft import AircraftCreate, SeatTemplateCreate


def _generate_seat_map(row_count: int, seat_letters: str, business_rows: str = None, economy_rows: str = None) -> dict:
    """Генератор структуры мест на основе параметров"""
    # Парсим диапазоны рядов
    def parse_rows(row_str):
        if not row_str: return set()
        rows = set()
        for part in row_str.split(','):
            part = part.strip()
            if '-' in part:
                start, end = map(int, part.split('-'))
                rows.update(range(start, end + 1))
            else:
                rows.add(int(part))
        return rows

    biz_set = parse_rows(business_rows)
    
    seats = []
    # seat_letters может быть "ABC DEF"
    # Ряды начинаются с 1
    for row_num in range(1, row_count + 1):
        is_business = row_num in biz_set
        
        column_idx = 0
        for char in seat_letters:
            if char == ' ':
                column_idx += 1
                continue # Проход (Aisle)
            
            seat_id = f"{row_num}{char}"
            seats.append({
                "seat_number": seat_id,
                "row": row_num,
                "letter": char,
                "class": "BUSINESS" if is_business else "ECONOMY",
                "is_available": True,
                "is_emergency_exit": False # Можно добавить логику позже
            })
            column_idx += 1
            
    return {"seats": seats}


def create_seat_template(db: Session, template_data: SeatTemplateCreate) -> SeatTemplate:
    """
    Creates a new seat layout template.
    If no seat_map is provided in template_data, it auto-generates one 
    based on row counts and seat letters.
    """
    try:
        if not template_data.seat_map:
            template_data.seat_map = _generate_seat_map(
                template_data.row_count,
                template_data.seat_letters,
                template_data.business_rows,
                template_data.economy_rows
            )
        
        template = SeatTemplate(**template_data.model_dump())
        db.add(template)
        db.commit()
        db.refresh(template)
        return template
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Error creating seat template: {str(e)}")


def get_seat_templates(db: Session) -> List[SeatTemplate]:
    """Returns all available seat templates for staff selection."""
    return db.query(SeatTemplate).all()


def get_seat_template_by_id(db: Session, template_id: int) -> SeatTemplate:
    """Fetches a specific seat template or raises 404."""
    template = db.query(SeatTemplate).filter(SeatTemplate.id == template_id).first()
    if not template:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Шаблон мест не найден"
        )
    return template


def create_aircraft(db: Session, aircraft_data: AircraftCreate) -> Aircraft:
    """
    Registers a new aircraft in the fleet.
    Validates registration uniqueness and template integrity.
    """
    try:
        # Check if template exists
        template = get_seat_template_by_id(db, aircraft_data.seat_template_id)
        
        # Auto-calculate capacity if not provided
        if aircraft_data.capacity is None:
            if template.seat_map and "seats" in template.seat_map:
                aircraft_data.capacity = len(template.seat_map["seats"])
            else:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Выбранный шаблон мест поврежден (отсутствует карта мест)"
                )

        # Registration uniqueness check
        existing = db.query(Aircraft).filter(
            Aircraft.registration_number == aircraft_data.registration_number
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Самолёт с таким регистрационным номером уже существует"
            )
        
        aircraft = Aircraft(**aircraft_data.model_dump())
        db.add(aircraft)
        db.commit()
        db.refresh(aircraft)
        return aircraft
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Error creating aircraft: {str(e)}")


def get_aircrafts(db: Session) -> List[Aircraft]:
    """Returns a list of all aircraft in the system."""
    return db.query(Aircraft).all()


def get_aircraft_by_id(db: Session, aircraft_id: int) -> Aircraft:
    """Fetches aircraft by ID or raises 404."""
    aircraft = db.query(Aircraft).filter(Aircraft.id == aircraft_id).first()
    if not aircraft:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Самолёт не найден"
        )
    return aircraft


def delete_aircraft(db: Session, aircraft_id: int) -> bool:
    """
    Safely deletes an aircraft and handles dependencies.
    - Cancels all associated flights.
    - Cancels all bookings/tickets for those flights.
    - Notifies passengers via system announcements.
    """
    from app.models.flight import Flight as FlightModel, FlightStatus
    from app.models.booking import Booking as BookingModel, BookingStatus
    from app.models.announcement import Announcement as AnnouncementModel

    aircraft = get_aircraft_by_id(db, aircraft_id)
    
    try:
        # 1. Find all flights associated with this aircraft
        flights = db.query(FlightModel).filter(FlightModel.aircraft_id == aircraft_id).all()
        
        for flight in flights:
            # 2. Cancel the flight
            flight.status = FlightStatus.CANCELLED
            flight.aircraft_id = None # Decouple from aircraft

            # 3. Find all bookings for this flight
            bookings = db.query(BookingModel).filter(
                BookingModel.flight_id == flight.id,
                BookingModel.status != BookingStatus.CANCELLED
            ).all()

            for booking in bookings:
                # 4. Cancel the booking
                booking.status = BookingStatus.CANCELLED
                
                # 5. Notify the passenger via Announcement
                notification = AnnouncementModel(
                    title="Рейс отменен",
                    message=f"Уважаемый пассажир, ваш рейс {flight.flight_number} был отменен в связи с заменой воздушного судна. Ваше бронирование {booking.seat_number} аннулировано.",
                    flight_id=flight.id,
                    created_by=booking.passenger_id
                )
                db.add(notification)

        # 6. Delete the aircraft itself
        db.delete(aircraft)
        db.commit()
        return True
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete aircraft: {str(e)}")


def delete_seat_template(db: Session, template_id: int) -> bool:
    """
    Deletes a seat template if it's not currently used by any aircraft.
    """
    template = get_seat_template_by_id(db, template_id)
    
    # Usage check
    in_use = db.query(Aircraft).filter(Aircraft.seat_template_id == template_id).first()
    if in_use:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя удалить шаблон, который используется в самолётах"
        )
        
    try:
        db.delete(template)
        db.commit()
        return True
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete template: {str(e)}")



