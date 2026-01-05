from sqlalchemy import Column, Integer, String, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.core.database import Base


class Aircraft(Base):
    __tablename__ = "aircrafts"

    id = Column(Integer, primary_key=True, index=True)
    model = Column(String, nullable=False)
    registration_number = Column(String, unique=True, index=True, nullable=False)
    capacity = Column(Integer, nullable=False)
    seat_template_id = Column(Integer, ForeignKey("seat_templates.id"), nullable=False)

    # Relationships
    seat_template = relationship("SeatTemplate", back_populates="aircrafts")
    flights = relationship("Flight", back_populates="aircraft")


class SeatTemplate(Base):
    __tablename__ = "seat_templates"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    
    # Configuration for generator
    row_count = Column(Integer, nullable=False, default=20)
    seat_letters = Column(String, nullable=False, default="ABC DEF") # Letters with space for aisle
    business_rows = Column(String, nullable=True) # e.g. "1-3"
    economy_rows = Column(String, nullable=True)  # e.g. "4-20"
    
    seat_map = Column(JSON, nullable=False)  # Generated JSON structure

    # Relationships
    aircrafts = relationship("Aircraft", back_populates="seat_template")



