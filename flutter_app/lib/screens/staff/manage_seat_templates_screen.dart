import 'package:flutter/material.dart';
import '../../models/seat_template.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';
import '../../utils/app_router.dart';

class ManageSeatTemplatesScreen extends StatefulWidget {
  const ManageSeatTemplatesScreen({super.key});

  @override
  State<ManageSeatTemplatesScreen> createState() => _ManageSeatTemplatesScreenState();
}

class _ManageSeatTemplatesScreenState extends State<ManageSeatTemplatesScreen> {
  List<SeatTemplate> _templates = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getStaffSeatTemplates();
      setState(() {
        _templates = response.map((json) => SeatTemplate.fromJson(json)).toList();
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

  void _confirmDeleteTemplate(SeatTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить шаблон?'),
        content: Text('Вы действительно хотите удалить шаблон "${template.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.deleteSeatTemplate(template.id);
                _loadTemplates();
              } catch (e) {
                if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаблоны мест'),
        actions: [
          IconButton(onPressed: _loadTemplates, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _templates.isEmpty
                  ? const Center(child: Text('Нет доступных шаблонов'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Рядов: ${template.rowCount}, Места: ${template.seatLetters}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDeleteTemplate(template),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRouter.staffCreateSeatTemplate);
          if (result == true) _loadTemplates();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
