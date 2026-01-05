

class PassengerFormData {
  final String seatNumber;
  String firstName;
  String lastName;
  String? passportNumber;
  DateTime? dateOfBirth;

  PassengerFormData({
    required this.seatNumber,
    this.firstName = '',
    this.lastName = '',
    this.passportNumber,
    this.dateOfBirth,
  });

  Map<String, dynamic> toJson() {
    return {
      'seat_number': seatNumber,
      'first_name': firstName,
      'last_name': lastName,
      'passport_number': passportNumber,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
    };
  }
}
