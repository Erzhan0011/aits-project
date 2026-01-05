import 'flight.dart';
import 'announcement.dart';

enum TripStatus {
  upcoming,
  checkinAvailable,
  checkedIn,
  inFlight,
  completed,
  cancelled,
  created
}

class Trip {
  final int id;
  final int passengerId;
  final int flightId;
  final Flight flight;
  final String seatNumber;
  final double price;
  final String status;
  final DateTime createdAt;
  final String pnr;
  final String? gate;
  final String terminal;
  final String paymentMethod;
  final DateTime? expiresAt;
  final bool checkedIn;
  final String? qrCode;
  final String? firstName;
  final String? lastName;
  final String? passportNumber;
  final DateTime? dateOfBirth;
  final DateTime? confirmedAt;
  final DateTime? checkedInAt;
  final String? transactionId;
  final List<Announcement> history; // Added history field

  Trip({
    required this.id,
    required this.passengerId,
    required this.flightId,
    required this.flight,
    required this.seatNumber,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.pnr,
    this.gate,
    required this.terminal,
    required this.paymentMethod,
    this.expiresAt,
    required this.checkedIn,
    this.qrCode,
    this.firstName,
    this.lastName,
    this.passportNumber,
    this.dateOfBirth,
    this.confirmedAt,
    this.checkedInAt,
    this.transactionId,
    this.history = const [],
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as int? ?? 0,
      passengerId: json['passenger_id'] as int? ?? 0,
      flightId: json['flight_id'] as int? ?? 0,
      flight: json['flight'] != null 
          ? Flight.fromJson(json['flight'] as Map<String, dynamic>)
          : Flight.empty(),
      seatNumber: (json['seat_number'] ?? 'N/A').toString(),
      price: (json['price'] as num? ?? 0).toDouble(),
      status: (json['status'] ?? 'Scheduled').toString(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      pnr: (json['pnr'] ?? 'N/A').toString(),
      gate: json['gate']?.toString(),
      terminal: (json['terminal'] ?? 'A').toString(),
      paymentMethod: (json['payment_method'] ?? 'CARD').toString(),
      expiresAt: _parseDate(json['expires_at']),
      checkedIn: json['checked_in'] as bool? ?? false,
      qrCode: json['qr_code']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      passportNumber: json['passport_number']?.toString(),
      dateOfBirth: _parseDate(json['date_of_birth']),
      confirmedAt: _parseDate(json['confirmed_at']),
      checkedInAt: _parseDate(json['checked_in_at']),
      transactionId: json['transaction_id']?.toString(),
      history: (json['history'] as List?)
              ?.map((h) => Announcement.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    try {
      if (date is String && date.isNotEmpty) {
        return DateTime.parse(date).toLocal();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  TripStatus get tripStatus {
    final now = DateTime.now();
    
    // Explicit server override
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'cancelled' || lowerStatus.contains('отменен')) return TripStatus.cancelled;
    if (lowerStatus == 'created' || lowerStatus == 'pending') return TripStatus.created;
    if (lowerStatus == 'completed' || lowerStatus == 'arrived' || lowerStatus.contains('прибыл')) return TripStatus.completed;
    if (lowerStatus == 'departed' || lowerStatus.contains('вылетел')) return TripStatus.inFlight;
    if (lowerStatus == 'boarding' || lowerStatus.contains('посадка')) return TripStatus.checkinAvailable;
    
    // Time-based calculation for dynamic updates
    if (now.isAfter(flight.arrivalTime)) return TripStatus.completed;
    if (now.isAfter(flight.departureTime)) return TripStatus.inFlight;
    if (checkedIn) return TripStatus.checkedIn;
    if (isCheckinOpen) return TripStatus.checkinAvailable;
    
    return TripStatus.upcoming;
  }

  bool get isCheckinOpen {
    final now = DateTime.now();
    final checkinStart = flight.departureTime.subtract(const Duration(hours: 24));
    final checkinEnd = flight.departureTime.subtract(const Duration(hours: 1));
    return now.isAfter(checkinStart) && now.isBefore(checkinEnd);
  }

  bool get isCheckinClosed {
    final now = DateTime.now();
    final checkinEnd = flight.departureTime.subtract(const Duration(hours: 1));
    return now.isAfter(checkinEnd) && now.isBefore(flight.departureTime);
  }

  String get checkinStatusMessage {
    if (status.toLowerCase() == 'cancelled') return 'Рейс отменен';
    if (status.toLowerCase() == 'created' || status.toLowerCase() == 'pending') return 'Ожидание оплаты';
    if (checkedIn) return 'Вы успешно прошли регистрацию';
    if (tripStatus == TripStatus.completed) return 'Полет завершен';
    if (tripStatus == TripStatus.inFlight) return 'Рейс в воздухе';
    
    if (isCheckinOpen) {
      return 'Регистрация открыта! Пожалуйста, зарегистрируйтесь';
    } else if (isCheckinClosed) {
      return 'Регистрация закрыта. Ожидайте посадку';
    } else if (DateTime.now().isBefore(flight.departureTime.subtract(const Duration(hours: 24)))) {
      final hoursWait = flight.departureTime.difference(DateTime.now()).inMinutes ~/ 60;
      if (hoursWait > 24) {
        final days = hoursWait ~/ 24;
        return 'Регистрация откроется через $days дн.';
      }
      return 'Регистрация откроется через ${hoursWait - 24} ч.';
    }
    
    return 'Ожидание вылета';
  }

  String get statusText {
    switch (tripStatus) {
      case TripStatus.upcoming: return 'ПОДТВЕРЖДЕНО';
      case TripStatus.checkinAvailable: return 'РЕГИСТРАЦИЯ';
      case TripStatus.checkedIn: return 'ЗАРЕГИСТРИРОВАН';
      case TripStatus.inFlight: return 'В ПОЛЕТЕ';
      case TripStatus.completed: return 'ЗАВЕРШЕН';
      case TripStatus.cancelled: return 'ОТМЕНЕНО';
      case TripStatus.created: return 'ОЖИДАЕТ ОПЛАТЫ';
    }
  }

  String get route => '${flight.departureCity} → ${flight.arrivalCity}';
  String get duration {
    final duration = flight.arrivalTime.difference(flight.departureTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hoursч $minutesм';
  }
}
