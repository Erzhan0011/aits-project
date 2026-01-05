"""
Auth Routes.
HTTP слой — только маршрутизация, без бизнес-логики.
"""
from fastapi import APIRouter, Depends, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.controller import AuthController
from app.modules.auth.schemas import UserRegisterRequest, TokenResponse, UserResponse, TokenRefreshRequest
from app.modules.auth.dependencies import get_current_user
from app.core.security import decode_access_token
from app.models.user import User


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(data: UserRegisterRequest, db: Session = Depends(get_db)):
    """Регистрация нового пассажира."""
    controller = AuthController(db)
    return controller.register(data)


@router.post("/token", response_model=TokenResponse)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Вход в систему (OAuth2 совместимый)."""
    controller = AuthController(db)
    return controller.login(form_data.username, form_data.password)


@router.post("/login", response_model=TokenResponse)
def login_alternative(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Альтернативный эндпоинт входа."""
    controller = AuthController(db)
    return controller.login(form_data.username, form_data.password)


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(request: TokenRefreshRequest, db: Session = Depends(get_db)):
    """Обновление токена доступа."""
    payload = decode_access_token(request.refresh_token, token_type="refresh")
    if not payload:
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail="Невалидный refresh token")
    
    user_id = int(payload.get("sub"))
    controller = AuthController(db)
    return controller.refresh(user_id)


@router.get("/me", response_model=UserResponse)
def get_current_user_profile(current_user: User = Depends(get_current_user)):
    """Получить профиль текущего пользователя."""
    return UserResponse.model_validate(current_user)
