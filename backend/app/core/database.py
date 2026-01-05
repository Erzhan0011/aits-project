# Импортируем необходимые модули SQLAlchemy
from sqlalchemy import create_engine  # Для подключения к базе данных
from sqlalchemy.ext.declarative import declarative_base  # Для создания базового класса моделей
from sqlalchemy.orm import sessionmaker  # Для создания сессий (работы с базой данных)
from app.core.config import settings  # Импортируем объект настроек с параметрами из Settings

# Создаём движок SQLAlchemy, который управляет подключением к базе данных
# connect_args={"check_same_thread": False} нужен для SQLite, чтобы разрешить работу из разных потоков
engine = create_engine(
    settings.DATABASE_URL, connect_args={"check_same_thread": False}
)

# Создаём класс для работы с сессиями базы данных
# autocommit=False → изменения не сохраняются автоматически, нужно вызывать commit()
# autoflush=False → изменения не отправляются автоматически при каждом действии
# bind=engine → сессии будут работать через наш движок
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Создаём базовый класс для всех моделей базы данных
# Все таблицы будут наследоваться от Base
Base = declarative_base()

# Функция для получения сессии базы данных
# Часто используется как зависимость в FastAPI
def get_db():
    db = SessionLocal()  # создаём сессию
    try:
        yield db  # возвращаем сессию, чтобы её использовать в запросах
    finally:
        db.close()  # обязательно закрываем сессию после использования




