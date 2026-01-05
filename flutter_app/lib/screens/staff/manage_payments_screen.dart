import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';

class ManagePaymentsScreen extends StatefulWidget {
  const ManagePaymentsScreen({super.key});

  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen> {
  List<StaffPayment> _allPayments = [];
  List<StaffPayment> _filteredPayments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedStatus;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statuses = ['SUCCESS', 'FAILED', 'REFUNDED', 'PENDING'];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getStaffPayments(status: _selectedStatus);
      setState(() {
        _allPayments = response.map((json) => StaffPayment.fromJson(json)).toList();
        _filterPayments(_searchController.text);
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

  void _filterPayments(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPayments = _allPayments;
      } else {
        query = query.toLowerCase();
        _filteredPayments = _allPayments.where((p) {
          return p.pnr.toLowerCase().contains(query) ||
                 p.transactionId.toLowerCase().contains(query) ||
                 p.passengerName.toLowerCase().contains(query) ||
                 p.flightInfo.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Финансовый контроль'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _filteredPayments.isEmpty
                        ? _buildEmptyView()
                        : _buildPaymentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск (PNR, ID транзакции, Имя)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: _filterPayments,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(null, 'Все'),
                ..._statuses.map((s) => _buildStatusChip(s, _getStatusLabel(s))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? status : null;
          });
          _loadPayments();
        },
        selectedColor: Colors.blue.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[900] : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'SUCCESS': return 'Успешно';
      case 'FAILED': return 'Ошибка';
      case 'REFUNDED': return 'Возврат';
      case 'PENDING': return 'В обработке';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUCCESS': return Colors.green;
      case 'FAILED': return Colors.red;
      case 'REFUNDED': return Colors.orange;
      case 'PENDING': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildPaymentsList() {
    return ListView.builder(
      itemCount: _filteredPayments.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final payment = _filteredPayments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(payment.status).withOpacity(0.1),
              child: Icon(
                payment.status == 'SUCCESS' ? Icons.check_circle : Icons.error,
                color: _getStatusColor(payment.status),
              ),
            ),
            title: Text(
              '${payment.amount} ${payment.currency}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text('ID: ${payment.transactionId}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    _buildDetailRow('Пассажир', payment.passengerName),
                    _buildDetailRow('Рейс', payment.flightInfo),
                    _buildDetailRow('PNR', payment.pnr),
                    _buildDetailRow('Метод', payment.methodText),
                    _buildDetailRow('Дата', DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                               // Link to booking details could go here
                               UiUtils.showNotification(context: context, message: 'Переход к бронированию ${payment.bookingId}');
                            },
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Бронирование'),
                          ),
                        ),
                        if (payment.status == 'SUCCESS') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                 UiUtils.showNotification(context: context, message: 'Функция возврата в разработке', isError: true);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red),
                              icon: const Icon(Icons.undo),
                              label: const Text('Возврат'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Неизвестная ошибка'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadPayments, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Платежи не найдены', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
