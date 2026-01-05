class PassengerInfo {
  final String seatNumber;
  final String firstName;
  final String lastName;
  final String? passportNumber;
  final DateTime? dateOfBirth;

  PassengerInfo({
    required this.seatNumber,
    required this.firstName,
    required this.lastName,
    this.passportNumber,
    this.dateOfBirth,
  });

  Map<String, dynamic> toJson() {
    return {
      'seat_number': seatNumber,
      'first_name': firstName,
      'last_name': lastName,
      'passport_number': passportNumber,
      'date_of_birth': dateOfBirth?.toIso8601String(),
    };
  }

  factory PassengerInfo.fromJson(Map<String, dynamic> json) {
    return PassengerInfo(
      seatNumber: json['seat_number'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      passportNumber: json['passport_number'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
    );
  }
}
