class SecondarySalesDashboardData {
  final SecondarySalesFilters filters;
  final SecondarySalesOverview overview;
  final SecondarySalesSummary summary;
  final List<SecondarySalesZoneRow> zones;
  final SecondarySalesBreakdown breakdown;
  final List<RecentSecondarySalesDocument> recentDocuments;
  final List<SecondarySalesEmployeePerformance> managerPerformance;
  final List<SecondarySalesEmployeePerformance> kamPerformance;
  final List<SecondarySalesStockistPerformance> stockistPerformance;

  const SecondarySalesDashboardData({
    required this.filters,
    required this.overview,
    required this.summary,
    required this.zones,
    required this.breakdown,
    required this.recentDocuments,
    this.managerPerformance = const [],
    this.kamPerformance = const [],
    this.stockistPerformance = const [],
  });

  List<SecondarySalesStockistPerformance> get visibleStockists {
    if (stockistPerformance.isNotEmpty) return stockistPerformance;
    return [
      for (final row in breakdown.stockist)
        SecondarySalesStockistPerformance(
          stockistId: row.id,
          stockistName: row.name,
          sales: row.sales,
          documents: row.processed,
        ),
    ];
  }

  bool get hasNoRecords {
    final noLists = managerPerformance.isEmpty &&
        kamPerformance.isEmpty &&
        visibleStockists.isEmpty &&
        recentDocuments.isEmpty;
    final noOverview = overview.totalSales == 0 &&
        overview.statementCount == 0;
    return noLists && noOverview;
  }

  factory SecondarySalesDashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return SecondarySalesDashboardData(
      filters: SecondarySalesFilters.fromJson(
        data['filters'] is Map
            ? Map<String, dynamic>.from(data['filters'] as Map)
            : const {},
      ),
      overview: SecondarySalesOverview.fromJson(
        data['overview'] is Map
            ? Map<String, dynamic>.from(data['overview'] as Map)
            : const {},
      ),
      summary: SecondarySalesSummary.fromJson(
        data['summary'] is Map
            ? Map<String, dynamic>.from(data['summary'] as Map)
            : const {},
      ),
      zones: SecondarySalesZoneRow.listFrom(data['zone_performance']),
      breakdown: SecondarySalesBreakdown.fromJson(
        data['performance_breakdown'] is Map
            ? Map<String, dynamic>.from(data['performance_breakdown'] as Map)
            : const {},
      ),
      recentDocuments: RecentSecondarySalesDocument.listFrom(
        data['recent_documents'],
      ),
      managerPerformance: SecondarySalesEmployeePerformance.listFrom(
        data['manager_performance'],
      ),
      kamPerformance: SecondarySalesEmployeePerformance.listFrom(
        data['kam_performance'],
      ),
      stockistPerformance: SecondarySalesStockistPerformance.listFrom(
        data['stockist_performance'],
      ),
    );
  }
}

class SecondarySalesHierarchyFilter {
  final int? viewerId;
  final bool unrestricted;

  const SecondarySalesHierarchyFilter({
    this.viewerId,
    this.unrestricted = false,
  });

  factory SecondarySalesHierarchyFilter.fromJson(Map<String, dynamic> json) {
    return SecondarySalesHierarchyFilter(
      viewerId: _asInt(json['viewer_id']),
      unrestricted: json['unrestricted'] == true,
    );
  }
}

class SecondarySalesFilters {
  final List<SecondarySalesKamOption> availableKams;
  final List<SecondarySalesZoneOption> availableZones;
  final SecondarySalesHierarchyFilter? hierarchy;

  const SecondarySalesFilters({
    this.availableKams = const [],
    this.availableZones = const [],
    this.hierarchy,
  });

  bool get unrestricted => hierarchy?.unrestricted == true;

  factory SecondarySalesFilters.fromJson(Map<String, dynamic> json) {
    final rawHierarchy = json['hierarchy'];
    return SecondarySalesFilters(
      availableKams: SecondarySalesKamOption.listFrom(
        json['available_kams'] ?? json['kams'],
      ),
      availableZones: SecondarySalesZoneOption.listFrom(
        json['available_zones'] ?? json['zones'],
      ),
      hierarchy: rawHierarchy is Map
          ? SecondarySalesHierarchyFilter.fromJson(
              Map<String, dynamic>.from(rawHierarchy),
            )
          : json['unrestricted'] == true
              ? const SecondarySalesHierarchyFilter(unrestricted: true)
              : null,
    );
  }
}

