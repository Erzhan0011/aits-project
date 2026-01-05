"""
Auth Service.
Бизнес-логика аутентификации и авторизации.
"""
from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import UserRegisterRequest, TokenResponse
from app.core.security import get_password_hash, verify_password, create_access_token, create_refresh_token
from app.core.exceptions import AuthenticationError, UserExistsError, TokenError
from app.models.user import User, UserRole


class AuthService:
    """
    Сервис аутентификации.
    Содержит всю бизнес-логику, не знает о HTTP.
    """
    
    def __init__(self, repository: AuthRepository):
        self.repository = repository
    
    def register(self, data: UserRegisterRequest) -> TokenResponse:
        """
        Регистрация нового пользователя.
        
        Raises:
            UserExistsError: Если email уже занят
        """
        if self.repository.email_exists(data.email):
            raise UserExistsError()
        
        user = self.repository.create({
            "email": data.email,
            "hashed_password": get_password_hash(data.password),
            "first_name": data.first_name,
            "last_name": data.last_name,
            "full_name": f"{data.first_name} {data.last_name}",
            "role": UserRole.PASSENGER,
        })
        
        return self._generate_tokens(user)
    
    def authenticate(self, email: str, password: str) -> TokenResponse:
        """
        Аутентификация пользователя.
        
        Raises:
            AuthenticationError: Если credentials неверны
        """
        user = self.repository.get_by_email(email)
        
        if not user:
            raise AuthenticationError("Неверный email или пароль")
        
        if not verify_password(password, user.hashed_password):
            raise AuthenticationError("Неверный email или пароль")
        
        if not user.is_active:
            raise AuthenticationError("Аккаунт заблокирован")
        
        return self._generate_tokens(user)
    
    def refresh_tokens(self, user_id: int) -> TokenResponse:
        """
        Обновление токенов по refresh token.
        
        Raises:
            TokenError: Если пользователь не найден
        """
        user = self.repository.get_by_id(user_id)
        
        if not user or not user.is_active:
            raise TokenError("Пользователь не найден или заблокирован")
        
        return self._generate_tokens(user)
    
    def _generate_tokens(self, user: User) -> TokenResponse:
        """Генерация пары токенов для пользователя."""
        return TokenResponse(
            access_token=create_access_token(data={"sub": str(user.id)}),
            refresh_token=create_refresh_token(data={"sub": str(user.id)}),
        )
