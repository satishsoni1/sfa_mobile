import 'dart:convert';

// ─── Product (sample/input master) ───────────────────────────────────────────

class DcrProduct {
  final int id;
  final String name;
  final String therapyArea;
  int stockAvailable;
  final int allocationPerDoctor;

  DcrProduct({
    required this.id,
    required this.name,
    this.therapyArea = '',
    this.stockAvailable = 0,
    this.allocationPerDoctor = 2,
  });

  factory DcrProduct.fromDb(Map<String, dynamic> r) => DcrProduct(
        id: r['id'] as int,
        name: r['name'] as String,
        therapyArea: r['therapy_area']?.toString() ?? '',
        stockAvailable: r['stock_available'] as int? ?? 0,
        allocationPerDoctor: r['allocation_per_doctor'] as int? ?? 2,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'name': name,
        'therapy_area': therapyArea,
        'stock_available': stockAvailable,
        'allocation_per_doctor': allocationPerDoctor,
      };
}

// ─── Chemist ──────────────────────────────────────────────────────────────────

class DcrChemist {
  final int? id;
  final String name;
  final String area;
  final String territory;
  final String? address;
  final String? mobile;

  DcrChemist({
    this.id,
    required this.name,
    this.area = '',
    this.territory = '',
    this.address,
    this.mobile,
  });

