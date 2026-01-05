import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/booking_timer.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrips();
    });

    // Start a timer to refresh the UI every 15 seconds to update statuses
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        Provider.of<BookingProvider>(context, listen: false).loadTrips(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    if (!mounted) return;
    try {
      final provider = Provider.of<BookingProvider>(context, listen: false);
      await provider.loadTrips();
      
      if (mounted) {
        // Proactive notification for registration
        final pendingCheckin = provider.upcomingTrips.any((t) => t.tripStatus == TripStatus.checkinAvailable);
        if (pendingCheckin) {
          UiUtils.showNotification(
            context: context,
            message: 'У вас есть рейсы, доступные для регистрации!',
          );
        }
      }
    } catch (e) {
      // Error is handled by provider and shown in UI
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final isLoading = bookingProvider.isLoading;
    final error = bookingProvider.error;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Premium Header
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                   Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             const Text(
                              'Мои поездки',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.home, color: Colors.white),
                              onPressed: () {
                                Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ваше небо, ваши правила',
                          style: TextStyle(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 20,
                    right: 20,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF38BDF8),
                      indicatorWeight: 4,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: 'АКТИВНЫЕ'),
                        Tab(text: 'АРХИВ'),
                        Tab(text: 'ОТМЕНЕННЫЕ'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              error,
                              style: const TextStyle(fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadTrips,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                      : RefreshIndicator(
                          onRefresh: _loadTrips,
                          child: TabBarView(
                            key: const ValueKey('trips_tab_view'),
                            controller: _tabController,
                            children: [
                              _buildTripListView(bookingProvider, bookingProvider.upcomingTrips, 'У вас нет предстоящих поездок', 'upcoming'),
                              _buildTripListView(bookingProvider, bookingProvider.pastTrips, 'История поездок пуста', 'past'),
                              _buildTripListView(bookingProvider, bookingProvider.cancelledTrips, 'Нет отмененных поездок', 'cancelled'),
                            ],
                          ),
                        ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripListView(BookingProvider provider, List<Trip> trips, String emptyMessage, String keyPrefix) {
    if (trips.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            key: ValueKey('empty_$keyPrefix'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(emptyMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    final groupedTrips = provider.groupTrips(trips);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: groupedTrips.length,
      itemBuilder: (context, index) {
        final group = groupedTrips[index];
        return _buildTripCard(group, key: ValueKey('trip_group_${group.first.flightId}_${group.first.tripStatus}'));
      },
    );
  }

  Widget _buildTripCard(List<Trip> trips, {Key? key}) {
    final primaryTrip = trips.first;
    final statusColor = _getStatusColor(primaryTrip.tripStatus);
    final isMulti = trips.length > 1;
    final totalPrice = trips.fold(0.0, (sum, t) => sum + t.price);
    final sortedSeats = trips.map((t) => t.seatNumber).toList()..sort();
    
    return Card(
      key: key,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (primaryTrip.tripStatus != TripStatus.created) {
            if (isMulti) {
              _showMultiTicketSelection(trips, (selectedTrip) {
                // Reorder trips so the selected one is first (primary for Info/QR)
                final reordered = List<Trip>.from(trips);
                reordered.removeWhere((t) => t.id == selectedTrip.id);
                reordered.insert(0, selectedTrip);
                
                Navigator.pushNamed(
                  context,
                  AppRouter.ticketDetail,
                  arguments: reordered,
                );
              });
            } else {
              Navigator.pushNamed(
                context,
                AppRouter.ticketDetail,
                arguments: trips, // Contains only 1 trip anyway
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        primaryTrip.flight.flightNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          primaryTrip.statusText,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'PNR: ${primaryTrip.pnr}', // Assuming shared PNR or just showing one
                    style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Multi-passenger indicator
              if (isMulti)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.purple[700]),
                      const SizedBox(width: 6),
                      Text(
                        '${trips.length} пассажиров',
                        style: TextStyle(color: Colors.purple[900], fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (primaryTrip.isCheckinOpen && !primaryTrip.checkedIn && primaryTrip.tripStatus != TripStatus.created) 
                      ? Colors.orange.withValues(alpha: 0.1) 
                      : Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      primaryTrip.checkedIn ? Icons.check_circle : Icons.info_outline,
                      size: 16,
                      color: primaryTrip.checkedIn ? Colors.green : (primaryTrip.isCheckinOpen && primaryTrip.tripStatus != TripStatus.created ? Colors.orange : Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        primaryTrip.checkinStatusMessage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryTrip.checkedIn ? Colors.green[700] : (primaryTrip.isCheckinOpen && primaryTrip.tripStatus != TripStatus.created ? Colors.orange[900] : Colors.blue[900]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (primaryTrip.tripStatus == TripStatus.created && primaryTrip.expiresAt != null) ...[
                const SizedBox(height: 12),
                BookingTimer(
                  expiresAt: primaryTrip.expiresAt!,
                  onExpired: _loadTrips,
                ),
              ],
              
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildCityTime(primaryTrip.flight.departureCity, primaryTrip.flight.departureTime, true),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.flight_takeoff, color: Theme.of(context).primaryColor, size: 20),
                        Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                        Text(primaryTrip.duration, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  _buildCityTime(primaryTrip.flight.arrivalCity, primaryTrip.flight.arrivalTime, false),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.event_seat, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isMulti ? 'Места: ${sortedSeats.join(", ")}' : 'Место: ${primaryTrip.seatNumber}', 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${totalPrice.toStringAsFixed(0)} ₽',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
              
              if (primaryTrip.checkedIn) ...[
                const Divider(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                      Navigator.pushNamed(context, AppRouter.checkin, arguments: trips);
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: Text('ПОСАДОЧНЫЙ ТАЛОН${isMulti ? "Ы" : ""}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (primaryTrip.tripStatus == TripStatus.checkinAvailable) ...[
                const Divider(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRouter.checkin, arguments: trips);
                  },
                  icon: const Icon(Icons.how_to_reg),
                  label: Text('ПРОЙТИ РЕГИСТРАЦИЮ${isMulti ? " (ВСЕ)" : ""}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              
              if (primaryTrip.tripStatus == TripStatus.created) ...[
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      // For simplicity, cancel one by one or all? Let's just cancel one for now or loop.
                      // Ideally, show list to cancel.
                      onPressed: () {
                        if(isMulti) {
                           _showMultiTicketSelection(trips, (trip) => _cancelBooking(trip.id));
                        } else {
                          _cancelBooking(primaryTrip.id);
                        }
                      },
                      child: const Text('ОТМЕНИТЬ', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                         Navigator.pushNamed(
                          context,
                          AppRouter.passengerDetails,
                          arguments: {
                            'flight': primaryTrip.flight,
                            'selectedSeats': trips.map((t) => t.seatNumber).toList(),
                            'expiresAt': primaryTrip.expiresAt,
                            // Pass list of trips ids if needed? The screen takes flight and seats.
                            // However, we rely on seat holds. 
                            // If we pay for all, we need to pass all seats.
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ОПЛАТИТЬ ВСЕ'),
                    ),
                  ],
                ),
              ],
              
              // Cancel button for confirmed bookings (not checked in yet)
              if ((primaryTrip.tripStatus == TripStatus.upcoming || primaryTrip.tripStatus == TripStatus.checkinAvailable) && !primaryTrip.checkedIn) ...[
                const Divider(height: 24),
                TextButton.icon(
                  onPressed: () {
                    if (isMulti) {
                        _showMultiTicketSelection(trips, (trip) => _cancelBooking(trip.id));
                    } else {
                      _cancelBooking(primaryTrip.id);
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                  label: const Text('ОТМЕНИТЬ БРОНИРОВАНИЕ', style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMultiTicketSelection(List<Trip> trips, Function(Trip) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выберите билет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: trips.length,
                  separatorBuilder: (c, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.event_seat, color: Colors.white, size: 20),
                      ),
                      title: Text('Место ${trip.seatNumber}'),
                      subtitle: Text(trip.pnr),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(trip);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelBooking(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена бронирования'),
        content: const Text('Вы уверены, что хотите отменить это бронирование?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Назад')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Отменить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      try {
        await Provider.of<BookingProvider>(context, listen: false).cancelBooking(id);
        _loadTrips();
        if (mounted) {
          UiUtils.showNotification(
            context: context,
            message: 'Бронирование отменено',
          );
        }
      } catch (e) {
        if (mounted) {
          UiUtils.showNotification(
            context: context,
            message: 'Ошибка: $e',
            isError: true,
          );
        }
      }
    }
  }

  Widget _buildCityTime(String city, DateTime time, bool isLeft) {
    return Column(
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(city, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(DateFormat('HH:mm').format(time), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        Text(DateFormat('dd MMM').format(time), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
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

  }
}
