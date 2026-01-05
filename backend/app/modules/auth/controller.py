"""
Auth Controller.
Оркестрирует взаимодействие между Routes и Service.
"""
from sqlalchemy.orm import Session

from app.modules.auth.service import AuthService
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import UserRegisterRequest, TokenResponse, UserResponse
from app.models.user import User


class AuthController:
    """
    Контроллер аутентификации.
    Создаёт зависимости и делегирует работу Service.
    """
    
    def __init__(self, db: Session):
        self.repository = AuthRepository(db)
        self.service = AuthService(self.repository)
    
    def register(self, data: UserRegisterRequest) -> TokenResponse:
        """Регистрация нового пользователя."""
        return self.service.register(data)
    
    def login(self, email: str, password: str) -> TokenResponse:
        """Вход в систему."""
        return self.service.authenticate(email, password)
    
    def refresh(self, user_id: int) -> TokenResponse:
        """Обновление токенов."""
        return self.service.refresh_tokens(user_id)
    
    def get_profile(self, user: User) -> UserResponse:
        """Получение профиля текущего пользователя."""
        return UserResponse.model_validate(user)
