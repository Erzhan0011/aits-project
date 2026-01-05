"""
Request ID Middleware.
Добавляет уникальный идентификатор к каждому запросу для трассировки.
"""
import uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response


class RequestIdMiddleware(BaseHTTPMiddleware):
    """
    Middleware для добавления уникального Request-ID к каждому запросу.
    
    Использование:
        - Позволяет отслеживать запросы в логах
        - Помогает при отладке проблем
        - Клиент может передать свой X-Request-ID
    """
    
    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        # Используем ID от клиента или генерируем новый
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        
        # Сохраняем в state для доступа в обработчиках
        request.state.request_id = request_id
        
        # Обрабатываем запрос
        response = await call_next(request)
        
        # Добавляем ID в ответ
        response.headers["X-Request-ID"] = request_id
        
        return response
