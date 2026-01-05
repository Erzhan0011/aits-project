"""
Announcement Service.
Управление объявлениями и уведомлениями системы.
"""
from datetime import datetime, timedelta
from typing import List

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session, joinedload
from fastapi import HTTPException, status

from app.models.announcement import Announcement
from app.models.booking import Booking, BookingStatus, SeatHold
from app.models.flight import Flight
from app.models.user import User, UserRole
from app.schemas.announcement import AnnouncementCreate



def create_announcement(
    db: Session,
    announcement_data: AnnouncementCreate,
    created_by: int
) -> Announcement:
    """Creates a new announcement, optionally linked to a specific flight."""
    try:
        # Validate flight exists if provided
        if announcement_data.flight_id is not None:
            flight = db.query(Flight).filter(Flight.id == announcement_data.flight_id).first()
            if not flight:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Рейс не найден"
                )
        
        announcement = Announcement(
            **announcement_data.model_dump(),
            created_by=created_by
        )
        db.add(announcement)
        db.commit()
        db.refresh(announcement)
        return announcement
    except Exception as e:
        db.rollback()
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Error creating announcement: {str(e)}")


def get_flight_announcements(db: Session, flight_id: int) -> List[Announcement]:
    """Retrieves all announcements for a specific flight, sorted by date."""
    return db.query(Announcement).filter(
        Announcement.flight_id == flight_id
    ).order_by(Announcement.created_at.desc()).all()


def get_announcement_by_id(db: Session, announcement_id: int) -> Announcement:
    """Fetches an announcement by ID or raises 404."""
    announcement = db.query(Announcement).filter(Announcement.id == announcement_id).first()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Объявление не найдено"
        )
    return announcement


def delete_announcement(db: Session, announcement_id: int) -> None:
    """Deletes an announcement."""
    announcement = get_announcement_by_id(db, announcement_id)
    try:
        db.delete(announcement)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete announcement: {str(e)}")


def get_user_announcements(db: Session, current_user: User) -> List[Announcement]:

    """
    Fetches announcements relevant to the current user.
    Also performs proactive checks for expired holds and upcoming flights.
    """
    try:
        bookings = db.query(Booking).filter(Booking.passenger_id == current_user.id).all()
        relevant_flight_ids = [b.flight_id for b in bookings if b.status in [BookingStatus.CONFIRMED, BookingStatus.CREATED]]
        
        now = datetime.utcnow()
        holds = db.query(SeatHold).filter(SeatHold.passenger_id == current_user.id, SeatHold.expires_at > now).all()
        holds_map = { (h.flight_id, h.seat_number) for h in holds }
        
        for b in bookings:
            # 1. Cleanup expired CREATED bookings that lost their hold
            if b.status == BookingStatus.CREATED and (b.flight_id, b.seat_number) not in holds_map:
                b.status = BookingStatus.CANCELLED
                db.add(Announcement(
                    title="Время истекло", 
                    message=f"Бронь места {b.seat_number} на рейс {b.flight.flight_number} истекла.", 
                    flight_id=b.flight_id, 
                    created_by=current_user.id
                ))
            
            # 2. Alert for upcoming flights (within 1 hour)
            if b.status == BookingStatus.CONFIRMED:
                time_to_dep = b.flight.scheduled_departure - now
                if timedelta(minutes=0) < time_to_dep <= timedelta(minutes=65):
                    alert_title = "ВНИМАНИЕ: Вылет скоро"
                    existing_alert = db.query(Announcement).filter(
                        Announcement.flight_id == b.flight_id,
                        Announcement.created_by == current_user.id,
                        Announcement.title == alert_title
                    ).first()
                    
                    if not existing_alert:
                        db.add(Announcement(
                            title=alert_title,
                            message=f"Ваш рейс {b.flight.flight_number} ({b.flight.departure_city} -> {b.flight.arrival_city}) вылетает через 1 час! Пожалуйста, пройдите к гейту {b.flight.gate or 'не указан'}.",
                            flight_id=b.flight_id,
                            created_by=current_user.id,
                            created_at=now
                        ))
        db.commit()
    except Exception:
        db.rollback()
        # Non-critical failure in background checks shouldn't block message viewing
        pass
    
    # 3. Final query for all relevant messages
    staff_ids_subquery = db.query(User.id).filter(User.role.in_([UserRole.STAFF, UserRole.ADMIN])).scalar_subquery()
    
    announcements = db.query(Announcement).options(joinedload(Announcement.flight)).filter(
        or_(
            # Global announcements for my flights (made by staff)
            and_(Announcement.flight_id.in_(relevant_flight_ids), Announcement.created_by.in_(staff_ids_subquery)),
            # My individual history entries for my flights
            and_(Announcement.flight_id.in_(relevant_flight_ids), Announcement.created_by == current_user.id),
            # System-wide news or my personal notes
            and_(Announcement.flight_id.is_(None), or_(Announcement.created_by == current_user.id, Announcement.created_by.in_(staff_ids_subquery)))
        )).order_by(Announcement.created_at.desc()).all()
    
    return announcements


def list_all_announcements(db: Session) -> List[Announcement]:
    """Returns a list of all announcements (Staff view)."""
    return db.query(Announcement).order_by(Announcement.created_at.desc()).all()



