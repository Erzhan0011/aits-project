import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/booking_provider.dart';
import '../../models/trip.dart';
import '../../utils/ui_utils.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  // Map booking ID to QR code
  final Map<int, String> _boardingPassQRs = {};
  final Set<int> _checkedInIds = {};
  bool _isCheckingIn = false;

  Future<void> _checkInAll(List<Trip> trips) async {
    setState(() {
      _isCheckingIn = true;
    });

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    
    // Filter trips that need check-in
    final tripsToCheckIn = trips.where((t) => !t.checkedIn && !_checkedInIds.contains(t.id)).toList();
    
    bool allSuccess = true;
    String? errorMsg;

    for (final trip in tripsToCheckIn) {
      final result = await bookingProvider.checkIn(trip.id);
      
      if (mounted) {
        if (result != null && result['boarding_pass'] != null) {
          setState(() {
            _boardingPassQRs[trip.id] = result['boarding_pass'];
            _checkedInIds.add(trip.id);
          });
        } else {
          allSuccess = false;
          errorMsg = bookingProvider.error;
        }
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingIn = false;
      });

      if (allSuccess && tripsToCheckIn.isNotEmpty) {
        UiUtils.showNotification(
          context: context,
          message: 'Регистрация успешно пройдена для всех пассажиров!',
          isError: false,
        );
      } else if (!allSuccess) {
        UiUtils.showNotification(
          context: context,
          message: errorMsg ?? 'Ошибка при регистрации некоторых пассажиров',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    List<Trip> trips = [];
    
    if (args is Trip) {
      trips = [args];
    } else if (args is List<Trip>) {
      trips = args;
    } else if (args is List) {
      trips = args.cast<Trip>();
    }

    if (trips.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Данные о поезде не найдены')),
      );
    }

    final mainTrip = trips.first;
    // Check if ALL are checked in (either natively or locally)
    final allCheckedIn = trips.every((t) => t.checkedIn || _checkedInIds.contains(t.id));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(allCheckedIn ? 'Посадочные талоны' : 'Регистрация'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!allCheckedIn) ...[
              _buildFlightSummary(mainTrip),
              const SizedBox(height: 32),
              const Text(
                'Вас приветствует Antigravity Airlines!\nПожалуйста, подтвердите регистрацию на рейс для всех пассажиров.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              // List of passengers to check in
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: trips.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    final isDone = trip.checkedIn || _checkedInIds.contains(trip.id);
                    return ListTile(
                      leading: Icon(
                        isDone ? Icons.check_circle : Icons.person_outline, 
                        color: isDone ? Colors.green : Colors.grey
                      ),
                      title: Text('${trip.firstName ?? "Пассажир"} ${trip.lastName ?? "${index+1}"}'),
                      subtitle: Text('Место: ${trip.seatNumber}'),
                      trailing: isDone ? const Text('Готово', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isCheckingIn
                      ? null
                      : () => _checkInAll(trips),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isCheckingIn
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'ЗАРЕГИСТРИРОВАТЬ ВСЕХ (${trips.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              Text(
                'Завершая регистрацию, вы подтверждаете ознакомление с правилами перевозки багажа.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ] else ...[
              // All checked in - Show Boarding Passes (scrollable if multiple)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trips.length,
                separatorBuilder: (c, i) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  // Use local QR if just generated, else trip QR
                  final qr = _boardingPassQRs[trip.id] ?? trip.qrCode;
                  final name = '${trip.firstName ?? "Пассажир"} ${trip.lastName ?? "${index+1}"}';
                  return _buildBoardingPass(trip, name, qr);
                },
              ),
              
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('ГОТОВО'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlightSummary(Trip trip) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlace(trip.flight.departureCity, DateFormat('HH:mm').format(trip.flight.departureTime), CrossAxisAlignment.start),
                Icon(Icons.flight_takeoff, color: Colors.orange[800]),
                _buildPlace(trip.flight.arrivalCity, DateFormat('HH:mm').format(trip.flight.arrivalTime), CrossAxisAlignment.end),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallInfo('РЕЙС', trip.flight.flightNumber),
                _buildSmallInfo('ДАТА', DateFormat('dd MMM').format(trip.flight.departureTime)),
                _buildSmallInfo('КЛАСС', 'ЭКОНОМ'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlace(String city, String time, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(city, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(time, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSmallInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBoardingPass(Trip trip, String passengerName, String? qrData) {
    final boardingTime = trip.flight.departureTime.subtract(const Duration(minutes: 40));
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BOARDING PASS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                Text(
                  trip.flight.flightNumber,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Passenger Info
                _buildInfoBlock('PASSENGER NAME', passengerName.toUpperCase(), isLarge: true),
                const SizedBox(height: 24),
                
                // Flight Routes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoBlock('FROM', trip.flight.departureCity.toUpperCase()),
                    const Icon(Icons.flight_takeoff, color: Colors.grey, size: 20),
                    _buildInfoBlock('TO', trip.flight.arrivalCity.toUpperCase(), alignment: CrossAxisAlignment.end),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Detailed Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoBlock('GATE', trip.gate ?? 'A1'),
                    _buildInfoBlock('SEAT', trip.seatNumber),
                    _buildInfoBlock('BOARDING', DateFormat('HH:mm').format(boardingTime), color: Colors.orange[800]),
                  ],
                ),
                const SizedBox(height: 24),
                
                // QR Code Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      if (qrData != null)
                        QrImageView(
                          data: 'https://elqr.kz/b39f7d69-6d7f-479a-a3d0-e36d7a3c91a3',
                          version: QrVersions.auto,
                          size: 180,
                          backgroundColor: Colors.white,
                        )
                      else
                        const Icon(Icons.qr_code, size: 100, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'PNR: ${trip.pnr}',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Perforated Bottom
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Center(
              child: Text(
                'PROCEED TO GATE ON TIME',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String value, {bool isLarge = false, CrossAxisAlignment alignment = CrossAxisAlignment.start, Color? color}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }
}
