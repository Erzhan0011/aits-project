import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/flight.dart';
import '../../models/trip.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';
import '../passenger/ticket_detail_screen.dart';

class ManageBookingsScreen extends StatefulWidget {
  const ManageBookingsScreen({super.key});

  @override
  State<ManageBookingsScreen> createState() => _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends State<ManageBookingsScreen> {
  List<Booking> _allBookings = [];
  List<Booking> _filteredBookings = [];
  List<Flight> _flights = [];
  int? _selectedFlightId;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Handle passed arguments for initial flight filter
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('flight_id')) {
      _selectedFlightId = args['flight_id'] as int?;
    } else if (args is int) {
      _selectedFlightId = args;
    }

    setState(() => _isLoading = true);
    try {
      final flightsResponse = await ApiService.getStaffFlights();
      _flights = flightsResponse.map((json) => Flight.fromJson(json)).toList();
      
      await _loadBookings();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBookings() async {
    try {
      final response = await ApiService.getStaffBookings(
        flightId: _selectedFlightId,
      );
      setState(() {
        _allBookings = response.map((json) => Booking.fromJson(json)).toList();
        _filterBookings(_searchController.text);
      });
    } catch (e) {
      if (mounted) UiUtils.showNotification(context: context, message: 'Ошибка загрузки: $e', isError: true);
    }
  }

  void _filterBookings(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBookings = _allBookings;
      } else {
        query = query.toLowerCase();
        _filteredBookings = _allBookings.where((b) {
          final pnr = b.pnr?.toLowerCase() ?? '';
          final name = '${b.firstName ?? ""} ${b.lastName ?? ""}'.toLowerCase();
          final flight = b.flight.flightNumber.toLowerCase();
          return pnr.contains(query) || name.contains(query) || flight.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _reassignSeat(Booking booking) async {
    final newSeatController = TextEditingController();
    final newSeat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить место (ПРИНУДИТЕЛЬНО)'),
        content: TextField(
          controller: newSeatController,
          decoration: const InputDecoration(
            labelText: 'Новый номер (напр. 1A)',
            hintText: 'Система проверит конфликты',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, newSeatController.text),
            child: const Text('СОХРАНИТЬ'),
          ),
        ],
      ),
    );

    if (newSeat != null && newSeat.isNotEmpty) {
      try {
        await ApiService.post('/staff/bookings/${booking.id}/reassign', data: {'new_seat_number': newSeat});
        await _loadBookings();
        if (mounted) UiUtils.showNotification(context: context, message: 'Место успешно изменено');
      } catch (e) {
        if (mounted) UiUtils.showNotification(context: context, message: 'Ошибка: $e', isError: true);
      }
    }
  }

  Future<void> _cancelBooking(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена бронирования'),
        content: const Text('Вы уверены? Это приведет к аннуляции билета.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('НЕТ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ДА, ОТМЕНИТЬ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.cancelBookingStaff(id);
        await _loadBookings();
        if (mounted) UiUtils.showNotification(context: context, message: 'Бронирование отменено');
      } catch (e) {
        if (mounted) UiUtils.showNotification(context: context, message: 'Ошибка отмены: $e', isError: true);
      }
    }
  }

  void _viewTicket(Booking booking) {
    // Convert Booking to Trip for TicketDetailScreen
    final trip = Trip(
      id: booking.id,
      passengerId: booking.passengerId,
      flightId: booking.flightId,
      flight: booking.flight,
      seatNumber: booking.seatNumber,
      price: booking.price,
      status: booking.status.name.toUpperCase(),
      createdAt: booking.createdAt,
      pnr: booking.pnr ?? 'N/A',
      terminal: booking.flight.terminal,
      gate: booking.flight.gate,
      paymentMethod: booking.paymentMethod?.name.toUpperCase() ?? 'NONE',
      checkedIn: booking.checkedIn,
      qrCode: booking.qrCode,
      firstName: booking.firstName,
      lastName: booking.lastName,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailScreen(trips: [trip]),
      ),
    );
  }

  Future<void> _checkConflicts() async {
    if (_selectedFlightId == null) {
      UiUtils.showNotification(context: context, message: 'Выберите рейс для проверки конфликтов', isError: true);
      return;
    }

    try {
      final conflictsRaw = await ApiService.getSeatConflicts(_selectedFlightId!);
      if (conflictsRaw.isEmpty) {
        if (mounted) UiUtils.showNotification(context: context, message: 'Конфликтов на рейсе не обнаружено');
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Конфликты мест', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: conflictsRaw.length,
                    itemBuilder: (context, index) {
                      final conflict = conflictsRaw[index];
                      final seat = conflict['seat_number'];
                      final bookings = (conflict['bookings'] as List).map((j) => Booking.fromJson(j)).toList();
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.red[50],
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.warning, color: Colors.red),
                              title: Text('Место $seat', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Найдено ${bookings.length} бронирований'),
                            ),
                            ...bookings.map((b) => ListTile(
                              title: Text('${b.firstName} ${b.lastName} (${b.pnr})'),
                              subtitle: Text('Дата: ${DateFormat('dd.MM HH:mm').format(b.createdAt)}'),
                              trailing: TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _reassignSeat(b);
                                },
                                child: const Text('ИЗМЕНИТЬ'),
                              ),
                            )),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) UiUtils.showNotification(context: context, message: 'Ошибка при проверке: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Управление бронированиями'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: _checkConflicts,
            tooltip: 'Проверка конфликтов',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _filteredBookings.isEmpty
                        ? _buildEmptyView()
                        : _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedFlightId,
                  decoration: InputDecoration(
                    labelText: 'Рейс',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все рейсы')),
                    ..._flights.map((f) => DropdownMenuItem(
                      value: f.id,
                      child: Text('${f.flightNumber}: ${f.departureCity} → ${f.arrivalCity}'),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedFlightId = val);
                    _loadBookings();
                  },
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Colors.blue[50],
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: _loadBookings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по PNR, фамилии или номеру рейса',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: _filterBookings,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return ListView.builder(
      itemCount: _filteredBookings.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final b = _filteredBookings[index];
        final isCancelled = b.status == BookingStatus.cancelled;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    Text(
                      b.pnr ?? 'NO-PNR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(b.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b.status.name.toUpperCase(),
                        style: TextStyle(color: _getStatusColor(b.status), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.flight_takeoff, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${b.flight.flightNumber}: ${b.flight.departureCity} → ${b.flight.arrivalCity}', 
                             style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${b.firstName} ${b.lastName}', style: const TextStyle(color: Colors.black)),
                        const Spacer(),
                        const Icon(Icons.event_seat_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('МЕСТО ${b.seatNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewTicket(b),
                      icon: const Icon(Icons.airplane_ticket_outlined, size: 18),
                      label: const Text('БИЛЕТ'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                    ),
                    if (!isCancelled) ...[
                      TextButton.icon(
                        onPressed: () => _reassignSeat(b),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('МЕСТО'),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
                      ),
                      TextButton.icon(
                        onPressed: () => _cancelBooking(b.id),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('ОТМЕНА'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed: return Colors.green;
      case BookingStatus.cancelled: return Colors.red;
      case BookingStatus.pending: return Colors.orange;
    }

  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Неизвестная ошибка'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadInitialData, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Бронирования не найдены', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
