import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/airport.dart';
import '../../models/flight.dart';
import '../../services/mock_data_service.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_utils.dart';
import 'package:provider/provider.dart';

class AirportsScreen extends StatefulWidget {
  const AirportsScreen({super.key});

  @override
  State<AirportsScreen> createState() => _AirportsScreenState();
}

class _AirportsScreenState extends State<AirportsScreen> {
  List<Airport> _airports = [];
  List<Airport> _filteredAirports = [];
  bool _isLoading = true;
  Airport? _selectedAirport;
  List<Flight> _airportFlights = [];
  bool _isLoadingFlights = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get('/passenger/airports');
      if (mounted) {
        setState(() {
          _airports = (response.data as List)
              .map((json) => Airport.fromJson(json))
              .toList();
          _filteredAirports = _airports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback to mock data on error
          _airports = MockDataService.getMockAirports();
          _filteredAirports = _airports;
          _isLoading = false;
        });
        UiUtils.showNotification(
          context: context,
          message: 'Загружены тестовые данные (ошибка API)',
          isError: false,
        );
      }
    }
  }

  void _filterAirports(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAirports = _airports;
      } else {
        _filteredAirports = _airports.where((airport) {
          final lowerQuery = query.toLowerCase();
          return airport.name.toLowerCase().contains(lowerQuery) ||
              airport.code.toLowerCase().contains(lowerQuery) ||
              airport.city.toLowerCase().contains(lowerQuery) ||
              airport.country.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  Future<void> _loadFlightsForAirport(Airport airport) async {
    setState(() {
      _selectedAirport = airport;
      _isLoadingFlights = true;
      _airportFlights = [];
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Use public endpoint if not authenticated
      final endpoint = authProvider.isAuthenticated 
          ? '/passenger/flights'
          : '/passenger/flights/public';

      // Загружаем рейсы параллельно для ускорения
      try {
        final results = await Future.wait([
          ApiService.get(endpoint, queryParameters: {
            'from_city': airport.city,
          }),
          ApiService.get(endpoint, queryParameters: {
            'to_city': airport.city,
          }),
        ]);

      List<Flight> departureFlights = [];
      if (results[0].data != null) {
        departureFlights = (results[0].data as List)
            .map((json) => Flight.fromJson(json))
            .toList();
      }

      List<Flight> arrivalFlights = [];
      if (results[1].data != null) {
        arrivalFlights = (results[1].data as List)
            .map((json) => Flight.fromJson(json))
            .toList();
      }

        // Объединяем и убираем дубликаты
        final allFlights = <int, Flight>{};
        for (var flight in departureFlights) {
          allFlights[flight.id] = flight;
        }
        for (var flight in arrivalFlights) {
          allFlights[flight.id] = flight;
        }

        if (mounted) {
          final now = DateTime.now();
          setState(() {
            // Apply 2-hour filter
            _airportFlights = allFlights.values.where((f) => 
              f.departureTime.difference(now).inMinutes >= 120
            ).toList();
            _isLoadingFlights = false;
          });
        }
      } catch (apiError) {
        // Если API не работает, используем mock данные
        final mockFlights = MockDataService.getMockFlights();
        final filteredFlights = mockFlights.where((flight) =>
          flight.departureCity.toLowerCase() == airport.city.toLowerCase() ||
          flight.arrivalCity.toLowerCase() == airport.city.toLowerCase()
        ).toList();
        
        if (mounted) {
          final now = DateTime.now();
          setState(() {
            // Apply 2-hour filter
            _airportFlights = filteredFlights.where((f) => 
              f.departureTime.difference(now).inMinutes >= 120
            ).toList();
            _isLoadingFlights = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFlights = false;
        });
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка загрузки рейсов: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedAirport = null;
      _airportFlights = [];
    });
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase().contains('расписанию')) {
      return Colors.green;
    } else if (status.toLowerCase().contains('задержан')) {
      return Colors.orange;
    } else if (status.toLowerCase().contains('отменён') || status.toLowerCase().contains('отменен')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedAirport != null) {
      // Показываем список рейсов для выбранного аэропорта
      return Scaffold(
        appBar: AppBar(
          title: Text('Рейсы: ${_selectedAirport!.name}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _clearSelection,
          ),
        ),
        body: _isLoadingFlights
            ? const Center(child: CircularProgressIndicator())
            : _airportFlights.isEmpty
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _clearSelection,
                          child: const Text('Назад к аэропортам'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadFlightsForAirport(_selectedAirport!),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _airportFlights.length,
                      itemBuilder: (context, index) {
                        final flight = _airportFlights[index];
                        final isDeparture = flight.departureCity == _selectedAirport!.city;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      flight.flightNumber,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(flight.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        flight.status,
                                        style: TextStyle(
                                          color: _getStatusColor(flight.status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isDeparture ? flight.departureCity : flight.arrivalCity,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            isDeparture ? 'Отправление' : 'Прибытие',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            DateFormat('HH:mm').format(
                                              isDeparture ? flight.departureTime : flight.arrivalTime,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Icon(
                                          isDeparture ? Icons.flight_takeoff : Icons.flight_land,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        Text(
                                          flight.duration,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            isDeparture ? flight.arrivalCity : flight.departureCity,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            isDeparture ? 'Прибытие' : 'Отправление',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            DateFormat('HH:mm').format(
                                              isDeparture ? flight.arrivalTime : flight.departureTime,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('dd MMM yyyy').format(flight.departureTime),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Свободно мест: ${flight.availableSeats}/${flight.totalSeats}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/flight-details',
                                        arguments: flight.id,
                                      );
                                    },
                                    icon: const Icon(Icons.info_outline),
                                    label: const Text('Детали рейса'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
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

    // Показываем список аэропортов
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аэропорты'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _airports.isEmpty
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
                        'Аэропорты не найдены',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterAirports,
                        decoration: InputDecoration(
                          hintText: 'Поиск (Нижний, NJS, Россия)...',
                          prefixIcon: const Icon(Icons.search, color: Colors.orange),
                          suffixIcon: _searchController.text.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterAirports('');
                                },
                              )
                            : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          _searchController.clear();
                          _loadAirports();
                        },
                        child: _filteredAirports.isEmpty
                            ? const Center(
                                child: Text('Ничего не найдено'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredAirports.length,
                                itemBuilder: (context, index) {
                                  final airport = _filteredAirports[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: InkWell(
                                      onTap: () => _loadFlightsForAirport(airport),
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.orange,
                                          child: Text(
                                            airport.code,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          airport.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.location_city, size: 16, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${airport.city}, ${airport.country}',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.orange,
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
    );
  }
}
