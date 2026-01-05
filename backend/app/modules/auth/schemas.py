"""
Auth Schemas (DTO).
Pydantic модели для валидации входных/выходных данных.
"""
from pydantic import BaseModel, EmailStr, Field
from typing import Optional


# ─────────────────────────────────────────
# Request DTOs
# ─────────────────────────────────────────

class UserRegisterRequest(BaseModel):
    """Запрос на регистрацию."""
    email: EmailStr
    password: str = Field(..., min_length=6, description="Минимум 6 символов")
    first_name: str = Field(..., min_length=1)
    last_name: str = Field(..., min_length=1)


class TokenRefreshRequest(BaseModel):
    """Запрос на обновление токена."""
    refresh_token: str


# ─────────────────────────────────────────
# Response DTOs
# ─────────────────────────────────────────

class TokenResponse(BaseModel):
    """Ответ с токенами авторизации."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    """Публичные данные пользователя."""
    id: int
    email: str
    first_name: str
    last_name: str
    full_name: Optional[str] = None
    role: str
    is_active: bool
    
    class Config:
        from_attributes = True
