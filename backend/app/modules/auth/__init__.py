"""
Auth module.
Модуль аутентификации и авторизации.
"""
from app.modules.auth.routes import router as auth_router
from app.modules.auth.dependencies import get_current_user, get_current_staff, get_current_admin

__all__ = ["auth_router", "get_current_user", "get_current_staff", "get_current_admin"]
