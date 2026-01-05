import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class AirportDetailScreen extends StatefulWidget {
  final int airportId;

  const AirportDetailScreen({super.key, required this.airportId});

  @override
  State<AirportDetailScreen> createState() => _AirportDetailScreenState();
}

class _AirportDetailScreenState extends State<AirportDetailScreen> {
  Map<String, dynamic>? _airportDetail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getStaffAirportDetails(widget.airportId);
      setState(() {
        _airportDetail = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(_airportDetail != null ? '${_airportDetail!['code']}' : 'Детали аэропорта'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Вылеты'),
              Tab(text: 'Прилеты'),
            ],
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
          ),
          actions: [
            IconButton(onPressed: _loadDetail, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Ошибка: $_error'))
                : _airportDetail == null
                    ? const Center(child: Text('Данные не найдены'))
                    : TabBarView(
                        children: [
                          _buildFlightsList(_airportDetail!['origin_flights'] ?? []),
                          _buildFlightsList(_airportDetail!['destination_flights'] ?? [], isArrival: true),
                        ],
                      ),
      ),
    );
  }

  Widget _buildFlightsList(List<dynamic> flights, {bool isArrival = false}) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isArrival ? 'Нет прибывающих рейсов' : 'Нет исходящих рейсов',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort flights by time with null safety
    final sortedFlights = List.from(flights)
      ..sort((a, b) {
        final aTime = a['scheduled_departure'] ?? a['departure_time'] ?? '';
        final bTime = b['scheduled_departure'] ?? b['departure_time'] ?? '';
        return aTime.compareTo(bTime);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedFlights.length,
      itemBuilder: (context, index) {
        final flight = sortedFlights[index];
        final timeStr = isArrival 
          ? (flight['scheduled_arrival'] ?? flight['arrival_time']) 
          : (flight['scheduled_departure'] ?? flight['departure_time']);
        
        DateTime dateTime;
        try {
          dateTime = timeStr != null ? DateTime.parse(timeStr) : DateTime.now();
        } catch (e) {
          dateTime = DateTime.now();
        }

        final originCode = (flight['origin_airport']?['code'] as String?) ?? (flight['origin_airport_id']?.toString() ?? '???');
        final destCode = (flight['destination_airport']?['code'] as String?) ?? (flight['destination_airport_id']?.toString() ?? '???');
        final otherPort = isArrival ? originCode : destCode;
        final status = (flight['status'] as String?) ?? 'SCHEDULED';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            leading: Container(
              width: 55,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('HH:mm').format(dateTime),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                  ),
                  Text(
                    DateFormat('dd.MM').format(dateTime),
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ],
              ),
            ),
            title: Text(
              '${flight['flight_number'] ?? 'N/A'}: ${isArrival ? otherPort : (_airportDetail!['code'] ?? '???')} → ${isArrival ? (_airportDetail!['code'] ?? '???') : otherPort}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Статус: $status',
              style: TextStyle(fontSize: 12, color: _getStatusColor(status)),
            ),
            trailing: const Icon(Icons.chevron_right, size: 16),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SCHEDULED': return Colors.blue;
      case 'DELAYED': return Colors.orange;
      case 'CANCELLED': return Colors.red;
      case 'ARRIVED': return Colors.green;
      default: return Colors.grey;
    }
  }
}
