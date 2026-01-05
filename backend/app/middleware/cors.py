"""
CORS Middleware.
Настраивает безопасную политику Cross-Origin Resource Sharing.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings


def setup_cors(app: FastAPI) -> None:
    """
    Настраивает CORS middleware для приложения.
    
    В режиме DEBUG:
        - Разрешает localhost origins динамически
        - Более мягкие ограничения для разработки
    
    В режиме PRODUCTION:
        - Строгий whitelist из ALLOWED_ORIGINS
        - Только указанные методы и заголовки
    """
    
    # Список разрешенных методов (всегда включаем OPTIONS)
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    
    # Список разрешенных заголовков (расширенный для Flutter Web и SPA)
    allowed_headers = [
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "X-Requested-With",
        "X-Request-ID",
        "Access-Control-Request-Method",
        "Access-Control-Request-Headers",
    ]

    if settings.DEBUG:
        # Режим разработки: динамическое разрешение localhost порта
        # Полезно для Flutter Web, который запускается на случайных портах
        app.add_middleware(
            CORSMiddleware,
            allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
            allow_credentials=True,
            allow_methods=allowed_methods,
            allow_headers=["*"],
            expose_headers=["X-Request-ID"],
            max_age=3600,
        )
    else:
        # Production режим: строгий whitelist из конфига
        if not settings.allowed_origins_list:
            raise ValueError(
                "ALLOWED_ORIGINS must be set in production mode! "
                "Example: ALLOWED_ORIGINS=https://your-domain.com"
            )
        
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.allowed_origins_list,
            allow_credentials=True,
            allow_methods=allowed_methods,
            allow_headers=allowed_headers,
            expose_headers=["X-Request-ID"],
            max_age=86400,  # Кэширование preflight на 24 часа в prod
        )
