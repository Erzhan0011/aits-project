"""
Auth Dependencies.
FastAPI Dependency Injection для авторизации.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.security import decode_access_token
from app.models.user import User, UserRole


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/token")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """
    Получить текущего аутентифицированного пользователя.
    
    Raises:
        HTTPException 401: Если токен невалиден
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Не удалось проверить учётные данные",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    user_id_raw = payload.get("sub")
    if user_id_raw is None:
        raise credentials_exception
    
    try:
        user_id = int(user_id_raw)
    except (ValueError, TypeError):
        raise credentials_exception
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    
    return user


def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Получить активного пользователя.
    
    Raises:
        HTTPException 403: Если аккаунт заблокирован
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Аккаунт заблокирован"
        )
    return current_user


def get_current_staff(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """
    Получить пользователя с правами персонала.
    
    Raises:
        HTTPException 403: Если недостаточно прав
    """
    if current_user.role not in [UserRole.STAFF, UserRole.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Требуются права персонала"
        )
    return current_user


def get_current_admin(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """
    Получить пользователя с правами администратора.
    
    Raises:
        HTTPException 403: Если недостаточно прав
    """
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Требуются права администратора"
        )
    return current_user
