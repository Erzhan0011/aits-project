"""
Auth Repository.
Единственная точка доступа к БД для модуля auth.
"""
from typing import Optional
from sqlalchemy.orm import Session

from app.models.user import User


class AuthRepository:
    """
    Репозиторий для операций аутентификации.
    Инкапсулирует все запросы к БД.
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_by_email(self, email: str) -> Optional[User]:
        """Найти пользователя по email."""
        return self.db.query(User).filter(User.email == email).first()
    
    def get_by_id(self, user_id: int) -> Optional[User]:
        """Найти пользователя по ID."""
        return self.db.query(User).filter(User.id == user_id).first()
    
    def email_exists(self, email: str) -> bool:
        """Проверить существование email."""
        return self.get_by_email(email) is not None
    
    def create(self, user_data: dict) -> User:
        """Создать нового пользователя."""
        user = User(**user_data)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
    
    def update_password(self, user: User, hashed_password: str) -> User:
        """Обновить пароль пользователя."""
        user.hashed_password = hashed_password
        self.db.commit()
        self.db.refresh(user)
        return user
