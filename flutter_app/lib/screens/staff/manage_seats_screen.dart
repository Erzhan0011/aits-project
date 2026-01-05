import 'package:flutter/material.dart';
import '../../models/flight.dart';
import '../../models/staff_seat.dart';
import '../../models/seat.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';

class ManageSeatsScreen extends StatefulWidget {
  final Flight flight;

  const ManageSeatsScreen({
    super.key,
    required this.flight,
  });

  @override
  State<ManageSeatsScreen> createState() => _ManageSeatsScreenState();
}

class _ManageSeatsScreenState extends State<ManageSeatsScreen> {
  StaffSeatMap? _seatMap;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getStaffFlightSeats(widget.flight.id);
      setState(() {
        _seatMap = StaffSeatMap.fromJson(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSeatTap(StaffSeat seat) {
    if (seat.status == SeatStatus.occupied) {
      _showOccupiedSeatInfo(seat);
    } else {
      _showAvailableSeatActions(seat);
    }
  }

  void _showOccupiedSeatInfo(StaffSeat seat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Место ${seat.seatNumber}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ЗАНЯТО',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.person, 'Пассажир', seat.passengerName ?? 'Неизвестно'),
            _buildInfoRow(Icons.confirmation_number, 'ID Бронирования', seat.bookingId?.toString() ?? 'N/A'),
            _buildInfoRow(Icons.airline_seat_recline_extra, 'Класс', seat.seatClass == SeatClass.business ? 'Бизнес' : 'Эконом'),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelBooking(seat.bookingId!);
                    },
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('ОТМЕНИТЬ', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      UiUtils.showNotification(context: context, message: 'Используйте список броней для переназначения');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('ПЕРЕНАЗНАЧИТЬ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAvailableSeatActions(StaffSeat seat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Место ${seat.seatNumber}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Это место свободно. Вы можете заблокировать его для системных нужд.'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _blockSeat(seat.seatNumber);
                },
                icon: const Icon(Icons.block),
                label: const Text('ЗАБЛОКИРОВАТЬ МЕСТО'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking(int bookingId) async {
    try {
      await ApiService.cancelBookingStaff(bookingId);
      UiUtils.showNotification(context: context, message: 'Бронирование отменено');
      _loadSeats();
    } catch (e) {
      UiUtils.showNotification(context: context, message: 'Ошибка: $e', isError: true);
    }
  }

  Future<void> _blockSeat(String seatNumber) async {
    try {
      await ApiService.blockSeat(widget.flight.id, seatNumber);
      UiUtils.showNotification(context: context, message: 'Место заблокировано');
      _loadSeats();
    } catch (e) {
      UiUtils.showNotification(context: context, message: 'Ошибка: $e', isError: true);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Карта мест: ${widget.flight.flightNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadSeats, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadSeats, child: const Text('Повторить')),
                    ],
                  ),
                )
              : _buildSeatMap(),
    );
  }

  Widget _buildSeatMap() {
    final seats = _seatMap!.seats;
    if (seats.isEmpty) {
      return const Center(child: Text('Конфигурация мест не найдена'));
    }

    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('МЕСТ', _seatMap!.totalSeats.toString()),
              _buildStat('ЗАНЯТО', _seatMap!.occupiedSeats.toString()),
              _buildStat('СВОБОДНО', _seatMap!.availableSeats.toString()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            spacing: 16,
            children: [
              const _LegendItem(color: Color(0xFFE85D04), label: 'Бизнес'),
              const _LegendItem(color: Color(0xFFFF6B35), label: 'Эконом'),
              _LegendItem(color: Colors.grey[400]!, label: 'Занято', icon: Icons.close),
              const _LegendItem(color: Colors.green, label: 'Выход', icon: Icons.exit_to_app),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  child: Column(
                    children: [
                      _buildPlaneNose(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.symmetric(
                            vertical: BorderSide(color: Colors.grey[300]!, width: 4),
                          ),
                        ),
                        child: _buildCabin(seats),
                      ),
                      _buildPlaneTail(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPlaneNose() {
    return Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(100)),
        border: Border.all(color: Colors.grey[300]!, width: 4),
      ),
      child: const Center(child: Text('НОС', style: TextStyle(fontSize: 10, color: Colors.grey))),
    );
  }

  Widget _buildPlaneTail() {
    return Container(
      width: 150,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(60)),
        border: Border.all(color: Colors.grey[300]!, width: 4),
      ),
    );
  }

  Widget _buildCabin(List<StaffSeat> seats) {
    final rows = seats.map((s) => s.row).toSet().toList()..sort();
    List<Widget> rowWidgets = [];

    for (int r in rows) {
      final seatsInRow = seats.where((s) => s.row == r).toList();
      seatsInRow.sort((a, b) => a.column.compareTo(b.column));

      rowWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 24, child: Text('$r', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              ..._buildSeatsWithAisles(seatsInRow),
              SizedBox(width: 24, child: Text('$r', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      );

      // Add space for wings or exits
      if (r == 2) rowWidgets.add(const SizedBox(height: 30));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(children: rowWidgets),
    );
  }

  List<Widget> _buildSeatsWithAisles(List<StaffSeat> seatsInRow) {
    List<Widget> items = [];
    final count = seatsInRow.length;
    final mid = count ~/ 2;

    for (int i = 0; i < count; i++) {
      if (i == mid) items.add(const SizedBox(width: 24));
      items.add(_buildSeatWidget(seatsInRow[i]));
    }
    return items;
  }

  Widget _buildSeatWidget(StaffSeat seat) {
    Color color;
    if (seat.status == SeatStatus.occupied) {
      color = Colors.grey[400]!;
    } else {
      color = seat.seatClass == SeatClass.business ? const Color(0xFFE85D04) : const Color(0xFFFF6B35);
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: seat.status == SeatStatus.occupied
              ? const Icon(Icons.close, color: Colors.white, size: 18)
              : Text(seat.column, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;

  const _LegendItem({required this.color, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: icon != null ? Icon(icon, size: 10, color: Colors.white) : null,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
