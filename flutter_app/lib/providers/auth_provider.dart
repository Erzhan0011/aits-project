import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isPassenger => _user?.isPassenger ?? false;
  bool get isStaff => _user?.isStaff ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  
  bool get isProfileComplete {
    if (_user == null) return false;
    return (_user!.firstName?.isNotEmpty ?? false) && 
           (_user!.lastName?.isNotEmpty ?? false) && 
           (_user!.passportNumber?.isNotEmpty ?? false) && 
           (_user!.dateOfBirth?.isNotEmpty ?? false);
  }

  AuthProvider() {
    // Загружаем пользователя синхронно если возможно
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        // Verify token by calling profile endpoint
        try {
          final profile = await AuthService.getProfile();
          _user = profile;
        } catch (e) {
          // If profile fetch fails (e.g. 401), clear everything
          await logout();
        }
      }
      notifyListeners();
    } catch (e) {
      _error = null;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService.login(email, password);
      if (response != null && response.containsKey('access_token')) {
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = 'Неверный email или пароль';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      String errorMessage = 'Ошибка входа';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await AuthService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      
      // User is automatically logged in after registration
      _user = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String errorMessage = 'Ошибка регистрации';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final profile = await AuthService.getProfile();
      _user = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
