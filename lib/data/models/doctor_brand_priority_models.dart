class BrandPriorityBrand {
  final String brandCluster;
  final String brandName;
  final int? gstBrandProductId;
  final List<String> preferredSpecialities;
  final String? composition;
  final List<String> skus;

  BrandPriorityBrand({
    required this.brandCluster,
    required this.brandName,
    this.gstBrandProductId,
    this.preferredSpecialities = const [],
    this.composition,
    this.skus = const [],
  });

  factory BrandPriorityBrand.fromJson(Map<String, dynamic> json) {
    return BrandPriorityBrand(
      brandCluster: (json['brand_cluster'] ?? json['brand_name'] ?? '').toString(),
      brandName: (json['brand_name'] ?? json['brand_cluster'] ?? '').toString(),
      gstBrandProductId: json['gst_brand_product_id'] as int?,
      preferredSpecialities: (json['preferred_specialities'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      composition: json['composition']?.toString(),
      skus: (json['skus'] as List? ?? []).map((e) => e.toString()).toList(),
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
      priorityRank: json['priority_rank'] as int? ?? 1,
      brandCluster: (json['brand_cluster'] ?? '').toString(),
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

  bool get isPrioritized => priorities.isNotEmpty;
  bool get isApproved => approvalStatus?.toLowerCase() == 'approved';
  bool get isPending => approvalStatus?.toLowerCase() == 'pending';
  bool get isRejected => approvalStatus?.toLowerCase() == 'rejected';

  factory MclDoctorPriority.fromJson(Map<String, dynamic> json) {
    final rawPriorities = (json['priorities'] as List? ?? []);
    final parsedPriorities = <DoctorPriorityItem>[];
    for (int i = 0; i < rawPriorities.length; i++) {
      final p = rawPriorities[i];
      if (p is Map<String, dynamic>) {
        parsedPriorities.add(DoctorPriorityItem.fromJson(p));
      } else if (p is String) {
        parsedPriorities.add(DoctorPriorityItem(
          priorityRank: i + 1,
          brandCluster: p,
        ));
      }
    }

    return MclDoctorPriority(
      doctorId: json['doctor_id'] as int? ?? 0,
      doctorName: (json['doctor_name'] ?? '').toString(),
      speciality: (json['speciality'] ?? '').toString(),
      qualification: json['qualification']?.toString(),
      visitCategory: json['visit_category']?.toString(),
      routeName: json['route_name']?.toString(),
      mobile: json['mobile']?.toString(),
      pathfinderBrandCount: json['pathfinder_brand_count'] as int? ?? 0,
      pathfinderBrands: (json['pathfinder_brands'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      priorities: parsedPriorities,
      priorityCount: json['priority_count'] as int? ?? parsedPriorities.length,
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
      totalMclDoctors: json['total_mcl_doctors'] as int? ?? 0,
      prioritizedDoctors: json['prioritized_doctors'] as int? ?? 0,
      pendingDoctors: json['pending_doctors'] as int? ?? 0,
      approvedDoctors: json['approved_doctors'] as int? ?? 0,
      rejectedDoctors: json['rejected_doctors'] as int? ?? 0,
      draftDoctors: json['draft_doctors'] as int? ?? 0,
      unmappedDoctors: json['unmapped_doctors'] as int? ?? 0,
      minRequiredBrands: json['min_required_brands'] as int? ?? 8,
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
      employeeId: json['employee_id'] as int? ?? 0,
      employeeName: (json['employee_name'] ?? '').toString(),
      positionCode: (json['position_code'] ?? '').toString(),
      headQtr: (json['head_qtr'] ?? '').toString(),
      division: (json['division'] ?? '').toString(),
    );
  }
}
