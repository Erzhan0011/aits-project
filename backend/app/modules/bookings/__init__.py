"""
Bookings module.
Управление бронированиями и билетами.
"""
from app.modules.bookings.routes import router as bookings_router

__all__ = ["bookings_router"]
