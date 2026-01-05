import 'package:flutter/material.dart';
import '../../utils/app_router.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Try to get cached data first, or fetch fresh
      final data = await ApiService.getUserData();
      if (data != null) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
      
      // Fetch fresh in background
      final response = await ApiService.get('/auth/me');
      if (mounted) {
        setState(() {
          _userData = response.data;
          _isLoading = false;
        });
        // Update cache
        ApiService.saveUserData(response.data);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        automaticallyImplyLeading: true, // Allow back button
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_userData != null)
                  UserAccountsDrawerHeader(
                    accountName: Text('${_userData!['first_name']} ${_userData!['last_name']}'),
                    accountEmail: Text(_userData!['email']),
                    currentAccountPicture: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Color(0xFF0F172A)),
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.flight_takeoff),
                  title: const Text('Мои поездки'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, AppRouter.myBookings);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('История платежей'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, AppRouter.paymentHistory);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Редактировать профиль'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.pushNamed(context, AppRouter.editProfile);
                    _loadUserData(); // Reload when returning
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Выйти', style: TextStyle(color: Colors.red)),
                  onTap: _logout,
                ),
              ],
            ),
    );
  }
}
