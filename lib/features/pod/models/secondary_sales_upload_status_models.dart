// Models for Secondary Sales Upload Status Report (hierarchy-aware).

class SecondarySalesUploadStatusSummary {
  const SecondarySalesUploadStatusSummary({
    this.totalCustomer,
    this.dataUploaded,
    this.dataNotUploaded,
    this.dataUploadedPercentage,
    this.dataNotUploadedPercentage,
  });

  final int? totalCustomer;
  final int? dataUploaded;
  final int? dataNotUploaded;
  final double? dataUploadedPercentage;
  final double? dataNotUploadedPercentage;

  factory SecondarySalesUploadStatusSummary.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return const SecondarySalesUploadStatusSummary();
    return SecondarySalesUploadStatusSummary(
      totalCustomer: _asInt(
        json['total_customer'] ?? json['totalCustomer'] ?? json['total'],
      ),
      dataUploaded: _asInt(
        json['data_uploaded'] ?? json['dataUploaded'] ?? json['uploaded'],
      ),
      dataNotUploaded: _asInt(
        json['data_not_uploaded'] ??
            json['dataNotUploaded'] ??
            json['not_uploaded'],
      ),
      dataUploadedPercentage: _asDouble(
        json['data_uploaded_percentage'] ??
            json['dataUploadedPercentage'] ??
            json['uploaded_percentage'],
      ),
      dataNotUploadedPercentage: _asDouble(
        json['data_not_uploaded_percentage'] ??
            json['dataNotUploadedPercentage'] ??
            json['not_uploaded_percentage'],
      ),
    );
  }
}

class SecondarySalesUploadStatusPagination {
  const SecondarySalesUploadStatusPagination({
    this.page = 1,
    this.perPage = 50,
    this.total = 0,
    this.lastPage = 1,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasMore => page < lastPage;

  factory SecondarySalesUploadStatusPagination.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const SecondarySalesUploadStatusPagination();
    }
    return SecondarySalesUploadStatusPagination(
      page: _asInt(json['page'] ?? json['current_page']) ?? 1,
      perPage: _asInt(json['per_page'] ?? json['perPage']) ?? 50,
      total: _asInt(json['total']) ?? 0,
      lastPage: _asInt(json['last_page'] ?? json['lastPage']) ?? 1,
    );
  }
}

class SecondarySalesUploadStatusRow {
  const SecondarySalesUploadStatusRow({
    this.id,
    this.name,
    this.levelLabel,
    this.code,
    this.totalCustomer,
    this.dataUploaded,
    this.dataNotUploaded,
    this.uploadedPercentage,
    this.notUploadedPercentage,
    this.stockistId,
    this.employeeId,
    this.raw,
  });

  final int? id;
  final String? name;
  final String? levelLabel;
  final String? code;
  final int? totalCustomer;
  final int? dataUploaded;
  final int? dataNotUploaded;
  final double? uploadedPercentage;
  final double? notUploadedPercentage;
  final int? stockistId;
  final int? employeeId;
  final Map<String, dynamic>? raw;

  String get displayTitle {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final label = levelLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (id != null) return 'ID $id';
    return '—';
  }

