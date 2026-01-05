from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class Announcement(BaseModel):
    """Announcement schema for API responses"""
    id: int
    title: str
    message: str
    flight_id: Optional[int] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class AnnouncementCreate(BaseModel):
    """Schema for creating a new announcement"""
    flight_id: Optional[int] = None
    title: str
    message: str
