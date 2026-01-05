import 'package:flutter/foundation.dart';
import '../models/flight.dart';
import '../models/airport.dart';
import '../services/api_service.dart';

class FlightProvider with ChangeNotifier {
  List<Flight> _flights = [];
  List<Airport> _airports = [];
  bool _isLoading = false;
  String? _error;

  List<Flight> get flights => _flights;
  List<Airport> get airports => _airports;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAirports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/passenger/airports');
      _airports = (response.data as List)
          .map((json) => Airport.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchFlights({
    required String originCode,
    required String destinationCode,
    required DateTime departureDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.post('/passenger/flights/search', data: {
        'origin_code': originCode,
        'destination_code': destinationCode,
        'departure_date': departureDate.toIso8601String(),
      });

      _flights = (response.data as List)
          .map((json) => Flight.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Flight?> getFlightDetails(int flightId) async {
    try {
      final response = await ApiService.get('/passenger/flights/$flightId');
      return Flight.fromJson(response.data);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearFlights() {
    _flights = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}



