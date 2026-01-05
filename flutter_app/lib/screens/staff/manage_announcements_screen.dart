import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';

class ManageAnnouncementsScreen extends StatefulWidget {
  const ManageAnnouncementsScreen({super.key});

  @override
  State<ManageAnnouncementsScreen> createState() => _ManageAnnouncementsScreenState();
}

class _ManageAnnouncementsScreenState extends State<ManageAnnouncementsScreen> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  List<dynamic> _flights = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        ApiService.getStaffAnnouncements(),
        ApiService.getStaffFlights(),
      ]);
      setState(() {
        _announcements = futures[0];
        _flights = futures[1];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка загрузки данных: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    try {
      await ApiService.deleteStaffAnnouncement(id);
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Объявление удалено',
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка при удалении: $e',
          isError: true,
        );
      }
    }
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    int? selectedFlightId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Создать объявление'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Заголовок'),
                ),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Сообщение'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: selectedFlightId,
                  decoration: const InputDecoration(labelText: 'Рейс (опционально)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Для всех рейсов (Global)'),
                    ),
                    ..._flights.map((f) => DropdownMenuItem<int?>(
                          value: f['id'],
                          child: Text('${f['flight_number']} (${f['departure_city']} -> ${f['arrival_city']})'),
                        )),
                  ],
                  onChanged: (val) => setDialogState(() => selectedFlightId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) {
                  return;
                }
                try {
                  await ApiService.createStaffAnnouncement({
                    'title': titleController.text,
                    'message': messageController.text,
                    'flight_id': selectedFlightId,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    UiUtils.showNotification(
                      context: context,
                      message: 'Ошибка создания: $e',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление объявлениями'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? const Center(child: Text('Объявлений пока нет'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final ann = _announcements[index];
                    final createdAtRaw = ann['created_at'];
                    final date = createdAtRaw != null 
                        ? DateTime.parse(createdAtRaw).toLocal() 
                        : DateTime.now();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.announcement, color: Colors.white),
                        ),
                        title: Text(ann['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(ann['message']),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ann['flight_id'] == null ? "Глобальное" : "Рейс #${ann['flight_id']}",
                                  style: TextStyle(
                                    color: ann['flight_id'] == null ? Colors.green : Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd.MM HH:mm').format(date),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteAnnouncement(ann['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
