import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flight.dart';
import '../../models/seat.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';

class SeatSelectionScreen extends StatefulWidget {
  final Flight flight;
  final int passengersCount;

  const SeatSelectionScreen({
    super.key,
    required this.flight,
    required this.passengersCount,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  List<Seat> _seats = [];
  final Set<String> _selectedSeatNumbers = {};
  bool _isLoading = true;
  String? _error;
  late TransformationController _transformationController;
  Map<int, List<Seat>> _groupedSeats = {};

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadSeatsFromAPI();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadSeatsFromAPI() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.get('/passenger/flights/${widget.flight.id}/seats');
      
      if (response.data != null && response.data['seats'] != null) {
        final seatsData = response.data['seats'] as List;
        _seats = seatsData.map((json) => Seat.fromJson(json)).toList();
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _groupSeats();
        });
      }
    } catch (e) {
      debugPrint('Error loading seats: $e');
      // If API fails, fall back to mock data
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка загрузки мест: $e. Используются демо-данные.',
          isError: true,
        );
        _generateMockSeatMap();
      }
    }
  }

  void _generateMockSeatMap() {
    List<Seat> generatedSeats = [];
    final cols = ['A', 'B', 'C', 'D', 'E', 'F'];
    final capacity = widget.flight.totalSeats;
    const seatsPerRow = 6;
    final neededRows = (capacity / seatsPerRow).ceil();

    for (int r = 1; r <= neededRows; r++) {
      for (int i = 0; i < seatsPerRow; i++) {
        if (generatedSeats.length >= capacity) break;
        
        final c = cols[i];
        bool isOccupied = (r * c.codeUnitAt(0)) % 7 == 0;
        bool isExit = (r == 12 || r == 13);
        bool isBusiness = r <= 2;
        
        generatedSeats.add(Seat(
          seatNumber: '$r$c',
          row: r,
          column: c,
          seatClass: isBusiness ? SeatClass.business : SeatClass.economy,
          status: isOccupied ? SeatStatus.occupied : SeatStatus.available,
          isEmergencyExit: isExit,
          price: isBusiness ? widget.flight.basePrice * 2 : widget.flight.basePrice,
        ));
      }
      if (generatedSeats.length >= capacity) break;
    }

    setState(() {
      _seats = generatedSeats;
      _isLoading = false;
      _groupSeats();
    });
  }

  void _groupSeats() {
    _groupedSeats = {};
    for (var seat in _seats) {
      _groupedSeats.putIfAbsent(seat.row, () => []).add(seat);
    }
    // Sort seats in each row by column
    for (var rowSeats in _groupedSeats.values) {
      rowSeats.sort((a, b) => a.column.compareTo(b.column));
    }
  }

  void _toggleSeat(Seat seat) {
    setState(() {
      if (_selectedSeatNumbers.contains(seat.seatNumber)) {
        _selectedSeatNumbers.remove(seat.seatNumber);
      } else {
        if (_selectedSeatNumbers.length < widget.passengersCount) {
          _selectedSeatNumbers.add(seat.seatNumber);
        } else {
          UiUtils.showNotification(
            context: context,
            message: 'Вы уже выбрали максимальное количество мест',
            isError: true,
          );
        }
      }
    });
  }

  Color _getSeatColor(Seat seat, bool isSelected) {
    if (isSelected) return Colors.orange;
    if (seat.isOccupied || seat.status == SeatStatus.reserved || seat.status == SeatStatus.held) {
      return Colors.grey;
    }

    switch (seat.seatClass) {
      case SeatClass.business:
        return const Color(0xFFE85D04);
      case SeatClass.economy:
        return const Color.fromARGB(255, 134, 67, 43);
      case SeatClass.standard:
        return const Color.fromARGB(255, 86, 66, 26);
      // ignore: unreachable_switch_default
      default:
        return const Color(0xFFFF6B35);
    }
  }

  double get _totalPrice {
    double total = 0;
    for (var seatNum in _selectedSeatNumbers) {
      final seat = _seats.firstWhere(
        (s) => s.seatNumber == seatNum, 
        orElse: () => const Seat(seatNumber: '', row: 0, column: '', seatClass: SeatClass.economy, status: SeatStatus.available)
      );
      // Use seat specific price if available, else flight base price
      total += seat.price ?? widget.flight.basePrice;
    }
    return total;
  }

  Future<void> _autoAssignSeats() async {
    final availableSeats = _seats.where((s) => !s.isOccupied && s.status != SeatStatus.reserved && s.status != SeatStatus.held).toList();
    
    if (availableSeats.length < widget.passengersCount) {
      UiUtils.showNotification(
        context: context,
        message: 'Недостаточно свободных мест для автоназначения',
        isError: true,
      );
      return;
    }

    // Shuffle and pick
    availableSeats.shuffle();
    final picked = availableSeats.take(widget.passengersCount).map((s) => s.seatNumber).toList();

    setState(() {
      _selectedSeatNumbers.clear();
      _selectedSeatNumbers.addAll(picked);
    });
    
    // Automatically proceed to the next step
    await _confirmSelection();
  }

  Future<void> _confirmSelection() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      UiUtils.showNotification(
        context: context,
        message: 'Для бронирования необходимо войти в систему',
        isError: true,
      );
      return;
    }

    // Hold seats on backend
    final expiresAt = await bookingProvider.holdSeats(widget.flight.id, _selectedSeatNumbers.toList());
    
    if (expiresAt == null) {
      if (!mounted) return;
      UiUtils.showNotification(
        context: context,
        message: bookingProvider.error ?? 'Ошибка бронирования мест',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    
    UiUtils.showNotification(
      context: context,
      message: 'Места забронированы. У вас есть 10 минут на оплату.',
    );

    Navigator.pushNamed(
      context,
      AppRouter.passengerDetails,
      arguments: {
        'flight': widget.flight,
        'selectedSeats': _selectedSeatNumbers.toList(),
        'expiresAt': expiresAt,
      },
    );
  }

  // ignore: unused_element
  void _showBookingSuccess(int bookingId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Бронирование подтверждено!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text('Номер бронирования: $bookingId', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Рейс: ${widget.flight.flightNumber}', style: const TextStyle(fontSize: 15)),
            Text('${widget.flight.departureCity} → ${widget.flight.arrivalCity}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            const Text('Выбранные места:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedSeatNumbers.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.blue[100],
              )).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итого к оплате:', style: TextStyle(fontSize: 15)),
                  Text('${_totalPrice.toStringAsFixed(0)} ₽', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[800])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ГОТОВО', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
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
        title: const Text('Выбор мест'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSeatsFromAPI,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Subtitle
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      width: double.infinity,
                      child: Column(
                        children: [
                          Text(
                            'Рейс ${widget.flight.flightNumber}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.flight.departureCity} → ${widget.flight.arrivalCity}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),

                    // Legend
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.white,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildLegendItem(const Color(0xFFE85D04), 'Бизнес'),
                          _buildLegendItem(const Color(0xFFFF6B35), 'Эконом'),
                          _buildLegendItem(Colors.grey[400]!, 'Занято', icon: Icons.close),
                          _buildLegendItem(Colors.orange, 'Выбрано'),
                          _buildLegendItem(Colors.green, 'Выход', icon: Icons.exit_to_app),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Seat Map (Vertical Only)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Airplane Nose
                                  const RepaintBoundary(child: _PlaneNose()),
                                  
                                  // Main Cabin
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5),
                                      ],
                                      border: Border.symmetric(
                                        vertical: BorderSide(color: Colors.grey[300]!, width: 4),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 40),
                                        if (_seats.any((s) => s.seatClass == SeatClass.business)) ...[
                                          _buildSectionHeader(
                                            'БИЗНЕС-КЛАСС', 
                                            _seats.firstWhere((s) => s.seatClass == SeatClass.business).price ?? widget.flight.basePrice * 2
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: _buildSeatGrid(_groupedSeats.values.where((r) => r.any((s) => s.seatClass == SeatClass.business)).expand((e) => e).toList()),
                                          ),
                                          const SizedBox(height: 40),
                                          const RepaintBoundary(child: _Wings()),
                                          const SizedBox(height: 40),
                                        ],

                                        if (_seats.any((s) => s.seatClass == SeatClass.economy || s.seatClass == SeatClass.standard)) ...[
                                          _buildSectionHeader(
                                            'ЭКОНОМ-КЛАСС', 
                                            _seats.firstWhere((s) => s.seatClass == SeatClass.economy || s.seatClass == SeatClass.standard).price ?? widget.flight.basePrice
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: _buildSeatGrid(_groupedSeats.values.where((r) => r.any((s) => s.seatClass == SeatClass.economy || s.seatClass == SeatClass.standard)).expand((e) => e).toList()),
                                          ),
                                        ],
                                        const SizedBox(height: 40),
                                      ],
                                    ),
                                  ),
                                  
                                  // Airplane Tail
                                  const RepaintBoundary(child: _PlaneTail()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Summary Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1), offset: const Offset(0, -5)),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Выбрано: ${_selectedSeatNumbers.length} / ${widget.passengersCount}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${_totalPrice.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _autoAssignSeats,
                                    icon: const Icon(Icons.auto_awesome, size: 18),
                                    label: const Text('АВТО-ВЫБОР', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      side: BorderSide(color: Theme.of(context).primaryColor),
                                      foregroundColor: Theme.of(context).primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: (_selectedSeatNumbers.length == widget.passengersCount)
                                        ? _confirmSelection
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      disabledBackgroundColor: Colors.grey[300],
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: const Text('ПРОДОЛЖИТЬ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSectionHeader(String title, double price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black45, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5), width: 1.5),
            ),
            child: Text(
              '${price.toStringAsFixed(0)} ₽',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE85D04), fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatGrid(List<Seat> sectionSeats) {
    if (sectionSeats.isEmpty) return const SizedBox.shrink();

    final rows = sectionSeats.map((s) => s.row).toSet().toList()..sort();
    List<Widget> rowWidgets = [];

    for (int r in rows) {
      final seatsInRow = _groupedSeats[r] ?? [];
      if (seatsInRow.isEmpty) continue;

      // Check if this is an emergency exit row
      final isExitRow = seatsInRow.any((s) => s.isEmergencyExit);
      final int() = seatsInRow.length;

      rowWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emergency exit indicator (left)
              if (isExitRow)
                const Icon(Icons.exit_to_app, size: 16, color: Colors.green)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 4),

              // Row Number
              SizedBox(
                width: 24,
                child: Text('$r', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              ),

              // Dynamic Seats with Aisle(s)
              ..._buildSeatsWithAisles(seatsInRow),

              // Row Number (right)
              SizedBox(
                width: 24,
                child: Text('$r', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              ),

              const SizedBox(width: 4),
              // Emergency exit indicator (right)
              if (isExitRow)
                const Icon(Icons.exit_to_app, size: 16, color: Colors.green)
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      );
    }

    return Column(children: rowWidgets);
  }

  List<Widget> _buildSeatsWithAisles(List<Seat> seatsInRow) {
    List<Widget> items = [];
    final count = seatsInRow.length;

    if (count <= 4) {
      // 2-2 or similar
      int mid = count ~/ 2;
      for (int i = 0; i < count; i++) {
        if (i == mid) items.add(const SizedBox(width: 24)); // Aisle
        items.add(_buildSeatItem(seatsInRow[i]));
      }
    } else if (count == 6) {
      // 3-3
      for (int i = 0; i < count; i++) {
        if (i == 3) items.add(const SizedBox(width: 24)); // Aisle
        items.add(_buildSeatItem(seatsInRow[i]));
      }
    } else if (count >= 10) {
      // 3-4-3 (Widebody)
      for (int i = 0; i < count; i++) {
        if (i == 3 || i == 7) items.add(const SizedBox(width: 16)); // Double aisles for widebody
        items.add(_buildSeatItem(seatsInRow[i]));
      }
    } else {
      // Generic fallback
      int mid = count ~/ 2;
      for (int i = 0; i < count; i++) {
        if (i == mid) items.add(const SizedBox(width: 20));
        items.add(_buildSeatItem(seatsInRow[i]));
      }
    }
    return items;
  }


  Widget _buildSeatItem(Seat seat) {
    final isSelected = _selectedSeatNumbers.contains(seat.seatNumber);
    final color = _getSeatColor(seat, isSelected);
    final isAvailable = !seat.isOccupied && seat.status != SeatStatus.reserved && seat.status != SeatStatus.held;

    return GestureDetector(
      onTap: isAvailable ? () => _toggleSeat(seat) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        width: 42,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.orange[900]! : (isAvailable ? color.withOpacity(0.5) : Colors.transparent),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
            if (isAvailable && !isSelected)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner indentation effect
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              bottom: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            if (seat.isOccupied)
              const Icon(Icons.close, color: Colors.white, size: 20)
            else if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 22)
            else
              Text(
                seat.column,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: icon != null ? Icon(icon, size: 10, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: color.withOpacity(1.0) == Colors.white ? Colors.black : color,
            )
          ),
        ],
      ),
    );
  }
}

class _PlaneNose extends StatelessWidget {
  const _PlaneNose();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(100)),
        border: Border.all(color: Colors.grey[300]!, width: 4),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue[900]!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: Text('COCKPIT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaneTail extends StatelessWidget {
  const _PlaneTail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(60)),
        border: Border.all(color: Colors.grey[300]!, width: 4),
      ),
    );
  }
}

class _Wings extends StatelessWidget {
  const _Wings();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(100),
              bottomLeft: Radius.circular(20),
            ),
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
        ),
        const SizedBox(width: 200),
        Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(100),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
        ),
      ],
    );
  }
}
