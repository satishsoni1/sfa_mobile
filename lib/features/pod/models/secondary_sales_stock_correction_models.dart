// Strongly typed models for Secondary Sales manual stock corrections.
// Laravel is the source of truth for permissions and validation.

class SecondarySalesCorrectionPermission {
  const SecondarySalesCorrectionPermission({
    required this.canCorrectStock,
  });

  final bool canCorrectStock;

  factory SecondarySalesCorrectionPermission.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const SecondarySalesCorrectionPermission(canCorrectStock: false);
    }
    return SecondarySalesCorrectionPermission(
      canCorrectStock: _asBool(
        json['can_correct_stock'] ?? json['canCorrectStock'],
      ),
    );
  }
}

class SecondarySalesLineValidation {
  const SecondarySalesLineValidation({
    this.status,
    this.expectedClosingQty,
    this.actualClosingQty,
    this.variance,
    this.message,
  });

  final String? status;
  final double? expectedClosingQty;
  final double? actualClosingQty;
  final double? variance;
  final String? message;

  String get normalizedStatus => (status ?? '').trim().toLowerCase();

  bool get isValid =>
      normalizedStatus == 'valid' || normalizedStatus == 'ok';

  bool get isInvalid =>
      normalizedStatus == 'invalid' || normalizedStatus == 'failed';

  bool get isWarning => normalizedStatus == 'warning';

  String get displayStatus {
    if (normalizedStatus.isEmpty) return 'NOT VALIDATED';
    if (isValid) return 'VALID';
    if (isInvalid) return 'INVALID';
    if (isWarning) return 'WARNING';
    if (normalizedStatus.contains('not')) return 'NOT VALIDATED';
    return status!.toUpperCase();
  }

  factory SecondarySalesLineValidation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SecondarySalesLineValidation();
    return SecondarySalesLineValidation(
      status: _asString(json['status']),
      expectedClosingQty: _asDouble(
        json['expected_closing_qty'] ?? json['expectedClosingQty'],
      ),
      actualClosingQty: _asDouble(
        json['actual_closing_qty'] ?? json['actualClosingQty'],
      ),
      variance: _asDouble(json['variance']),
      message: _asString(json['message']),
    );
  }
}

class SecondarySalesStatementValidation {
  const SecondarySalesStatementValidation({
    this.status,
    this.invalidLines,
    this.validLines,
    this.message,
  });

  final String? status;
  final int? invalidLines;
  final int? validLines;
  final String? message;

  String get normalizedStatus => (status ?? '').trim().toLowerCase();

  String get displayStatus {
    if (normalizedStatus.isEmpty) return 'NOT VALIDATED';
    if (normalizedStatus == 'valid' || normalizedStatus == 'ok') {
      return 'VALID';
    }
    if (normalizedStatus == 'invalid' || normalizedStatus == 'failed') {
      return 'INVALID';
    }
    if (normalizedStatus == 'warning') return 'WARNING';
    if (normalizedStatus.contains('not')) return 'NOT VALIDATED';
    return status!.toUpperCase();
  }

  factory SecondarySalesStatementValidation.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return const SecondarySalesStatementValidation();
    return SecondarySalesStatementValidation(
      status: _asString(json['status']),
      invalidLines: _asInt(json['invalid_lines'] ?? json['invalidLines']),
      validLines: _asInt(json['valid_lines'] ?? json['validLines']),
      message: _asString(json['message']),
    );
  }
}

class SecondarySalesCorrectionLine {
  const SecondarySalesCorrectionLine({
    required this.lineIndex,
    required this.productName,
    this.extractedOpeningQty,
    this.effectiveOpeningQty,
    this.openingCorrected = false,
    this.extractedClosingQty,
    this.effectiveClosingQty,
    this.closingCorrected = false,
    this.receiptQty,
    this.salesQty,
    this.sampleQty,
    this.expiryQty,
    this.stockValidation = const SecondarySalesLineValidation(),
  });

