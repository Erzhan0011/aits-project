"""
Dependencies for FastAPI routes.
Handles authentication and authorization.
"""
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.security import decode_access_token
from app.models.user import User, UserRole

# OAuth2 scheme for token extraction
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")


from sqlalchemy.orm import Session
from app.core.database import get_db

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    """
    Get current authenticated user from JWT token.
    Raises 401 if token is invalid or user not found.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # Decode token
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    # Get user ID from token
    user_id_raw = payload.get("sub")
    if user_id_raw is None:
        raise credentials_exception
    
    try:
        user_id = int(user_id_raw)
    except (ValueError, TypeError):
        raise credentials_exception
        
    # Get user from database
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    
    return user


def get_current_passenger(current_user: User = Depends(get_current_user)) -> User:
    """
    Get current user and verify they can act as a passenger.
    Allows PASSENGER, STAFF, and ADMIN roles.
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    return current_user


def get_current_staff(current_user: User = Depends(get_current_user)) -> User:
    """
    Get current user and verify they are staff.
    Raises 403 if user is not staff.
    For future use when staff module is implemented.
    """
    if current_user.role not in [UserRole.STAFF, UserRole.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions. Staff access required."
        )
    return current_user
