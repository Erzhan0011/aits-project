import 'seat.dart';

class StaffSeat extends Seat {
  final String? passengerName;
  final int? bookingId;

  StaffSeat({
    required super.seatNumber,
    required super.row,
    required super.column,
    required super.seatClass,
    required super.status,
    super.isEmergencyExit,
    this.passengerName,
    this.bookingId,
  });

  factory StaffSeat.fromJson(Map<String, dynamic> json) {
    // Map backend status strings to SeatStatus enum
    SeatStatus getStatus(String? status) {
      switch (status?.toLowerCase()) {
        case 'available':
          return SeatStatus.available;
        case 'occupied':
          return SeatStatus.occupied;
        case 'reserved':
          return SeatStatus.reserved;
        default:
          return SeatStatus.available;
      }
    }

    // Map backend seat_type to SeatClass enum
    SeatClass getSeatClass(String? type) {
      switch (type?.toLowerCase()) {
        case 'business':
          return SeatClass.business;
        case 'economy':
          return SeatClass.economy;
        case 'standard':
          return SeatClass.standard;
        default:
          return SeatClass.economy;
      }
    }

    return StaffSeat(
      seatNumber: json['seat_number'] ?? '',
      row: json['row'] ?? 0,
      column: json['column'] ?? '',
      seatClass: getSeatClass(json['seat_type']),
      status: getStatus(json['status']),
      passengerName: json['passenger_name'],
      bookingId: json['booking_id'],
      isEmergencyExit: json['is_emergency_exit'] ?? false,
    );
  }
}

class StaffSeatMap {
  final int flightId;
  final List<StaffSeat> seats;
  final int totalSeats;
  final int availableSeats;
  final int occupiedSeats;

  StaffSeatMap({
    required this.flightId,
    required this.seats,
    required this.totalSeats,
    required this.availableSeats,
    required this.occupiedSeats,
  });

  factory StaffSeatMap.fromJson(Map<String, dynamic> json) {
    final seatsList = json['seats'] as List? ?? [];
    return StaffSeatMap(
      flightId: json['flight_id'] ?? 0,
      seats: seatsList.map((s) => StaffSeat.fromJson(s)).toList(),
      totalSeats: json['total_seats'] ?? 0,
      availableSeats: json['available_seats'] ?? 0,
      occupiedSeats: json['occupied_seats'] ?? 0,
    );
  }
}
