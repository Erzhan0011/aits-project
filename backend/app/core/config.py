"""
Конфигурация приложения.
Все секреты и настройки читаются из .env файла.
"""
from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List
import os


class Settings(BaseSettings):
    """
    Настройки приложения.
    Все значения читаются из переменных окружения или .env файла.
    """
    
    # ─────────────────────────────────────────
    # БЕЗОПАСНОСТЬ
    # ─────────────────────────────────────────
    SECRET_KEY: str = "dev-secret-key-change-in-production-32chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # ─────────────────────────────────────────
    # БАЗА ДАННЫХ
    # ─────────────────────────────────────────
    DATABASE_URL: str = "sqlite:///./airline.db"
    
    # ─────────────────────────────────────────
    # CORS
    # ─────────────────────────────────────────
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"
    
    # ─────────────────────────────────────────
    # РЕЖИМ РАБОТЫ
    # ─────────────────────────────────────────
    DEBUG: bool = True
    LOG_LEVEL: str = "INFO"
    
    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Проверяет, что SECRET_KEY достаточно длинный."""
        if len(v) < 32:
            raise ValueError("SECRET_KEY должен быть минимум 32 символа для безопасности")
        return v
    
    @property
    def allowed_origins_list(self) -> List[str]:
        """Возвращает список разрешённых origins для CORS."""
        if not self.ALLOWED_ORIGINS:
            return []
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"  # Игнорировать неизвестные переменные


# Создаём экземпляр настроек
settings = Settings()


# Проверка при запуске
if __name__ == "__main__":
    print("=" * 50)
    print("Zhan Airline - Конфигурация")
    print("=" * 50)
    print(f"SECRET_KEY: {'*' * 8}...{'*' * 8} (скрыто)")
    print(f"ALGORITHM: {settings.ALGORITHM}")
    print(f"ACCESS_TOKEN_EXPIRE_MINUTES: {settings.ACCESS_TOKEN_EXPIRE_MINUTES}")
    print(f"REFRESH_TOKEN_EXPIRE_DAYS: {settings.REFRESH_TOKEN_EXPIRE_DAYS}")
    print(f"DATABASE_URL: {settings.DATABASE_URL}")
    print(f"ALLOWED_ORIGINS: {settings.allowed_origins_list}")
    print(f"DEBUG: {settings.DEBUG}")
    print(f"LOG_LEVEL: {settings.LOG_LEVEL}")
    print("=" * 50)
