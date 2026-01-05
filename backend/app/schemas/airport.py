from pydantic import BaseModel
from typing import List
from .airport_base import Airport


class AirportCreate(BaseModel):
    """Schema for creating a new airport"""
    name: str
    city: str
    country: str
    code: str


class AirportDetail(Airport):
    """Detailed airport schema including flights"""
    origin_flights: List['Flight'] = []
    destination_flights: List['Flight'] = []

    class Config:
        from_attributes = True

from app.schemas.flight import Flight
AirportDetail.update_forward_refs()
