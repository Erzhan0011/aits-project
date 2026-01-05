"""
Infrastructure Layer.
Реализации интерфейсов домена для конкретных технологий (SQLAlchemy, Redis, etc.)
"""
from app.infrastructure.unit_of_work import SqlAlchemyUnitOfWork

__all__ = ["SqlAlchemyUnitOfWork"]
