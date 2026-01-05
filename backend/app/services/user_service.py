"""
User Service.
Операции с профилями пользователей и административное управление.
"""
from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException

from app.models.user import User, UserRole
from app.schemas.user import UserUpdate


def update_user_profile(db: Session, user_id: int, user_data: UserUpdate) -> Optional[User]:
    """
    Updates user profile data with partial support.
    Automatically keeps full_name in sync with first/last names.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None
        
    try:
        update_dict = user_data.model_dump(exclude_unset=True)
        for field, value in update_dict.items():
            setattr(user, field, value)
            
        if 'first_name' in update_dict or 'last_name' in update_dict:
            user.full_name = f"{user.first_name} {user.last_name}"
            
        db.commit()
        db.refresh(user)
        return user
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update profile: {str(e)}")


def list_all_users(db: Session) -> List[User]:
    """Staff logic for listing all users in the system."""
    return db.query(User).all()


def delete_user_staff(db: Session, user_id: int, current_staff_id: int) -> None:
    """
    Administrative deletion of a passenger.
    Protects staff/admin accounts and self-deletion.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    if user.id == current_staff_id:
        raise HTTPException(status_code=400, detail="Вы не можете удалить свою собственную учетную запись.")
    
    if user.role != UserRole.PASSENGER:
        raise HTTPException(
            status_code=403, 
            detail="Ошибка доступа: Сотрудники и администраторы не могут быть удалены этим методом."
        )
        
    try:
        db.delete(user)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Deletion failed: {str(e)}")


def toggle_block_user_staff(db: Session, user_id: int) -> User:
    """
    Staff logic for blocking/unblocking a passenger.
    Protects other staff members from being blocked via this UI.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    if user.role != UserRole.PASSENGER:
        raise HTTPException(
            status_code=403, 
            detail="Ошибка доступа: Статус сотрудников и администраторов изменять нельзя."
        )
        
    try:
        user.is_active = not user.is_active
        db.commit()
        db.refresh(user)
        return user
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Toggle block failed: {str(e)}")
