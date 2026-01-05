import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/flight.dart';
import '../../models/passenger_form_data.dart';
import '../../widgets/booking_timer.dart';

class PassengerDetailsScreen extends StatefulWidget {
  final Flight flight;
  final List<String> selectedSeats;
  final DateTime expiresAt;

  const PassengerDetailsScreen({
    super.key,
    required this.flight,
    required this.selectedSeats,
    required this.expiresAt,
  });

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<PassengerFormData> _passengers = [];

  @override
  void initState() {
    super.initState();
    // Initialize a form for each seat
    for (var seat in widget.selectedSeats) {
      _passengers.add(PassengerFormData(seatNumber: seat));
    }
  }

  void _continue() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Navigate to payment screen
      Navigator.pushNamed(
        context,
        '/payment',
        arguments: {
          'flight': widget.flight,
          'seats': widget.selectedSeats,
          'passengers': List<PassengerFormData>.from(_passengers),
          'expiresAt': widget.expiresAt,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight;
    final selectedSeats = widget.selectedSeats;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Данные пассажиров'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Flight summary header
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primary.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: BookingTimer(
                      expiresAt: widget.expiresAt,
                      onExpired: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            title: const Text('Время вышло'),
                            content: const Text('К сожалению, время на бронирование истекло. Пожалуйста, выберите места заново.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                                child: const Text('ОК'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${flight.departureCity} → ${flight.arrivalCity}',
                    style: theme.textTheme.titleLarge,
                  ),
// ...
                  const SizedBox(height: 4),
                  Text(
                    'Рейс ${flight.flightNumber} • ${DateFormat('dd.MM HH:mm').format(flight.departureTime)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Места: ${selectedSeats.join(", ")}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Passenger forms list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _passengers.length,
                itemBuilder: (context, index) {
                  return _buildPassengerForm(index);
                },
              ),
            ),
            
            // Continue button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Продолжить к оплате'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerForm(int index) {
    final passenger = _passengers[index];
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Пассажир ${index + 1} — Место ${passenger.seatNumber}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // First Name
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Имя *',
                hintText: 'Введите имя',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Пожалуйста, введите имя';
                }
                return null;
              },
              onSaved: (value) {
                passenger.firstName = value?.trim() ?? '';
              },
            ),
            const SizedBox(height: 12),
            
            // Last Name
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Фамилия *',
                hintText: 'Введите фамилию',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Пожалуйста, введите фамилию';
                }
                return null;
              },
              onSaved: (value) {
                passenger.lastName = value?.trim() ?? '';
              },
            ),
            const SizedBox(height: 12),
            
            // Passport Number (optional)
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Номер паспорта (необязательно)',
                hintText: 'Введите номер паспорта',
              ),
              onSaved: (value) {
                passenger.passportNumber = value?.trim();
              },
            ),
            const SizedBox(height: 12),
            
            // Date of Birth (optional)
            InkWell(
              onTap: () => _selectDateOfBirth(index),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата рождения (необязательно)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  passenger.dateOfBirth != null
                      ? DateFormat('dd.MM.yyyy').format(passenger.dateOfBirth!)
                      : 'Выберите дату',
                  style: TextStyle(
                    color: passenger.dateOfBirth != null
                        ? theme.textTheme.bodyLarge?.color
                        : theme.hintColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateOfBirth(int passengerIndex) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _passengers[passengerIndex].dateOfBirth = picked;
      });
    }
  }
}
