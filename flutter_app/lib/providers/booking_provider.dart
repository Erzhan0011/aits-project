import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/trip.dart';
import '../services/api_service.dart';

class BookingProvider with ChangeNotifier {
  List<Booking> _bookings = [];
  List<Trip> _trips = [];
  bool _isLoading = false;
  String? _error;

  List<Booking> get bookings => _bookings;
  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filtered trips for UI tabs
  List<Trip> get upcomingTrips => _trips.where((t) => 
    t.tripStatus == TripStatus.upcoming || 
    t.tripStatus == TripStatus.checkinAvailable || 
    t.tripStatus == TripStatus.checkedIn ||
    t.tripStatus == TripStatus.inFlight ||
    t.tripStatus == TripStatus.created
  ).toList();
  
  List<Trip> get pastTrips => _trips.where((t) => 
    t.tripStatus == TripStatus.completed
  ).toList();

  List<Trip> get cancelledTrips => _trips.where((t) => 
    t.tripStatus == TripStatus.cancelled
  ).toList();

  Future<DateTime?> holdSeats(int flightId, List<String> seatNumbers) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/passenger/flights/$flightId/hold-seats',
        data: {'seat_numbers': seatNumbers},
      );
      
      _isLoading = false;
      notifyListeners();
      
      final expiresAtStr = response.data['expires_at'] as String;
      return DateTime.parse(expiresAtStr);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadTrips({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await ApiService.get('/passenger/profile/trips');
      if (response.data != null) {
        _trips = (response.data as List)
            .map((json) => Trip.fromJson(json))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List<List<Trip>> groupTrips(List<Trip> tripList) {
    final Map<String, List<Trip>> groups = {};
    for (var trip in tripList) {
      String key;
      if (trip.transactionId != null && trip.transactionId!.isNotEmpty) {
        key = 'TX_${trip.transactionId}';
      } else {
        final window = (trip.createdAt.millisecondsSinceEpoch / (1000 * 60 * 10)).floor();
        key = 'AUTO_${trip.passengerId}_${trip.flightId}_$window';
      }
      
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(trip);
    }
    
    final sortedGroups = groups.values.toList();
    sortedGroups.sort((a, b) => b.first.createdAt.compareTo(a.first.createdAt));
    return sortedGroups;
  }

  Future<void> loadBookings({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final response = await ApiService.get('/passenger/profile/trips');
      _bookings = (response.data as List)
          .map((json) => Booking.fromJson(json))
          .toList();
      if (showLoading) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      if (showLoading) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<bool> cancelBooking(int bookingId) async {
    _error = null;
    try {
      await ApiService.post('/passenger/bookings/$bookingId/cancel');
      await loadTrips(silent: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkIn(int ticketId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.post('/passenger/check-in', data: {
        'ticket_id': ticketId,
      });
      _isLoading = false;
      notifyListeners();
      return response.data;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}



