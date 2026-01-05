"""
Zhan Airline - Backend API
Точка входа приложения.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI

from app.core.database import Base, engine
from app.core.config import settings
from app.routes import auth, passenger, staff

# Middleware imports
from app.middleware.cors import setup_cors
from app.middleware.request_id import RequestIdMiddleware
from app.middleware.logging import RequestLoggingMiddleware, setup_logging


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events: startup and shutdown."""
    # Startup
    setup_logging()
    Base.metadata.create_all(bind=engine)
    yield
    # Shutdown (cleanup if needed)


# ─────────────────────────────────────────
# Создание приложения
# ─────────────────────────────────────────
app = FastAPI(
    title="Zhan Airline API",
    description="Backend API для системы бронирования авиабилетов",
    version="2.0.0",
    docs_url="/docs" if settings.DEBUG else None,  # Скрыть docs в production
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan
)


# ─────────────────────────────────────────
# Middleware Pipeline (порядок важен!)
# ─────────────────────────────────────────
# 1. Request ID (первый - для трассировки)
app.add_middleware(RequestIdMiddleware)

# 2. Logging (после Request ID, чтобы иметь доступ к ID)
app.add_middleware(RequestLoggingMiddleware)

# 3. CORS (настраивается отдельно)
setup_cors(app)


# ─────────────────────────────────────────
# Роутеры
# ─────────────────────────────────────────

# 1. Modular API (Clean Architecture 10/10)
from app.api.v1.router import api_v1_router
app.include_router(api_v1_router)

# 2. Legacy Routes (for backward compatibility)
app.include_router(auth.router)
app.include_router(passenger.router)
app.include_router(staff.router)


# ─────────────────────────────────────────
# Системные эндпоинты
# ─────────────────────────────────────────
@app.get("/", tags=["System"])
def root():
    """Корневой эндпоинт с информацией об API."""
    return {
        "name": "Zhan Airline API",
        "version": "2.0.0",
        "docs": "/docs" if settings.DEBUG else "disabled",
        "status": "operational"
    }


@app.get("/health", tags=["System"])
def health_check():
    """Health check для мониторинга."""
    return {
        "status": "healthy",
        "version": "2.0.0",
        "debug": settings.DEBUG
    }


# ─────────────────────────────────────────
# Запуск (для разработки)
# ─────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower()
    )
