import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/flight.dart';
import '../../models/airport.dart';
import '../../models/aircraft.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';
import '../../utils/app_router.dart';

class ManageFlightsScreen extends StatefulWidget {
  const ManageFlightsScreen({super.key});

  @override
  State<ManageFlightsScreen> createState() => _ManageFlightsScreenState();
}

class _ManageFlightsScreenState extends State<ManageFlightsScreen> with SingleTickerProviderStateMixin {
  List<Flight> _flights = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFlights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Filter flights by category
  List<Flight> get _upcomingFlights {
    final now = DateTime.now();
    return _flights.where((f) {
      final s = f.statusEnum;
      // Scheduled/Boarding AND in the future
      return (s == FlightStatus.scheduled && f.departureTime.isAfter(now)) || 
             s == FlightStatus.boarding;
    }).toList()..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }
  
  List<Flight> get _inFlightFlights => _flights.where((f) => 
    f.statusEnum == FlightStatus.departed
  ).toList()..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  
  List<Flight> get _completedFlights {
    final now = DateTime.now();
    return _flights.where((f) => 
      f.statusEnum == FlightStatus.arrived || 
      (f.statusEnum != FlightStatus.cancelled && f.arrivalTime.isBefore(now))
    ).toList()..sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
  }
  
  List<Flight> get _problemFlights {
    final now = DateTime.now();
    return _flights.where((f) {
      final s = f.statusEnum;
      // Cancelled, Delayed, OR Scheduled but time has passed (implicitly delayed)
      return s == FlightStatus.cancelled || 
             s == FlightStatus.delayed ||
             (s == FlightStatus.scheduled && f.departureTime.isBefore(now));
    }).toList()..sort((a, b) => b.departureTime.compareTo(a.departureTime));
  }

