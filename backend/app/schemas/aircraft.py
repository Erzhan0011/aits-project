from pydantic import BaseModel
from typing import Dict, Any, List, Optional


class SeatTemplateBase(BaseModel):
    name: str
    row_count: int
    seat_letters: str
    business_rows: Optional[str] = None
    economy_rows: Optional[str] = None
    seat_map: Optional[Dict[str, Any]] = None


class SeatTemplateCreate(SeatTemplateBase):
    pass


class SeatTemplate(SeatTemplateBase):
    id: int

    class Config:
        from_attributes = True


class AircraftBase(BaseModel):
    model: str
    registration_number: str
    capacity: Optional[int] = None
    seat_template_id: int


class AircraftCreate(AircraftBase):
    pass


class Aircraft(AircraftBase):
    id: int
    seat_template: SeatTemplate

    class Config:
        from_attributes = True



class AircraftDetail(Aircraft):
    """Detailed aircraft schema including flights"""
    flights: List['Flight'] = []

    class Config:
        from_attributes = True

from app.schemas.flight import Flight
AircraftDetail.update_forward_refs()
