# Импортируем необходимые модули
from datetime import datetime, timedelta  # Для работы с датой и временем
from typing import Optional  # Для типов, которые могут быть None
from jose import JWTError, jwt  # Для создания и декодирования JWT токенов
import bcrypt  # Для безопасного хэширования паролей
from app.core.config import settings  # Импортируем настройки приложения

# Bcrypt имеет ограничение в 72 байта для пароля
BCRYPT_MAX_PASSWORD_LENGTH = 72


# Функция для обрезки пароля до 72 байт (ограничение bcrypt)
def _truncate_password(password: str) -> bytes:
    """Обрезает пароль до 72 байт для совместимости с bcrypt"""
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > BCRYPT_MAX_PASSWORD_LENGTH:
        return password_bytes[:BCRYPT_MAX_PASSWORD_LENGTH]
    return password_bytes


# Функция для проверки пароля
# Сравнивает обычный пароль с захэшированным
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверяет пароль с учётом ограничения bcrypt в 72 байта"""
    try:
        password_bytes = _truncate_password(plain_password)
        hashed_bytes = hashed_password.encode('utf-8')
        return bcrypt.checkpw(password_bytes, hashed_bytes)
    except Exception:
        return False


# Функция для хэширования пароля перед сохранением в базу
def get_password_hash(password: str) -> str:
    """Хэширует пароль с учётом ограничения bcrypt в 72 байта"""
    password_bytes = _truncate_password(password)
    # Генерируем соль и хэшируем пароль
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')


# Функция для создания JWT токена (Access Token)
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    # Копируем данные, чтобы не изменять исходный словарь
    to_encode = data.copy()

    # Вычисляем время истечения токена
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    # Добавляем тип токена для безопасности
    to_encode.update({"exp": expire, "type": "access"})

    # Кодируем JWT
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


# Функция для создания Refresh токена
def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        
    to_encode.update({"exp": expire, "type": "refresh"})
    
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


# Функция для декодирования JWT токена
def decode_access_token(token: str, token_type: Optional[str] = "access") -> Optional[dict]:
    """
    Декодирует токен и проверяет его тип.
    По умолчанию ожидает 'access' токен.
    """
    try:
        # Декодируем токен и проверяем подпись
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        
        # Проверяем тип токена, если он задан
        if token_type and payload.get("type") != token_type:
            return None
            
        return payload
    except JWTError:
        return None




