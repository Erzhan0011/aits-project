import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/flight.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_utils.dart';

class PassengerInfoScreen extends StatefulWidget {
  final Flight flight;
  final int passengersCount;
  final List<String> selectedSeats;

  const PassengerInfoScreen({
    super.key,
    required this.flight,
    required this.passengersCount,
    required this.selectedSeats,
  });

  @override
  State<PassengerInfoScreen> createState() => _PassengerInfoScreenState();
}

class _PassengerInfoScreenState extends State<PassengerInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, TextEditingController>> _controllers = [];
  final List<DateTime?> _birthDates = [];
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each passenger
    for (int i = 0; i < widget.selectedSeats.length; i++) {
      _controllers.add({
        'firstName': TextEditingController(),
        'lastName': TextEditingController(),
        'passport': TextEditingController(),
      });
      _birthDates.add(null);
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controllerSet in _controllers) {
      for (var controller in controllerSet.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDates[index] = picked;
      });
    }
  }

  double get _totalPrice => widget.flight.basePrice * widget.selectedSeats.length;

  Future<void> _bookFlightWithPassengers() async {
    if (!_formKey.currentState!.validate()) {
      UiUtils.showNotification(
        context: context,
        message: 'Пожалуйста, заполните все обязательные поля',
        isError: true,
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      UiUtils.showNotification(
        context: context,
        message: 'Для бронирования необходимо войти в систему',
        isError: true,
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    try {
      // Prepare passenger data
      List<Map<String, dynamic>> passengers = [];
      for (int i = 0; i < widget.selectedSeats.length; i++) {
        passengers.add({
          'seat_number': widget.selectedSeats[i],
          'first_name': _controllers[i]['firstName']!.text.trim(),
          'last_name': _controllers[i]['lastName']!.text.trim(),
          'passport_number': _controllers[i]['passport']!.text.trim().isEmpty 
              ? null 
              : _controllers[i]['passport']!.text.trim(),
          'date_of_birth': _birthDates[i]?.toIso8601String(),
        });
      }

      final response = await ApiService.post(
        '/passenger/flights/${widget.flight.id}/book',
        data: {
          'seat_numbers': widget.selectedSeats,
          'passengers': passengers,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (mounted) {
          _showBookingSuccess(response.data['booking_id'] ?? 0);
        }
      } else {
        throw Exception('Бронирование не удалось');
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка бронирования: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

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
                  Text('Номер: $bookingId', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Рейс: ${widget.flight.flightNumber}', style: const TextStyle(fontSize: 15)),
            Text('${widget.flight.departureCity} → ${widget.flight.arrivalCity}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            const Text('Места:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedSeats.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итого:', style: TextStyle(fontSize: 15)),
                  Text('${_totalPrice.toStringAsFixed(0)} ₽', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18, 
                      color: Theme.of(context).colorScheme.primary
                    )
                  ),
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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Данные пассажиров'),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Flight Info Header
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
                const SizedBox(height: 8),
                Text(
                  'Выбранные места: ${widget.selectedSeats.join(", ")}',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.selectedSeats.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Место ${widget.selectedSeats[index]}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Пассажир ${index + 1}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // First Name
                          TextFormField(
                            controller: _controllers[index]['firstName'],
                            decoration: const InputDecoration(
                              labelText: 'Имя *',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите имя';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // Last Name
                          TextFormField(
                            controller: _controllers[index]['lastName'],
                            decoration: const InputDecoration(
                              labelText: 'Фамилия *',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите фамилию';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // Passport Number
                          TextFormField(
                            controller: _controllers[index]['passport'],
                            decoration: const InputDecoration(
                              labelText: 'Номер паспорта (опционально)',
                              prefixIcon: Icon(Icons.badge),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Date of Birth
                          TextFormField(
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Дата рождения (опционально)',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(
                              text: _birthDates[index] != null
                                  ? DateFormat('dd.MM.yyyy').format(_birthDates[index]!)
                                  : '',
                            ),
                            onTap: () => _selectDate(context, index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, -5)
                ),
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
                      const Text(
                        'Итого к оплате:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_totalPrice.toStringAsFixed(0)} ₽',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isBooking ? null : _bookFlightWithPassengers,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isBooking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'ЗАБРОНИРОВАТЬ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
