import 'package:flutter/material.dart';

enum FlightStatus {
  scheduled,
  boarding,
  departed,
  arrived,
  delayed,
  cancelled;

  static FlightStatus fromString(String status) {
    final s = status.toUpperCase();
    if (s.contains('РАСПИСАНИЮ') || s == 'SCHEDULED') {
      return FlightStatus.scheduled;
    } else if (s.contains('ЗАДЕРЖАН') || s == 'DELAYED') {
      return FlightStatus.delayed;
    } else if (s.contains('ОТМЕНЕН') || s.contains('ОТМЕНЁН') || s == 'CANCELLED') {
      return FlightStatus.cancelled;
    } else if (s.contains('ВЫЛЕТЕЛ') || s == 'DEPARTED' || s.contains('ПОЛЕТ') || s.contains('FLIGHT') || s.contains('AIR')) {
      return FlightStatus.departed;
    } else if (s.contains('ПРИБЫЛ') || s == 'ARRIVED' || s.contains('LANDED')) {
      return FlightStatus.arrived;
    } else if (s.contains('ПОСАДКА') || s == 'BOARDING') {
      return FlightStatus.boarding;
    }
    return FlightStatus.scheduled;
  }

  Color get color {
    switch (this) {
      case FlightStatus.scheduled:
        return Colors.green;
      case FlightStatus.boarding:
        return Colors.orange;
      case FlightStatus.departed:
        return Colors.blue;
      case FlightStatus.arrived:
        return Colors.grey;
      case FlightStatus.delayed:
        return Colors.red;
      case FlightStatus.cancelled:
        return Colors.black87;
    }
  }
}

class Flight {
  final int id;
  final String flightNumber;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String status; // Статус как строка из backend
  final int availableSeats;
  final int totalSeats;
  final double basePrice;
  final int aircraftId;
  final int originAirportId;
  final int destinationAirportId;
  final String? gate;
  final String terminal;

  Flight({
    required this.id,
    required this.flightNumber,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.availableSeats,
    required this.totalSeats,
    required this.basePrice,
    this.aircraftId = 0,
    this.originAirportId = 0,
    this.destinationAirportId = 0,
    this.gate,
    this.terminal = 'A',
  });

  factory Flight.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Flight.empty();
    }
    
    return Flight(
      id: json['id'] as int? ?? 0,
      flightNumber: (json['flight_number'] ?? 'N/A').toString(),
      departureCity: (json['departure_city'] ?? 'Unknown').toString(),
      arrivalCity: (json['arrival_city'] ?? 'Unknown').toString(),
      departureTime: _parseDate(json['departure_time']),
      arrivalTime: _parseDate(json['arrival_time']),
      status: (json['status'] ?? 'Scheduled').toString(),
      availableSeats: json['available_seats'] as int? ?? 0,
      totalSeats: json['total_seats'] as int? ?? 0,
      basePrice: (json['base_price'] as num? ?? 0).toDouble(),
      aircraftId: json['aircraft_id'] as int? ?? 0,
      originAirportId: json['origin_airport_id'] as int? ?? 0,
      destinationAirportId: json['destination_airport_id'] as int? ?? 0,
      gate: json['gate']?.toString(),
      terminal: (json['terminal'] ?? 'A').toString(),
    );
  }

  factory Flight.empty() {
    return Flight(
      id: 0,
      flightNumber: 'N/A',
      departureCity: 'Unknown',
      arrivalCity: 'Unknown',
      departureTime: DateTime.now(),
      arrivalTime: DateTime.now(),
      status: 'Scheduled',
      availableSeats: 0,
      totalSeats: 0,
      basePrice: 0.0,
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      if (date is String && date.isNotEmpty) {
        return DateTime.parse(date);
      }
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  FlightStatus get statusEnum => FlightStatus.fromString(status);

  String get route => '$departureCity → $arrivalCity';
  String get duration {
    final duration = arrivalTime.difference(departureTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hoursч $minutesм';
  }
}

class FlightDetail {
  final int id;
  final String flightNumber;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String status;
  final int availableSeats;
  final int totalSeats;
  final double basePrice;
  final String aircraftType;
  final String aircraftModel;
  final int aircraftId;
  final int originAirportId;
  final int destinationAirportId;
  final String? gate;
  final String terminal;
  final int durationMinutes;

  FlightDetail({
    required this.id,
    required this.flightNumber,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.availableSeats,
    required this.totalSeats,
    required this.basePrice,
    required this.aircraftType,
    required this.aircraftModel,
    required this.aircraftId,
    required this.originAirportId,
    required this.destinationAirportId,
    this.gate,
    required this.terminal,
    required this.durationMinutes,
  });

  factory FlightDetail.fromJson(Map<String, dynamic> json) {
    return FlightDetail(
      id: json['id'] ?? 0,
      flightNumber: json['flight_number'] ?? 'N/A',
      departureCity: json['departure_city'] ?? 'Unknown',
      arrivalCity: json['arrival_city'] ?? 'Unknown',
      departureTime: json['departure_time'] != null ? DateTime.parse(json['departure_time']) : DateTime.now(),
      arrivalTime: json['arrival_time'] != null ? DateTime.parse(json['arrival_time']) : DateTime.now(),
      status: json['status'] ?? 'Scheduled',
      availableSeats: json['available_seats'] ?? 0,
      totalSeats: json['total_seats'] ?? 0,
      basePrice: (json['base_price'] ?? 0).toDouble(),
      aircraftType: json['aircraft_type'] ?? 'Boeing 737',
      aircraftModel: json['aircraft_model'] ?? '737-800',
      aircraftId: json['aircraft_id'] ?? 0,
      originAirportId: json['origin_airport_id'] ?? 0,
      destinationAirportId: json['destination_airport_id'] ?? 0,
      gate: json['gate'],
      terminal: json['terminal'] ?? 'A',
      durationMinutes: json['duration_minutes'] ?? 0,
    );
  }

  FlightStatus get statusEnum => FlightStatus.fromString(status);

  String get route => '$departureCity → $arrivalCity';
  String get duration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '$hoursч $minutesм';
  }
}
