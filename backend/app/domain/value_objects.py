"""
Value Objects.
Неизменяемые объекты, определяемые своими значениями, а не идентификатором.

Value Objects инкапсулируют валидацию и бизнес-правила для примитивных типов.
Они immutable и сравниваются по значению.
"""
from dataclasses import dataclass
from typing import Optional
import re


@dataclass(frozen=True)
class Email:
    """
    Value Object для email адреса.
    Инкапсулирует валидацию формата.
    """
    value: str
    
    def __post_init__(self):
        if not self._is_valid(self.value):
            raise ValueError(f"Некорректный email: {self.value}")
    
    @staticmethod
    def _is_valid(email: str) -> bool:
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))
    
    def __str__(self) -> str:
        return self.value


@dataclass(frozen=True)
class Password:
    """
    Value Object для пароля.
    Хранит хэш, не сам пароль.
    """
    hashed_value: str
    
    def __post_init__(self):
        if not self.hashed_value or len(self.hashed_value) < 10:
            raise ValueError("Некорректный хэш пароля")
    
    def __str__(self) -> str:
        return "********"  # Никогда не показываем хэш


@dataclass(frozen=True)
class Money:
    """
    Value Object для денежных сумм.
    Предотвращает ошибки с плавающей точкой.
    """
    amount: int  # Храним в копейках/центах
    currency: str = "RUB"
    
    def __post_init__(self):
        if self.amount < 0:
            raise ValueError("Сумма не может быть отрицательной")
    
    @classmethod
    def from_float(cls, value: float, currency: str = "RUB") -> "Money":
        """Создать из float (конвертирует в копейки)."""
        return cls(amount=int(value * 100), currency=currency)
    
    def to_float(self) -> float:
        """Конвертировать в float для отображения."""
        return self.amount / 100
    
    def add(self, other: "Money") -> "Money":
        """Сложить две суммы."""
        if self.currency != other.currency:
            raise ValueError("Нельзя складывать разные валюты")
        return Money(self.amount + other.amount, self.currency)
    
    def multiply(self, factor: float) -> "Money":
        """Умножить на коэффициент."""
        return Money(int(self.amount * factor), self.currency)
    
    def __str__(self) -> str:
        return f"{self.to_float():.2f} {self.currency}"


@dataclass(frozen=True)
class SeatNumber:
    """
    Value Object для номера места.
    Формат: ряд (число) + буква (A-K).
    """
    value: str
    
    def __post_init__(self):
        if not self._is_valid(self.value):
            raise ValueError(f"Некорректный номер места: {self.value}")
    
    @staticmethod
    def _is_valid(seat: str) -> bool:
        if not seat or len(seat) < 2:
            return False
        row = seat[:-1]
        letter = seat[-1].upper()
        return row.isdigit() and letter in "ABCDEFGHJK"
    
    @property
    def row(self) -> int:
        """Номер ряда."""
        return int(self.value[:-1])
    
    @property
    def letter(self) -> str:
        """Буква места."""
        return self.value[-1].upper()
    
    @property
    def is_window(self) -> bool:
        """Место у окна."""
        return self.letter in ("A", "K")
    
    @property
    def is_aisle(self) -> bool:
        """Место у прохода."""
        return self.letter in ("C", "D", "G", "H")
    
    def __str__(self) -> str:
        return self.value.upper()


@dataclass(frozen=True)
class PNR:
    """
    Value Object для кода бронирования (Passenger Name Record).
    6 символов, буквы и цифры.
    """
    value: str
    
    def __post_init__(self):
        if not self._is_valid(self.value):
            raise ValueError(f"Некорректный PNR: {self.value}")
    
    @staticmethod
    def _is_valid(pnr: str) -> bool:
        return bool(pnr) and len(pnr) == 6 and pnr.isalnum()
    
    def __str__(self) -> str:
        return self.value.upper()
