import sys
import os
from datetime import datetime, timedelta
import uuid

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from app.core.database import SessionLocal
from app.models.user import User, UserRole
from app.models.flight import Flight, FlightStatus
from app.models.airport import Airport
from app.models.booking import Booking, BookingStatus, SeatHold, PaymentMethod
from app.schemas.seat import BookWithPassengersRequest, PassengerInfo
from app.services.booking_service import create_bookings_with_passengers, hold_seats

def reproduce():
    db = SessionLocal()
    try:
        print("--- Setting up test data ---")
        # 1. Create/Get User
        user = db.query(User).filter(User.email == "test_crash@example.com").first()
        if not user:
            user = User(
                email="test_crash@example.com",
                hashed_password="hash",
                role=UserRole.PASSENGER,
                first_name="Test",
                last_name="Crash",
                passport_number="123456",
                nationality="RU",
                date_of_birth=datetime(1990, 1, 1)
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        print(f"User ID: {user.id}")

        # 2. Create/Get Flight
        flight = db.query(Flight).filter(Flight.flight_number == "CRASH101").first()
        if not flight:
            # Need airports
            a1 = db.query(Airport).first()
            if not a1:
                a1 = Airport(code="A1", name="A1", city="City1", country="C1")
                db.add(a1)
                db.flush()
            
            flight = Flight(
                flight_number="CRASH101",
                origin_airport_id=a1.id,
                destination_airport_id=a1.id,
                scheduled_departure=datetime.utcnow() + timedelta(days=1),
                scheduled_arrival=datetime.utcnow() + timedelta(days=1, hours=2),
                base_price=1000.0,
                status=FlightStatus.SCHEDULED
            )
            db.add(flight)
            db.commit()
            db.refresh(flight)
        print(f"Flight ID: {flight.id}")

        # 3. Hold Seats
        seats = ["1A", "1B"]
        print(f"Holding seats: {seats}")
        # Clear existing
        try:
            # Manual join-like delete or loose delete
            # Delete tickets for this flight
            from app.models.booking import Ticket
            from app.models.payment import Payment
            
            # Simple cleanup for test user
            db.query(Ticket).filter(Ticket.passenger_id == user.id).delete()
            db.query(Payment).filter(Payment.passenger_id == user.id).delete()
            db.query(Booking).filter(Booking.passenger_id == user.id).delete()
            db.query(SeatHold).filter(SeatHold.passenger_id == user.id).delete()
            db.commit()
        except:
            db.rollback()
        
        # Create holds (using service logic mostly)
        expires_at = datetime.utcnow() + timedelta(minutes=10)
        for seat in seats:
            db.add(SeatHold(
                flight_id=flight.id,
                seat_number=seat,
                passenger_id=user.id,
                expires_at=expires_at
            ))
            # Also need CREATED bookings as per hold_seats logic
            db.add(Booking(
                pnr=None, # generated later? No, hold_seats generates it.
                passenger_id=user.id,
                flight_id=flight.id,
                seat_number=seat,
                price=flight.base_price,
                status=BookingStatus.CREATED,
                created_at=datetime.utcnow()
            ))
        db.commit()
        print("Seats held and CREATED bookings inserted.")

        # 4. Try Booking
        print("--- Attempting Booking ---")
        req = BookWithPassengersRequest(
            passengers=[
                PassengerInfo(seat_number="1A", first_name="P1", last_name="L1", passport_number="111", date_of_birth=None),
                PassengerInfo(seat_number="1B", first_name="P2", last_name="L2", passport_number="222", date_of_birth=None)
            ],
            payment_method="CARD"
        )
        
        resp = create_bookings_with_passengers(db, flight.id, req, user.id)
        print("SUCCESS!")
        print(resp)
        
        # Verify payments
        payments = db.query(Payment).filter(Payment.passenger_id == user.id).order_by(Payment.id.desc()).limit(2).all()
        print(f"Found {len(payments)} payments.")
        for p in payments:
            print(f"Payment {p.id}: TransID={p.transaction_id}, Booking={p.booking_id}")
            
        if len(payments) == 2 and payments[0].transaction_id == payments[1].transaction_id:
             print("VERIFICATION PASSED: Multipax transaction succeeded with shared ID.")
        else:
             print("VERIFICATION FAILED: Payments not grouped or missing.")
    except Exception as e:
        print("\n!!! EXCEPTION CAUGHT !!!")
        print(e)
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    reproduce()
