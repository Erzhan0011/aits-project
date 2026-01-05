import 'api_service.dart';
import '../models/user.dart';

/// Mock authentication service using local storage
/// For development/testing purposes only
class AuthService {
  // Login - Returns full response from server (token + user data if configured, or just token)
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      // 1. Get Token
      // FastAPI OAuth2PasswordRequestForm requires application/x-www-form-urlencoded
      final tokenResponse = await ApiService.post(
        '/auth/token', 
        data: 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
      );
      
      final tokenData = tokenResponse.data;
      final accessToken = tokenData['access_token'];
      final refreshToken = tokenData['refresh_token'];
      
      if (accessToken == null) throw Exception('Токен не получен');
      
      // Save tokens
      await ApiService.saveToken(accessToken);
      if (refreshToken != null) {
        await ApiService.saveRefreshToken(refreshToken);
      }

      // 2. Get User Profile
      final userResponse = await ApiService.get('/auth/me');
      final userData = userResponse.data;

      // Save user data locally
      await ApiService.saveUserData(userData);

      return {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user': userData,
      };
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Get Profile
  static Future<User> getProfile() async {
    try {
      final response = await ApiService.get('/auth/me');
      final userData = response.data;
      await ApiService.saveUserData(userData);
      return User.fromJson(userData);
    } catch (e) {
      rethrow;
    }
  }

  // Register
  static Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final data = {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      };

      final response = await ApiService.post('/auth/register', data: data);
      final result = response.data;
      
      // If registration returns tokens immediately, save them
      if (result['access_token'] != null) {
         await ApiService.saveToken(result['access_token']);
         if (result['refresh_token'] != null) {
           await ApiService.saveRefreshToken(result['refresh_token']);
         }
         
         final userResponse = await ApiService.get('/auth/me');
         final userData = userResponse.data;
         await ApiService.saveUserData(userData);
         return User.fromJson(userData);
      }

      // If just a user object is returned or we need to parse what we have
      return User(
        id: 0, // Placeholder if not returned
        email: email, 
        firstName: firstName,
        lastName: lastName,
        role: 'PASSENGER', 
        isActive: true
      ); 
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Get current user (from local storage, verify with API if needed)
  static Future<User?> getCurrentUser() async {
    try {
      final userData = await ApiService.getUserData();
      final token = await ApiService.getToken();
      
      if (userData != null && token != null) {
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Logout
  static Future<void> logout() async {
    await ApiService.logout();
  }

  // Get token
  static Future<String?> getToken() async {
    return await ApiService.getToken();
  }
}
