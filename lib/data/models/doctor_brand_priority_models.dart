/// Strips leading prefixes like `dr.`, `DR`, `doctor`, `Dr`, `DOCTOR` from a doctor name.
String stripDoctorPrefix(String raw) {
  return raw
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(
        RegExp(r'^(?:(?:doctor|dr)(?:\.\s*|\s+|$))+', caseSensitive: false),
        '',
      )
      .trim();
}

/// Formats a doctor name with a consistent single `"Dr. "` prefix.
String formatCleanDoctorName(String raw) {
  final clean = stripDoctorPrefix(raw);
  if (clean.isEmpty) return '';
  return 'Dr. $clean';
}

List<String> _parseStringList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw
        .map((e) {
          // pathfinder_brands may be a list of objects: {"brand_cluster": "X", ...}
          if (e is Map) {
            return (e['brand_cluster'] ?? e['brand_name'] ?? '').toString().trim();
          }
          return e.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.contains(',')) {
      return trimmed
          .split(',')
          .map((e) => e.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [trimmed];
  }
  return [raw.toString().trim()];
}

int? _parseInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim());
}

List<int> _parseIntList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw
        .map((e) => _parseInt(e))
        .whereType<int>()
        .toList();
  }
  final parsed = _parseInt(raw);
  return parsed != null ? [parsed] : [];
}

class BrandPriorityBrand {
  final String brandCluster;
  final String brandName;
  final int? gstBrandProductId;
  final int? brandPathfinderId;
  final List<String> preferredSpecialities;
  final String? composition;
  final List<String> skus;
  final List<int> gstBrandProductIds;

  BrandPriorityBrand({
    required this.brandCluster,
    required this.brandName,
    this.gstBrandProductId,
    this.brandPathfinderId,
    this.preferredSpecialities = const [],
    this.composition,
    this.skus = const [],
    this.gstBrandProductIds = const [],
  });

  factory BrandPriorityBrand.fromJson(Map<String, dynamic> json) {
    return BrandPriorityBrand(
      brandCluster: (json['brand_cluster'] ?? json['brand_name'] ?? '').toString(),
      brandName: (json['brand_name'] ?? json['brand_cluster'] ?? '').toString(),
      gstBrandProductId: _parseInt(json['gst_brand_product_id']),
      brandPathfinderId: _parseInt(json['brand_pathfinder_id']),
      preferredSpecialities: _parseStringList(json['preferred_specialities']),
      composition: json['composition']?.toString(),
      skus: _parseStringList(json['skus']),
      gstBrandProductIds: _parseIntList(json['gst_brand_product_ids']),
    );
  }
}

class DoctorPriorityItem {
  int priorityRank;
  String brandCluster;
  String? brandName;

  DoctorPriorityItem({
    required this.priorityRank,
    required this.brandCluster,
    this.brandName,
  });

  factory DoctorPriorityItem.fromJson(Map<String, dynamic> json) {
    return DoctorPriorityItem(
      priorityRank: _parseInt(json['priority_rank']) ?? 1,
      brandCluster: (json['brand_cluster'] ?? json['brand_name'] ?? '').toString(),
      brandName: json['brand_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'priority_rank': priorityRank,
      'brand_cluster': brandCluster,
    };
  }
}

class MclDoctorPriority {
  final int doctorId;
  final String doctorName;
  final String speciality;
  final String? qualification;
  final String? visitCategory;
  final String? routeName;
  final String? mobile;
  final int pathfinderBrandCount;
  final List<String> pathfinderBrands;
  final List<DoctorPriorityItem> priorities;
  final int priorityCount;
  final String? approvalStatus;
  final String? rejectionReason;

  MclDoctorPriority({
    required this.doctorId,
    required this.doctorName,
    required this.speciality,
    this.qualification,
    this.visitCategory,
    this.routeName,
    this.mobile,
    this.pathfinderBrandCount = 0,
    this.pathfinderBrands = const [],
    this.priorities = const [],
    this.priorityCount = 0,
    this.approvalStatus,
    this.rejectionReason,
  });