class SecondarySalesKamOption {
  final String? id;
  final String label;
  final bool unassigned;

  const SecondarySalesKamOption({
    this.id,
    required this.label,
    this.unassigned = false,
  });

  factory SecondarySalesKamOption.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['kam_id'] ?? json['emp_id'];
    final name = (json['name'] ?? json['label'] ?? json['kam_name'] ?? 'KAM')
        .toString();
    final unassigned = json['unassigned'] == true ||
        rawId == null ||
        rawId.toString().toLowerCase() == 'unassigned';
    return SecondarySalesKamOption(
      id: rawId?.toString(),
      label: name,
      unassigned: unassigned,
    );
  }

  static List<SecondarySalesKamOption> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SecondarySalesKamOption.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

class SecondarySalesZoneOption {
  final String? id;
  final String label;

  const SecondarySalesZoneOption({this.id, required this.label});

  factory SecondarySalesZoneOption.fromJson(Map<String, dynamic> json) {
    return SecondarySalesZoneOption(
      id: (json['id'] ?? json['zone_id'])?.toString(),
      label: (json['name'] ?? json['label'] ?? json['zone'] ?? 'Zone').toString(),
    );
  }

  static List<SecondarySalesZoneOption> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SecondarySalesZoneOption.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

class SecondarySalesCoverage {
  final int? numerator;
  final int? denominator;
  final double? percentage;
  final String? raw;

  const SecondarySalesCoverage({
    this.numerator,
    this.denominator,
    this.percentage,
    this.raw,
  });

  String get display {
    if (numerator != null && denominator != null) {
      return '$numerator/$denominator';
    }
    if (raw != null && raw!.isNotEmpty) return raw!;
    if (percentage != null) return '${percentage!.toStringAsFixed(1)}%';
    return '—';
  }

  factory SecondarySalesCoverage.from(dynamic value) {
    if (value == null) return const SecondarySalesCoverage();
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      return SecondarySalesCoverage(
        numerator: _asInt(json['numerator'] ?? json['covered'] ?? json['count']),
        denominator: _asInt(json['denominator'] ?? json['total']),
        percentage: _asDouble(
          json['percentage'] ?? json['percent'] ?? json['coverage'],
        ),
        raw: json['label']?.toString(),
      );
    }
    if (value is num) {
      return SecondarySalesCoverage(percentage: value.toDouble());
    }
    return SecondarySalesCoverage(raw: value.toString());
  }
}

class SecondarySalesOverview {
  final double totalSales;
  final int totalDocuments;
  final double productValue;
  final double completionPercentage;
  final int eInvoicesProcessed;
  final SecondarySalesCoverage hospitalCoverage;
  final SecondarySalesCoverage stockistCoverage;
  final int? totalStatements;
  final int? totalBatches;
  final int? multiStatementCount;
  final int? doctorsMapped;
  final int? productsMapped;
  final int? pendingProducts;
  final double? allocatedQty;
  final double? remainingQty;

  const SecondarySalesOverview({
    required this.totalSales,
    required this.totalDocuments,
    required this.productValue,
    required this.completionPercentage,
    required this.eInvoicesProcessed,
    required this.hospitalCoverage,
    required this.stockistCoverage,
    this.totalStatements,
    this.totalBatches,
    this.multiStatementCount,
    this.doctorsMapped,
    this.productsMapped,
    this.pendingProducts,
    this.allocatedQty,
    this.remainingQty,
  });

  bool get isEmpty =>
      totalSales == 0 &&
      totalDocuments == 0 &&
      productValue == 0 &&
      eInvoicesProcessed == 0;