  final int lineIndex;
  final String productName;
  final double? extractedOpeningQty;
  final double? effectiveOpeningQty;
  final bool openingCorrected;
  final double? extractedClosingQty;
  final double? effectiveClosingQty;
  final bool closingCorrected;
  final double? receiptQty;
  final double? salesQty;
  final double? sampleQty;
  final double? expiryQty;
  final SecondarySalesLineValidation stockValidation;

  factory SecondarySalesCorrectionLine.fromJson(Map<String, dynamic> json) {
    final validationRaw = json['stock_validation'] ?? json['stockValidation'];
    return SecondarySalesCorrectionLine(
      lineIndex: _asInt(json['line_index'] ?? json['lineIndex']) ?? 0,
      productName: _asString(
            json['product_name'] ?? json['productName'] ?? json['name'],
          ) ??
          'Product',
      extractedOpeningQty: _asDouble(
        json['extracted_opening_qty'] ?? json['extractedOpeningQty'],
      ),
      effectiveOpeningQty: _asDouble(
        json['effective_opening_qty'] ?? json['effectiveOpeningQty'],
      ),
      openingCorrected: _asBool(
        json['opening_corrected'] ?? json['openingCorrected'],
      ),
      extractedClosingQty: _asDouble(
        json['extracted_closing_qty'] ?? json['extractedClosingQty'],
      ),
      effectiveClosingQty: _asDouble(
        json['effective_closing_qty'] ?? json['effectiveClosingQty'],
      ),
      closingCorrected: _asBool(
        json['closing_corrected'] ?? json['closingCorrected'],
      ),
      receiptQty: _asDouble(
        json['receipt_qty'] ??
            json['receipts_qty'] ??
            json['purchase_qty'] ??
            json['purchases'],
      ),
      salesQty: _asDouble(json['sales_qty'] ?? json['salesQty']),
      sampleQty: _asDouble(json['sample_qty'] ?? json['sampleQty']),
      expiryQty: _asDouble(json['expiry_qty'] ?? json['expiryQty']),
      stockValidation: SecondarySalesLineValidation.fromJson(
        validationRaw is Map
            ? Map<String, dynamic>.from(validationRaw)
            : null,
      ),
    );
  }
}

class SecondarySalesCorrectionHistoryItem {
  const SecondarySalesCorrectionHistoryItem({
    this.id,
    this.correctedAt,
    this.correctedBy,
    this.reason,
    this.productName,
    this.field,
    this.previousQty,
    this.newQty,
    this.lineIndex,
  });

  final int? id;
  final String? correctedAt;
  final String? correctedBy;
  final String? reason;
  final String? productName;
  final String? field;
  final double? previousQty;
  final double? newQty;
  final int? lineIndex;

  factory SecondarySalesCorrectionHistoryItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return SecondarySalesCorrectionHistoryItem(
      id: _asInt(json['id']),
      correctedAt: _asString(
        json['corrected_at'] ??
            json['created_at'] ??
            json['date'] ??
            json['timestamp'],
      ),
      correctedBy: _asString(
        json['corrected_by'] ??
            json['corrected_by_name'] ??
            json['user_name'] ??
            (json['user'] is Map ? json['user']['name'] : null),
      ),
      reason: _asString(json['reason']),
      productName: _asString(
        json['product_name'] ?? json['productName'] ?? json['product'],
      ),
      field: _asString(
        json['field'] ?? json['quantity_type'] ?? json['type'],
      ),
      previousQty: _asDouble(
        json['previous_qty'] ??
            json['old_qty'] ??
            json['from_qty'] ??
            json['previous_quantity'],
      ),
      newQty: _asDouble(
        json['new_qty'] ??
            json['to_qty'] ??
            json['corrected_qty'] ??
            json['new_quantity'],
      ),
      lineIndex: _asInt(json['line_index'] ?? json['lineIndex']),
    );
  }
}

class SecondarySalesCorrectionResponse {
  const SecondarySalesCorrectionResponse({
    required this.statementId,
    required this.enabled,
    required this.permissions,
    required this.lines,
    required this.correctionHistory,
    required this.stockValidation,
    this.stockistName,
    this.statementMonth,
  });

