"""
Кастомные исключения приложения.
Обеспечивают единообразную обработку ошибок без утечки внутренних деталей.
"""
from fastapi import HTTPException, status


class AppException(HTTPException):
    """
    Базовый класс для всех исключений приложения.
    Наследуется от HTTPException для автоматической обработки FastAPI.
    """
    def __init__(
        self, 
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail: str = "Внутренняя ошибка сервера"
    ):
        super().__init__(status_code=status_code, detail=detail)


# ─────────────────────────────────────────
# Ошибки аутентификации (401, 403)
# ─────────────────────────────────────────

class AuthenticationError(AppException):
    """Ошибка аутентификации (неверные credentials)."""
    def __init__(self, detail: str = "Неверный email или пароль"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail
        )


class TokenError(AppException):
    """Ошибка токена (истёк, невалидный)."""
    def __init__(self, detail: str = "Недействительный или просроченный токен"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail
        )


class PermissionDenied(AppException):
    """Недостаточно прав доступа."""
    def __init__(self, detail: str = "Недостаточно прав для выполнения операции"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )


class AccountDisabled(AppException):
    """Аккаунт заблокирован."""
    def __init__(self, detail: str = "Аккаунт заблокирован"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )


# ─────────────────────────────────────────
# Ошибки валидации (400)
# ─────────────────────────────────────────

class ValidationError(AppException):
    """Ошибка валидации входных данных."""
    def __init__(self, detail: str = "Некорректные данные"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )


class UserExistsError(AppException):
    """Пользователь с таким email уже существует."""
    def __init__(self, detail: str = "Пользователь с таким email уже зарегистрирован"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )


class InvalidPasswordError(AppException):
    """Пароль не соответствует требованиям."""
    def __init__(self, detail: str = "Пароль должен содержать минимум 6 символов"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )


# ─────────────────────────────────────────
# Ошибки бизнес-логики (400, 409)
# ─────────────────────────────────────────

class SeatNotAvailable(AppException):
    """Место уже занято или зарезервировано."""
    def __init__(self, seat_number: str = ""):
        detail = f"Место {seat_number} уже занято" if seat_number else "Место уже занято"
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail=detail
        )


class BookingNotAllowed(AppException):
    """Бронирование недоступно (время вышло, рейс отменён)."""
    def __init__(self, detail: str = "Бронирование на этот рейс недоступно"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )


class CheckInNotAllowed(AppException):
    """Регистрация недоступна."""
    def __init__(self, detail: str = "Регистрация на рейс недоступна в данный момент"):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail
        )


class FlightConflict(AppException):
    """Конфликт расписания (самолёт занят)."""
    def __init__(self, detail: str = "Конфликт расписания: самолёт уже занят"):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail=detail
        )


# ─────────────────────────────────────────
# Ошибки не найдено (404)
# ─────────────────────────────────────────

class NotFoundError(AppException):
    """Ресурс не найден."""
    def __init__(self, resource: str = "Ресурс"):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"{resource} не найден"
        )


class UserNotFound(NotFoundError):
    """Пользователь не найден."""
    def __init__(self):
        super().__init__("Пользователь")


class FlightNotFound(NotFoundError):
    """Рейс не найден."""
    def __init__(self):
        super().__init__("Рейс")


class BookingNotFound(NotFoundError):
    """Бронирование не найдено."""
    def __init__(self):
        super().__init__("Бронирование")


class AirportNotFound(NotFoundError):
    """Аэропорт не найден."""
    def __init__(self):
        super().__init__("Аэропорт")


# ─────────────────────────────────────────
# Ошибки оплаты (402)
# ─────────────────────────────────────────

class PaymentError(AppException):
    """Ошибка оплаты."""
    def __init__(self, detail: str = "Ошибка при обработке платежа"):
        super().__init__(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=detail
        )


class PaymentDeclined(PaymentError):
    """Платёж отклонён."""
    def __init__(self):
        super().__init__("Платёж отклонён банком. Проверьте данные карты.")
