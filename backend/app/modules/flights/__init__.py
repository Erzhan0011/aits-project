"""
Flights module.
Управление рейсами, аэропортами и самолётами.
"""
from app.modules.flights.routes import router as flights_router

__all__ = ["flights_router"]