  final int statementId;
  final bool enabled;
  final SecondarySalesCorrectionPermission permissions;
  final List<SecondarySalesCorrectionLine> lines;
  final List<SecondarySalesCorrectionHistoryItem> correctionHistory;
  final SecondarySalesStatementValidation stockValidation;
  final String? stockistName;
  final String? statementMonth;

  bool get canCorrectStock =>
      enabled && permissions.canCorrectStock;

  factory SecondarySalesCorrectionResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final linesRaw = data['lines'] ?? data['items'] ?? const [];
    final historyRaw =
        data['correction_history'] ?? data['history'] ?? const [];
    final permissionsRaw = data['permissions'];
    final validationRaw = data['stock_validation'] ?? data['stockValidation'];

    return SecondarySalesCorrectionResponse(
      statementId: _asInt(data['statement_id'] ?? data['statementId']) ?? 0,
      enabled: _asBool(data['enabled'], defaultValue: true),
      permissions: SecondarySalesCorrectionPermission.fromJson(
        permissionsRaw is Map
            ? Map<String, dynamic>.from(permissionsRaw)
            : null,
      ),
      lines: _mapList(linesRaw, SecondarySalesCorrectionLine.fromJson),
      correctionHistory: _mapList(
        historyRaw,
        SecondarySalesCorrectionHistoryItem.fromJson,
      ),
      stockValidation: SecondarySalesStatementValidation.fromJson(
        validationRaw is Map
            ? Map<String, dynamic>.from(validationRaw)
            : null,
      ),
      stockistName: _asString(
        data['stockist_name'] ??
            data['stockistName'] ??
            (data['stockist'] is Map
                ? (data['stockist']['name'] ?? data['stockist']['stockist_name'])
                : data['stockist']),
      ),
      statementMonth: _asString(
        data['statement_month'] ?? data['statementMonth'] ?? data['month'],
      ),
    );
  }
}

class SecondarySalesCorrectionDraft {
  SecondarySalesCorrectionDraft({
    required this.lineIndex,
    this.openingQty,
    this.closingQty,
  });

  final int lineIndex;
  double? openingQty;
  double? closingQty;
}

String? validateCorrectionQuantityInput(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = double.tryParse(raw.trim());
  if (parsed == null) return 'Enter a valid number.';
  if (parsed < 0) return 'Quantity cannot be negative.';
  return null;
}

/// Builds POST corrections payload — only includes changed fields.
Map<String, dynamic> buildSecondarySalesCorrectionPayload({
  required String reason,
  required List<SecondarySalesCorrectionLine> originalLines,
  required Map<int, SecondarySalesCorrectionDraft> drafts,
}) {
  final corrections = <Map<String, dynamic>>[];
  for (final line in originalLines) {
    final draft = drafts[line.lineIndex];
    if (draft == null) continue;

    final map = <String, dynamic>{'line_index': line.lineIndex};
    var changed = false;

    if (draft.openingQty != null &&
        !_sameQty(draft.openingQty, line.effectiveOpeningQty)) {
      map['opening_qty'] = draft.openingQty;
      changed = true;
    }
    if (draft.closingQty != null &&
        !_sameQty(draft.closingQty, line.effectiveClosingQty)) {
      map['closing_qty'] = draft.closingQty;
      changed = true;
    }
    if (changed) corrections.add(map);
  }

  return {
    'reason': reason.trim(),
    'corrections': corrections,
  };
}

bool _sameQty(double? a, double? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return (a - b).abs() < 0.000001;
}

List<T> _mapList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) mapper,
) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is Map) {
      out.add(mapper(Map<String, dynamic>.from(item)));
    }
  }
  return out;
}

bool _asBool(dynamic v, {bool defaultValue = false}) {
  if (v == true || v == 1 || v == '1') return true;
  if (v == false || v == 0 || v == '0') return false;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == 'yes') return true;
    if (s == 'false' || s == 'no') return false;
  }
  return defaultValue;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', ''));
}

String? _asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
