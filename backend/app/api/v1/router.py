"""
API v1 Router.
Агрегирует все модули в единый API.
"""
from fastapi import APIRouter

from app.modules.auth.routes import router as auth_router
from app.modules.flights.routes import router as flights_router
from app.modules.bookings.routes import router as bookings_router


# Создаём главный v1 router
api_v1_router = APIRouter(prefix="/api/v1")

# Подключаем модули
api_v1_router.include_router(auth_router)
api_v1_router.include_router(flights_router)
api_v1_router.include_router(bookings_router)
