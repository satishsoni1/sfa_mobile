/// Models for the Chemist Selection (Field Operations) feature.
/// These are completely separate from the DCR-flow [Chemist] model.
library;

class ChemistCategory {
  final String key;
  final String name;
  final int frequency;
  final String description;
  final String badgeColor;
  final bool isMandatory;

  ChemistCategory({
    required this.key,
    required this.name,
    required this.frequency,
    required this.description,
    required this.badgeColor,
    required this.isMandatory,
  });

  factory ChemistCategory.fromJson(Map<String, dynamic> json) {
    return ChemistCategory(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      frequency: json['frequency'] is int
          ? json['frequency'] as int
          : int.tryParse(json['frequency']?.toString() ?? '1') ?? 1,
      description: json['description']?.toString() ?? '',
      badgeColor: json['badge_color']?.toString() ?? 'secondary',
      isMandatory: json['is_mandatory'] == true || json['is_mandatory'] == 1,
    );
  }
}

class ChemistSelectionRules {
  final int minCombineCount;
  final String condition;
  final int saturdayMinChemists;
  final String saturdayRule;

  ChemistSelectionRules({
    required this.minCombineCount,
    required this.condition,
    required this.saturdayMinChemists,
    required this.saturdayRule,
  });

  factory ChemistSelectionRules.fromJson(Map<String, dynamic> json) {
    return ChemistSelectionRules(
      minCombineCount: _i(json['min_combine_count'], 50),
      condition: json['condition']?.toString() ?? '',
      saturdayMinChemists: _i(json['saturday_attendance_min_chemists'], 5),
      saturdayRule: json['saturday_rule']?.toString() ?? '',
    );
  }

  static int _i(dynamic v, int fallback) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

/// A single chemist record from the master list API.
class ChemistItem {
  final String uid;
  final String source;
  final int chemistId;
  final String name;
  final String? contactPerson;
  final String? mobile;
  final String? address;
  final String? pincode;

  /// "normal" or "4-visit"
  final String category;
  final int frequency;
  final String? action;
  final bool isSelected;
  final bool isExisting;

  ChemistItem({
    required this.uid,
    required this.source,
    required this.chemistId,
    required this.name,
    this.contactPerson,
    this.mobile,
    this.address,
    this.pincode,
    required this.category,
    required this.frequency,
    this.action,
    required this.isSelected,
    required this.isExisting,
  });

  ChemistItem copyWith({
    String? uid,
    String? source,
    int? chemistId,
    String? name,
    String? contactPerson,
    String? mobile,
    String? address,
    String? pincode,
    String? category,
    int? frequency,
    String? action,
    bool? isSelected,
    bool? isExisting,
  }) {
    return ChemistItem(
      uid: uid ?? this.uid,
      source: source ?? this.source,
      chemistId: chemistId ?? this.chemistId,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      action: action ?? this.action,
      isSelected: isSelected ?? this.isSelected,
      isExisting: isExisting ?? this.isExisting,
    );
  }

  factory ChemistItem.fromJson(Map<String, dynamic> json) {
    return ChemistItem(
      uid: json['uid']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      chemistId: json['chemist_id'] is int
          ? json['chemist_id'] as int
          : int.tryParse(json['chemist_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Unknown Chemist',
      contactPerson: json['contact_person']?.toString(),
      mobile: json['mobile']?.toString(),
      address: json['address']?.toString(),
      pincode: json['pincode']?.toString(),
      category: json['category']?.toString() ?? 'normal',
      frequency: json['frequency'] is int
          ? json['frequency'] as int
          : int.tryParse(json['frequency']?.toString() ?? '1') ?? 1,
      action: json['action']?.toString(),
      isSelected: json['is_selected'] == true || json['is_selected'] == 1,
      isExisting: json['is_existing'] == true || json['is_existing'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'source': source,
    'chemist_id': chemistId,
    'name': name,
    'contact_person': contactPerson,
    'mobile': mobile,
    'address': address,
    'pincode': pincode,
    'category': category,
    'frequency': frequency,
    'action': action,
    'is_selected': isSelected,
    'is_existing': isExisting,
  };
}

/// Summary block returned inside the master API response.
class ChemistMasterSummary {
  final int existingSfaCount;
  final int clientCount;
  final int combineCount;
  final int fourVisitCount;
  final int normalCount;
  final bool isValidCombineCount;
  final int requiredMinCount;

  /// Raw status from the backend:
  /// "not_initiated" | "pending" | "approved" | "rejected"
  final String approvalStatus;
  final int? requestId;
  final String? submittedAt;
  final String? rejectionReason;

  ChemistMasterSummary({
    required this.existingSfaCount,
    required this.clientCount,
    required this.combineCount,
    required this.fourVisitCount,
    required this.normalCount,
    required this.isValidCombineCount,
    required this.requiredMinCount,
    required this.approvalStatus,
    this.requestId,
    this.submittedAt,
    this.rejectionReason,
  });

  factory ChemistMasterSummary.fromJson(Map<String, dynamic> json) {
    return ChemistMasterSummary(
      existingSfaCount: _i(json['existing_sfa_count']),
      clientCount: _i(json['client_zoriva_count']),
      combineCount: _i(json['combine_count']),
      fourVisitCount: _i(json['four_visit_count']),
      normalCount: _i(json['normal_count']),
      isValidCombineCount:
          json['is_valid_combine_count'] == true ||
          json['is_valid_combine_count'] == 1,
      requiredMinCount: _i(json['required_min_count']),
      approvalStatus: json['approval_status']?.toString() ?? 'not_initiated',
      requestId: json['request_id'] is int
          ? json['request_id'] as int
          : int.tryParse(json['request_id']?.toString() ?? ''),
      submittedAt: json['submitted_at']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
    );
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  /// Maps backend status to a UI-friendly status string.
  /// Returns null when the list has not been submitted yet.
  String? get uiStatus {
    switch (approvalStatus) {
      case 'pending':
        return 'pending';
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      default:
        // "not_initiated" and any other unknown state → no submission yet
        return null;
    }
  }
}
