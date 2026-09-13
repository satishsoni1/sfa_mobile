// ============================================================
// Statement Detail Model
// Maps GET /api/pods/{id} response to typed Dart objects.
// All new fields are nullable — screen degrades gracefully
// when backend has not yet added them.
// ============================================================

class StatementDetail {
  final int id;
  final String? invoiceNo;
  final String? invoiceDate;
  final String? irn;
  final String? documentType;
  final String status;
  final String? filePath;

  final String? vendorName;
  final String? customerName;

  final String? sourceFileName;
  final String? uploadedBy;
  final String? uploadedAt;

  final String? reportDescription;
  final String? reportPeriodFrom;
  final String? reportPeriodTo;

  final double totalAmount;
  final double openingValue;
  final double closingValue;
  final double purchaseValue;
  final double purchaseReturn;

  final int openingQty;
  final int closingQty;
  final int totalProducts;

  final Map<String, dynamic>? stockist;
  final Map<String, dynamic>? hospital;
  final StatementMappingSummary mappingSummary;

  final List<StatementItem> items;

  double get salesValue => totalAmount;

  const StatementDetail({
    required this.id,
    this.invoiceNo,
    this.invoiceDate,
    this.irn,
    this.documentType,
    required this.status,
    this.filePath,
    this.vendorName,
    this.customerName,
    this.sourceFileName,
    this.uploadedBy,
    this.uploadedAt,
    this.reportDescription,
    this.reportPeriodFrom,
    this.reportPeriodTo,
    required this.totalAmount,
    required this.openingValue,
    required this.closingValue,
    required this.purchaseValue,
    required this.purchaseReturn,
    required this.openingQty,
    required this.closingQty,
    required this.totalProducts,
    this.stockist,
    this.hospital,
    required this.mappingSummary,
    required this.items,
  });

  static double _d(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  factory StatementDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<StatementItem> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((m) => StatementItem.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : [];

    StatementMappingSummary mappingSummary;
    final rawSummary = json['mapping_summary'];
    if (rawSummary is Map) {
      mappingSummary =
          StatementMappingSummary.fromJson(Map<String, dynamic>.from(rawSummary));
    } else {
      final pending = items.where((it) => it.mappingStatus != 'mapped').length;
      final remaining = items.fold<double>(0.0, (sum, it) => sum + it.remainingQty);
      mappingSummary = StatementMappingSummary(
        doctorsMapped: 0,
        productsMapped: 0,
        pendingProducts: pending,
        allocatedQty: 0.0,
        remainingQty: remaining,
      );
    }

    final totalProducts =
        json['total_products'] != null ? _i(json['total_products']) : items.length;

    return StatementDetail(
      id: _i(json['id']),
      invoiceNo: json['invoice_no']?.toString(),
      invoiceDate: json['invoice_date']?.toString(),
      irn: json['irn']?.toString(),
      documentType: json['document_type']?.toString(),
      status: json['status']?.toString() ?? 'unknown',
      filePath: json['file_path']?.toString(),
      vendorName: json['vendor_name']?.toString(),
      customerName: json['customer_name']?.toString(),
      sourceFileName: json['source_file_name']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
      uploadedAt: json['uploaded_at']?.toString(),
      reportDescription: json['report_description']?.toString(),
      reportPeriodFrom: json['report_period_from']?.toString(),
      reportPeriodTo: json['report_period_to']?.toString(),
      totalAmount: _d(json['total_amount']),
      openingValue: _d(json['opening_value']),
      closingValue: _d(json['closing_value']),
      purchaseValue: _d(json['purchase_value']),
      purchaseReturn: _d(json['purchase_return']),
      openingQty: _i(json['opening_qty']),
      closingQty: _i(json['closing_qty']),
      totalProducts: totalProducts,
      stockist: json['stockist'] is Map
          ? Map<String, dynamic>.from(json['stockist'] as Map)
          : null,
      hospital: json['hospital'] is Map
          ? Map<String, dynamic>.from(json['hospital'] as Map)
          : null,
      mappingSummary: mappingSummary,
      items: items,
    );
  }
}

// -------------------------------------------------------

class StatementMappingSummary {
  final int doctorsMapped;
  final int productsMapped;
  final int pendingProducts;
  final double allocatedQty;
  final double remainingQty;

  const StatementMappingSummary({
    required this.doctorsMapped,
    required this.productsMapped,
    required this.pendingProducts,
    required this.allocatedQty,
    required this.remainingQty,
  });

  static double _d(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  factory StatementMappingSummary.fromJson(Map<String, dynamic> json) {
    return StatementMappingSummary(
      doctorsMapped: _i(json['doctors_mapped']),
      productsMapped: _i(json['products_mapped']),
      pendingProducts: _i(json['pending_products']),
      allocatedQty: _d(json['allocated_qty']),
      remainingQty: _d(json['remaining_qty']),
    );
  }
}

// -------------------------------------------------------

class StatementItem {
  final int id;
  final int lineIndex;
  final String productName;
  final String? hsnCode;
  final String packing;
  final String? batchNo;
  final double openingQty;
  final double receiptsQty;
  final double salesQty;
  final double salesValue;
  final double closingQty;
  final double closingValue;
  final double histMay;
  final double histApr;
  final double mappedQty;
  final double remainingQty;
  final String mappingStatus;

  const StatementItem({
    required this.id,
    required this.lineIndex,
    required this.productName,
    this.hsnCode,
    required this.packing,
    this.batchNo,
    required this.openingQty,
    required this.receiptsQty,
    required this.salesQty,
    required this.salesValue,
    required this.closingQty,
    required this.closingValue,
    required this.histMay,
    required this.histApr,
    required this.mappedQty,
    required this.remainingQty,
    required this.mappingStatus,
  });

  static double _d(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  factory StatementItem.fromJson(Map<String, dynamic> json) {
    final salesQty = _d(json['sales_qty'] ?? json['quantity']);
    final salesValue = _d(json['sales_value'] ?? json['amount']);

    return StatementItem(
      id: _i(json['id']),
      lineIndex: _i(json['line_index']),
      productName: (json['product_name']?.toString() ?? '').isNotEmpty
          ? json['product_name'].toString()
          : 'Item #${_i(json['line_index']) + 1}',
      hsnCode: json['hsn_code']?.toString(),
      packing: (json['packing']?.toString() ?? '').isNotEmpty
          ? json['packing'].toString()
          : '—',
      batchNo: json['batch_no']?.toString(),
      openingQty: _d(json['opening_qty']),
      receiptsQty: _d(json['receipts_qty']),
      salesQty: salesQty,
      salesValue: salesValue,
      closingQty: _d(json['closing_qty']),
      closingValue: _d(json['closing_value']),
      histMay: _d(json['hist_may']),
      histApr: _d(json['hist_apr']),
      mappedQty: _d(json['mapped_qty']),
      remainingQty: _d(json['remaining_qty']),
      mappingStatus: json['mapping_status']?.toString() ?? 'pending',
    );
  }
}
