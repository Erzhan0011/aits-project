"""
Database session management.
Единая точка доступа к сессиям БД.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator

from app.core.config import settings


# Создание engine
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {},
    echo=settings.DEBUG,
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    """
    Dependency для получения сессии БД.
    Автоматически закрывает сессию после использования.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