  factory SecondarySalesOverview.fromJson(Map<String, dynamic> json) {
    return SecondarySalesOverview(
      totalSales: _asDouble(json['total_sales']) ?? 0,
      totalDocuments: _asInt(json['total_documents']) ?? 0,
      productValue: _asDouble(json['product_value']) ?? 0,
      completionPercentage: _asDouble(
            json['secondary_sales_completion_percentage'] ??
                json['completion'] ??
                json['completion_percentage'],
          ) ??
          0,
      eInvoicesProcessed: _asInt(
            json['e_invoices_processed'] ?? json['einvoices_processed'],
          ) ??
          0,
      hospitalCoverage: SecondarySalesCoverage.from(json['hospital_coverage']),
      stockistCoverage: SecondarySalesCoverage.from(json['stockist_coverage']),
      totalStatements: _asInt(json['total_statements']),
      totalBatches: _asInt(json['total_batches']),
      multiStatementCount: _asInt(json['multi_statement_count']),
      doctorsMapped: _asInt(json['doctors_mapped']),
      productsMapped: _asInt(json['products_mapped']),
      pendingProducts: _asInt(json['pending_products']),
      allocatedQty: _asDouble(json['allocated_quantity'] ?? json['allocated_qty']),
      remainingQty: _asDouble(json['remaining_quantity'] ?? json['remaining_qty']),
    );
  }

  int get statementCount => totalStatements ?? totalDocuments;
}

class SecondarySalesSummary {
  final int totalDocuments;
  final int secondarySales;
  final int grnDocuments;
  final int eInvoices;
  final int pending;
  final int verified;

  const SecondarySalesSummary({
    required this.totalDocuments,
    required this.secondarySales,
    required this.grnDocuments,
    required this.eInvoices,
    required this.pending,
    required this.verified,
  });

  bool get isEmpty =>
      totalDocuments == 0 &&
      secondarySales == 0 &&
      grnDocuments == 0 &&
      eInvoices == 0 &&
      pending == 0 &&
      verified == 0;

  factory SecondarySalesSummary.fromJson(Map<String, dynamic> json) {
    return SecondarySalesSummary(
      totalDocuments: _asInt(json['total_documents']) ?? 0,
      secondarySales: _asInt(json['secondary_sales']) ?? 0,
      grnDocuments: _asInt(json['grn_documents'] ?? json['grn_count']) ?? 0,
      eInvoices: _asInt(json['e_invoices'] ?? json['einvoice_count']) ?? 0,
      pending: _asInt(json['pending'] ?? json['pending_count']) ?? 0,
      verified: _asInt(json['verified'] ?? json['verified_count']) ?? 0,
    );
  }
}

class SecondarySalesZoneRow {
  final String name;
  final double sales;
  final double percentage;
  final int processed;

  const SecondarySalesZoneRow({
    required this.name,
    required this.sales,
    required this.percentage,
    required this.processed,
  });

  factory SecondarySalesZoneRow.fromJson(Map<String, dynamic> json) {
    return SecondarySalesZoneRow(
      name: (json['name'] ?? json['zone'] ?? json['zone_name'] ?? 'Zone')
          .toString(),
      sales: _asDouble(json['sales'] ?? json['total_sales']) ?? 0,
      percentage: _asDouble(json['percentage'] ?? json['pct'] ?? json['completion']) ??
          0,
      processed: _asInt(json['processed'] ?? json['processed_count']) ?? 0,
    );
  }

