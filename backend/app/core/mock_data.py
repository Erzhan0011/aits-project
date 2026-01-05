"""
Mock data for flights, airports, and announcements
"""
from datetime import datetime, timedelta
from typing import List, Dict
from enum import Enum


class SeatType(str, Enum):
    """Типы мест в самолете"""
    STANDARD = "standard"  # Обычное место
    LEGROOM = "legroom"   # Увеличенное пространство для ног
    WINDOW = "window"     # У окна
    AISLE = "aisle"       # У прохода


class SeatStatus(str, Enum):
    """Статус места"""
    AVAILABLE = "available"  # Свободно
    OCCUPIED = "occupied"    # Занято
    RESERVED = "reserved"    # Забронировано


class MockSeat:
    """Модель места в самолете"""
    def __init__(
        self,
        seat_number: str,
        row: int,
        column: str,
        seat_type: SeatType,
        status: SeatStatus = SeatStatus.AVAILABLE
    ):
        self.seat_number = seat_number
        self.row = row
        self.column = column
        self.seat_type = seat_type
        self.status = status


class MockFlight:
    """Mock flight model"""
    def __init__(
        self,
        id: int,
        flight_number: str,
        departure_city: str,
        arrival_city: str,
        departure_time: datetime,
        arrival_time: datetime,
        status: str,
        available_seats: int,
        total_seats: int,
        base_price: float = 5000.0,
        aircraft_type: str = "Boeing 737",
        aircraft_model: str = "737-800",
        gate: str = None,
        terminal: str = "A"
    ):
        self.id = id
        self.flight_number = flight_number
        self.departure_city = departure_city
        self.arrival_city = arrival_city
        self.departure_time = departure_time
        self.arrival_time = arrival_time
        self.status = status
        self.available_seats = available_seats
        self.total_seats = total_seats
        self.base_price = base_price
        self.aircraft_type = aircraft_type
        self.aircraft_model = aircraft_model
        self.gate = gate
        self.terminal = terminal
        # Генерируем карту мест для этого рейса
        self.seats = self._generate_seat_map()

