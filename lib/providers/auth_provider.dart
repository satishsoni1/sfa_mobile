import 'package:flutter/material.dart';
import '../data/services/api_service.dart';
import '../data/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  User? _currentUser; // Store the actual user object

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get user => _currentUser; // Getter to access user details in UI

  // 1. CHECK LOGIN STATUS (Run on App Start)
  Future<void> checkLoginStatus() async {
    final token = await _apiService.getToken();
    final user = await _apiService.getUser();

    if (token != null && user != null) {
      _currentUser = user;
      _isAuthenticated = true;
    } else {
      _isAuthenticated = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  // 2. LOGIN ACTION
  Future<String> login(String empId, String password) async {
    try {
      // Call API
      final result = await _apiService.login(empId, password);

      // Parse User
      final token = result['token'];
      final user = User.fromJson(result['user']); // Convert Map to User Object
      // Save Session
      await _apiService.saveSession(token, user);

      // Update State
      _currentUser = user;
      _isAuthenticated = true;
      notifyListeners();

        // CHECK: Is this the first login?
        if (user.isFirstLogin) {
          // Navigate to Change Password Screen immediately
          // We return a specific status to the UI to handle navigation
          return "FIRST_LOGIN";
        } else {
          // Normal flow
          return "SUCCESS";
        }
      return "FAILED";
    } catch (e) {
      print("Login Error: $e");
      return "ERROR";
    }
  }

  // 3. LOGOUT ACTION
  Future<void> logout() async {
    await _apiService.clearSession();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
