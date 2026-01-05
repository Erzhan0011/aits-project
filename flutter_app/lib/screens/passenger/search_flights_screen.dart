import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/flight.dart';
import '../../providers/flight_provider.dart';
import '../../utils/app_router.dart';
import 'dart:async';

class SearchFlightsScreen extends StatefulWidget {
  const SearchFlightsScreen({super.key});

  @override
  State<SearchFlightsScreen> createState() => _SearchFlightsScreenState();
}

class _SearchFlightsScreenState extends State<SearchFlightsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // State variables for primitive types as requested
  String? _originCode;
  String? _destinationCode;
  DateTime? _departureDate;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FlightProvider>(context, listen: false).loadAirports();
    });
    
    // Auto-refresh the UI every 15 seconds to filter out newly past flights
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
      });
    }
  }

  void _searchFlights() {
    if (!_formKey.currentState!.validate()) return;
    
    // Safety check - although validator should catch this
    if (_originCode == null || _destinationCode == null || _departureDate == null) {
      return;
    }

    final flightProvider = Provider.of<FlightProvider>(context, listen: false);
    
    flightProvider.searchFlights(
      originCode: _originCode!,
      destinationCode: _destinationCode!,
      departureDate: _departureDate!,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск рейсов'),
      ),
      body: Consumer<FlightProvider>(
        builder: (context, flightProvider, child) {
          // 1. Loading State
          if (flightProvider.isLoading && flightProvider.airports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Empty List State
          if (flightProvider.airports.isEmpty) {
            if (flightProvider.error != null) {
               return Center(child: Text('Ошибка загрузки: ${flightProvider.error}'));
            }
            return const Center(child: Text('Список городов пуст'));
          }

          final airports = flightProvider.airports;
          // Filter destinations to exclude the selected origin
          final availableDestinations = airports.where((a) => a.code != _originCode).toList();

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Search Filter Card ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Параметры поиска',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),
                        
                        // --- Origin Dropdown ---
                        DropdownButtonFormField<String>(
                          initialValue: airports.any((a) => a.code == _originCode) 
                              ? _originCode 
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Откуда',
                            labelStyle: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                            prefixIcon: Icon(Icons.flight_takeoff, color: Theme.of(context).primaryColor),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
                          ),
                          items: airports.map((airport) {
                            return DropdownMenuItem<String>(
                              value: airport.code,
                              child: Text('${airport.city} (${airport.code})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _originCode = value;
                              if (_destinationCode == value) {
                                 _destinationCode = null;
                              }
                            });
                          },
                          validator: (value) => value == null ? 'Выберите город вылета' : null,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // --- Destination Dropdown ---
                        DropdownButtonFormField<String>(
                          initialValue: availableDestinations.any((a) => a.code == _destinationCode) 
                              ? _destinationCode 
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Куда',
                            labelStyle: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                            prefixIcon: Icon(Icons.flight_land, color: Theme.of(context).primaryColor),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
                          ),
                          items: availableDestinations.map((airport) {
                            return DropdownMenuItem<String>(
                              value: airport.code,
                              child: Text('${airport.city} (${airport.code})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _destinationCode = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) return 'Выберите город прилета';
                            if (value == _originCode) return 'Города должны отличаться';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // --- Date Picker ---
                        TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Дата вылета',
                            labelStyle: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                            prefixIcon: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
                          ),
                          controller: TextEditingController(
                            text: _departureDate != null
                                ? DateFormat('dd.MM.yyyy').format(_departureDate!)
                                : '',
                          ),
                          onTap: () => _selectDate(context),
                          validator: (value) => _departureDate == null ? 'Выберите дату' : null,
                        ),

                        const SizedBox(height: 24),

                        // --- Search Button ---
                        ElevatedButton(
                          onPressed: flightProvider.isLoading ? null : _searchFlights,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
                          ),
                          child: flightProvider.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('НАЙТИ РЕЙСЫ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
                  
                  // --- Results Section ---
                  if (flightProvider.flights.isNotEmpty) ...[
                     const SizedBox(height: 32),
                     const Text(
                      'Найденные рейсы',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: flightProvider.flights.where((f) {
                        final now = DateTime.now();
                        return f.departureTime.difference(now).inMinutes >= 120;
                      }).length,
                      itemBuilder: (context, index) {
                        final flights = flightProvider.flights.where((f) {
                          final now = DateTime.now();
                          return f.departureTime.difference(now).inMinutes >= 120;
                        }).toList();
                        final flight = flights[index];
                        final isBookable = flight.statusEnum == FlightStatus.scheduled && flight.availableSeats > 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${flight.departureCity} → ${flight.arrivalCity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${flight.basePrice.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF6B35))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${flight.flightNumber} • ${DateFormat('HH:mm').format(flight.departureTime)}'),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: flight.statusEnum.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: flight.statusEnum.color.withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        flight.status.toUpperCase(),
                                        style: TextStyle(
                                          color: flight.statusEnum.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Мест: ${flight.availableSeats}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isBookable 
                                        ? () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRouter.flightDetails,
                                              arguments: flight.id,
                                            );
                                          } 
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Бронировать'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // --- Error Display ---
                  if (flightProvider.error != null && flightProvider.airports.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Ошибка: ${flightProvider.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
