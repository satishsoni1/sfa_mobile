class GiftShipmentModel {
  final String shipmentId;
  final String shippedOn;
  final String shippedBy;
  final String status; // "pending_acceptance", "accepted", "partial"
  final List<ShipmentItem> items;

  GiftShipmentModel({
    required this.shipmentId,
    required this.shippedOn,
    required this.shippedBy,
    this.status = 'pending_acceptance',
    required this.items,
  });

  GiftShipmentModel copyWith({
    String? shipmentId,
    String? shippedOn,
    String? shippedBy,
    String? status,
    List<ShipmentItem>? items,
  }) {
    return GiftShipmentModel(
      shipmentId: shipmentId ?? this.shipmentId,
      shippedOn: shippedOn ?? this.shippedOn,
      shippedBy: shippedBy ?? this.shippedBy,
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }

  factory GiftShipmentModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<ShipmentItem> itemList = [];
    if (rawItems is List) {
      itemList = rawItems
          .map((item) => ShipmentItem.fromJson(Map<String, dynamic>.from(item is Map ? item : {})))
          .toList();
    }

    return GiftShipmentModel(
      shipmentId: (json['shipment_id'] ?? json['shipmentId'] ?? json['id'] ?? '').toString(),
      shippedOn: (json['shipped_on'] ?? json['shippedOn'] ?? json['date'] ?? '').toString(),
      shippedBy: (json['shipped_by'] ?? json['shippedBy'] ?? json['sender'] ?? 'Head Office').toString(),
      status: (json['status'] ?? 'pending_acceptance').toString(),
      items: itemList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,
      'shipped_on': shippedOn,
      'shipped_by': shippedBy,
      'status': status,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

class ShipmentItem {
  final String giftId;
  final String giftName;
  final String batchNo;
  final int shippedQty;
  final int? acceptedQty; // null means not yet entered
  final String? rejectionReason;

  ShipmentItem({
    required this.giftId,
    required this.giftName,
    required this.batchNo,
    required this.shippedQty,
    this.acceptedQty,
    this.rejectionReason,
  });

  ShipmentItem copyWith({
    String? giftId,
    String? giftName,
    String? batchNo,
    int? shippedQty,
    int? acceptedQty,
    String? rejectionReason,
  }) {
    return ShipmentItem(
      giftId: giftId ?? this.giftId,
      giftName: giftName ?? this.giftName,
      batchNo: batchNo ?? this.batchNo,
      shippedQty: shippedQty ?? this.shippedQty,
      acceptedQty: acceptedQty ?? this.acceptedQty,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  factory ShipmentItem.fromJson(Map<String, dynamic> json) {
    return ShipmentItem(
      giftId: (json['gift_id'] ?? json['giftId'] ?? json['id'] ?? '').toString(),
      giftName: (json['gift_name'] ?? json['giftName'] ?? json['name'] ?? 'Unknown Gift').toString(),
      batchNo: (json['batch_no'] ?? json['batchNo'] ?? json['batch'] ?? 'N/A').toString(),
      shippedQty: int.tryParse((json['shipped_qty'] ?? json['shippedQty'] ?? json['quantity'] ?? '0').toString()) ?? 0,
      acceptedQty: json['accepted_qty'] != null || json['acceptedQty'] != null
          ? int.tryParse((json['accepted_qty'] ?? json['acceptedQty']).toString())
          : null,
      rejectionReason: json['rejection_reason'] ?? json['rejectionReason'] ?? json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gift_id': giftId,
      'gift_name': giftName,
      'batch_no': batchNo,
      'shipped_qty': shippedQty,
      'accepted_qty': acceptedQty,
      'reason': rejectionReason ?? '',
    };
  }
}

class GiftInventoryItem {
  final String giftId;
  final String giftName;
  final String batchNo;
  final int quantity;
  final String? category;
  final String? lastUpdated;

  GiftInventoryItem({
    required this.giftId,
    required this.giftName,
    required this.batchNo,
    required this.quantity,
    this.category,
    this.lastUpdated,
  });

  factory GiftInventoryItem.fromJson(Map<String, dynamic> json) {
    return GiftInventoryItem(
      giftId: (json['gift_id'] ?? json['giftId'] ?? json['id'] ?? '').toString(),
      giftName: (json['gift_name'] ?? json['giftName'] ?? json['name'] ?? 'Gift Item').toString(),
      batchNo: (json['batch_no'] ?? json['batchNo'] ?? json['batch'] ?? '-').toString(),
      quantity: int.tryParse((json['available_qty'] ?? json['available_quantity'] ?? json['quantity'] ?? json['current_stock'] ?? json['stock'] ?? json['qty'] ?? '0').toString()) ?? 0,
      category: (json['category'] ?? json['brand_name'] ?? json['brand'])?.toString(),
      lastUpdated: json['last_updated']?.toString() ?? json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gift_id': giftId,
      'gift_name': giftName,
      'batch_no': batchNo,
      'quantity': quantity,
      if (category != null) 'category': category,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    };
  }
}
