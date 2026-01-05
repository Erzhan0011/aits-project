import 'flight.dart';

enum PaymentMethod {
  card,
  applePay,
  googlePay;

  static PaymentMethod fromString(String method) {
    switch (method.toUpperCase()) {
      case 'CARD':
        return PaymentMethod.card;
      case 'APPLE_PAY':
        return PaymentMethod.applePay;
      case 'GOOGLE_PAY':
        return PaymentMethod.googlePay;
      default:
        return PaymentMethod.card;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.card:
        return 'Банковская карта';
      case PaymentMethod.applePay:
        return 'Apple Pay';
      case PaymentMethod.googlePay:
        return 'Google Pay';
    }
  }
}

enum BookingStatus {
  pending,
  confirmed,
  cancelled;

  static BookingStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return BookingStatus.pending;
      case 'CONFIRMED':
        return BookingStatus.confirmed;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }
}

class Booking {
  final int id;
  final String? pnr; // Added PNR
  final int passengerId;
  final int flightId;
  final Flight flight;
  final String seatNumber;
  final double price;
  final PaymentMethod? paymentMethod;
  final BookingStatus status;
  final String? firstName;
  final String? lastName;
  final String? passportNumber;
  final DateTime? dateOfBirth;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? expiresAt;
  final bool checkedIn;
  final String? qrCode;

  Booking({
    required this.id,
    this.pnr,
    required this.passengerId,
    required this.flightId,
    required this.flight,
    required this.seatNumber,
    required this.price,
    this.paymentMethod,
    required this.status,
    this.firstName,
    this.lastName,
    this.passportNumber,
    this.dateOfBirth,
    required this.createdAt,
    this.confirmedAt,
    this.expiresAt,
    this.checkedIn = false,
    this.qrCode,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as int? ?? 0,
      pnr: json['pnr'] as String?,
      passengerId: json['passenger_id'] as int? ?? 0,
      flightId: json['flight_id'] as int? ?? 0,
      flight: Flight.fromJson(json['flight'] as Map<String, dynamic>? ?? {}),
      seatNumber: (json['seat_number'] ?? 'N/A').toString(),
      price: (json['price'] as num? ?? 0).toDouble(),
      paymentMethod: json['payment_method'] != null
          ? PaymentMethod.fromString(json['payment_method'].toString())
          : null,
      status: BookingStatus.fromString((json['status'] ?? 'pending').toString()),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      passportNumber: json['passport_number'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      confirmedAt: _parseDate(json['confirmed_at']),
      expiresAt: _parseDate(json['expires_at']),
      checkedIn: json['checked_in'] as bool? ?? false,
      qrCode: json['qr_code'] as String?,
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
}



