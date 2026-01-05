"""
Базовый репозиторий.
Реализует паттерн Repository для чистого разделения data access и business logic.
"""
from typing import TypeVar, Generic, Type, Optional, List, Any
from sqlalchemy.orm import Session
from sqlalchemy import and_

# Тип для generic модели
ModelType = TypeVar("ModelType")


class BaseRepository(Generic[ModelType]):
    """
    Базовый репозиторий с CRUD операциями.
    
    Наследники могут добавлять специфичные методы для своих моделей.
    
    Пример использования:
        class UserRepository(BaseRepository[User]):
            def __init__(self, db: Session):
                super().__init__(User, db)
            
            def get_by_email(self, email: str) -> Optional[User]:
                return self.db.query(User).filter(User.email == email).first()
    """
    
    def __init__(self, model: Type[ModelType], db: Session):
        """
        Инициализация репозитория.
        
        Args:
            model: SQLAlchemy модель
            db: Сессия базы данных
        """
        self.model = model
        self.db = db
    
    def get(self, id: int) -> Optional[ModelType]:
        """Получить запись по ID."""
        return self.db.query(self.model).filter(self.model.id == id).first()
    
    def get_or_404(self, id: int) -> ModelType:
        """Получить запись по ID или выбросить исключение."""
        obj = self.get(id)
        if not obj:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail=f"{self.model.__name__} not found")
        return obj
    
    def get_multi(
        self, 
        skip: int = 0, 
        limit: int = 100,
        order_by: Any = None
    ) -> List[ModelType]:
        """
        Получить список записей с пагинацией.
        
        Args:
            skip: Количество пропускаемых записей
            limit: Максимальное количество записей
            order_by: Поле для сортировки (опционально)
        """
        query = self.db.query(self.model)
        if order_by is not None:
            query = query.order_by(order_by)
        return query.offset(skip).limit(limit).all()
    
    def get_all(self) -> List[ModelType]:
        """Получить все записи."""
        return self.db.query(self.model).all()
    
    def create(self, obj_in: dict) -> ModelType:
        """
        Создать новую запись.
        
        Args:
            obj_in: Словарь с данными для создания
        
        Returns:
            Созданный объект
        """
        db_obj = self.model(**obj_in)
        self.db.add(db_obj)
        self.db.commit()
        self.db.refresh(db_obj)
        return db_obj
    
    def create_no_commit(self, obj_in: dict) -> ModelType:
        """Создать без коммита (для транзакций)."""
        db_obj = self.model(**obj_in)
        self.db.add(db_obj)
        self.db.flush()
        return db_obj
    
    def update(self, db_obj: ModelType, obj_in: dict) -> ModelType:
        """
        Обновить существующую запись.
        
        Args:
            db_obj: Существующий объект
            obj_in: Словарь с новыми данными
        
        Returns:
            Обновлённый объект
        """
        for field, value in obj_in.items():
            if hasattr(db_obj, field) and value is not None:
                setattr(db_obj, field, value)
        self.db.commit()
        self.db.refresh(db_obj)
        return db_obj
    
    def delete(self, id: int) -> bool:
        """
        Удалить запись по ID.
        
        Returns:
            True если удалено, False если не найдено
        """
        obj = self.get(id)
        if obj:
            self.db.delete(obj)
            self.db.commit()
            return True
        return False
    
    def delete_obj(self, obj: ModelType) -> bool:
        """Удалить переданный объект."""
        self.db.delete(obj)
        self.db.commit()
        return True
    
    def exists(self, id: int) -> bool:
        """Проверить существование записи по ID."""
        return self.db.query(self.model).filter(self.model.id == id).first() is not None
    
    def count(self) -> int:
        """Подсчитать количество записей."""
        return self.db.query(self.model).count()
    
    def filter_by(self, **kwargs) -> List[ModelType]:
        """
        Фильтрация по произвольным полям.
        
        Пример:
            repo.filter_by(status="active", role="admin")
        """
        filters = [getattr(self.model, k) == v for k, v in kwargs.items() if hasattr(self.model, k)]
        return self.db.query(self.model).filter(and_(*filters)).all() if filters else []
