"""
Auth Use Cases.
Application Layer: сценарии использования для аутентификации.
"""
from dataclasses import dataclass
from typing import Optional

from app.domain.interfaces import IUnitOfWork
from app.domain.entities import UserEntity, UserRole
from app.core.security import get_password_hash, verify_password, create_access_token, create_refresh_token


@dataclass
class RegisterUserRequest:
    """DTO запроса регистрации."""
    email: str
    password: str
    first_name: str
    last_name: str


@dataclass
class AuthResponse:
    """DTO ответа аутентификации."""
    success: bool
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    error_message: Optional[str] = None


class RegisterUserUseCase:
    """
    Use Case: Регистрация пользователя.
    
    Сценарий:
    1. Проверить уникальность email
    2. Создать UserEntity
    3. Хэшировать пароль
    4. Сохранить
    5. Сгенерировать токены
    """
    
    def __init__(self, uow: IUnitOfWork):
        self.uow = uow
    
    def execute(self, request: RegisterUserRequest) -> AuthResponse:
        """Выполнить регистрацию."""
        with self.uow:
            # 1. Проверить уникальность
            existing = self.uow.users.get_by_email(request.email)
            if existing:
                return AuthResponse(
                    success=False,
                    error_message="Пользователь с таким email уже существует"
                )
            
            # 2. Создать Entity
            user = UserEntity(
                id=None,
                email=request.email,
                hashed_password=get_password_hash(request.password),
                first_name=request.first_name,
                last_name=request.last_name,
                role=UserRole.PASSENGER,
                is_active=True,
            )
            
            # 3. Сохранить
            saved_user = self.uow.users.save(user)
            self.uow.commit()
            
            # 4. Сгенерировать токены
            return AuthResponse(
                success=True,
                access_token=create_access_token(data={"sub": str(saved_user.id)}),
                refresh_token=create_refresh_token(data={"sub": str(saved_user.id)}),
            )


@dataclass
class LoginRequest:
    """DTO запроса входа."""
    email: str
    password: str


class LoginUserUseCase:
    """
    Use Case: Вход в систему.
    """
    
    def __init__(self, uow: IUnitOfWork):
        self.uow = uow
    
    def execute(self, request: LoginRequest) -> AuthResponse:
        """Выполнить аутентификацию."""
        with self.uow:
            # 1. Найти пользователя
            user = self.uow.users.get_by_email(request.email)
            
            if not user:
                return AuthResponse(
                    success=False,
                    error_message="Неверный email или пароль"
                )
            
            # 2. Проверить пароль
            if not verify_password(request.password, user.hashed_password):
                return AuthResponse(
                    success=False,
                    error_message="Неверный email или пароль"
                )
            
            # 3. Проверить активность (бизнес-правило Entity)
            if not user.can_book_flights():
                return AuthResponse(
                    success=False,
                    error_message="Аккаунт заблокирован"
                )
            
            # 4. Сгенерировать токены
            return AuthResponse(
                success=True,
                access_token=create_access_token(data={"sub": str(user.id)}),
                refresh_token=create_refresh_token(data={"sub": str(user.id)}),
            )
