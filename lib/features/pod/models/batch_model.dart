class Batch {
  final int id;
  final int userId;
  final int hospitalId;
  final int stockistId;
  final int totalFiles;
  final int successfulFiles;
  final int failedFiles;
  final int cancelledFiles;
  final String status;
  final String? startedAt;
  final String? completedAt;
  /// Statement / business date (YYYY-MM-DD) used for month grouping.
  final String? statementDate;
  final String? statementMonth;
  final String? periodFrom;
  final String? periodTo;
  final Map<String, dynamic> steps;
  final String? failureReasons;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? hospital;
  final Map<String, dynamic>? stockist;
  final bool hasValidationIssue;
  final String? validationMessage;
  /// Flat string fallbacks when API returns hospital_name / stockist as scalars.
  final String? hospitalNameOverride;
  final String? stockistNameOverride;
  /// POD / statement document ids created from this batch (for Statement Details).
  final List<int> documentIds;

  Batch({
    required this.id,
    required this.userId,
    required this.hospitalId,
    required this.stockistId,
    required this.totalFiles,
    required this.successfulFiles,
    required this.failedFiles,
    required this.cancelledFiles,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.statementDate,
    this.statementMonth,
    this.periodFrom,
    this.periodTo,
    required this.steps,
    this.failureReasons,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.hospital,
    this.stockist,
    this.hasValidationIssue = false,
    this.validationMessage,
    this.hospitalNameOverride,
    this.stockistNameOverride,
    this.documentIds = const [],
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to String
    String? _safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is List && value.isNotEmpty) {
        // If it's a list, take the first element and convert to string
        return value.first.toString();
      }
      return value.toString();
    }

    // Helper to safely convert to int
    int _safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to safely convert to Map
    Map<String, dynamic>? _safeMap(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

    bool _asBool(dynamic value) {
      if (value == true || value == 1 || value == '1') return true;
      if (value is String) {
        final v = value.toLowerCase().trim();
        return v == 'true' || v == 'yes';
      }
      return false;
    }

    final hospitalMap = _safeMap(json['hospital']);
    final stockistRaw = json['stockist'];
    final stockistMap = _safeMap(stockistRaw);

    final hospitalFlat = _safeString(
      json['hospital_name'] ??
          json['hospitalName'] ??
          json['company_name'] ??
          json['companyName'],
    );
    final stockistFlat = _safeString(
      (stockistRaw is String || stockistRaw is num) ? stockistRaw : null,
    ) ??
        _safeString(
          json['stockist_name'] ?? json['stockistName'],
        );

    final metadata = _safeMap(json['metadata']) ?? {};
    final metaValidation = _safeMap(metadata['validation']);
    final validationMsg = _safeString(
      json['validation_message'] ??
          json['validationMessage'] ??
          metaValidation?['validation_message'] ??
          metaValidation?['validationMessage'] ??
          metadata['validation_message'] ??
          metadata['validationMessage'],
    );
    final explicitHasValidation = json.containsKey('has_validation_issue') ||
        json.containsKey('hasValidationIssue') ||
        metaValidation?.containsKey('has_validation_issue') == true ||
        metaValidation?.containsKey('hasValidationIssue') == true ||
        metadata.containsKey('has_validation_issue') ||
        metadata.containsKey('hasValidationIssue');
    final hasValidationFlag = _asBool(
      json['has_validation_issue'] ??
          json['hasValidationIssue'] ??
          metaValidation?['has_validation_issue'] ??
          metaValidation?['hasValidationIssue'] ??
          metadata['has_validation_issue'] ??
          metadata['hasValidationIssue'],
    );
    // Prefer explicit API flags. Only infer from message when the flag is absent.
    final hasValidation = explicitHasValidation
        ? hasValidationFlag
        : (validationMsg?.trim().isNotEmpty ?? false);

    final statementDate = _safeString(
      json['date'] ??
          json['statement_date'] ??
          json['statementDate'] ??
          json['business_date'] ??
          json['businessDate'] ??
          metadata['date'] ??
          metadata['statement_date'] ??
          metadata['statementDate'],
    );
    final statementMonth = _safeString(
      json['statement_month'] ??
          json['statementMonth'] ??
          json['month'] ??
          metadata['statement_month'] ??
          metadata['statementMonth'] ??
          metadata['month'],
    );
    final periodFrom = _safeString(
      json['period_from'] ??
          json['periodFrom'] ??
          json['report_period_from'] ??
          json['reportPeriodFrom'] ??
          metadata['period_from'] ??
          metadata['periodFrom'] ??
          metadata['report_period_from'],
    );
    final periodTo = _safeString(
      json['period_to'] ??
          json['periodTo'] ??
          json['report_period_to'] ??
          json['reportPeriodTo'] ??
          metadata['period_to'] ??
          metadata['periodTo'] ??
          metadata['report_period_to'],
    );

    final documentIds = _parseDocumentIds(json, metadata);

    return Batch(
      id: _safeInt(json['id'], 0),
      userId: _safeInt(json['user_id'] ?? json['userId'], 0),
      hospitalId: _safeInt(json['hospital_id'] ?? json['hospitalId'], 0),
      stockistId: _safeInt(json['stockist_id'] ?? json['stockistId'], 0),
      totalFiles: _safeInt(
        json['total_files'] ?? json['totalFiles'],
        0,
      ),
      successfulFiles: _safeInt(
        json['successful_files'] ?? json['successfulFiles'],
        0,
      ),
      failedFiles: _safeInt(
        json['failed_files'] ?? json['failedFiles'],
        0,
      ),
      cancelledFiles: _safeInt(
        json['cancelled_files'] ?? json['cancelledFiles'],
        0,
      ),
      status: _safeString(json['status']) ?? 'unknown',
      startedAt: _safeString(json['started_at'] ?? json['startedAt']),
      completedAt: _safeString(json['completed_at'] ?? json['completedAt']),
      statementDate: statementDate,
      statementMonth: statementMonth,
      periodFrom: periodFrom,
      periodTo: periodTo,
      steps: _safeMap(json['steps']) ?? {},
      failureReasons: _safeString(
        json['failure_reasons'] ?? json['failureReasons'],
      ),
      metadata: metadata,
      createdAt: _safeString(json['created_at'] ?? json['createdAt']) ?? '',
      updatedAt: _safeString(json['updated_at'] ?? json['updatedAt']) ?? '',
      user: _safeMap(json['user']),
      hospital: hospitalMap,
      stockist: stockistMap,
      hasValidationIssue: hasValidation,
      validationMessage: hasValidation ? validationMsg : null,
      hospitalNameOverride: hospitalFlat,
      stockistNameOverride: stockistFlat,
      documentIds: documentIds,
    );
  }

  /// Collects POD/statement ids from common batch payload shapes.
  static List<int> _parseDocumentIds(
    Map<String, dynamic> json,
    Map<String, dynamic> metadata,
  ) {
    final ids = <int>[];
    void addId(dynamic value) {
      if (value == null) return;
      if (value is int) {
        if (value > 0) ids.add(value);
        return;
      }
      if (value is num) {
        final n = value.toInt();
        if (n > 0) ids.add(n);
        return;
      }
      final parsed = int.tryParse(value.toString());
      if (parsed != null && parsed > 0) ids.add(parsed);
    }

    void collect(dynamic raw) {
      if (raw == null) return;
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            addId(
              item['id'] ??
                  item['document_id'] ??
                  item['documentId'] ??
                  item['pod_id'] ??
                  item['podId'],
            );
          } else {
            addId(item);
          }
        }
        return;
      }
      if (raw is Map) {
        addId(
          raw['id'] ??
              raw['document_id'] ??
              raw['documentId'] ??
              raw['pod_id'] ??
              raw['podId'],
        );
        return;
      }
      addId(raw);
    }

    for (final key in [
      'document_ids',
      'documentIds',
      'documents',
      'pods',
      'pod_ids',
      'podIds',
      'document_id',
      'documentId',
      'pod_id',
      'podId',
    ]) {
      collect(json[key]);
      collect(metadata[key]);
    }
    return ids.toSet().toList();
  }

  String get hospitalName {
    final resolved = resolvedHospitalName;
    return resolved ?? '—';
  }

  String get stockistName {
    final resolved = resolvedStockistName;
    return resolved ?? '—';
  }

  /// Non-placeholder hospital/company name from API, or null.
  String? get resolvedHospitalName {
    final name = hospital?['name'] ??
        hospital?['hospital_name'] ??
        hospital?['company_name'];
    final fromMap = _cleanName(name);
    if (fromMap != null) return fromMap;
    return _cleanName(hospitalNameOverride);
  }

  /// Non-placeholder stockist name from API, or null.
  String? get resolvedStockistName {
    final name = stockist?['name'] ?? stockist?['stockist_name'];
    final fromMap = _cleanName(name);
    if (fromMap != null) return fromMap;
    return _cleanName(stockistNameOverride);
  }

  static String? _cleanName(dynamic name) {
    if (name == null) return null;
    String text;
    if (name is String) {
      text = name.trim();
    } else if (name is List && name.isNotEmpty) {
      text = name.first.toString().trim();
    } else {
      text = name.toString().trim();
    }
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('unknown')) return null;
    return text;
  }

  String get userName {
    final name = user?['name'];
    if (name == null) return '—';
    if (name is String) {
      final t = name.trim();
      return t.isEmpty ? '—' : t;
    }
    if (name is List && name.isNotEmpty) return name.first.toString();
    return name.toString();
  }

  String get displayStatus {
    switch (normalizedStatus) {
      case 'completed':
      case 'success':
        return 'COMPLETED';
      case 'failed':
      case 'error':
        return 'FAILED';
      case 'cancelled':
        return 'CANCELLED';
      case 'processing':
      case 'in_progress':
      case 'pending':
      case 'queued':
      case 'uploading':
      case 'extracting':
        return 'PROCESSING';
      default:
        if (status.isEmpty) return 'UNKNOWN';
        return status.toUpperCase();
    }
  }

  /// First POD/statement id for Statement Details (products, opening/closing).
  int? get primaryDocumentId =>
      documentIds.isNotEmpty ? documentIds.first : null;

  /// True when Statement Details (products / analytics) can be opened.
  bool get canOpenStatementDetails => primaryDocumentId != null;

  /// YYYY-MM style month for display, derived from statement_month or date.
  String? get displayStatementMonth {
    final raw = statementMonth?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (RegExp(r'^\d{4}-\d{2}$').hasMatch(raw)) {
        final parts = raw.split('-');
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null) {
          const names = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          if (month >= 1 && month <= 12) return '${names[month - 1]} $year';
        }
      }
      return raw;
    }
    final date = effectiveStatementDate;
    if (date == null) return null;
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  bool get showsValidationIssue {
    if (hasValidationIssue) return true;
    final msg = validationMessage?.trim();
    return msg != null && msg.isNotEmpty;
  }

  String get normalizedStatus => status.toLowerCase().trim();

  bool get isProcessingStatus {
    switch (normalizedStatus) {
      case 'processing':
      case 'in_progress':
      case 'pending':
      case 'queued':
      case 'uploading':
      case 'extracting':
        return true;
      default:
        return false;
    }
  }

  bool get isCompletedStatus =>
      normalizedStatus == 'completed' || normalizedStatus == 'success';

  /// Change Date is only for already-extracted completed batches.
  bool get canChangeStatementDate =>
      isCompletedStatus && !isProcessingStatus;

  /// Parsed statement/business date for pickers (date-only, local).
  DateTime? get parsedStatementDate {
    final raw = statementDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = DateTime.parse(raw);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  /// Prefer statement date, then completed/started/created as display fallback.
  DateTime? get effectiveStatementDate =>
      parsedStatementDate ??
      _parseDateOnly(completedAt) ??
      _parseDateOnly(startedAt) ??
      _parseDateOnly(createdAt);

  static DateTime? _parseDateOnly(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final parsed = DateTime.parse(raw);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }
}

