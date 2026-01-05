class User {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName; // For backward compatibility
  final String? phone;
  final String? passportNumber;
  final String? nationality;
  final String? dateOfBirth;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phone,
    this.passportNumber,
    this.nationality,
    this.dateOfBirth,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Support both new format (first_name/last_name) and old format (full_name)
    String? firstName = json['first_name'];
    String? lastName = json['last_name'];
    String? fullName = json['full_name'];
    
    // If fullName exists but firstName/lastName don't, try to split
    if (fullName != null && firstName == null && lastName == null) {
      final parts = fullName.trim().split(' ');
      if (parts.length >= 2) {
        firstName = parts.first;
        lastName = parts.sublist(1).join(' ');
      } else if (parts.length == 1) {
        firstName = parts.first;
      }
    }
    
    return User(
      id: json['id'],
      email: json['email'],
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      phone: json['phone'],
      passportNumber: json['passport_number'],
      nationality: json['nationality'],
      dateOfBirth: json['date_of_birth'],
      role: json['role'],
      isActive: json['is_active'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (fullName != null) 'full_name': fullName,
      'phone': phone,
      'passport_number': passportNumber,
      'nationality': nationality,
      'date_of_birth': dateOfBirth,
      'role': role,
      'is_active': isActive,
    };
  }

  // Get display name (prefer firstName + lastName, fallback to fullName)
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return fullName ?? email;
  }

  bool get isPassenger => role == 'PASSENGER';
  bool get isStaff => role == 'STAFF';
  bool get isAdmin => role == 'ADMIN';
  
  // Keep for backward compatibility, but profile is always complete for passenger module
  bool get isProfileComplete => true;
}



