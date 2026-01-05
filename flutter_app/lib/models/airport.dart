class Airport {
  final int id;
  final String code; // IATA code
  final String name;
  final String city;
  final String country;

  Airport({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.country,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      id: json['id'],
      code: json['iata_code'] ?? json['code'], // Backend использует iata_code
      name: json['name'],
      city: json['city'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'iata_code': code,
      'code': code, // Для обратной совместимости
      'name': name,
      'city': city,
      'country': country,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Airport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  String get displayName => '$name ($code)';
  String get fullLocation => '$city, $country';
}