  String get cleanNameWithoutPrefix => stripDoctorPrefix(doctorName);
  String get formattedDoctorName => formatCleanDoctorName(doctorName);

  bool get isPrioritized => priorities.isNotEmpty;
  bool get isApproved => approvalStatus?.toLowerCase() == 'approved';
  bool get isPending => approvalStatus?.toLowerCase() == 'pending';
  bool get isRejected => approvalStatus?.toLowerCase() == 'rejected';

  factory MclDoctorPriority.fromJson(Map<String, dynamic> json) {
    final rawPriorities = json['priorities'];
    final parsedPriorities = <DoctorPriorityItem>[];
    if (rawPriorities is List) {
      for (int i = 0; i < rawPriorities.length; i++) {
        final p = rawPriorities[i];
        if (p is Map) {
          parsedPriorities.add(DoctorPriorityItem.fromJson(Map<String, dynamic>.from(p)));
        } else if (p is String && p.trim().isNotEmpty) {
          parsedPriorities.add(DoctorPriorityItem(
            priorityRank: i + 1,
            brandCluster: p.trim(),
          ));
        }
      }
    }

    return MclDoctorPriority(
      doctorId: _parseInt(json['doctor_id']) ?? 0,
      doctorName: (json['doctor_name'] ?? '').toString(),
      speciality: (json['speciality'] ?? '').toString(),
      qualification: json['qualification']?.toString(),
      visitCategory: json['visit_category']?.toString(),
      routeName: json['route_name']?.toString(),
      mobile: json['mobile']?.toString(),
      pathfinderBrandCount: _parseInt(json['pathfinder_brand_count']) ?? 0,
      pathfinderBrands: _parseStringList(json['pathfinder_brands']),
      priorities: parsedPriorities,
      priorityCount: _parseInt(json['priority_count']) ?? parsedPriorities.length,
      approvalStatus: json['approval_status']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
    );
  }
}

class PrioritySummary {
  final int totalMclDoctors;
  final int prioritizedDoctors;
  final int pendingDoctors;
  final int approvedDoctors;
  final int rejectedDoctors;
  final int draftDoctors;
  final int unmappedDoctors;
  final int minRequiredBrands;

  PrioritySummary({
    this.totalMclDoctors = 0,
    this.prioritizedDoctors = 0,
    this.pendingDoctors = 0,
    this.approvedDoctors = 0,
    this.rejectedDoctors = 0,
    this.draftDoctors = 0,
    this.unmappedDoctors = 0,
    this.minRequiredBrands = 8,
  });

  factory PrioritySummary.fromJson(Map<String, dynamic> json) {
    return PrioritySummary(
      totalMclDoctors: _parseInt(json['total_mcl_doctors']) ?? 0,
      prioritizedDoctors: _parseInt(json['prioritized_doctors']) ?? 0,
      pendingDoctors: _parseInt(json['pending_doctors']) ?? 0,
      approvedDoctors: _parseInt(json['approved_doctors']) ?? 0,
      rejectedDoctors: _parseInt(json['rejected_doctors']) ?? 0,
      draftDoctors: _parseInt(json['draft_doctors']) ?? 0,
      unmappedDoctors: _parseInt(json['unmapped_doctors']) ?? 0,
      minRequiredBrands: _parseInt(json['min_required_brands']) ?? 8,
    );
  }
}

class PriorityEmployeeInfo {
  final int employeeId;
  final String employeeName;
  final String positionCode;
  final String headQtr;
  final String division;

  PriorityEmployeeInfo({
    this.employeeId = 0,
    this.employeeName = '',
    this.positionCode = '',
    this.headQtr = '',
    this.division = '',
  });

  factory PriorityEmployeeInfo.fromJson(Map<String, dynamic> json) {
    return PriorityEmployeeInfo(
      employeeId: _parseInt(json['employee_id']) ?? 0,
      employeeName: (json['employee_name'] ?? '').toString(),
      positionCode: (json['position_code'] ?? '').toString(),
      headQtr: (json['head_qtr'] ?? '').toString(),
      division: (json['division'] ?? '').toString(),
    );
  }
}