  static List<SecondarySalesZoneRow> listFrom(dynamic raw) {
    if (raw is Map) {
      final list = raw['data'] ?? raw['zones'] ?? raw['items'];
      return listFrom(list);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SecondarySalesZoneRow.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

class SecondarySalesBreakdownRow {
  final int? id;
  final String name;
  final String? code;
  final double sales;
  final double percentage;
  final int processed;

  const SecondarySalesBreakdownRow({
    this.id,
    required this.name,
    this.code,
    required this.sales,
    required this.percentage,
    required this.processed,
  });

  factory SecondarySalesBreakdownRow.fromJson(Map<String, dynamic> json) {
    return SecondarySalesBreakdownRow(
      id: _asInt(json['id'] ?? json['stockist_id'] ?? json['entity_id']),
      name: (json['name'] ?? json['label'] ?? json['title'] ?? '—').toString(),
      code: (json['code'] ?? json['emp_id'])?.toString(),
      sales: _asDouble(json['sales'] ?? json['total_sales']) ?? 0,
      percentage: _asDouble(json['percentage'] ?? json['pct'] ?? json['completion']) ??
          0,
      processed: _asInt(json['processed'] ?? json['processed_count']) ?? 0,
    );
  }

  static List<SecondarySalesBreakdownRow> listFrom(dynamic raw) {
    if (raw is Map) {
      return listFrom(raw['data'] ?? raw['items'] ?? raw['rows']);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => SecondarySalesBreakdownRow.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList();
  }
}

class SecondarySalesBreakdown {
  final List<SecondarySalesBreakdownRow> kam;
  final List<SecondarySalesBreakdownRow> hospital;
  final List<SecondarySalesBreakdownRow> stockist;

  const SecondarySalesBreakdown({
    this.kam = const [],
    this.hospital = const [],
    this.stockist = const [],
  });

  factory SecondarySalesBreakdown.fromJson(Map<String, dynamic> json) {
    return SecondarySalesBreakdown(
      kam: SecondarySalesBreakdownRow.listFrom(json['kam'] ?? json['kams']),
      hospital: SecondarySalesBreakdownRow.listFrom(
        json['hospital'] ?? json['hospitals'],
      ),
      stockist: SecondarySalesBreakdownRow.listFrom(
        json['stockist'] ?? json['stockists'],
      ),
    );
  }

  List<SecondarySalesBreakdownRow> forType(String type) {
    switch (type) {
      case 'hospital':
        return hospital;
      case 'stockist':
        return stockist;
      default:
        return kam;
    }
  }
}

class SecondarySalesBreakdownPage {
  final List<SecondarySalesBreakdownRow> rows;
  final int page;
  final bool hasMore;

  const SecondarySalesBreakdownPage({
    required this.rows,
    required this.page,
    required this.hasMore,
  });
}

class RecentSecondarySalesDocument {
  final int? id;
  final String? batchId;
  final String name;
  final String status;
  final String? stockist;
  final String? uploadedAt;
  final String? sales;
  final String? type;

  const RecentSecondarySalesDocument({
    this.id,
    this.batchId,
    required this.name,
    required this.status,
    this.stockist,
    this.uploadedAt,
    this.sales,
    this.type,
  });

  String get normalizedStatus => status.toLowerCase();

  bool get isProcessing =>
      normalizedStatus.contains('process') ||
      normalizedStatus.contains('pending') ||
      normalizedStatus.contains('queued');

  bool get isCompleted =>
      normalizedStatus.contains('complete') ||
      normalizedStatus.contains('success') ||
      normalizedStatus.contains('verified') ||
      normalizedStatus.contains('processed') ||
      normalizedStatus.contains('approved');

  factory RecentSecondarySalesDocument.fromJson(Map<String, dynamic> json) {
    final stockist = json['stockist'];
    String? stockistName;
    if (stockist is Map) {
      stockistName = (stockist['name'] ?? stockist['stockist_name'])?.toString();
    }
    stockistName ??= json['stockist_name']?.toString();

    return RecentSecondarySalesDocument(
      id: _asInt(json['id'] ?? json['document_id'] ?? json['pod_id']),
      batchId: json['batch_id']?.toString(),
      name: (json['name'] ??
              json['file_name'] ??
              json['source_file_name'] ??
              'Untitled document')
          .toString(),
      status: (json['status'] ?? 'unknown').toString(),
      stockist: stockistName,
      uploadedAt: (json['uploaded_at'] ?? json['created_at'])?.toString(),
      sales: (json['total_amount'] ?? json['sales'] ?? json['amount'])
          ?.toString(),
      type: json['type']?.toString(),
    );
  }

  static List<RecentSecondarySalesDocument> listFrom(dynamic raw) {
    if (raw is Map) {
      return listFrom(raw['data'] ?? raw['documents']);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => RecentSecondarySalesDocument.fromJson(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList();
  }
}

class SecondarySalesStockistInfo {
  final int? id;
  final String name;

  const SecondarySalesStockistInfo({this.id, required this.name});

  factory SecondarySalesStockistInfo.fromJson(Map<String, dynamic> json) {
    return SecondarySalesStockistInfo(
      id: _asInt(json['id'] ?? json['stockist_id']),
      name: (json['name'] ?? json['stockist_name'] ?? 'Stockist').toString(),
    );
  }
}

class SecondarySalesStockistStatement {
  final int? id;
  final int? documentId;
  final int? batchId;
  final String? batchCode;
  final String fileName;
  final String status;
  final String? stockistName;
  final double? sales;
  final int? productCount;
  final String? createdAt;
  final String? statementMonth;
  final String? errorMessage;

  const SecondarySalesStockistStatement({
    this.id,
    this.documentId,
    this.batchId,
    this.batchCode,
    required this.fileName,
    required this.status,
    this.stockistName,
    this.sales,
    this.productCount,
    this.createdAt,
    this.statementMonth,
    this.errorMessage,
  });

  String get identity =>
      '${id ?? 'x'}:${documentId ?? 'x'}:${batchId ?? 'x'}';

  String get normalizedStatus => status.toLowerCase().trim();

  bool get isCompleted => normalizedStatus == 'completed';
  bool get isProcessing => normalizedStatus == 'processing';
  bool get isPending => normalizedStatus == 'pending';
  bool get isFailed => normalizedStatus == 'failed';

  String get displayStatus {
    switch (normalizedStatus) {
      case 'completed':
        return 'Completed';
      case 'processing':
        return 'Processing';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  factory SecondarySalesStockistStatement.fromJson(Map<String, dynamic> json) {
    return SecondarySalesStockistStatement(
      id: _asInt(json['id']),
      documentId: _asInt(json['document_id'] ?? json['pod_id']),
      batchId: _asInt(json['batch_id']),
      batchCode: json['batch_code']?.toString(),
      fileName: (json['file_name'] ?? json['name'] ?? 'Untitled statement')
          .toString(),
      status: (json['status'] ?? 'unknown').toString(),
      stockistName: json['stockist_name']?.toString(),
      sales: _asDouble(json['sales']),
      productCount: _asInt(json['product_count']),
      createdAt: json['created_at']?.toString(),
      statementMonth: json['statement_month']?.toString(),
      errorMessage: (json['error'] ??
              json['error_message'] ??
              json['failure_reason'] ??
              json['failure_message'])
          ?.toString(),
    );
  }

  static List<SecondarySalesStockistStatement> listFrom(dynamic raw) {
    if (raw is Map) {
      return listFrom(raw['statements'] ?? raw['data'] ?? raw['items']);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => SecondarySalesStockistStatement.fromJson(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList();
  }
}

class SecondarySalesPagination {
  final int currentPage;
  final int perPage;
  final int? totalPages;
  final int? totalRecords;
  final int? total;
  final int? lastPage;
  final int? nextPage;
  final int? prevPage;

  const SecondarySalesPagination({
    required this.currentPage,
    required this.perPage,
    this.totalPages,
    this.totalRecords,
    this.total,
    this.lastPage,
    this.nextPage,
    this.prevPage,
  });

  int get recordCount => totalRecords ?? total ?? 0;

  bool get hasNextPage =>
      nextPage != null ||
      (lastPage != null && currentPage < lastPage!) ||
      (totalPages != null && currentPage < totalPages!);

  factory SecondarySalesPagination.fromJson(
    Map<String, dynamic> json, {
    int fallbackPage = 1,
    int fallbackPerPage = 20,
  }) {
    return SecondarySalesPagination(
      currentPage: _asInt(json['current_page'] ?? json['page']) ?? fallbackPage,
      perPage: _asInt(json['per_page']) ?? fallbackPerPage,
      totalPages: _asInt(json['total_pages']),
      totalRecords: _asInt(json['total_records'] ?? json['total']),
      total: _asInt(json['total'] ?? json['total_records']),
      lastPage: _asInt(json['last_page'] ?? json['total_pages']),
      nextPage: _asInt(json['next_page']),
      prevPage: _asInt(json['prev_page']),
    );
  }
}

class SecondarySalesStockistStatementsResponse {
  final SecondarySalesStockistInfo stockist;
  final String month;
  final List<SecondarySalesStockistStatement> statements;
  final SecondarySalesPagination pagination;

  const SecondarySalesStockistStatementsResponse({
    required this.stockist,
    required this.month,
    required this.statements,
    required this.pagination,
  });

  factory SecondarySalesStockistStatementsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final stockistRaw = data['stockist'];
    final paginationRaw = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : (data['pagination'] is Map
            ? Map<String, dynamic>.from(data['pagination'] as Map)
            : const <String, dynamic>{});

    return SecondarySalesStockistStatementsResponse(
      stockist: stockistRaw is Map
          ? SecondarySalesStockistInfo.fromJson(
              Map<String, dynamic>.from(stockistRaw),
            )
          : const SecondarySalesStockistInfo(name: 'Stockist'),
      month: (data['month'] ?? '').toString(),
      statements: SecondarySalesStockistStatement.listFrom(data['statements']),
      pagination: SecondarySalesPagination.fromJson(paginationRaw),
    );
  }
}

class SecondarySalesEmployeePerformance {
  final int? employeeId;
  final String employeeName;
  final String? designation;
  final String? positionCode;
  final int? managerId;
  final String? managerName;
  final double? totalSales;
  final int? totalDocuments;
  final int? stockistCount;
  final int? completedStatements;
  final int? teamSize;

  const SecondarySalesEmployeePerformance({
    this.employeeId,
    required this.employeeName,
    this.designation,
    this.positionCode,
    this.managerId,
    this.managerName,
    this.totalSales,
    this.totalDocuments,
    this.stockistCount,
    this.completedStatements,
    this.teamSize,
  });

  factory SecondarySalesEmployeePerformance.fromJson(Map<String, dynamic> json) {
    return SecondarySalesEmployeePerformance(
      employeeId: _asInt(
        json['employee_id'] ?? json['emp_id'] ?? json['id'] ?? json['kam_id'],
      ),
      employeeName: (json['employee_name'] ??
              json['name'] ??
              json['kam_name'] ??
              json['manager_name'] ??
              'Employee')
          .toString(),
      designation: (json['designation'] ?? json['position'] ?? json['role'])
          ?.toString(),
      positionCode: json['position_code']?.toString(),
      managerId: _asInt(json['manager_id']),
      managerName: json['manager_name']?.toString(),
      totalSales: _asDouble(json['total_sales'] ?? json['sales']),
      totalDocuments: _asInt(
        json['total_documents'] ??
            json['total_statements'] ??
            json['documents'] ??
            json['statements'],
      ),
      stockistCount: _asInt(json['stockist_count'] ?? json['stockists']),
      completedStatements: _asInt(json['completed_statements']),
      teamSize: _asInt(json['team_size']),
    );
  }

  static List<SecondarySalesEmployeePerformance> listFrom(dynamic raw) {
    if (raw is Map) {
      return listFrom(raw['data'] ?? raw['items'] ?? raw['rows']);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => SecondarySalesEmployeePerformance.fromJson(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList();
  }
}

class SecondarySalesStockistPerformance {
  final int? stockistId;
  final String stockistName;
  final int? kamId;
  final String? kamName;
  final double? sales;
  final int? documents;
  final int? completedStatements;

  const SecondarySalesStockistPerformance({
    this.stockistId,
    required this.stockistName,
    this.kamId,
    this.kamName,
    this.sales,
    this.documents,
    this.completedStatements,
  });

  factory SecondarySalesStockistPerformance.fromJson(Map<String, dynamic> json) {
    return SecondarySalesStockistPerformance(
      stockistId: _asInt(json['stockist_id'] ?? json['id']),
      stockistName: (json['stockist_name'] ?? json['name'] ?? 'Stockist')
          .toString(),
      kamId: _asInt(json['kam_id'] ?? json['employee_id']),
      kamName: (json['kam_name'] ?? json['employee_name'])?.toString(),
      sales: _asDouble(json['sales'] ?? json['total_sales']),
      documents: _asInt(
        json['documents'] ??
            json['total_documents'] ??
            json['statements'] ??
            json['total_statements'],
      ),
      completedStatements: _asInt(json['completed_statements']),
    );
  }

  String get kamLabel {
    if (kamName != null && kamName!.trim().isNotEmpty) return kamName!;
    return 'Unassigned';
  }

  static List<SecondarySalesStockistPerformance> listFrom(dynamic raw) {
    if (raw is Map) {
      return listFrom(
        raw['stockists'] ?? raw['data'] ?? raw['items'] ?? raw['rows'],
      );
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (m) => SecondarySalesStockistPerformance.fromJson(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList();
  }
}

class SecondarySalesKamStockistsResponse {
  final int? kamId;
  final String? kamName;
  final String month;
  final List<SecondarySalesStockistPerformance> stockists;
  final double? totalSales;

  const SecondarySalesKamStockistsResponse({
    this.kamId,
    this.kamName,
    required this.month,
    required this.stockists,
    this.totalSales,
  });

  factory SecondarySalesKamStockistsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final kamRaw = data['kam'];
    int? kamId;
    String? kamName;
    if (kamRaw is Map) {
      kamId = _asInt(kamRaw['id'] ?? kamRaw['employee_id'] ?? kamRaw['kam_id']);
      kamName = (kamRaw['name'] ?? kamRaw['employee_name'])?.toString();
    }
    kamId ??= _asInt(data['kam_id'] ?? data['employee_id']);
    kamName ??= (data['kam_name'] ?? data['employee_name'])?.toString();

    return SecondarySalesKamStockistsResponse(
      kamId: kamId,
      kamName: kamName,
      month: (data['month'] ?? '').toString(),
      stockists: SecondarySalesStockistPerformance.listFrom(
        data['stockists'] ?? data['items'] ?? data['data'] ?? data['stockist_performance'],
      ),
      totalSales: _asDouble(data['total_sales'] ?? data['sales']),
    );
  }
}

/// Groups API-returned manager/KAM rows using only [manager_id].
/// Does not invent relationships or decide visibility.
class SecondarySalesHierarchyNode {
  final SecondarySalesEmployeePerformance employee;
  final bool isKam;
  final int depth;
  final List<SecondarySalesHierarchyNode> children;

  const SecondarySalesHierarchyNode({
    required this.employee,
    required this.isKam,
    this.depth = 0,
    this.children = const [],
  });

  SecondarySalesHierarchyNode copyWithDepth(int depth) {
    return SecondarySalesHierarchyNode(
      employee: employee,
      isKam: isKam,
      depth: depth,
      children: children,
    );
  }
}

class SecondarySalesHierarchyTree {
  static List<SecondarySalesHierarchyNode> fromApi({
    required List<SecondarySalesEmployeePerformance> managers,
    required List<SecondarySalesEmployeePerformance> kams,
  }) {
    final managerIds = <int>{
      for (final manager in managers)
        if (manager.employeeId != null) manager.employeeId!,
    };
    final childManagers = <int, List<SecondarySalesEmployeePerformance>>{};
    final childKams = <int, List<SecondarySalesEmployeePerformance>>{};
    final roots = <SecondarySalesEmployeePerformance>[];
    final rootKams = <SecondarySalesEmployeePerformance>[];

    for (final manager in managers) {
      final parentId = manager.managerId;
      if (parentId != null &&
          managerIds.contains(parentId) &&
          parentId != manager.employeeId) {
        childManagers.putIfAbsent(parentId, () => []).add(manager);
      } else {
        roots.add(manager);
      }
    }
    for (final kam in kams) {
      final parentId = kam.managerId;
      if (parentId != null && managerIds.contains(parentId)) {
        childKams.putIfAbsent(parentId, () => []).add(kam);
      } else {
        rootKams.add(kam);
      }
    }

    final visiting = <int>{};
    SecondarySalesHierarchyNode buildManager(
      SecondarySalesEmployeePerformance manager,
    ) {
      final id = manager.employeeId;
      if (id != null && !visiting.add(id)) {
        return SecondarySalesHierarchyNode(employee: manager, isKam: false);
      }
      final children = <SecondarySalesHierarchyNode>[
        for (final child in childManagers[id] ?? const []) buildManager(child),
        for (final kam in childKams[id] ?? const [])
          SecondarySalesHierarchyNode(employee: kam, isKam: true),
      ];
      if (id != null) visiting.remove(id);
      return SecondarySalesHierarchyNode(
        employee: manager,
        isKam: false,
        children: children,
      );
    }

    return [
      for (final manager in roots) buildManager(manager),
      for (final kam in rootKams)
        SecondarySalesHierarchyNode(employee: kam, isKam: true),
    ];
  }

  static List<SecondarySalesHierarchyNode> flattenVisible(
    List<SecondarySalesHierarchyNode> roots,
    Set<int> expandedIds,
  ) {
    final visible = <SecondarySalesHierarchyNode>[];
    void walk(SecondarySalesHierarchyNode node, int depth) {
      visible.add(node.copyWithDepth(depth));
      final id = node.employee.employeeId;
      if (!node.isKam && id != null && expandedIds.contains(id)) {
        for (final child in node.children) {
          walk(child, depth + 1);
        }
      }
    }

    for (final root in roots) {
      walk(root, 0);
    }
    return visible;
  }
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
  return double.tryParse(v.toString());
}
