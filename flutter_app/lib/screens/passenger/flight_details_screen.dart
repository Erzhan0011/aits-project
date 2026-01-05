import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/flight.dart';

import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';
import '../../models/trip.dart';
import 'ticket_detail_screen.dart';

class FlightDetailsScreen extends StatefulWidget {
  final int flightId;

  const FlightDetailsScreen({
    super.key,
    required this.flightId,
  });

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState extends State<FlightDetailsScreen> {
  FlightDetail? _flightDetail;
  Trip? _userBooking;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFlightDetails();
  }

  Future<void> _loadFlightDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Use protected endpoint if authenticated, otherwise public
      final endpoint = authProvider.isAuthenticated 
          ? '/passenger/flights/${widget.flightId}'
          : '/passenger/public/flight/${widget.flightId}';
      
      final response = await ApiService.get(endpoint);

      if (mounted) {
        setState(() {
          _flightDetail = FlightDetail.fromJson(response.data);
        });
      }

      // Check if user has a booking for this flight
      if (authProvider.isAuthenticated) {
        final tripsResponse = await ApiService.get('/passenger/profile/trips');
        if (tripsResponse.data != null) {
          final List<Trip> trips = [];
          for (var item in (tripsResponse.data as List)) {
            try {
              trips.add(Trip.fromJson(item));
            } catch (e) {
              debugPrint('Error parsing trip: $e');
            }
          }
          
          try {
            final existingBooking = trips.firstWhere(
              (t) => t.flightId == widget.flightId,
            );
            
            if (mounted) {
              setState(() {
                _userBooking = existingBooking;
              });
            }
          } catch (_) {
            // No matching trip found
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // If public endpoint fails, try to give a user-friendly error
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Не удалось загрузить детали рейса. Попробуйте еще раз.';
        });
      }
      debugPrint('Flight details error: $e');
    }
  }

  void _onBookPressed() {
    if(_flightDetail == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      UiUtils.showNotification(
        context: context,
        message: 'Для бронирования необходимо войти в систему',
        isError: true,
      );
      return;
    }

    if (!authProvider.isProfileComplete) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Заполните профиль'),
          content: const Text('Для бронирования билетов необходимо полностью заполнить профиль (ФИО, паспорт, дата рождения).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ОТМЕНА'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRouter.profile);
              },
              child: const Text('К ПРОФИЛЮ'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Create Flight object from Detail
    final flight = Flight(
      id: _flightDetail!.id,
      flightNumber: _flightDetail!.flightNumber,
      departureCity: _flightDetail!.departureCity,
      arrivalCity: _flightDetail!.arrivalCity,
      departureTime: _flightDetail!.departureTime,
      arrivalTime: _flightDetail!.arrivalTime,
      status: _flightDetail!.status,
      availableSeats: _flightDetail!.availableSeats,
      totalSeats: _flightDetail!.totalSeats,
      basePrice: _flightDetail!.basePrice,
      aircraftId: _flightDetail!.aircraftId,
      originAirportId: _flightDetail!.originAirportId,
      destinationAirportId: _flightDetail!.destinationAirportId,
      gate: _flightDetail!.gate,
      terminal: _flightDetail!.terminal,
    );

    Navigator.pushNamed(
      context,
      AppRouter.passengerCount,
      arguments: flight,
    );
  }




  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Детали рейса')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _flightDetail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Детали рейса')),
        body: Center(child: Text('Ошибка: $_error')),
      );
    }

    final flight = _flightDetail!;
    // Use the color from our centralized enum
    final statusColor = flight.statusEnum.color;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: Text('Рейс ${flight.flightNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          if (_userBooking != null)
            IconButton(
              icon: const Icon(Icons.airplane_ticket, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TicketDetailScreen(trips: [_userBooking!]),
                  ),
                );
              },
              tooltip: 'Посмотреть билет',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Status Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        flight.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Route Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRoutePoint(flight.departureCity, flight.departureTime, CrossAxisAlignment.start),
                            Column(
                              children: [
                                Icon(Icons.flight_takeoff, color: Colors.blue[600], size: 28),
                                const SizedBox(height: 6),
                                Text(flight.duration, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            _buildRoutePoint(flight.arrivalCity, flight.arrivalTime, CrossAxisAlignment.end),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Divider(),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryInfo('ЦЕНА ОТ', '${flight.basePrice.toStringAsFixed(0)} ₽', true),
                            _buildSummaryInfo('МЕСТ СВОБОДНО', '${flight.availableSeats}', true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Full Detail List
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('ИНФОРМАЦИЯ О РЕЙСЕ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildDetailItem(Icons.airplane_ticket_outlined, 'Номер рейса', flight.flightNumber),
                        _buildDetailItem(Icons.airplanemode_active_outlined, 'Тип ВС', '${flight.aircraftType} ${flight.aircraftModel}'),
                        _buildDetailItem(Icons.meeting_room, 'Выход / Терминал', '${flight.gate ?? '-'} / ${flight.terminal}'),
                        _buildDetailItem(Icons.access_time_outlined, 'Длительность', flight.duration),
                        _buildDetailItem(Icons.event_seat_outlined, 'Доступные классы', 'Эконом, Бизнес', isLast: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Action
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Enabled only if status is scheduled-like and seats > 0
                  onPressed: (flight.availableSeats > 0 && 
                              flight.status.toLowerCase() != 'cancelled' &&
                              flight.status.toLowerCase() != 'отменен' &&
                              flight.status.toLowerCase() != 'отменён')
                      ? _onBookPressed 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('ВЫБРАТЬ МЕСТА', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePoint(String city, DateTime time, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(DateFormat('HH:mm').format(time), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 2),
        Text(city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
        Text(DateFormat('dd MMM, E').format(time), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  Widget _buildSummaryInfo(String label, String value, bool isBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isBlue ? Colors.blue[800] : Colors.black)),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue[400]),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
            ],
          ),
        ),
        if (!isLast) Divider(color: Colors.grey[100], height: 1),
      ],
    );
  }


}
