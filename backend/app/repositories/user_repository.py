"""
Репозиторий пользователей.
Специализированные методы для работы с User моделью.
"""
from typing import Optional, List
from sqlalchemy.orm import Session

from app.repositories.base import BaseRepository
from app.models.user import User, UserRole


class UserRepository(BaseRepository[User]):
    """
    Репозиторий для работы с пользователями.
    
    Наследует базовые CRUD операции и добавляет специфичные методы.
    """
    
    def __init__(self, db: Session):
        super().__init__(User, db)
    
    def get_by_email(self, email: str) -> Optional[User]:
        """Найти пользователя по email."""
        return self.db.query(User).filter(User.email == email).first()
    
    def get_active_users(self) -> List[User]:
        """Получить всех активных пользователей."""
        return self.db.query(User).filter(User.is_active == True).all()
    
    def get_by_role(self, role: UserRole) -> List[User]:
        """Получить пользователей по роли."""
        return self.db.query(User).filter(User.role == role).all()
    
    def get_passengers(self) -> List[User]:
        """Получить всех пассажиров."""
        return self.get_by_role(UserRole.PASSENGER)
    
    def get_staff(self) -> List[User]:
        """Получить весь персонал (STAFF + ADMIN)."""
        return self.db.query(User).filter(
            User.role.in_([UserRole.STAFF, UserRole.ADMIN])
        ).all()
    
    def email_exists(self, email: str) -> bool:
        """Проверить, занят ли email."""
        return self.db.query(User).filter(User.email == email).first() is not None
    
    def deactivate(self, user_id: int) -> bool:
        """Деактивировать пользователя."""
        user = self.get(user_id)
        if user:
            user.is_active = False
            self.db.commit()
            return True
        return False
    
    def activate(self, user_id: int) -> bool:
        """Активировать пользователя."""
        user = self.get(user_id)
        if user:
            user.is_active = True
            self.db.commit()
            return True
        return False
    
    def update_password(self, user_id: int, hashed_password: str) -> bool:
        """Обновить пароль пользователя."""
        user = self.get(user_id)
        if user:
            user.hashed_password = hashed_password
            self.db.commit()
            return True
        return False
    
    def search(self, query: str, limit: int = 20) -> List[User]:
        """Поиск пользователей по имени или email."""
        search_term = f"%{query}%"
        return self.db.query(User).filter(
            (User.email.ilike(search_term)) |
            (User.first_name.ilike(search_term)) |
            (User.last_name.ilike(search_term))
        ).limit(limit).all()
