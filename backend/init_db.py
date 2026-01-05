"""
Скрипт для инициализации базы данных и создания тестовых данных
"""
from app.core.database import Base, engine, SessionLocal
from app.models.user import User, UserRole
from app.models.airport import Airport
from app.models.aircraft import SeatTemplate, Aircraft
from app.models.flight import Flight, FlightStatus
from app.models.booking import Booking
from app.models.payment import Payment
from app.core.security import get_password_hash
from datetime import datetime, timedelta, date

# Очищаем базу данных перед созданием (чтобы избежать конфликтов схем)
Base.metadata.drop_all(bind=engine)
# Создаём все таблицы заново
Base.metadata.create_all(bind=engine)

db = SessionLocal()

try:
    # Создаём тестового сотрудника (Staff Admin)
    staff_user = db.query(User).filter(User.email == "staff@airline.com").first()
    if not staff_user:
        staff_user = User(
            email="staff@airline.com",
            hashed_password=get_password_hash("StaffAdmin2025!"),
            first_name="Staff",
            last_name="Administrator",
            full_name="Staff Administrator",
            role=UserRole.STAFF,
            is_active=True
        )
        db.add(staff_user)
        db.commit()
        print("✓ Создан аккаунт сотрудника: staff@airline.com / StaffAdmin2025!")

    # Создаём тестового пассажира
    passenger_user = db.query(User).filter(User.email == "passenger@test.com").first()
    if not passenger_user:
        passenger_user = User(
            email="passenger@test.com",
            hashed_password=get_password_hash("pass123"),
            first_name="Test",
            last_name="Passenger",
            full_name="Test Passenger",
            phone="+1234567890",
            passport_number="AB123456",
            nationality="US",
            date_of_birth=date.fromisoformat("1990-01-01"),
            role=UserRole.PASSENGER,
            is_active=True
        )
        db.add(passenger_user)
        db.commit()
        print("✓ Создан тестовый пассажир: passenger@test.com / pass123")

    # Создаём аэропорты
    airports_data = [
        {"code": "SVO", "name": "Шереметьево", "city": "Москва", "country": "Россия"},
        {"code": "LED", "name": "Пулково", "city": "Санкт-Петербург", "country": "Россия"},
        {"code": "JFK", "name": "John F. Kennedy", "city": "Нью-Йорк", "country": "США"},
        {"code": "LHR", "name": "London Heathrow", "city": "Лондон", "country": "Великобритания"},
        {"code": "DXB", "name": "Dubai International", "city": "Дубай", "country": "ОАЭ"},
    ]

    for airport_data in airports_data:
        airport = db.query(Airport).filter(Airport.code == airport_data["code"]).first()
        if not airport:
            airport = Airport(**airport_data)
            db.add(airport)
    db.commit()
    print("✓ Созданы аэропорты")

    # Создаём шаблоны мест
    from app.services.aircraft_service import _generate_seat_map
    
    templates_data = [
        {
            "name": "Narrowbody 3-3",
            "row_count": 30,
            "seat_letters": "ABC DEF",
            "business_rows": "1-3",
            "economy_rows": "4-30",
        },
        {
            "name": "Widebody 3-4-3",
            "row_count": 40,
            "seat_letters": "ABC DEFG HJK",
            "business_rows": "1-5",
            "economy_rows": "6-40",
        },
        {
            "name": "Large Narrowbody 3-3",
            "row_count": 37,
            "seat_letters": "ABC DEF",
            "business_rows": "1-2",
            "economy_rows": "3-37",
        }
    ]

    templates = {}
    for t_data in templates_data:
        template = db.query(SeatTemplate).filter(SeatTemplate.name == t_data["name"]).first()
        if not template:
            # Генерируем карту мест
            t_data["seat_map"] = _generate_seat_map(
                t_data["row_count"],
                t_data["seat_letters"],
                t_data["business_rows"],
                t_data["economy_rows"]
            )
            template = SeatTemplate(**t_data)
            db.add(template)
            db.flush()
        templates[t_data["name"]] = template
    db.commit()
    print("✓ Созданы шаблоны мест")

    # Создаём самолёты
    aircrafts_data = [
        {"model": "Boeing 737-800", "registration_number": "RA-73001", "capacity": 180, "template": "Narrowbody 3-3"},
        {"model": "Airbus A321", "registration_number": "RA-32101", "capacity": 220, "template": "Large Narrowbody 3-3"},
        {"model": "Boeing 777-300ER", "registration_number": "RA-77001", "capacity": 400, "template": "Widebody 3-4-3"},
    ]
    
    aircrafts = []
    for ac_data in aircrafts_data:
        aircraft = db.query(Aircraft).filter(Aircraft.registration_number == ac_data["registration_number"]).first()
        if not aircraft:
            aircraft = Aircraft(
                model=ac_data["model"],
                registration_number=ac_data["registration_number"],
                capacity=ac_data["capacity"],
                seat_template_id=templates[ac_data["template"]].id
            )
            db.add(aircraft)
            db.flush()
        aircrafts.append(aircraft)
    db.commit()
    print("✓ Созданы самолёты")

    # Создаём рейсы
    svo = db.query(Airport).filter(Airport.code == "SVO").first()
    led = db.query(Airport).filter(Airport.code == "LED").first()
    jfk = db.query(Airport).filter(Airport.code == "JFK").first()
    dxb = db.query(Airport).filter(Airport.code == "DXB").first()
    lhr = db.query(Airport).filter(Airport.code == "LHR").first()
    
    now = datetime.utcnow()
    import random
    
    flights_data = [
        # Москва -> Питер (сегодня)
        {"flight_number": "SU010", "origin": svo, "dest": led, "delta_hours": 2, "duration": 1.5, "price": 4500.0, "ac": aircrafts[0]},
        {"flight_number": "SU012", "origin": svo, "dest": led, "delta_hours": 6, "duration": 1.5, "price": 5200.0, "ac": aircrafts[1]},
        # Москва -> Нью-Йорк (завтра)
        {"flight_number": "SU101", "origin": svo, "dest": jfk, "delta_days": 1, "delta_hours": 10, "duration": 11, "price": 85000.0, "ac": aircrafts[2]},
        # Москва -> Дубай (через 3 дня)
        {"flight_number": "SU520", "origin": svo, "dest": dxb, "delta_days": 3, "delta_hours": 14, "duration": 5.5, "price": 35000.0, "ac": aircrafts[0]},
        # Лондон -> Москва (Сегодня!)
        {"flight_number": "SU506", "origin": lhr, "dest": svo, "delta_days": 0, "delta_hours": 2, "duration": 6.0, "price": 48000.0, "ac": aircrafts[1]},
    ]
    
    for f_data in flights_data:
        if not f_data["origin"] or not f_data["dest"]: continue
        
        departure = now + timedelta(days=f_data.get("delta_days", 0), hours=f_data["delta_hours"])
        arrival = departure + timedelta(hours=f_data["duration"])
        
        flight = db.query(Flight).filter(Flight.flight_number == f_data["flight_number"]).first()
        if not flight:
            flight = Flight(
                flight_number=f_data["flight_number"],
                aircraft_id=f_data["ac"].id,
                origin_airport_id=f_data["origin"].id,
                destination_airport_id=f_data["dest"].id,
                scheduled_departure=departure,
                scheduled_arrival=arrival,
                base_price=f_data["price"],
                gate=f"Gate-{random.randint(1, 20)}",
                status=FlightStatus.SCHEDULED
            )
            db.add(flight)
    
    db.commit()
    print("✓ Созданы тестовые рейсы")

    print("\n✓ База данных инициализирована успешно!")
    print("\n════════════════════════════════════════════════════")
    print("📋 УЧЕТНЫЕ ДАННЫЕ ДЛЯ ВХОДА")
    print("════════════════════════════════════════════════════")
    print("👨‍💼 СОТРУДНИК (Staff):")
    print("   Email: staff@airline.com")
    print("   Пароль: StaffAdmin2025!")
    print("")
    print("👤 ПАССАЖИР (Passenger):")
    print("   Email: passenger@test.com")
    print("   Пароль: pass123")
    print("════════════════════════════════════════════════════")

except Exception as e:
    print(f"Ошибка при инициализации: {e}")
    db.rollback()
finally:
    db.close()



