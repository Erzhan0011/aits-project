# ✈️ Zhan Airline

**Enterprise-grade система бронирования авиабилетов**

Backend: FastAPI (Python) | Frontend: Flutter (Mobile/Web)

---

## 🏆 Архитектурные решения

Проект реализован с соблюдением принципов **Clean Architecture** и **SOLID**:

```
┌─────────────────────────────────────────────────────────────────┐
│                         API Gateway                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Middleware Pipeline                           │  │
│  │  [RequestID] → [Logging] → [CORS] → [Auth]                │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ROUTES (Controllers)                         │
│         Только маршрутизация и валидация входных данных         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SERVICES (Use Cases)                        │
│              Бизнес-логика и правила домена                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   REPOSITORIES (Data Access)                     │
│                  CRUD операции с базой данных                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATABASE (SQLAlchemy)                       │
│                        Models + SQLite                          │
└─────────────────────────────────────────────────────────────────┘
```

### ✅ Реализованные паттерны:

| Паттерн | Применение |
|---------|------------|
| **Repository Pattern** | Абстракция доступа к данным (`app/repositories/`) |
| **Dependency Injection** | FastAPI Depends для сервисов и репозиториев |
| **DTO/Schema Pattern** | Pydantic schemas для валидации (`app/schemas/`) |
| **Middleware Pipeline** | RequestID → Logging → CORS |
| **Custom Exceptions** | Единообразная обработка ошибок (`app/core/exceptions.py`) |

---

## 📁 Структура проекта

```
backend/
├── app/
│   ├── api/                    # Версионированные API эндпоинты
│   │   └── v1/                 # API v1
│   │
│   ├── core/                   # Ядро приложения
│   │   ├── config.py           # Конфигурация через .env
│   │   ├── security.py         # JWT, bcrypt
│   │   ├── database.py         # SQLAlchemy session
│   │   ├── dependencies.py     # FastAPI dependencies
│   │   └── exceptions.py       # Кастомные исключения
│   │
│   ├── middleware/             # HTTP Middleware
│   │   ├── cors.py             # Production CORS
│   │   ├── logging.py          # Структурированное логирование
│   │   └── request_id.py       # Трассировка запросов
│   │
│   ├── models/                 # SQLAlchemy модели
│   │   ├── user.py
│   │   ├── flight.py
│   │   ├── booking.py
│   │   └── ...
│   │
│   ├── repositories/           # Data Access Layer
│   │   ├── base.py             # Generic CRUD
│   │   ├── user_repository.py
│   │   ├── flight_repository.py
│   │   └── booking_repository.py
│   │
│   ├── schemas/                # Pydantic DTOs
│   │   ├── user.py
│   │   ├── flight.py
│   │   └── ...
│   │
│   ├── services/               # Business Logic
│   │   ├── auth_service.py
│   │   ├── booking_service.py
│   │   └── ...
│   │
│   └── routes/                 # API роутеры
│       ├── auth.py
│       ├── passenger.py
│       └── staff.py
│
├── .env.example                # Шаблон переменных окружения
├── main.py                     # Точка входа
└── requirements.txt            # Python зависимости
```

---

## 🔐 Безопасность

### Аутентификация
- **JWT токены** (Access + Refresh)
- **bcrypt** хэширование паролей
- **Role-based Access Control** (PASSENGER, STAFF, ADMIN)

### Защита
- Секреты хранятся в `.env` (не в коде!)
- Production CORS с whitelist origins
- Валидация SECRET_KEY при старте (минимум 32 символа)
- Request-ID для трассировки всех запросов

---

## ⚡ Быстрый запуск

### 1. Backend

```bash
cd backend

# Создать виртуальное окружение
python -m venv venv
.\venv\Scripts\activate  # Windows
source venv/bin/activate  # Linux/Mac

# Установить зависимости
pip install -r requirements.txt

# Скопировать и настроить .env
copy .env.example .env  # Или: cp .env.example .env

# Инициализировать БД
python init_db.py

# Запустить сервер
python -m uvicorn main:app --reload --port 8000
```

### 2. Frontend

```bash
cd flutter_app
flutter pub get
flutter run
```

---

## 🔑 Тестовые аккаунты

| Роль | Email | Пароль |
|------|-------|--------|
| Пассажир | `passenger@test.com` | `pass123` |
| Персонал | `staff@airline.com` | `staff123` |

---

## 📚 API Документация

После запуска Backend:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## 🎓 Обоснование для жюри



---

## 📝 Лицензия

MIT
