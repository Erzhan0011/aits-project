import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use 127.0.0.1 with 'adb reverse tcp:8000 tcp:8000' for Android Emulator
  // Use http://192.168.68.53:8000 for physical Android device on the same connection
  static String get baseUrl {
    if (kReleaseMode) return 'http://your-production-server.com';
    if (!kIsWeb && Platform.isAndroid) return 'http://127.0.0.1:8000'; // Using adb reverse
    return 'http://127.0.0.1:8000';
  }

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          if (options.data is String) {
            options.headers['Content-Type'] = 'application/x-www-form-urlencoded';
          }
          
          return handler.next(options);
        },
        onError: (error, handler) async {
          // If 401 Unauthorized, try to refresh token
          if (error.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString('refresh_token');
            
            if (refreshToken != null) {
              try {
                // Try to refresh token - use a separate Dio instance to avoid interceptor loop
                final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
                final response = await refreshDio.post('/auth/refresh', data: {
                  'refresh_token': refreshToken
                });
                
                final newAccessToken = response.data['access_token'];
                final newRefreshToken = response.data['refresh_token'];
                
                if (newAccessToken != null) {
                  // Save new tokens
                  await prefs.setString('access_token', newAccessToken);
                  if (newRefreshToken != null) {
                    await prefs.setString('refresh_token', newRefreshToken);
                  }
                  
                  // Retry original request with new token
                  final options = error.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccessToken';
                  
                  final retryResponse = await _dio.fetch(options);
                  return handler.resolve(retryResponse);
                }
              } catch (e) {
                // Refresh failed, clear tokens and let the error propagate
                await _clearToken();
              }
            } else {
              await _clearToken();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
  }

  static Exception _handleDioError(DioException e) {
    final usedBaseUrl = e.requestOptions.baseUrl;
    debugPrint('API Error: ${e.requestOptions.method} ${e.requestOptions.path} (Base: $usedBaseUrl) -> ${e.message}');
    
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return Exception('Превышено время ожидания. Проверьте, запущен ли backend-сервер по адресу $usedBaseUrl');
    }
    
    if (e.type == DioExceptionType.connectionError) {
      return Exception('Ошибка соединения. Убедитесь, что сервер доступен по адресу $usedBaseUrl. В браузере проверьте CORS.');
    }
    
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final errorData = e.response!.data;
      String message = 'Ошибка сервера ($statusCode)';
      
      if (errorData is Map && errorData.containsKey('detail')) {
        final detail = errorData['detail'];
        if (statusCode == 422 && detail is List) {
          message = 'Ошибка валидации: ${detail.map((v) => "${v['loc'].last}: ${v['msg']}").join(', ')}';
        } else {
          message = detail.toString();
        }
      } else {
        switch (statusCode) {
          case 401: message = 'Требуется авторизация'; break;
          case 403: message = 'Доступ запрещен (CORS или роль)'; break;
          case 404: message = 'Ресурс не найден (${e.requestOptions.path})'; break;
          case 400: message = 'Некорректный запрос'; break;
          case 500: message = 'Внутренняя ошибка сервера'; break;
        }
      }
      return Exception(message);
    }
    return Exception('Ошибка подключения: ${e.message}. URL: $usedBaseUrl${e.requestOptions.path}');
  }

  // HTTP Methods
  static Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      rethrow;
    }
  }

  // Token & User Management
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', token);
  }

  static Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString('access_token');
  
  static Future<String?> getRefreshToken() async => (await SharedPreferences.getInstance()).getString('refresh_token');

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final str = (await SharedPreferences.getInstance()).getString('user_data');
    return str != null ? jsonDecode(str) as Map<String, dynamic> : null;
  }

  static Future<void> logout() => _clearToken();

  // STAFF CONVENIENCES - LISTS
  static Future<List<dynamic>> getStaffFlights() async => (await get('/staff/flights')).data;
  static Future<List<dynamic>> getStaffAirports() async => (await get('/staff/airports')).data;
  static Future<List<dynamic>> getStaffAircrafts() async => (await get('/staff/aircrafts')).data;
  static Future<List<dynamic>> getStaffBookings({int? flightId, String? pnr}) async {
    final Map<String, dynamic> params = {};
    if (flightId != null) params['flight_id'] = flightId;
    if (pnr != null) params['pnr'] = pnr;
    return (await get('/staff/bookings', queryParameters: params)).data;
  }
  static Future<List<dynamic>> getSeatConflicts(int flightId) async => (await get('/staff/flights/$flightId/conflicts')).data;
  static Future<List<dynamic>> getStaffAnnouncements() async => (await get('/staff/announcements')).data;
  static Future<List<dynamic>> getStaffUsers() async => (await get('/staff/users')).data;
  static Future<List<dynamic>> getStaffSeatTemplates() async => (await get('/staff/seat-templates')).data;

  static Future<List<dynamic>> getStaffPayments({String? status}) async {
    final params = status != null ? {'status': status} : null;
    return (await get('/staff/payments', queryParameters: params)).data;
  }

  // STAFF CONVENIENCES - DETAILS
  static Future<Map<String, dynamic>> getStaffAirportDetails(int id) async => (await get('/staff/airports/$id')).data;
  static Future<Map<String, dynamic>> getStaffAircraftDetails(int id) async => (await get('/staff/aircrafts/$id')).data;
  static Future<Map<String, dynamic>> getStaffFlightSeats(int id) async => (await get('/staff/flights/$id/seats')).data;

  // STAFF CONVENIENCES - ACTIONS
  static Future<Map<String, dynamic>> createFlight(Map<String, dynamic> data) async => (await post('/staff/flights', data: data)).data;
  static Future<Map<String, dynamic>> updateFlight(int id, Map<String, dynamic> data) async => (await put('/staff/flights/$id', data: data)).data;
  static Future<void> deleteFlight(int id) => delete('/staff/flights/$id');

  static Future<Map<String, dynamic>> createAirport(Map<String, dynamic> data) async => (await post('/staff/airports', data: data)).data;
  static Future<void> deleteAirport(int id) => delete('/staff/airports/$id');

  static Future<Map<String, dynamic>> createAircraft(Map<String, dynamic> data) async => (await post('/staff/aircrafts', data: data)).data;
  static Future<void> deleteAircraft(int id) => delete('/staff/aircrafts/$id');

  static Future<Map<String, dynamic>> createStaffAnnouncement(Map<String, dynamic> data) async => (await post('/staff/announcements', data: data)).data;
  static Future<void> deleteStaffAnnouncement(int id) => delete('/staff/announcements/$id');

  static Future<void> deleteStaffUser(int id) => delete('/staff/users/$id');
  static Future<Map<String, dynamic>> cancelBookingStaff(int id) async => (await post('/staff/bookings/$id/cancel')).data;
  static Future<Map<String, dynamic>> blockSeat(int flightId, String seat) async => (await post('/staff/flights/$flightId/block-seat', data: {'seat_number': seat})).data;

  static Future<Map<String, dynamic>> createSeatTemplate(Map<String, dynamic> data) async => (await post('/staff/seat-templates', data: data)).data;
  static Future<void> deleteSeatTemplate(int id) => delete('/staff/seat-templates/$id');
}
