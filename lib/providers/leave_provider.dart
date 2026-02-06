import 'package:flutter/material.dart';
import '../data/models/leave_models.dart';
import '../data/services/api_service.dart';

class LeaveProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _leaves = [];
  List<dynamic> get leaves => _leaves;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

List<LeaveBalance> _balances = [];
List<LeaveBalance> get balances => _balances;

  Future<void> fetchLeaves() async {
    _isLoading = true;
    notifyListeners();
    try {
      _leaves = await _apiService.getLeaves();
    } catch (e) {
      debugPrint("Error fetching leaves: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyLeave(String type, DateTime from, DateTime to, String reason) async {
    try {
      await _apiService.applyLeave(type, from, to, reason);
      await fetchLeaves(); // Refresh list after applying
    } catch (e) {
      rethrow;
    }
  }
  

  Future<void> fetchBalances() async {
    _isLoading = true;
    notifyListeners();
    try {
      _balances = await _apiService.getLeaveBalances();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update applyLeave to handle the Map<String, dynamic> payload required by backend
  Future<void> submitLeaveRequest(Map<String, dynamic> payload) async {
    await _apiService.submitLeaveRaw(
      payload,
    ); // You'll need a generic post method
    await fetchLeaves();
  }
}
