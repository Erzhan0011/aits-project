import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class AircraftDetailScreen extends StatefulWidget {
  final int aircraftId;

  const AircraftDetailScreen({super.key, required this.aircraftId});

  @override
  State<AircraftDetailScreen> createState() => _AircraftDetailScreenState();
}

class _AircraftDetailScreenState extends State<AircraftDetailScreen> {
  Map<String, dynamic>? _aircraftDetail;
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
      final data = await ApiService.getStaffAircraftDetails(widget.aircraftId);
      setState(() {
        _aircraftDetail = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Детали самолёта'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadDetail, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _aircraftDetail == null
                  ? const Center(child: Text('Данные не найдены'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 24),
                          const Text(
                            'Расписание рейсов',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildFlightsList(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.airplanemode_active, color: Colors.blue, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _aircraftDetail!['model'] ?? 'Unknown Model',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _aircraftDetail!['registration_number'] ?? 'N/A',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Вместимость', '${_aircraftDetail!['capacity']} чел.'),
              _buildStat('ID Шаблона', '#${_aircraftDetail!['seat_template_id']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFlightsList() {
    final flights = _aircraftDetail!['flights'] as List? ?? [];
    if (flights.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Нет назначенных рейсов', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final flight = flights[index];
        final depString = flight['scheduled_departure'] ?? flight['departure_time'];
        final departureTime = depString != null ? DateTime.parse(depString) : DateTime.now();
        
        final originCode = (flight['origin_airport']?['code'] as String?) ?? (flight['origin_airport_id']?.toString() ?? '???');
        final destCode = (flight['destination_airport']?['code'] as String?) ?? (flight['destination_airport_id']?.toString() ?? '???');
        final flightNum = (flight['flight_number'] as String?) ?? 'N/A';
        final status = (flight['status'] as String?) ?? 'SCHEDULED';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd MMM').format(departureTime),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  DateFormat('HH:mm').format(departureTime),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            title: Text(
              '$flightNum: $originCode → $destCode',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              status,
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