# (omitted _generate_seat_map method for brevity if not changed)

    def _generate_seat_map(self) -> Dict[str, MockSeat]:
        """Генерирует карту мест для самолета"""
        seats = {}
        rows = max(1, self.total_seats // 6)  # 6 мест в ряду (A, B, C, D, E, F), минимум 1 ряд
        columns = ['A', 'B', 'C', 'D', 'E', 'F']
        
        # Предварительно вычисляем количество занятых мест
        occupied_count = max(0, min(self.total_seats - self.available_seats, self.total_seats))
        
        seat_id = 0
        for row in range(1, rows + 1):
            for col in columns:
                if seat_id >= self.total_seats:
                    break
                    
                seat_number = f"{row}{col}"
                # Первые 3 ряда и последние 2 ряда - увеличенное пространство
                seat_type = SeatType.LEGROOM if (row <= 3 or row > rows - 2) else SeatType.STANDARD
                # Определяем статус на основе available_seats
                status = SeatStatus.OCCUPIED if seat_id < occupied_count else SeatStatus.AVAILABLE
                
                seats[seat_number] = MockSeat(
                    seat_number=seat_number,
                    row=row,
                    column=col,
                    seat_type=seat_type,
                    status=status
                )
                seat_id += 1
            
            if seat_id >= self.total_seats:
                break
        
        return seats


class MockAirport:
    """Mock airport model"""
    def __init__(
        self,
        id: int,
        name: str,
        city: str,
        country: str,
        iata_code: str
    ):
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.iata_code = iata_code


class MockAnnouncement:
    """Mock announcement model"""
    def __init__(
        self,
        id: int,
        title: str,
        message: str,
        created_at: datetime
    ):
        self.id = id
        self.title = title
        self.message = message
        self.created_at = created_at


# Mock airports data
MOCK_AIRPORTS = [
    MockAirport(1, "Шереметьево", "Москва", "Россия", "SVO"),
    MockAirport(2, "Домодедово", "Москва", "Россия", "DME"),
    MockAirport(3, "Пулково", "Санкт-Петербург", "Россия", "LED"),
    MockAirport(4, "John F. Kennedy International", "Нью-Йорк", "США", "JFK"),
    MockAirport(5, "Charles de Gaulle", "Париж", "Франция", "CDG"),
    MockAirport(6, "London Heathrow", "Лондон", "Великобритания", "LHR"),
    MockAirport(7, "Dubai International", "Дубай", "ОАЭ", "DXB"),
    MockAirport(8, "Beijing Capital", "Пекин", "Китай", "PEK"),
    MockAirport(9, "Manas", "Бишкек", "Киргизия", "FRU"),
]


# Хранилище рейсов с картами мест
_flights_cache: Dict[int, MockFlight] = {}


# Mock flights data
def get_mock_flights() -> List[MockFlight]:
    """Generate mock flights data with seat maps"""
    global _flights_cache
    
    if _flights_cache:
        return list(_flights_cache.values())
    
    now = datetime.utcnow()
    flights_data = [
        {
            'id': 1,
            'flight_number': 'SU 101',
            'departure_city': 'Москва',
            'arrival_city': 'Нью-Йорк',
            'departure_time': now + timedelta(days=1, hours=2),
            'arrival_time': now + timedelta(days=1, hours=12),
            'status': 'по расписанию',
            'available_seats': 120,
            'total_seats': 180,
            'base_price': 45000.0,
            'gate': 'A15',
            'terminal': 'A'
        },
        {
            'id': 2,
            'flight_number': 'SU 102',
            'departure_city': 'Москва',
            'arrival_city': 'Санкт-Петербург',
            'departure_time': now + timedelta(hours=3),
            'arrival_time': now + timedelta(hours=4, minutes=30),
            'status': 'по расписанию',
            'available_seats': 45,
            'total_seats': 150,
            'base_price': 3500.0,
            'gate': 'B5',
            'terminal': 'B'
        },
        {
            'id': 3,
            'flight_number': 'SU 203',
            'departure_city': 'Париж',
            'arrival_city': 'Москва',
            'departure_time': now + timedelta(days=2, hours=6),
            'arrival_time': now + timedelta(days=2, hours=14),
            'status': 'по расписанию',
            'available_seats': 78,
            'total_seats': 180,
            'base_price': 38000.0,
            'gate': 'C8',
            'terminal': 'C'
        },
        {
            'id': 4,
            'flight_number': 'SU 304',
            'departure_city': 'Санкт-Петербург',
            'arrival_city': 'Москва',
            'departure_time': now + timedelta(hours=5),
            'arrival_time': now + timedelta(hours=6, minutes=45),
            'status': 'задержан',
            'available_seats': 12,
            'total_seats': 150,
            'base_price': 4200.0,
            'gate': 'A3',
            'terminal': 'A'
        },
        {
            'id': 5,
            'flight_number': 'SU 405',
            'departure_city': 'Москва',
            'arrival_city': 'Дубай',
            'departure_time': now + timedelta(days=3),
            'arrival_time': now + timedelta(days=3, hours=5),
            'status': 'по расписанию',
            'available_seats': 156,
            'total_seats': 200,
            'base_price': 25000.0,
            'gate': 'D12',
            'terminal': 'D'
        },
    ]
    
    for flight_data in flights_data:
        flight = MockFlight(**flight_data)
        _flights_cache[flight.id] = flight
    
    # Добавляем еще рейсы
    for i in range(6, 15):
        city_pairs = [
            ("Москва", "Париж"),
            ("Москва", "Лондон"),
            ("Санкт-Петербург", "Москва"),
            ("Москва", "Дубай"),
            ("Париж", "Москва"),
            ("Лондон", "Москва"),
        ]
        departure_city, arrival_city = city_pairs[i % len(city_pairs)]
        flight = MockFlight(
            id=i,
            flight_number=f"SU {100 + i}",
            departure_city=departure_city,
            arrival_city=arrival_city,
            departure_time=now + timedelta(days=i % 7, hours=i % 24),
            arrival_time=now + timedelta(days=i % 7, hours=(i % 24) + 3),
            status="по расписанию" if i % 3 != 0 else ("задержан" if i % 2 == 0 else "по расписанию"),
            available_seats=150 - (i * 5) % 150,
            total_seats=180,
            base_price=float(5000 + i * 500),
            gate=f"{(chr(65 + (i % 4)))}{i % 20}",
            terminal=chr(65 + (i % 4))
        )
        _flights_cache[flight.id] = flight
    
    return list(_flights_cache.values())


def get_flight_by_id(flight_id: int) -> MockFlight:
    """Get flight by ID"""
    flights = get_mock_flights()
    for flight in flights:
        if flight.id == flight_id:
            return flight
    raise ValueError(f"Flight with id {flight_id} not found")


# Mock announcements data
MOCK_ANNOUNCEMENTS = [
    MockAnnouncement(
        id=1,
        title="Новые правила регистрации на рейсы",
        message="Сообщаем об изменении правил регистрации на рейсы. Регистрация открывается за 24 часа до вылета и закрывается за 40 минут до вылета.",
        created_at=datetime.utcnow() - timedelta(days=2)
    ),
    MockAnnouncement(
        id=2,
        title="Дополнительные меры безопасности",
        message="В связи с ужесточением мер безопасности просим пассажиров прибывать в аэропорт не менее чем за 2 часа до вылета.",
        created_at=datetime.utcnow() - timedelta(days=5)
    ),
    MockAnnouncement(
        id=3,
        title="Новые маршруты в Азию",
        message="Рады сообщить об открытии новых рейсов в страны Азии. Билеты уже доступны для бронирования.",
        created_at=datetime.utcnow() - timedelta(days=10)
    ),
    MockAnnouncement(
        id=4,
        title="Скидки на рейсы в Европу",
        message="Специальное предложение: скидка 20% на все рейсы в страны Европы при бронировании до конца месяца.",
        created_at=datetime.utcnow() - timedelta(days=1)
    ),
    MockAnnouncement(
        id=5,
        title="Изменение расписания рейсов",
        message="Обращаем внимание на изменения в расписании некоторых рейсов. Пожалуйста, проверьте информацию о вашем рейсе перед поездкой.",
        created_at=datetime.utcnow() - timedelta(hours=6)
    ),
]
