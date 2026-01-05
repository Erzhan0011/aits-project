from pydantic import BaseModel

class Airport(BaseModel):
    """Airport schema for API responses"""
    id: int
    name: str
    city: str
    country: str
    code: str
    
    class Config:
        from_attributes = True
