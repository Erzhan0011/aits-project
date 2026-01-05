import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';

class CreateSeatTemplateScreen extends StatefulWidget {
  const CreateSeatTemplateScreen({super.key});

  @override
  State<CreateSeatTemplateScreen> createState() => _CreateSeatTemplateScreenState();
}

class _CreateSeatTemplateScreenState extends State<CreateSeatTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rowCountController = TextEditingController(text: '20');
  final _lettersController = TextEditingController(text: 'ABC DEF');
  final _businessRowsController = TextEditingController(text: '1-3');
  final _economyRowsController = TextEditingController(text: '4-20');

  List<dynamic> _previewSeats = [];

  @override
  void initState() {
    super.initState();
    _updatePreview();
  }

  void _updatePreview() {
    final rowCount = int.tryParse(_rowCountController.text) ?? 0;
    final letters = _lettersController.text;
    final bizRowsStr = _businessRowsController.text;
    
    if (rowCount <= 0 || letters.isEmpty) {
      setState(() => _previewSeats = []);
      return;
    }

    // Простая имитация генератора бэкенда для превью
    Set<int> bizRows = {};
    if (bizRowsStr.isNotEmpty) {
      for (var part in bizRowsStr.split(',')) {
        part = part.trim();
        if (part.contains('-')) {
          var split = part.split('-');
          int? start = int.tryParse(split[0].trim());
          int? end = int.tryParse(split[1].trim());
          if (start != null && end != null) {
            for (int i = start; i <= end; i++) {
              bizRows.add(i);
            }
          }
        } else {
          int? val = int.tryParse(part);
          if (val != null) bizRows.add(val);
        }
      }
    }

    List<dynamic> seats = [];
    for (int r = 1; r <= rowCount; r++) {
      for (int i = 0; i < letters.length; i++) {
        if (letters[i] == ' ') continue;
        seats.add({
          'seat_number': '$r${letters[i]}',
          'row': r,
          'letter': letters[i],
          'class': bizRows.contains(r) ? 'BUSINESS' : 'ECONOMY',
        });
      }
    }
    setState(() => _previewSeats = seats);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ApiService.createSeatTemplate({
        'name': _nameController.text,
        'row_count': int.parse(_rowCountController.text),
        'seat_letters': _lettersController.text,
        'business_rows': _businessRowsController.text,
        'economy_rows': _economyRowsController.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(context: context, message: e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый шаблон мест')),
      body: Row(
        children: [
          // Form Section
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                onChanged: _updatePreview,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Название шаблона', hintText: 'Boeing 737-800 Standard'),
                      validator: (v) => v?.isEmpty == true ? 'Укажите название' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rowCountController,
                            decoration: const InputDecoration(labelText: 'Кол-во рядов'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lettersController,
                            decoration: const InputDecoration(labelText: 'Буквы (с пробелом для прохода)', hintText: 'ABC DEF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessRowsController,
                      decoration: const InputDecoration(labelText: 'Ряды Бизнес-класса', hintText: '1-3'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _economyRowsController,
                      decoration: const InputDecoration(labelText: 'Ряды Эконом-класса', hintText: '4-20'),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                        child: const Text('СОЗДАТЬ ШАБЛОН'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Preview Section
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('ПРЕДПРОСМОТР СХЕМЫ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  Expanded(
                    child: _previewSeats.isEmpty 
                      ? const Center(child: Text('Введите параметры для генерации превью'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          itemCount: (int.tryParse(_rowCountController.text) ?? 0),
                          itemBuilder: (context, rowIdx) {
                            final rowNum = rowIdx + 1;
                            final rowSeats = _previewSeats.where((s) => s['row'] == rowNum).toList();
                            final letters = _lettersController.text;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 30, child: Text('$rowNum', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                  ...List.generate(letters.length, (idx) {
                                    if (letters[idx] == ' ') return const SizedBox(width: 30);
                                    final seat = rowSeats.firstWhere((s) => s['letter'] == letters[idx], orElse: () => null);
                                    if (seat == null) return const SizedBox(width: 40);
                                    
                                    final isBiz = seat['class'] == 'BUSINESS';
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isBiz ? Colors.orange[100] : Colors.blue[50],
                                        border: Border.all(color: isBiz ? Colors.orange : Colors.blue[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Center(
                                        child: Text(letters[idx], style: TextStyle(
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold,
                                          color: isBiz ? Colors.orange[800] : Colors.blue[800]
                                        )),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
