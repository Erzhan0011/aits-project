import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/flight.dart';
import '../../models/passenger_form_data.dart';
import '../../services/api_service.dart';
import '../../widgets/booking_timer.dart';
import '../../utils/ui_utils.dart';
import '../../utils/app_router.dart';

class PaymentScreen extends StatefulWidget {
  final Flight flight;
  final List<String> seats;
  final List<PassengerFormData> passengers;
  final DateTime expiresAt;

  const PaymentScreen({
    super.key,
    required this.flight,
    required this.seats,
    required this.passengers,
    required this.expiresAt,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;

  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _paymentDataController = TextEditingController(); // For Apple/Google Pay ID

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    _paymentDataController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) {
      UiUtils.showNotification(
        context: context,
        message: 'Выберите способ оплаты',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Build request
      final requestData = {
        'passengers': widget.passengers.map((p) => p.toJson()).toList(),
        'payment_method': _selectedPaymentMethod,
        // In a real premium app, we would send card details via a secure token (like Stripe Token)
        // For this mock, we send details to simulate backend validation
        if (_selectedPaymentMethod == 'CARD') ...{
          'card_number': _cardNumberController.text.replaceAll(' ', ''),
          'card_expiry': _cardExpiryController.text,
          'card_cvv': _cardCvvController.text,
          'card_holder': _cardHolderController.text,
        } else ...{
          'payment_data': _paymentDataController.text.isNotEmpty ? _paymentDataController.text : 'dummy_ref',
        },
      };

      // ignore: unused_local_variable
      final response = await ApiService.post(
        '/passenger/flights/${widget.flight.id}/book-with-passengers',
        data: requestData,
      );

      if (!mounted) return;

      // Show high-quality success feedback
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  'ОПЛАТА УСПЕШНА',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ваше путешествие начинается! Электронные билеты уже доступны в личном кабинете.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
                      Navigator.pushNamed(context, AppRouter.myBookings);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('ПОСМОТРЕТЬ БИЛЕТЫ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      UiUtils.showNotification(
        context: context,
        message: e.toString().contains('402') 
            ? 'Карта отклонена. Пожалуйста, попробуйте другую карту.' 
            : 'Ошибка оплаты: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight;
    final seats = widget.seats;
    final passengers = widget.passengers;
    final theme = Theme.of(context);

    final totalPrice = flight.basePrice * seats.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оплата'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                        'Детали бронирования',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildInfoRow('Рейс', flight.flightNumber),
                      _buildInfoRow(
                        'Маршрут',
                        '${flight.departureCity} → ${flight.arrivalCity}',
                      ),
                      _buildInfoRow(
                        'Вылет',
                        DateFormat('dd.MM.yyyy HH:mm').format(flight.departureTime),
                      ),
                      _buildInfoRow('Места', seats.join(', ')),
                      _buildInfoRow(
                        'Пассажиры',
                        '${passengers.length} чел.',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Итого',
                        '${totalPrice.toStringAsFixed(0)} ₽',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method Selection
              Text(
                'Способ оплаты',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              
              RadioListTile<String>(
                title: const Row(
                  children: [
                    Icon(Icons.credit_card),
                    SizedBox(width: 12),
                    Text('Банковская карта'),
                  ],
                ),
                value: 'CARD',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) => setState(() => _selectedPaymentMethod = value),
              ),
              
              if (_selectedPaymentMethod == 'CARD')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Номер карты',
                          hintText: '0000 0000 0000 0000',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Введите номер карты' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cardExpiryController,
                              decoration: const InputDecoration(
                                labelText: 'Срок действия',
                                hintText: 'ММ/ГГ',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.datetime,
                              validator: (v) => v == null || v.isEmpty ? 'Ошибочный срок' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cardCvvController,
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                hintText: '123',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              validator: (v) => v == null || v.length != 3 ? 'Ошибка' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cardHolderController,
                        decoration: const InputDecoration(
                          labelText: 'Имя владельца',
                          hintText: 'IVAN IVANOV',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => v == null || v.isEmpty ? 'Введите имя' : null,
                      ),
                    ],
                  ),
                ),

              RadioListTile<String>(
                title: const Row(
                  children: [
                    Icon(Icons.apple),
                    SizedBox(width: 12),
                    Text('Apple Pay'),
                  ],
                ),
                value: 'APPLE_PAY',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) => setState(() => _selectedPaymentMethod = value),
              ),
              
              if (_selectedPaymentMethod == 'APPLE_PAY')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextFormField(
                    controller: _paymentDataController,
                    decoration: const InputDecoration(
                      labelText: 'ID Apple Pay',
                      hintText: 'apple_pay_ref_...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Введите ID' : null,
                  ),
                ),

              RadioListTile<String>(
                title: const Row(
                  children: [
                    Icon(Icons.android),
                    SizedBox(width: 12),
                    Text('Google Pay'),
                  ],
                ),
                value: 'GOOGLE_PAY',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) => setState(() => _selectedPaymentMethod = value),
              ),

              if (_selectedPaymentMethod == 'GOOGLE_PAY')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextFormField(
                    controller: _paymentDataController,
                    decoration: const InputDecoration(
                      labelText: 'ID Google Pay',
                      hintText: 'google_pay_ref_...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Введите ID' : null,
                  ),
                ),

              const SizedBox(height: 32),

              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Оплатить ${totalPrice.toStringAsFixed(0)} ₽'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
