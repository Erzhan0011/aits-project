"""
Logging Middleware.
Структурированное логирование всех HTTP запросов.
"""
import time
import logging
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response
from app.core.config import settings

# Настройка логгера
logger = logging.getLogger("airline.requests")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware для логирования HTTP запросов.
    
    Логирует:
        - Метод и путь запроса
        - Статус ответа
        - Время обработки
        - Request-ID для трассировки
    """
    
    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        # Время начала обработки
        start_time = time.perf_counter()
        
        # Получаем Request-ID (если Request-ID middleware уже отработал)
        request_id = getattr(request.state, "request_id", "unknown")
        
        # Базовая информация о запросе
        method = request.method
        path = request.url.path
        client_ip = request.client.host if request.client else "unknown"
        
        # Обрабатываем запрос
        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception as e:
            # Логируем ошибку
            logger.error(
                f"[{request_id}] {method} {path} - ERROR: {str(e)}",
                extra={
                    "request_id": request_id,
                    "method": method,
                    "path": path,
                    "client_ip": client_ip,
                    "error": str(e),
                }
            )
            raise
        
        # Время обработки
        process_time = (time.perf_counter() - start_time) * 1000  # в миллисекундах
        
        # Определяем уровень логирования по статусу
        if status_code >= 500:
            log_level = logging.ERROR
        elif status_code >= 400:
            log_level = logging.WARNING
        else:
            log_level = logging.INFO
        
        # Логируем запрос
        logger.log(
            log_level,
            f"[{request_id}] {method} {path} - {status_code} ({process_time:.2f}ms)",
            extra={
                "request_id": request_id,
                "method": method,
                "path": path,
                "status_code": status_code,
                "process_time_ms": process_time,
                "client_ip": client_ip,
            }
        )
        
        # Добавляем время обработки в заголовок
        response.headers["X-Process-Time"] = f"{process_time:.2f}ms"
        
        return response


def setup_logging() -> None:
    """
    Настраивает логирование для приложения.
    Вызывается при старте.
    """
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)
    
    # Формат логов
    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(log_level)
    
    # Настраиваем корневой логгер
    root_logger = logging.getLogger("airline")
    root_logger.setLevel(log_level)
    root_logger.addHandler(console_handler)
    
    # Уменьшаем шум от библиотек
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
