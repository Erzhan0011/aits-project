"""
Database base models.
Содержит декларативную базу и базовые классы моделей.
"""
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import Column, Integer, DateTime
from datetime import datetime


class Base(DeclarativeBase):
    """Базовый класс для всех моделей."""
    pass


class TimestampMixin:
    """
    Mixin для автоматических timestamps.
    Добавляет created_at и updated_at к модели.
    """
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
