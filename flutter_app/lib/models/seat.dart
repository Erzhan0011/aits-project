enum SeatClass {
  business,
  economy,
  standard, // Sometimes economy acts as standard in mock
}

enum SeatStatus {
  available,
  occupied,
  reserved,
  held
}

class Seat {
  final String seatNumber;      // 12A
  final int row;                // 12
  final String column;          // A, B, C...
  final SeatClass seatClass;    // BUSINESS / ECONOMY
  final SeatStatus status;
  final bool isEmergencyExit;
  final double? price;

  const Seat({
    required this.seatNumber,
    required this.row,
    required this.column,
    required this.seatClass,
    required this.status,
    this.isEmergencyExit = false,
    this.price,
  });
  
  // Helpers
  bool get isAvailable => status == SeatStatus.available;
  bool get isOccupied => status == SeatStatus.occupied;

  factory Seat.fromJson(Map<String, dynamic> json) {
     return Seat(
      seatNumber: json['seat_number'] as String,
      row: json['row'] as int,
      column: json['column'] as String,
      seatClass: _parseSeatClass(json['seat_type'] ?? 'standard'),
      status: _parseStatus(json['status'] ?? 'available'),
      // Assuming mock data doesn't have emergency exit yet, default false or infer
      isEmergencyExit: json['is_emergency_exit'] as bool? ?? false, 
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    );
  }

  static SeatClass _parseSeatClass(String type) {
    switch (type.toLowerCase()) {
      case 'business': return SeatClass.business;
      case 'legroom': return SeatClass.economy; // Mapping legroom to economy/standard distinction if needed, or separate
      case 'standard': return SeatClass.standard;
      default: return SeatClass.economy;
    }
  }

  static SeatStatus _parseStatus(String status) {
     switch (status.toLowerCase()) {
      case 'available': return SeatStatus.available;
      case 'occupied': return SeatStatus.occupied;
      case 'reserved': return SeatStatus.reserved;
      case 'held': return SeatStatus.held;
      default: return SeatStatus.occupied;
    }
  }
}
