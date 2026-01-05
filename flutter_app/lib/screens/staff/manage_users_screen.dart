import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getStaffUsers();
      setState(() {
        _users = (data)
            .map((e) => UserProfile.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка загрузки пользователей: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление пользователя'),
        content: const Text('Вы уверены, что хотите удалить этого пользователя?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteStaffUser(userId);
        if (mounted) {
          UiUtils.showNotification(
            context: context,
            message: 'Пользователь удален',
          );
          _loadUsers();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Пользователей пока нет'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(user.role),
                          child: Text(
                            (user.firstName?.isNotEmpty == true ? user.firstName![0] : '?').toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text('${user.firstName ?? ""} ${user.lastName ?? ""}'.trim().isEmpty 
                            ? "Без имени" 
                            : '${user.firstName ?? ""} ${user.lastName ?? ""}'.trim()),
                        subtitle: Text(user.email),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteUser(user.id),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildDetailRow(Icons.security, 'Роль', user.role),
                                if (user.phone != null)
                                  _buildDetailRow(Icons.phone, 'Телефон', user.phone!),
                                if (user.passportNumber != null)
                                  _buildDetailRow(Icons.badge, 'Паспорт', user.passportNumber!),
                                if (user.nationality != null)
                                  _buildDetailRow(Icons.flag, 'Гражданство', user.nationality!),
                                if (user.dateOfBirth != null)
                                  _buildDetailRow(Icons.cake, 'Дата рождения', user.dateOfBirth!),
                                _buildDetailRow(
                                  Icons.calendar_today, 
                                  'Зарегистрирован', 
                                  DateFormat('dd.MM.yyyy HH:mm').format(user.createdAt)
                                ),
                                _buildDetailRow(
                                  Icons.info_outline, 
                                  'Статус', 
                                  user.isActive ? "Активен" : "Заблокирован"
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.red;
      case 'STAFF':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
