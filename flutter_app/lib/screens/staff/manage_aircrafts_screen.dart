import 'package:flutter/material.dart';
import '../../models/aircraft.dart';
import '../../services/api_service.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';

class ManageAircraftsScreen extends StatefulWidget {
  const ManageAircraftsScreen({super.key});

  @override
  State<ManageAircraftsScreen> createState() => _ManageAircraftsScreenState();
}

class _ManageAircraftsScreenState extends State<ManageAircraftsScreen> {
  List<Aircraft> _aircrafts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAircrafts();
  }

  Future<void> _loadAircrafts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getStaffAircrafts();
      setState(() {
        _aircrafts = response.map((json) => Aircraft.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showAddAircraftDialog() async {
    final modelController = TextEditingController();
    final regController = TextEditingController();
    int? selectedTemplateId;
    List<dynamic> templates = [];
    
    // Load templates first
    try {
      templates = await ApiService.getStaffSeatTemplates();
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка загрузки шаблонов: $e',
          isError: true,
        );
        return;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить самолёт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Модель (например, Boeing 737)'),
                ),
                TextField(
                  controller: regController,
                  decoration: const InputDecoration(labelText: 'Рег. номер (например, RA-12345)'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: selectedTemplateId,
                  items: templates.map<DropdownMenuItem<int>>((t) {
                    return DropdownMenuItem<int>(
                      value: t['id'],
                      child: Text(t['name']),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedTemplateId = val),
                  decoration: const InputDecoration(labelText: 'Шаблон мест'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
            ElevatedButton(
              onPressed: () async {
                if (modelController.text.isNotEmpty && 
                    regController.text.isNotEmpty && 
                    selectedTemplateId != null) {
                  try {
                    await ApiService.createAircraft({
                      'model': modelController.text,
                      'registration_number': regController.text,
                      'seat_template_id': selectedTemplateId,
                    });
                    if (context.mounted) Navigator.pop(context);
                    _loadAircrafts();
                  } catch (e) {
                    if (context.mounted) {
                      UiUtils.showNotification(
                        context: context,
                        message: e.toString(),
                        isError: true,
                      );
                    }
                  }
                }
              },
              child: const Text('СОЗДАТЬ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Управление самолётами'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRouter.manageSeatTemplates),
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Шаблоны мест',
          ),
          IconButton(
            onPressed: _loadAircrafts,
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
                      Text('Ошибка: $_errorMessage', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadAircrafts, child: const Text('Повторить')),
                    ],
                  ),
                )
              : _aircrafts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.airplanemode_inactive, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Самолёты не найдены', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAircrafts,
                      child: ListView.builder(
                        itemCount: _aircrafts.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final aircraft = _aircrafts[index];
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
                                  AppRouter.staffAircraftDetail,
                                  arguments: aircraft.id,
                                );
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  // ...
                                  child: const Icon(Icons.airplanemode_active, color: Colors.blue),
                                ),
                                title: Text(
                                  aircraft.model,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${aircraft.registrationNumber} • ${aircraft.capacity} мест',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                trailing: IconButton(
                                  onPressed: () => _confirmDeleteAircraft(aircraft),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAircraftDialog,
        backgroundColor: Colors.blue[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDeleteAircraft(Aircraft aircraft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить самолёт?'),
        content: Text('Вы действительно хотите удалить самолёт ${aircraft.model} (${aircraft.registrationNumber})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                await ApiService.deleteAircraft(aircraft.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadAircrafts();
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