  Future<void> _loadFlights() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getStaffFlights();
      setState(() {
        _flights = response.map((json) => Flight.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateFlightDialog() async {
    // Load airports and aircrafts first
    List<Airport> airports = [];
    List<Aircraft> aircrafts = [];

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final airportsResponse = await ApiService.getStaffAirports();
      final aircraftsResponse = await ApiService.getStaffAircrafts();

      airports = airportsResponse.map((json) => Airport.fromJson(json)).toList();
      aircrafts = aircraftsResponse.map((json) => Aircraft.fromJson(json)).toList();

      if (mounted) Navigator.pop(context); // Close loading

      if (airports.isEmpty) {
        if (mounted) {
          UiUtils.showNotification(
            context: context,
            message: 'Сначала создайте аэропорты',
            isError: true,
          );
        }
        return;
      }

      if (aircrafts.isEmpty) {
        if (mounted) {
          UiUtils.showNotification(
            context: context,
            message: 'Нет доступных самолётов',
            isError: true,
          );
        }
        return;
      }

      if (mounted) {
        _showFlightForm(airports: airports, aircrafts: aircrafts);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка загрузки данных: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showFlightForm({
    required List<Airport> airports,
    required List<Aircraft> aircrafts,
    Flight? flight,
  }) {
    final flightNumberController = TextEditingController(text: flight?.flightNumber ?? '');
    final basePriceController = TextEditingController(
      text: flight?.basePrice.toString() ?? '',
    );
    final gateController = TextEditingController(text: flight?.gate ?? '');
    final terminalController = TextEditingController(text: flight?.terminal ?? 'A');

    Airport? selectedOrigin = flight != null
        ? airports.firstWhere(
            (a) => a.id == flight.originAirportId,
            orElse: () => airports.first,
          )
        : (airports.isNotEmpty ? airports.first : null);
        
    Airport? selectedDestination = flight != null
        ? airports.firstWhere(
            (a) => a.id == flight.destinationAirportId,
            orElse: () => airports.first,
          )
        : (airports.isNotEmpty ? airports.last : null);
        
    Aircraft? selectedAircraft = flight != null
        ? aircrafts.firstWhere(
            (a) => a.id == flight.aircraftId,
            orElse: () => aircrafts.first,
          )
        : (aircrafts.isNotEmpty ? aircrafts.first : null);

    String selectedStatus = flight?.status ?? 'ПО РАСПИСАНИЮ';
    final statusOptions = ['ПО РАСПИСАНИЮ', 'ПОСАДКА', 'ВЫЛЕТЕЛ', 'ПРИБЫЛ', 'ЗАДЕРЖАН', 'ОТМЕНЕН'];

    DateTime selectedDepartureDate = flight?.departureTime ?? DateTime.now().add(const Duration(hours: 24));
    TimeOfDay selectedDepartureTime = TimeOfDay.fromDateTime(selectedDepartureDate);

    DateTime selectedArrivalDate = flight?.arrivalTime ?? selectedDepartureDate.add(const Duration(hours: 2));
    TimeOfDay selectedArrivalTime = TimeOfDay.fromDateTime(selectedArrivalDate);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(flight == null ? 'Создать рейс' : 'Редактировать рейс'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: flightNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Номер рейса',
                        hintText: 'Например: AA100',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите номер рейса';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: statusOptions.map((status) {
                        return DropdownMenuItem(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Aircraft>(
                      initialValue: selectedAircraft,
                      decoration: const InputDecoration(labelText: 'Самолёт'),
                      items: aircrafts.map((aircraft) {
                        return DropdownMenuItem(
                          value: aircraft,
                          child: Text(aircraft.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedAircraft = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Выберите самолёт';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Airport>(
                      initialValue: selectedOrigin,
                      decoration: const InputDecoration(labelText: 'Аэропорт вылета'),
                      items: airports.map((airport) {
                        return DropdownMenuItem(
                          value: airport,
                          child: Text('${airport.code} - ${airport.city}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedOrigin = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Выберите аэропорт вылета';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Airport>(
                      initialValue: selectedDestination,
                      decoration: const InputDecoration(labelText: 'Аэропорт прибытия'),
                      items: airports.map((airport) {
                        return DropdownMenuItem(
                          value: airport,
                          child: Text('${airport.code} - ${airport.city}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDestination = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Выберите аэропорт прибытия';
                        if (selectedOrigin != null && value.id == selectedOrigin!.id) {
                          return 'Должны отличаться от вылета';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Дата и время вылета'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(
                          DateTime(
                            selectedDepartureDate.year,
                            selectedDepartureDate.month,
                            selectedDepartureDate.day,
                            selectedDepartureTime.hour,
                            selectedDepartureTime.minute,
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDepartureDate,
                          firstDate: flight != null 
                              ? DateTime.now().subtract(const Duration(days: 365)) 
                              : DateTime.now().subtract(const Duration(minutes: 1)), // Allow today but not past
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedDepartureTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedDepartureDate = date;
                              selectedDepartureTime = time;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Дата и время прибытия'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(
                          DateTime(
                            selectedArrivalDate.year,
                            selectedArrivalDate.month,
                            selectedArrivalDate.day,
                            selectedArrivalTime.hour,
                            selectedArrivalTime.minute,
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedArrivalDate,
                          firstDate: flight != null 
                              ? DateTime.now().subtract(const Duration(days: 365)) 
                              : DateTime.now().subtract(const Duration(minutes: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedArrivalTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedArrivalDate = date;
                              selectedArrivalTime = time;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: basePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Базовая цена',
                        hintText: '299.99',
                        prefixText: '₽',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите цену';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Некорректная цена';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: gateController,
                      decoration: const InputDecoration(
                        labelText: 'Гейт (необязательно)',
                        hintText: 'Например: A12',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: terminalController,
                      decoration: const InputDecoration(
                        labelText: 'Терминал',
                        hintText: 'A',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите терминал';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);

                final departureDateTime = DateTime(
                  selectedDepartureDate.year,
                  selectedDepartureDate.month,
                  selectedDepartureDate.day,
                  selectedDepartureTime.hour,
                  selectedDepartureTime.minute,
                );

                final arrivalDateTime = DateTime(
                  selectedArrivalDate.year,
                  selectedArrivalDate.month,
                  selectedArrivalDate.day,
                  selectedArrivalTime.hour,
                  selectedArrivalTime.minute,
                );

                if (arrivalDateTime.isBefore(departureDateTime) || arrivalDateTime.isAtSameMomentAs(departureDateTime)) {
                  UiUtils.showNotification(
                    context: context,
                    message: 'Время прибытия должно быть позже времени вылета',
                    isError: true,
                  );
                  return;
                }

                if (flight == null) {
                  await _createFlight(
                    flightNumber: flightNumberController.text.toUpperCase(),
                    aircraftId: selectedAircraft!.id,
                    originAirportId: selectedOrigin!.id,
                    destinationAirportId: selectedDestination!.id,
                    scheduledDeparture: departureDateTime,
                    scheduledArrival: arrivalDateTime,
                    basePrice: double.parse(basePriceController.text),
                    gate: gateController.text.isNotEmpty ? gateController.text : null,
                    terminal: terminalController.text,
                  );
                } else {
                  await _updateFlight(
                    flightId: flight.id,
                    flightNumber: flightNumberController.text.toUpperCase(),
                    scheduledDeparture: departureDateTime,
                    scheduledArrival: arrivalDateTime,
                    basePrice: double.parse(basePriceController.text),
                    gate: gateController.text.isNotEmpty ? gateController.text : null,
                    terminal: terminalController.text,
                    status: selectedStatus,
                  );
                }
              }
            },
            child: Text(flight == null ? 'СОЗДАТЬ' : 'СОХРАНИТЬ'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFlight({
    required String flightNumber,
    required int aircraftId,
    required int originAirportId,
    required int destinationAirportId,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    required double basePrice,
    String? gate,
    required String terminal,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ApiService.createFlight({
        'flight_number': flightNumber,
        'aircraft_id': aircraftId,
        'origin_airport_id': originAirportId,
        'destination_airport_id': destinationAirportId,
        'scheduled_departure': scheduledDeparture.toIso8601String(),
        'scheduled_arrival': scheduledArrival.toIso8601String(),
        'base_price': basePrice,
        if (gate != null) 'gate': gate,
        'terminal': terminal,
        'status': 'ПО РАСПИСАНИЮ',
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        UiUtils.showNotification(
          context: context,
          message: 'Рейс успешно создан',
        );
        _loadFlights();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        UiUtils.showNotification(
          context: context,
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  Future<void> _updateFlight({
    required int flightId,
    String? flightNumber,
    DateTime? scheduledDeparture,
    DateTime? scheduledArrival,
    double? basePrice,
    String? gate,
    String? terminal,
    String? status,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final updateData = <String, dynamic>{};
      if (flightNumber != null) updateData['flight_number'] = flightNumber;
      if (scheduledDeparture != null) {
        updateData['scheduled_departure'] = scheduledDeparture.toIso8601String();
      }
      if (scheduledArrival != null) {
        updateData['scheduled_arrival'] = scheduledArrival.toIso8601String();
      }
      if (basePrice != null) updateData['base_price'] = basePrice;
      if (gate != null) updateData['gate'] = gate;
      if (terminal != null) updateData['terminal'] = terminal;
      if (status != null) updateData['status'] = status;

      await ApiService.updateFlight(flightId, updateData);

      if (mounted) {
        Navigator.pop(context); // Close loading
        UiUtils.showNotification(
          context: context,
          message: 'Рейс успешно обновлён',
        );
        _loadFlights();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        UiUtils.showNotification(
          context: context,
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  void _showEditFlightDialog(Flight flight) async {
    // Load airports and aircrafts
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final airportsResponse = await ApiService.getStaffAirports();
      final aircraftsResponse = await ApiService.getStaffAircrafts();

      final airports = airportsResponse.map((json) => Airport.fromJson(json)).toList();
      final aircrafts = aircraftsResponse.map((json) => Aircraft.fromJson(json)).toList();

      if (mounted) {
        Navigator.pop(context); // Close loading
        _showFlightForm(airports: airports, aircrafts: aircrafts, flight: flight);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Управление рейсами'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadFlights,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          isScrollable: true,
          tabs: [
            Tab(text: 'Предстоящие (${_upcomingFlights.length})'),
            Tab(text: 'В полёте (${_inFlightFlights.length})'),
            Tab(text: 'Завершённые (${_completedFlights.length})'),
            Tab(text: 'Проблемные (${_problemFlights.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Ошибка загрузки', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_errorMessage!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadFlights,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFlightsList(_upcomingFlights, 'Нет предстоящих рейсов'),
                    _buildFlightsList(_inFlightFlights, 'Нет рейсов в полёте'),
                    _buildFlightsList(_completedFlights, 'Нет завершённых рейсов'),
                    _buildFlightsList(_problemFlights, 'Нет проблемных рейсов'),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFlightDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFlightsList(List<Flight> flights, String emptyMessage) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFlights,
      child: ListView.builder(
        itemCount: flights.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final flight = flights[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showEditFlightDialog(flight),
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.flight_takeoff, color: Colors.orange[800], size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                flight.flightNumber,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          _buildStatusBadge(flight.status),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildLocationInfo(
                            flight.departureCity, 
                            DateFormat('dd.MM HH:mm').format(flight.departureTime)
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Icon(Icons.compare_arrows, color: Colors.grey[400], size: 20),
                                Text(
                                  _getFlightDuration(flight),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          _buildLocationInfo(
                            flight.arrivalCity, 
                            DateFormat('dd.MM HH:mm').format(flight.arrivalTime)
                          , isRight: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Места: ${flight.availableSeats}/${flight.totalSeats}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              Text(
                                '${flight.basePrice.toStringAsFixed(0)} ₽',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                              // DEBUG: Show raw status to identify parsing issues
                              Text(
                                'Raw: "${flight.status}"',
                                style: TextStyle(fontSize: 10, color: Colors.red.withOpacity(0.5)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _confirmDeleteFlight(flight),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.manageBookings,
                                    arguments: {'flight_id': flight.id},
                                  );
                                },
                                icon: const Icon(Icons.people_outline, size: 16),
                                label: const Text('БРОНИ'),
                                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.manageSeats,
                                    arguments: flight,
                                  );
                                },
                                icon: const Icon(Icons.event_seat, size: 16),
                                label: const Text('МЕСТА'),
                                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                              ),
                            ],
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
    );
  }

  String _getFlightDuration(Flight flight) {
    final duration = flight.arrivalTime.difference(flight.departureTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hoursч $minutesм';
  }

  Widget _buildStatusBadge(String status) {
    final statusEnum = FlightStatus.fromString(status);
    final color = statusEnum.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String city, String dateTime, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          city,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateTime,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteFlight(Flight flight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить рейс?'),
        content: Text('Вы действительно хотите удалить рейс ${flight.flightNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                await ApiService.deleteFlight(flight.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadFlights();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  UiUtils.showNotification(
                    context: context,
                    message: e.toString(),
                    isError: true,
                  );
                }
              }
            },
            child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
