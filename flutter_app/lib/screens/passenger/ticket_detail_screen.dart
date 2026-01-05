import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../models/flight.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_router.dart';

class TicketDetailScreen extends StatefulWidget {
  final List<Trip> trips;

  const TicketDetailScreen({super.key, required this.trips});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trips.isEmpty) return const SizedBox();
    final mainTrip = widget.trips.first;
    final Flight() = mainTrip.flight;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Детали поездки'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Инфо'),
            Tab(text: 'Пассажиры'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(mainTrip),
          _buildPassengersTab(),
          _buildHistoryTab(mainTrip),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Trip trip) {
    final flight = trip.flight;
    final AuthProvider() = Provider.of<AuthProvider>(context);
    final bool() = widget.trips.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // Flight Header with Gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor, 
                        Colors.orange,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flight.departureCity,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                DateFormat('HH:mm, dd MMM').format(flight.departureTime),
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                              ),
                            ],
                          ),
                          Icon(Icons.flight_takeoff, color: Colors.white.withOpacity(0.9), size: 36),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                flight.arrivalCity,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                DateFormat('HH:mm, dd MMM').format(flight.arrivalTime),
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trip.statusText,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem('РЕЙС', flight.flightNumber),
                          _buildInfoItem('МЕСТО', trip.seatNumber),
                          _buildInfoItem('КЛАСС', 'ЭКОНОМ'), // TODO: Dynamic class
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem('ГЕЙТ', trip.gate ?? 'A1'),
                          _buildInfoItem('ТЕРМИНАЛ', trip.terminal),
                          _buildInfoItem('PNR', trip.pnr),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Flight Progress if In Flight
                      if (trip.tripStatus == TripStatus.inFlight) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${trip.flight.departureCity} (${flight.flightNumber})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('В ПОЛЕТЕ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                                Text(trip.flight.arrivalCity, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final progress = _getFlightProgress(trip.flight);
                                final width = constraints.maxWidth;
                                final currentWidth = width * progress;
                                
                                return SizedBox(
                                  height: 30, // Enough height for the plane
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      // Track
                                      Container(
                                        height: 6,
                                        width: width,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      // Progress
                                      Container(
                                        height: 6,
                                        width: currentWidth,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.orange.shade300, Theme.of(context).primaryColor],
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      // Plane
                                      Positioned(
                                        left: (currentWidth - 12).clamp(0.0, width - 24),
                                        child: Transform.rotate(
                                          angle: 1.57, // Point right
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                )
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.flight, 
                                              size: 20, 
                                              color: Theme.of(context).primaryColor
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Status Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(trip.tripStatus),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(trip.tripStatus).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(trip.tripStatus),
                              color: _getStatusColor(trip.tripStatus),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                trip.checkinStatusMessage,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(trip.tripStatus).withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (trip.checkedIn) ...[
                          ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRouter.checkin,
                              arguments: widget.trips,
                            );
                          },
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('ПОСАДОЧНЫЙ ТАЛОН'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if (trip.tripStatus == TripStatus.checkinAvailable) ...[
                         ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRouter.checkin,
                              arguments: widget.trips,
                            );
                          },
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('ПРОЙТИ РЕГИСТРАЦИЮ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => PdfService.generateAndSaveTicket(trip, '${trip.firstName ?? ""} ${trip.lastName ?? ""}'),
                        icon: const Icon(Icons.download),
                        label: const Text('СКАЧАТЬ БИЛЕТ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: widget.trips.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final paxTrip = widget.trips[index];
        final fullName = '${paxTrip.firstName ?? "Пассажир"} ${paxTrip.lastName ?? "${index + 1}"}';
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                fullName[0].toUpperCase(),
                style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Билет #${paxTrip.id}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                paxTrip.seatNumber,
                style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPaxDetail('ПАСПОРТ', paxTrip.passportNumber ?? '—'),
                    _buildPaxDetail('ДАТА РОЖД.', paxTrip.dateOfBirth != null ? DateFormat('dd.MM.yyyy').format(paxTrip.dateOfBirth!) : '—'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaxDetail(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildHistoryTab(Trip trip) {
    final events = [
      {'title': 'Бронирование создано', 'date': trip.createdAt, 'icon': Icons.create, 'message': null},
      if (trip.confirmedAt != null)
        {'title': 'Оплата подтверждена', 'date': trip.confirmedAt!, 'icon': Icons.payment, 'message': null},
      if (trip.checkedIn && trip.checkedInAt != null)
        {'title': 'Регистрация пройдена', 'date': trip.checkedInAt!, 'icon': Icons.check_circle, 'message': null},
      if (trip.tripStatus == TripStatus.inFlight)
        {'title': 'Вылет состоялся', 'date': trip.flight.departureTime, 'icon': Icons.flight_takeoff, 'message': null},
      if (trip.tripStatus == TripStatus.completed)
        {'title': 'Рейс прибыл', 'date': trip.flight.arrivalTime, 'icon': Icons.flight_land, 'message': null},
      // Add dynamic history from backend
      ...trip.history.map((h) => {
        'title': h.title,
        'date': h.createdAt,
        'icon': Icons.notification_important_outlined,
        'message': h.message,
      }),
    ];

    events.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final date = event['date'] as DateTime;
        final isLast = index == events.length - 1;
        final message = event['message'] as String?;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).primaryColor),
                  ),
                  child: Icon(event['icon'] as IconData, size: 16, color: Theme.of(context).primaryColor),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: message != null ? 70 : 40,
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(message, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Text(DateFormat('dd MMM yyyy, HH:mm').format(date), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _getFlightProgress(Flight flight) {
    final now = DateTime.now();
    if (now.isBefore(flight.departureTime)) return 0.0;
    if (now.isAfter(flight.arrivalTime)) return 1.0;
    
    final total = flight.arrivalTime.difference(flight.departureTime).inSeconds;
    if (total <= 0) return 0.0;
    
    final elapsed = now.difference(flight.departureTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.upcoming: return Colors.blue;
      case TripStatus.checkinAvailable: return Colors.orange;
      case TripStatus.checkedIn: return Colors.green;
      case TripStatus.inFlight: return Colors.deepOrange;
      case TripStatus.completed: return Colors.grey;
      case TripStatus.cancelled: return Colors.red;
      case TripStatus.created: return Colors.amber;
    }
    // ignore: dead_code
    return Colors.grey;
  }

  Color _getStatusBgColor(TripStatus status) {
    final color = _getStatusColor(status);
    return color.withOpacity(0.1);
  }

  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.upcoming: return Icons.info_outline;
      case TripStatus.checkinAvailable: return Icons.notification_important;
      case TripStatus.checkedIn: return Icons.check_circle;
      case TripStatus.inFlight: return Icons.flight_takeoff;
      case TripStatus.completed: return Icons.flight_land;
      case TripStatus.cancelled: return Icons.cancel;
      case TripStatus.created: return Icons.timer;
    }
    // ignore: dead_code
    return Icons.help_outline;
  }

  Widget _buildInfoItem(String label, String value, {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