  factory DcrChemist.fromDb(Map<String, dynamic> r) => DcrChemist(
        id: r['id'] as int?,
        name: r['name'] as String,
        area: r['area']?.toString() ?? '',
        territory: r['territory']?.toString() ?? '',
        address: r['address']?.toString(),
        mobile: r['mobile']?.toString(),
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'name': name,
        'area': area,
        'territory': territory,
        'address': address,
        'mobile': mobile,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Employee ─────────────────────────────────────────────────────────────────

class DcrEmployee {
  final int? id;
  final String name;
  final String employeeCode;
  final String designation;

  DcrEmployee({
    this.id,
    required this.name,
    this.employeeCode = '',
    this.designation = '',
  });

  factory DcrEmployee.fromDb(Map<String, dynamic> r) => DcrEmployee(
        id: r['id'] as int?,
        name: r['name'] as String,
        employeeCode: r['employee_code']?.toString() ?? '',
        designation: r['designation']?.toString() ?? '',
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'name': name,
        'employee_code': employeeCode,
        'designation': designation,
      };
}

// ─── Visit Status ─────────────────────────────────────────────────────────────

enum DcrVisitStatus { draft, submitted }

extension DcrVisitStatusX on DcrVisitStatus {
  String get key => this == DcrVisitStatus.draft ? 'draft' : 'submitted';
  bool get isDraft => this == DcrVisitStatus.draft;

  static DcrVisitStatus fromKey(String k) =>
      k == 'submitted' ? DcrVisitStatus.submitted : DcrVisitStatus.draft;
}

// ─── Doctor DCR Visit ─────────────────────────────────────────────────────────

class DcrDoctorVisit {
  final int? id;
  final String? sessionId;
  final int doctorId;
  final String doctorName;
  final String visitDate;
  final DateTime visitStartTime;
  DateTime? visitEndTime;
  DcrVisitStatus status;
  String? voiceNotePath;
  String? voiceNoteTranscript;
  String? attachedLetterPath;
  double businessValuePts;
  List<int> featuredBrandIds;
  String remarks;
  bool isSynced;
  final DateTime createdAt;

  DcrDoctorVisit({
    this.id,
    this.sessionId,
    required this.doctorId,
    required this.doctorName,
    required this.visitDate,
    required this.visitStartTime,
    this.visitEndTime,
    this.status = DcrVisitStatus.draft,
    this.voiceNotePath,
    this.voiceNoteTranscript,
    this.attachedLetterPath,
    this.businessValuePts = 0,
    this.featuredBrandIds = const [],
    this.remarks = '',
    this.isSynced = false,
    required this.createdAt,
  });

  factory DcrDoctorVisit.fromDb(Map<String, dynamic> r) => DcrDoctorVisit(
        id: r['id'] as int?,
        sessionId: r['session_id']?.toString(),
        doctorId: r['doctor_id'] as int,
        doctorName: r['doctor_name']?.toString() ?? '',
        visitDate: r['visit_date'] as String,
        visitStartTime: DateTime.parse(r['visit_start_time'] as String),
        visitEndTime: r['visit_end_time'] != null
            ? DateTime.tryParse(r['visit_end_time'] as String)
            : null,
        status: DcrVisitStatusX.fromKey(r['status']?.toString() ?? 'draft'),
        voiceNotePath: r['voice_note_path']?.toString(),
        voiceNoteTranscript: r['voice_note_transcript']?.toString(),
        attachedLetterPath: r['attached_letter_path']?.toString(),
        businessValuePts: (r['business_value_pts'] as num?)?.toDouble() ?? 0,
        featuredBrandIds: r['featured_brands'] != null
            ? List<int>.from(json.decode(r['featured_brands'] as String))
            : [],
        remarks: r['remarks']?.toString() ?? '',
        isSynced: (r['is_synced'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'visit_date': visitDate,
        'visit_start_time': visitStartTime.toIso8601String(),
        'visit_end_time': visitEndTime?.toIso8601String(),
        'status': status.key,
        'voice_note_path': voiceNotePath,
        'voice_note_transcript': voiceNoteTranscript,
        'attached_letter_path': attachedLetterPath,
        'business_value_pts': businessValuePts,
        'featured_brands': json.encode(featuredBrandIds),
        'remarks': remarks,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

// ─── Visit Employee ───────────────────────────────────────────────────────────

class DcrVisitEmployee {
  final int? id;
  final int visitId;
  final int? employeeId;
  final String employeeCode;
  final String employeeName;

  DcrVisitEmployee({
    this.id,
    required this.visitId,
    this.employeeId,
    this.employeeCode = '',
    required this.employeeName,
  });

  factory DcrVisitEmployee.fromDb(Map<String, dynamic> r) => DcrVisitEmployee(
        id: r['id'] as int?,
        visitId: r['visit_id'] as int,
        employeeId: r['employee_id'] as int?,
        employeeCode: r['employee_code']?.toString() ?? '',
        employeeName: r['employee_name']?.toString() ?? '',
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'visit_id': visitId,
        'employee_id': employeeId,
        'employee_code': employeeCode,
        'employee_name': employeeName,
      };
}

// ─── Sample Item ──────────────────────────────────────────────────────────────

class DcrSampleItem {
  final int? id;
  final int visitId;
  final int productId;
  final String productName;
  int quantity;
  final int allocationLimit;
  final int stockAvailable;

  DcrSampleItem({
    this.id,
    required this.visitId,
    required this.productId,
    required this.productName,
    this.quantity = 0,
    required this.allocationLimit,
    required this.stockAvailable,
  });

  factory DcrSampleItem.fromDb(Map<String, dynamic> r) => DcrSampleItem(
        id: r['id'] as int?,
        visitId: r['visit_id'] as int,
        productId: r['product_id'] as int,
        productName: r['product_name']?.toString() ?? '',
        quantity: r['quantity'] as int? ?? 0,
        allocationLimit: r['allocation_limit'] as int? ?? 2,
        stockAvailable: r['stock_available'] as int? ?? 0,
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'visit_id': visitId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'allocation_limit': allocationLimit,
        'stock_available': stockAvailable,
      };

  int get effectiveMax =>
      allocationLimit <= stockAvailable ? allocationLimit : stockAvailable;
}

// ─── Visit Signature ──────────────────────────────────────────────────────────

class DcrVisitSignature {
  final int? id;
  final int visitId;
  final String signaturePath;
  final DateTime capturedAt;

  DcrVisitSignature({
    this.id,
    required this.visitId,
    required this.signaturePath,
    required this.capturedAt,
  });

  factory DcrVisitSignature.fromDb(Map<String, dynamic> r) =>
      DcrVisitSignature(
        id: r['id'] as int?,
        visitId: r['visit_id'] as int,
        signaturePath: r['signature_path'] as String,
        capturedAt: DateTime.parse(r['captured_at'] as String),
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'visit_id': visitId,
        'signature_path': signaturePath,
        'captured_at': capturedAt.toIso8601String(),
      };
}

// ─── Chemist Visit ────────────────────────────────────────────────────────────

class DcrChemistVisit {
  final int? id;
  final int? doctorVisitId;
  final int chemistId;
  final String chemistName;
  final String visitDate;
  final DateTime visitStartTime;
  DateTime? visitEndTime;
  DcrVisitStatus status;
  bool productAvailable;
  int pobUnits;
  String remarks;
  bool isSynced;
  final DateTime createdAt;

  DcrChemistVisit({
    this.id,
    this.doctorVisitId,
    required this.chemistId,
    required this.chemistName,
    required this.visitDate,
    required this.visitStartTime,
    this.visitEndTime,
    this.status = DcrVisitStatus.draft,
    this.productAvailable = false,
    this.pobUnits = 0,
    this.remarks = '',
    this.isSynced = false,
    required this.createdAt,
  });

  factory DcrChemistVisit.fromDb(Map<String, dynamic> r) => DcrChemistVisit(
        id: r['id'] as int?,
        doctorVisitId: r['doctor_visit_id'] as int?,
        chemistId: r['chemist_id'] as int,
        chemistName: r['chemist_name']?.toString() ?? '',
        visitDate: r['visit_date'] as String,
        visitStartTime: DateTime.parse(r['visit_start_time'] as String),
        visitEndTime: r['visit_end_time'] != null
            ? DateTime.tryParse(r['visit_end_time'] as String)
            : null,
        status: DcrVisitStatusX.fromKey(r['status']?.toString() ?? 'draft'),
        productAvailable: (r['product_available'] as int? ?? 0) == 1,
        pobUnits: r['pob_units'] as int? ?? 0,
        remarks: r['remarks']?.toString() ?? '',
        isSynced: (r['is_synced'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'doctor_visit_id': doctorVisitId,
        'chemist_id': chemistId,
        'chemist_name': chemistName,
        'visit_date': visitDate,
        'visit_start_time': visitStartTime.toIso8601String(),
        'visit_end_time': visitEndTime?.toIso8601String(),
        'status': status.key,
        'product_available': productAvailable ? 1 : 0,
        'pob_units': pobUnits,
        'remarks': remarks,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

// ─── Chemist Visit Employee ───────────────────────────────────────────────────

class DcrChemistEmployee {
  final int? id;
  final int chemistVisitId;
  final int? employeeId;
  final String employeeCode;
  final String employeeName;

  DcrChemistEmployee({
    this.id,
    required this.chemistVisitId,
    this.employeeId,
    this.employeeCode = '',
    required this.employeeName,
  });

  factory DcrChemistEmployee.fromDb(Map<String, dynamic> r) =>
      DcrChemistEmployee(
        id: r['id'] as int?,
        chemistVisitId: r['chemist_visit_id'] as int,
        employeeId: r['employee_id'] as int?,
        employeeCode: r['employee_code']?.toString() ?? '',
        employeeName: r['employee_name']?.toString() ?? '',
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'chemist_visit_id': chemistVisitId,
        'employee_id': employeeId,
        'employee_code': employeeCode,
        'employee_name': employeeName,
      };
}

// ─── RCPA Entry ───────────────────────────────────────────────────────────────

class DcrRcpaEntry {
  final int? id;
  final int chemistVisitId;
  final int doctorId;
  final String doctorName;
  final int? brandId;
  final String brandName;
  int rxQtyPerWeek;

  DcrRcpaEntry({
    this.id,
    required this.chemistVisitId,
    required this.doctorId,
    required this.doctorName,
    this.brandId,
    required this.brandName,
    this.rxQtyPerWeek = 0,
  });

  factory DcrRcpaEntry.fromDb(Map<String, dynamic> r) => DcrRcpaEntry(
        id: r['id'] as int?,
        chemistVisitId: r['chemist_visit_id'] as int,
        doctorId: r['doctor_id'] as int,
        doctorName: r['doctor_name']?.toString() ?? '',
        brandId: r['brand_id'] as int?,
        brandName: r['brand_name']?.toString() ?? '',
        rxQtyPerWeek: r['rx_qty_per_week'] as int? ?? 0,
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'chemist_visit_id': chemistVisitId,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'brand_id': brandId,
        'brand_name': brandName,
        'rx_qty_per_week': rxQtyPerWeek,
      };
}

// ─── RCPA Competitor ──────────────────────────────────────────────────────────

class DcrRcpaCompetitor {
  final int? id;
  final int rcpaEntryId;
  String competitorName;
  int salesQty;

  DcrRcpaCompetitor({
    this.id,
    required this.rcpaEntryId,
    required this.competitorName,
    this.salesQty = 0,
  });

  factory DcrRcpaCompetitor.fromDb(Map<String, dynamic> r) =>
      DcrRcpaCompetitor(
        id: r['id'] as int?,
        rcpaEntryId: r['rcpa_entry_id'] as int,
        competitorName: r['competitor_name']?.toString() ?? '',
        salesQty: r['sales_qty'] as int? ?? 0,
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'rcpa_entry_id': rcpaEntryId,
        'competitor_name': competitorName,
        'sales_qty': salesQty,
      };
}

// ─── Day Summary (read-model for dashboard) ───────────────────────────────────

class DcrDaySummary {
  final String date;
  final List<DcrDoctorVisit> doctorVisits;
  final List<DcrChemistVisit> chemistVisits;
  final int totalSamples;

  const DcrDaySummary({
    required this.date,
    this.doctorVisits = const [],
    this.chemistVisits = const [],
    this.totalSamples = 0,
  });

  bool get allSubmitted {
    if (doctorVisits.isEmpty && chemistVisits.isEmpty) return false;
    return doctorVisits.every((v) => !v.status.isDraft) &&
        chemistVisits.every((v) => !v.status.isDraft);
  }

  int get draftCount =>
      doctorVisits.where((v) => v.status.isDraft).length +
      chemistVisits.where((v) => v.status.isDraft).length;
}