class BatchListResponse {
  final int currentPage;
  final List<Batch> data;
  final int? lastPage;
  final int total;
  final int perPage;
  final String? nextPageUrl;
  final String? prevPageUrl;

  BatchListResponse({
    required this.currentPage,
    required this.data,
    this.lastPage,
    required this.total,
    required this.perPage,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory BatchListResponse.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to String
    String? _safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      return value.toString();
    }

    // Helper to safely convert to int
    int _safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper to safely convert to nullable int
    int? _safeIntNullable(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    final List<dynamic> dataList = json['data'] is List ? json['data'] as List<dynamic> : [];
    return BatchListResponse(
      currentPage: _safeInt(json['current_page'], 1),
      data: dataList
          .map((e) {
            try {
              if (e == null) return null;
              Map<String, dynamic>? batchMap;
              if (e is Map<String, dynamic>) {
                batchMap = e;
              } else if (e is Map) {
                try {
                  batchMap = Map<String, dynamic>.from(e);
                } catch (_) {
                  return null;
                }
              } else {
                return null;
              }
              return Batch.fromJson(batchMap);
            } catch (err) {
              print('Error parsing batch item: $err');
              return null;
            }
          })
          .whereType<Batch>()
          .toList(),
      lastPage: _safeIntNullable(json['last_page']),
      total: _safeInt(json['total'], 0),
      perPage: _safeInt(json['per_page'], 25),
      nextPageUrl: _safeString(json['next_page_url']),
      prevPageUrl: _safeString(json['prev_page_url']),
    );
  }
}

