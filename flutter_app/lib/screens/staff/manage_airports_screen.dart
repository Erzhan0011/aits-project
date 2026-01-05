import 'package:flutter/material.dart';
import '../../models/airport.dart';
import '../../services/api_service.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';

class ManageAirportsScreen extends StatefulWidget {
  const ManageAirportsScreen({super.key});

  @override
  State<ManageAirportsScreen> createState() => _ManageAirportsScreenState();
}

class _ManageAirportsScreenState extends State<ManageAirportsScreen> {
  List<Airport> _airports = [];
  List<Airport> _filteredAirports = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getStaffAirports();
      setState(() {
        _airports = response.map((json) => Airport.fromJson(json)).toList();
        _filteredAirports = _airports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterAirports(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAirports = _airports;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredAirports = _airports.where((airport) {
          return airport.name.toLowerCase().contains(lowerQuery) ||
              airport.code.toLowerCase().contains(lowerQuery) ||
              airport.city.toLowerCase().contains(lowerQuery) ||
              airport.country.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _showCreateAirportDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final cityController = TextEditingController();
    final countryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать аэропорт'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название аэропорта',
                    hintText: 'Например: John F. Kennedy Airport',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'IATA код',
                    hintText: 'Например: JFK',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите IATA код';
                    }
                    if (value.length != 3) {
                      return 'IATA код должен быть из 3 букв';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Город',
                    hintText: 'Например: New York',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите город';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: countryController,
                  decoration: const InputDecoration(
                    labelText: 'Страна',
                    hintText: 'Например: USA',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите страну';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
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
                await _createAirport(
                  nameController.text,
                  codeController.text.toUpperCase(),
                  cityController.text,
                  countryController.text,
                );
              }
            },
            child: const Text('СОЗДАТЬ'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAirport(
    String name,
    String code,
    String city,
    String country,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await ApiService.createAirport({
        'name': name,
        'code': code,
        'city': city,
        'country': country,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        UiUtils.showNotification(
          context: context,
          message: 'Аэропорт успешно создан',
        );
        _loadAirports(); // Reload list
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        UiUtils.showNotification(
          context: context,
          message: e.toString(),
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
        title: const Text('Управление аэропортами'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAirports,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                      Text(
                        'Ошибка загрузки',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_errorMessage!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadAirports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterAirports,
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию, коду или стране...',
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
                        onRefresh: _loadAirports,
                        child: _filteredAirports.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isEmpty ? 'Нет аэропортов' : 'Ничего не найдено',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredAirports.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (context, index) {
                                  final airport = _filteredAirports[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRouter.staffAirportDetail,
                                          arguments: airport.id,
                                        );
                                      },
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              airport.code,
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          airport.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${airport.city}, ${airport.country}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () => _confirmDeleteAirport(airport),
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            ),
                                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAirportDialog,
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDeleteAirport(Airport airport) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аэропорт?'),
        content: Text('Удалить аэропорт ${airport.name} (${airport.code})?'),
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
                await ApiService.deleteAirport(airport.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadAirports();
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