  factory SecondarySalesUploadStatusRow.fromJson(Map<String, dynamic> json) {
    return SecondarySalesUploadStatusRow(
      id: _asInt(
        json['id'] ??
            json['stockist_id'] ??
            json['employee_id'] ??
            json['team_id'] ??
            json['zm_id'] ??
            json['sm_id'] ??
            json['nsm_id'],
      ),
      name: _asString(
        json['name'] ??
            json['stockist_name'] ??
            json['employee_name'] ??
            json['team_name'] ??
            json['zm_name'] ??
            json['sm_name'] ??
            json['nsm_name'] ??
            json['state_name'] ??
            json['division_name'] ??
            json['label'],
      ),
      levelLabel: _asString(
        json['level'] ?? json['level_label'] ?? json['type'],
      ),
      code: _asString(
        json['code'] ?? json['stockist_code'] ?? json['employee_code'],
      ),
      totalCustomer: _asInt(
        json['total_customer'] ?? json['totalCustomer'] ?? json['total'],
      ),
      dataUploaded: _asInt(
        json['data_uploaded'] ?? json['dataUploaded'] ?? json['uploaded'],
      ),
      dataNotUploaded: _asInt(
        json['data_not_uploaded'] ??
            json['dataNotUploaded'] ??
            json['not_uploaded'],
      ),
      uploadedPercentage: _asDouble(
        json['data_uploaded_percentage'] ??
            json['uploaded_percentage'] ??
            json['uploadedPercentage'],
      ),
      notUploadedPercentage: _asDouble(
        json['data_not_uploaded_percentage'] ??
            json['not_uploaded_percentage'] ??
            json['notUploadedPercentage'],
      ),
      stockistId: _asInt(json['stockist_id'] ?? json['stockistId']),
      employeeId: _asInt(json['employee_id'] ?? json['employeeId']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class SecondarySalesUploadStatusResponse {
  const SecondarySalesUploadStatusResponse({
    required this.month,
    required this.level,
    required this.summary,
    required this.rows,
    required this.pagination,
  });

  final String month;
  final String level;
  final SecondarySalesUploadStatusSummary summary;
  final List<SecondarySalesUploadStatusRow> rows;
  final SecondarySalesUploadStatusPagination pagination;

  factory SecondarySalesUploadStatusResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final summaryRaw = data['summary'];
    final paginationRaw = data['pagination'] ?? data['meta'];
    final rowsRaw = data['rows'] ?? data['data'] ?? const [];

    return SecondarySalesUploadStatusResponse(
      month: _asString(data['month']) ?? '',
      level: _asString(data['level']) ?? 'team',
      summary: SecondarySalesUploadStatusSummary.fromJson(
        summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : null,
      ),
      rows: _mapList(rowsRaw, SecondarySalesUploadStatusRow.fromJson),
      pagination: SecondarySalesUploadStatusPagination.fromJson(
        paginationRaw is Map
            ? Map<String, dynamic>.from(paginationRaw)
            : null,
      ),
    );
  }
}

class SecondarySalesUploadStatusFilterOption {
  const SecondarySalesUploadStatusFilterOption({
    required this.id,
    required this.label,
    this.code,
  });

  final int id;
  final String label;
  final String? code;

  factory SecondarySalesUploadStatusFilterOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = _asInt(
          json['id'] ??
              json['value'] ??
              json['code'] ??
              json['employee_id'] ??
              json['stockist_id'],
        ) ??
        0;
    final label = _asString(
          json['name'] ??
              json['label'] ??
              json['title'] ??
              json['employee_name'] ??
              json['stockist_name'] ??
              json['display_name'],
        ) ??
        'Option $id';
    return SecondarySalesUploadStatusFilterOption(
      id: id,
      label: label,
      code: _asString(json['code'] ?? json['employee_code'] ?? json['stockist_code']),
    );
  }

  static List<SecondarySalesUploadStatusFilterOption> listFrom(dynamic raw) {
    Iterable<dynamic> rows;
    if (raw is List) {
      rows = raw;
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final data = map['data'];
      if (data is List) {
        rows = data;
      } else if (data is Map) {
        final nested = Map<String, dynamic>.from(data);
        rows = (nested['items'] ??
                nested['options'] ??
                nested['data'] ??
                nested['filters'] ??
                const []) as Iterable;
      } else {
        rows = (map['items'] ??
            map['options'] ??
            map['filters'] ??
            const []) as Iterable;
      }
    } else {
      return const [];
    }

    final out = <SecondarySalesUploadStatusFilterOption>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final opt = SecondarySalesUploadStatusFilterOption.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (opt.id <= 0) continue;
      out.add(opt);
    }
    return out;
  }
}

class SecondarySalesUploadStatusStockistSummary {
  const SecondarySalesUploadStatusStockistSummary({
    this.stockistId,
    this.stockistName,
    this.month,
    this.openingValue,
    this.receiptValue,
    this.salesValue,
    this.closingValue,
    this.openingQty,
    this.receiptQty,
    this.salesQty,
    this.closingQty,
  });

  final int? stockistId;
  final String? stockistName;
  final String? month;
  final double? openingValue;
  final double? receiptValue;
  final double? salesValue;
  final double? closingValue;
  final double? openingQty;
  final double? receiptQty;
  final double? salesQty;
  final double? closingQty;

  factory SecondarySalesUploadStatusStockistSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final consolidated = data['consolidated'] is Map
        ? Map<String, dynamic>.from(data['consolidated'] as Map)
        : data;

    return SecondarySalesUploadStatusStockistSummary(
      stockistId: _asInt(data['stockist_id'] ?? data['stockistId']),
      stockistName: _asString(
        data['stockist_name'] ??
            data['stockistName'] ??
            data['name'] ??
            (data['stockist'] is Map ? data['stockist']['name'] : null),
      ),
      month: _asString(data['month'] ?? data['statement_month']),
      openingValue: _asDouble(
        consolidated['opening'] ??
            consolidated['opening_value'] ??
            consolidated['openingValue'],
      ),
      receiptValue: _asDouble(
        consolidated['receipt'] ??
            consolidated['purchase'] ??
            consolidated['receipts'] ??
            consolidated['receipt_value'] ??
            consolidated['purchase_value'],
      ),
      salesValue: _asDouble(
        consolidated['sales'] ??
            consolidated['sales_value'] ??
            consolidated['salesValue'],
      ),
      closingValue: _asDouble(
        consolidated['closing'] ??
            consolidated['closing_value'] ??
            consolidated['closingValue'],
      ),
      openingQty: _asDouble(
        consolidated['opening_qty'] ?? consolidated['openingQty'],
      ),
      receiptQty: _asDouble(
        consolidated['receipt_qty'] ??
            consolidated['purchase_qty'] ??
            consolidated['receipts_qty'],
      ),
      salesQty: _asDouble(
        consolidated['sales_qty'] ?? consolidated['salesQty'],
      ),
      closingQty: _asDouble(
        consolidated['closing_qty'] ?? consolidated['closingQty'],
      ),
    );
  }
}

/// Supported report levels for the Upload Status API.
const List<MapEntry<String, String>> kSecondarySalesUploadStatusLevels = [
  MapEntry('zm', 'ZM'),
  MapEntry('sm', 'SM'),
  MapEntry('nsm', 'NSM'),
  MapEntry('state', 'State'),
  MapEntry('team', 'Team'),
  MapEntry('employee', 'Employee'),
  MapEntry('customer', 'Stockist'),
];

List<T> _mapList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) mapper,
) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is Map) out.add(mapper(Map<String, dynamic>.from(item)));
  }
  return out;
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
