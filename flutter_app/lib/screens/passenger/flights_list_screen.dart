import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/flight.dart';
import '../../models/airport.dart';
import '../../services/mock_data_service.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_router.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../models/booking.dart';
import 'dart:async';

class FlightsListScreen extends StatefulWidget {
  const FlightsListScreen({super.key});

  @override
  State<FlightsListScreen> createState() => _FlightsListScreenState();
}

class _FlightsListScreenState extends State<FlightsListScreen> {
  List<Flight> _flights = [];
  List<Flight> _filteredFlights = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  // Фильтры
  String? _selectedFromCity;
  String? _selectedToCity;
  DateTime? _selectedDate;
  List<Airport> _airports = [];
  
  // UI состояния
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Load bookings to check for pending status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<BookingProvider>(context, listen: false).loadBookings();
      }
    });

    // Start a timer to refresh the list every 30 seconds to fetch new flights
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted) {
        await _loadFlightsFromAPI();
        _applyFilters();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем города/аэропорты через API для точности фильтров
      final airportsResponse = await ApiService.get('/passenger/airports');
      if (airportsResponse.data != null) {
        _airports = (airportsResponse.data as List)
            .map((json) => Airport.fromJson(json))
            .toList();
      } else {
        _airports = MockDataService.getMockAirports();
      }
      
      // Загружаем рейсы через API (теперь и для гостей)
      await _loadFlightsFromAPI();
      
      _applyFilters();
    } catch (e) {
      // Fallback на mock данные при ошибке
      _flights = MockDataService.getMockFlights();
      _applyFilters();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFlightsFromAPI() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Use public or protected endpoint based on auth status
      final endpoint = authProvider.isAuthenticated 
          ? '/passenger/flights'
          : '/passenger/flights/public';

      Map<String, dynamic> queryParams = {};
      if (_selectedFromCity != null && _selectedFromCity!.isNotEmpty) {
        queryParams['from_city'] = _selectedFromCity;
      }
      if (_selectedToCity != null && _selectedToCity!.isNotEmpty) {
        queryParams['to_city'] = _selectedToCity;
      }
      if (_selectedDate != null) {
        queryParams['date'] = _selectedDate!.toIso8601String();
      }

      final response = await ApiService.get(endpoint, queryParameters: queryParams);
      
      if (response.data != null) {
        _flights = (response.data as List)
            .map((json) => Flight.fromJson(json))
            .toList();
      }
    } catch (e) {
      // При ошибке используем mock данные
      _flights = MockDataService.getMockFlights();
      if (_airports.isEmpty) {
        _airports = MockDataService.getMockAirports();
      }
    }
  }

  void _applyFilters() {
    setState(() {
      final now = DateTime.now();
      _filteredFlights = _flights.where((f) {
        // Show flights only if departure is at least 2 hours away (120 minutes)
        if (f.departureTime.difference(now).inMinutes < 120) return false;

        // Apply search filters
        // Фильтр по городу отправления
        if (_selectedFromCity != null && _selectedFromCity!.isNotEmpty) {
          if (f.departureCity.toLowerCase() != _selectedFromCity!.toLowerCase()) return false;
        }
        
        // Фильтр по городу прибытия
        if (_selectedToCity != null && _selectedToCity!.isNotEmpty) {
          if (f.arrivalCity.toLowerCase() != _selectedToCity!.toLowerCase()) return false;
        }
        
        // Фильтр по выбранной дате (если юзер выбрал конкретную дату в календаре)
        if (_selectedDate != null) {
          final targetDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
          final flightDate = DateFormat('yyyy-MM-dd').format(f.departureTime);
          if (flightDate != targetDate) return false;
        }
        
        return true;
      }).toList();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadFlightsFromAPI();
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFromCity = null;
      _selectedToCity = null;
      _selectedDate = null;
    });
    _loadData();
  }

  // ignore: unused_element
  static Color _getStatusColor(String status) {
  final s = status.toLowerCase();
  if (s.contains('расписанию')) return Colors.green;
  if (s.contains('задержан')) return Colors.orange;
  if (s.contains('отмен') || s.contains('отмен')) return Colors.red;
  return Colors.blue;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ВЫБОР РЕЙСА'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.close : Icons.tune),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: _showFilters ? 'Скрыть фильтры' : 'Показать фильтры',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
        ),
        child: Column(
          children: [
            // Premium Header Gradient
            Container(
              height: 200,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Куда летим сегодня?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickChip('Все', null, Icons.apps),
                            _buildQuickChip('Москва', 'Москва', Icons.location_city),
                            _buildQuickChip('Сочи', 'Сочи', Icons.wb_sunny),
                            _buildQuickChip('СПб', 'Санкт-Петербург', Icons.castle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_showFilters) ...[
               const SizedBox(height: 20),
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 24),
                 child: Text(
                   'ПОПУЛЯРНЫЕ НАПРАВЛЕНИЯ',
                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                 ),
               ),
               const SizedBox(height: 12),
               SizedBox(
                 height: 140,
                 child: ListView(
                   scrollDirection: Axis.horizontal,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   children: [
                     _buildFeaturedCard('БАЛИ', 'От 45 000 ₽', [Colors.orange, Colors.red], Icons.beach_access),
                     _buildFeaturedCard('ЛОНДОН', 'От 32 000 ₽', [Colors.blue, Colors.indigo], Icons.location_city),
                     _buildFeaturedCard('ПАРИЖ', 'От 28 000 ₽', [Colors.pink, Colors.purple], Icons.favorite),
                   ],
                 ),
               ),
            ],
          if (_showFilters) _buildFiltersPanel(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFlights.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.flight_takeoff,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Рейсы не найдены',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (_selectedFromCity != null || _selectedToCity != null || _selectedDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: ElevatedButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Очистить фильтры'),
                                ),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadFlightsFromAPI();
                          _applyFilters();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredFlights.length,
                          itemBuilder: (context, index) {
                            final flight = _filteredFlights[index];
                            final bookingProvider = Provider.of<BookingProvider>(context);
                            
                            // Find active pending booking for this flight
                            Booking? pendingBooking;
                            if (bookingProvider.bookings.isNotEmpty) {
                              for (var b in bookingProvider.bookings) {
                                if (b.flightId == flight.id && b.status == BookingStatus.pending) {
                                  pendingBooking = b;
                                  break;
                                }
                              }
                            }

                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 400 + (index * 100)),
                              tween: Tween(begin: 0.0, end: 1.0),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 30 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 8,
                                shadowColor: Colors.black26,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    if (pendingBooking != null) {
                                      Navigator.pushNamed(
                                        context,
                                        AppRouter.passengerDetails,
                                        arguments: {
                                          'flight': pendingBooking.flight,
                                          'selectedSeats': <String>[pendingBooking.seatNumber],
                                          'expiresAt': pendingBooking.expiresAt,
                                        },
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        AppRouter.flightDetails,
                                        arguments: flight.id,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.flight_takeoff, color: Theme.of(context).primaryColor, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  flight.flightNumber,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    flight.statusEnum.color,
                                                    flight.statusEnum.color.withOpacity(0.7),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: flight.statusEnum.color.withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                flight.status.toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildCityInfo(flight.departureCity, 'ОТПРАВЛЕНИЕ', DateFormat('HH:mm').format(flight.departureTime), CrossAxisAlignment.start),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  const Icon(Icons.airplanemode_active, color: Colors.grey, size: 20),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    height: 1,
                                                    width: 60,
                                                    color: Colors.grey.withOpacity(0.3),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    flight.duration,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            _buildCityInfo(flight.arrivalCity, 'ПРИБЫТИЕ', DateFormat('HH:mm').format(flight.arrivalTime), CrossAxisAlignment.end),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    _buildBottomInfo(Icons.calendar_today, DateFormat('dd MMM').format(flight.departureTime)),
                                                    _buildBottomInfo(Icons.event_seat, '${flight.availableSeats} мест'),
                                                    Text(
                                                      '${flight.basePrice.toInt()} ₽',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: pendingBooking != null 
                                                      ? [Colors.orange, Colors.deepOrange]
                                                      : [
                                                          Theme.of(context).primaryColor,
                                                          Theme.of(context).colorScheme.secondary,
                                                        ],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (pendingBooking != null ? Colors.orange : Theme.of(context).primaryColor).withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                pendingBooking != null ? 'ОЖИДАНИЕ' : 'БРОНЬ',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCityInfo(String city, String label, String time, CrossAxisAlignment alignment) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            city,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Фильтры',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Фильтр по городу отправления
          DropdownButtonFormField<String>(
            initialValue: _selectedFromCity,
            decoration: const InputDecoration(
              labelText: 'Город отправления',
              prefixIcon: Icon(Icons.flight_takeoff),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Все города'),
              ),
              ...(_airports
                  .map((a) => a.city)
                  .toSet()
                  .toList()
                  ..sort())
                  .map((city) => DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      )),
            ],
            onChanged: (value) async {
              setState(() {
                _selectedFromCity = value;
              });
              await _loadFlightsFromAPI();
              _applyFilters();
            },
          ),
          const SizedBox(height: 16),
          // Фильтр по городу прибытия
          DropdownButtonFormField<String>(
            initialValue: _selectedToCity,
            decoration: const InputDecoration(
              labelText: 'Город прибытия',
              prefixIcon: Icon(Icons.flight_land),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Все города'),
              ),
              ...(_airports
                  .map((a) => a.city)
                  .toSet()
                  .toList()
                  ..sort())
                  .map((city) => DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      )),
            ],
            onChanged: (value) async {
              setState(() {
                _selectedToCity = value;
              });
              await _loadFlightsFromAPI();
              _applyFilters();
            },
          ),
          const SizedBox(height: 16),
          // Фильтр по дате
          InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Дата вылета',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                _selectedDate != null
                    ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                    : 'Выберите дату',
                style: TextStyle(
                  color: _selectedDate != null ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String? city, IconData icon) {
    final isSelected = _selectedToCity == city;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.blue),
        selected: isSelected,
        onSelected: (value) async {
          setState(() {
            _selectedToCity = city;
          });
          await _loadFlightsFromAPI();
          _applyFilters();
        },
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
    );
  }

  Widget _buildFeaturedCard(String city, String price, List<Color> colors, IconData icon) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedToCity = city == 'БАЛИ' ? null : city; // Just for demo
            });
            _applyFilters();
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const Spacer(),
                Text(
                  city,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                ),
                Text(
                  price,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
