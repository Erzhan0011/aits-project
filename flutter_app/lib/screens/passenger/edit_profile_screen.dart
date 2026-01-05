import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/ui_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passportController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _dobController = TextEditingController();

  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/auth/me'); 
      _userData = response.data;
      
      _firstNameController.text = _userData?['first_name'] ?? '';
      _lastNameController.text = _userData?['last_name'] ?? '';
      _phoneController.text = _userData?['phone'] ?? '';
      _passportController.text = _userData?['passport_number'] ?? '';
      _nationalityController.text = _userData?['nationality'] ?? '';
      _dobController.text = _userData?['date_of_birth'] ?? '';
      
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка при загрузке профиля: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.put('/passenger/profile', data: {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'phone': _phoneController.text,
        'passport_number': _passportController.text,
        'nationality': _nationalityController.text,
        'date_of_birth': _dobController.text,
      });
      if (mounted) {
        // Update AuthProvider state
        Provider.of<AuthProvider>(context, listen: false).refreshUser();
        
        UiUtils.showNotification(
          context: context,
          message: 'Профиль успешно обновлен',
        );
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showNotification(
          context: context,
          message: 'Ошибка при сохранении: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование профиля')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'Имя'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Фамилия'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Телефон'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passportController,
                      decoration: const InputDecoration(labelText: 'Номер паспорта'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nationalityController,
                      decoration: const InputDecoration(labelText: 'Гражданство'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(
                        labelText: 'Дата рождения (YYYY-MM-DD)',
                        hintText: '1990-01-01',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
