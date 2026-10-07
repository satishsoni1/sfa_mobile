import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/api/gift_api_service.dart';
import '../data/models/gift_shipment_model.dart';

class GiftAcceptanceProvider with ChangeNotifier {
  final GiftApiService _apiService;

  GiftAcceptanceProvider({GiftApiService? apiService})
      : _apiService = apiService ?? GiftApiService();

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<GiftShipmentModel> _pendingShipments = [];
  List<GiftInventoryItem> _currentInventory = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<GiftShipmentModel> get pendingShipments => _pendingShipments;
  List<GiftInventoryItem> get currentInventory => _currentInventory;

  /// Fetches pending shipments for the current employee/MR
  Future<void> fetchPendingShipments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pendingShipments = await _apiService.getPendingShipments();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[GiftAcceptanceProvider] fetchPendingShipments error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches the MR's approved current gift inventory
  Future<void> fetchCurrentInventory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentInventory = await _apiService.getCurrentInventory();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[GiftAcceptanceProvider] fetchCurrentInventory error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the accepted quantity for a specific item in a shipment
  void updateAcceptedQty(String shipmentId, String giftId, int qty) {
    final shipmentIndex = _pendingShipments.indexWhere((s) => s.shipmentId == shipmentId);
    if (shipmentIndex == -1) return;

    final shipment = _pendingShipments[shipmentIndex];
    final updatedItems = shipment.items.map((item) {
      if (item.giftId == giftId) {
        return item.copyWith(
          acceptedQty: qty,
          // Clear rejection reason if accepted in full
          rejectionReason: qty >= item.shippedQty ? '' : item.rejectionReason,
        );
      }
      return item;
    }).toList();

    _pendingShipments[shipmentIndex] = shipment.copyWith(items: updatedItems);
    notifyListeners();
  }

  /// Updates the rejection reason if acceptedQty < shippedQty
  void updateRejectionReason(String shipmentId, String giftId, String reason) {
    final shipmentIndex = _pendingShipments.indexWhere((s) => s.shipmentId == shipmentId);
    if (shipmentIndex == -1) return;

    final shipment = _pendingShipments[shipmentIndex];
    final updatedItems = shipment.items.map((item) {
      if (item.giftId == giftId) {
        return item.copyWith(rejectionReason: reason);
      }
      return item;
    }).toList();

    _pendingShipments[shipmentIndex] = shipment.copyWith(items: updatedItems);
    notifyListeners();
  }

  /// Submits shipment acceptance to the backend API
  Future<bool> submitAcceptance(String shipmentId) async {
    final shipmentIndex = _pendingShipments.indexWhere((s) => s.shipmentId == shipmentId);
    if (shipmentIndex == -1) {
      _errorMessage = "Shipment not found.";
      notifyListeners();
      return false;
    }

    final shipment = _pendingShipments[shipmentIndex];

    // Validate that every item has an accepted quantity entered
    for (var item in shipment.items) {
      if (item.acceptedQty == null) {
        _errorMessage = "Please enter accepted quantity for '${item.giftName}'.";
        notifyListeners();
        return false;
      }

      if (item.acceptedQty! < 0 || item.acceptedQty! > item.shippedQty) {
        _errorMessage = "Accepted quantity for '${item.giftName}' cannot exceed shipped quantity (${item.shippedQty}).";
        notifyListeners();
        return false;
      }

      if (item.acceptedQty! < item.shippedQty && (item.rejectionReason == null || item.rejectionReason!.trim().isEmpty)) {
        _errorMessage = "Please provide a reason for short acceptance on '${item.giftName}'.";
        notifyListeners();
        return false;
      }
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nowFormatted = DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.now());

      final itemsPayload = shipment.items.map((item) {
        return {
          'gift_id': item.giftId,
          'shipped_qty': item.shippedQty,
          'accepted_qty': item.acceptedQty ?? item.shippedQty,
          'reason': item.rejectionReason ?? '',
        };
      }).toList();

      await _apiService.submitAcceptance(
        shipmentId: shipment.shipmentId,
        acceptedOn: nowFormatted,
        items: itemsPayload,
      );

      // Refresh both lists in background
      await Future.wait([
        fetchPendingShipments(),
        fetchCurrentInventory(),
      ]);

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[GiftAcceptanceProvider] submitAcceptance error: $e');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
