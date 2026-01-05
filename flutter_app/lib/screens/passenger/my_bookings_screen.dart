import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/booking_provider.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';
import '../../models/booking.dart';
import '../../widgets/booking_timer.dart';
import '../../models/trip.dart';
import 'ticket_detail_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookingProvider>(context, listen: false).loadBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои бронирования'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRouter.home,
                (route) => false,
              );
            },
            tooltip: 'На главную',
          ),
        ],
      ),
      body: bookingProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookingProvider.bookings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flight,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'У вас нет бронирований',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await bookingProvider.loadBookings();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookingProvider.bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookingProvider.bookings[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.flight, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          booking.flight.flightNumber,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    Chip(
                                      label: Text(
                                        booking.status == BookingStatus.confirmed
                                            ? 'Подтверждено'
                                            : booking.status == BookingStatus.cancelled
                                                ? 'Отменено'
                                                : 'Ожидание',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: booking.status == BookingStatus.cancelled ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      backgroundColor: booking.status == BookingStatus.confirmed
                                          ? Colors.green.shade100
                                          : booking.status == BookingStatus.cancelled
                                              ? Colors.red.shade400
                                              : Colors.orange.shade100,
                                      padding: const EdgeInsets.all(0),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 8),
                                
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Text(
                                              '${booking.flight.departureCity} → ${booking.flight.arrivalCity}',
                                              style: const TextStyle(fontSize: 15),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                               DateFormat('dd MMM yyyy, HH:mm').format(
                                                  booking.flight.departureTime,
                                                ),
                                                style: TextStyle(color: Colors.grey[600]),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Место: ${booking.seatNumber}',
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${booking.price.toStringAsFixed(0)} ₽',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                if (booking.status == BookingStatus.pending && 
                                    booking.expiresAt != null && 
                                    booking.expiresAt!.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 5))))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: BookingTimer(
                                      expiresAt: booking.expiresAt!,
                                      onExpired: () {
                                        final provider = Provider.of<BookingProvider>(context, listen: false);
                                        provider.loadBookings(showLoading: false);
                                      },
                                    ),
                                  ),
                                
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (booking.status == BookingStatus.pending) ...[
                                      TextButton.icon(
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Отмена бронирования'),
                                              content: const Text('Вы уверены, что хотите отменить это бронирование?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Назад'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Отменить', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirmed == true && context.mounted) {
                                            final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(booking.id);
                                            if (context.mounted) {
                                                if (success) {
                                                   UiUtils.showNotification(
                                                    context: context,
                                                    message: 'Бронирование отменено',
                                                  );
                                                } else {
                                                  UiUtils.showNotification(
                                                    context: context,
                                                    message: 'Ошибка при отмене бронирования',
                                                    isError: true,
                                                  );
                                                }
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                        label: const Text('Отменить', style: TextStyle(color: Colors.red)),
                                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRouter.passengerDetails,
                                              arguments: {
                                                'flight': booking.flight,
                                                'selectedSeats': <String>[booking.seatNumber],
                                                'expiresAt': booking.expiresAt,
                                              },
                                            );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Оплатить'),
                                      ),
                                    ] else if (booking.status == BookingStatus.confirmed) ...[
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final trip = Trip(
                                            id: booking.id,
                                            passengerId: booking.passengerId,
                                            flightId: booking.flightId,
                                            flight: booking.flight,
                                            seatNumber: booking.seatNumber,
                                            price: booking.price,
                                            status: 'CONFIRMED',
                                            createdAt: booking.createdAt,
                                            pnr: booking.pnr ?? 'N/A',
                                            gate: booking.flight.gate,
                                            terminal: booking.flight.terminal,
                                            paymentMethod: 'CARD',
                                            checkedIn: booking.checkedIn,
                                            qrCode: booking.qrCode,
                                          );
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TicketDetailScreen(trips: [trip]),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons. airplane_ticket, size: 18),
                                        label: const Text('Билет'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[800],
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRouter.checkin,
                                              arguments: [Trip(
                                                id: booking.id,
                                                passengerId: booking.passengerId,
                                                flightId: booking.flightId,
                                                flight: booking.flight,
                                                seatNumber: booking.seatNumber,
                                                price: booking.price,
                                                status: booking.status.name.toUpperCase(),
                                                createdAt: booking.createdAt,
                                                pnr: booking.pnr ?? 'N/A',
                                                gate: booking.flight.gate,
                                                terminal: booking.flight.terminal,
                                                paymentMethod: 'CARD',
                                                checkedIn: booking.checkedIn,
                                                qrCode: booking.qrCode,
                                              )],
                                            );
                                        },
                                        child: Text(booking.checkedIn ? 'Талон' : 'Регистрация'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Отмена бронирования'),
                                                    content: const Text('Вы уверены, что хотите отменить это бронирование? Деньги будут возвращены на карту.'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context, false),
                                                        child: const Text('Назад'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context, true),
                                                        child: const Text('Отменить', style: TextStyle(color: Colors.red)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                          
                                          if (confirmed == true && context.mounted) {
                                            final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(booking.id);
                                             if (context.mounted) {
                                                if (success) {
                                                   UiUtils.showNotification(
                                                    context: context,
                                                    message: 'Бронирование отменено',
                                                  );
                                                } else {
                                                  UiUtils.showNotification(
                                                    context: context,
                                                    message: 'Ошибка при отмене бронирования',
                                                    isError: true,
                                                  );
                                                }
                                            }
                                          }
                                        },
                                        child: const Text('Отменить', style: TextStyle(color: Colors.red)),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                    },
                  ),
                ),
    );
  }
}
