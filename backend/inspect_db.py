from app.core.database import SessionLocal
from app.models.booking import SeatHold
from datetime import datetime, timezone

db = SessionLocal()
holds = db.query(SeatHold).all()
print(f"Total holds: {len(holds)}")
for h in holds:
    print(f"Hold ID: {h.id}, Seat: {h.seat_number}, Expires: {h.expires_at}, Raw Type: {type(h.expires_at)}")
    
print(f"Current UTC: {datetime.now(timezone.utc)}")
