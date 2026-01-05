class Aircraft {
  final int id;
  final String model;
  final String registrationNumber;
  final int capacity;
  final int seatTemplateId;

  Aircraft({
    required this.id,
    required this.model,
    required this.registrationNumber,
    required this.capacity,
    required this.seatTemplateId,
  });

  factory Aircraft.fromJson(Map<String, dynamic> json) {
    return Aircraft(
      id: json['id'],
      model: json['model'],
      registrationNumber: json['registration_number'],
      capacity: json['capacity'],
      seatTemplateId: json['seat_template_id'] ?? 
                      (json['seat_template'] != null ? json['seat_template']['id'] : 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'registration_number': registrationNumber,
      'capacity': capacity,
    };
  }

  String get displayName => '$model ($registrationNumber)';
}
