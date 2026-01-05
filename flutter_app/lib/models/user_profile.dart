class UserProfile {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final String? phone;
  final String? passportNumber;
  final String? nationality;
  final String? dateOfBirth;

  UserProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.phone,
    this.passportNumber,
    this.nationality,
    this.dateOfBirth,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? 'N/A',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'PASSENGER',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
      phone: json['phone'] as String?,
      passportNumber: json['passport_number'] as String?,
      nationality: json['nationality'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
    );
  }
}
