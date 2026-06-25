import 'dart:convert';

class VisitReport {
  final String? id;   // Nullable for new reports not yet saved to DB
  final String doctorId;
  final String doctorName;
  final String doctorSpeciality;
  final DateTime visitTime;
  final String remarks;
  final List<String> workedWith;           // IDs only — used for internal checks (selection restore)
  final List<Map<String, dynamic>> workedWithNames; // [ADDED] id+name maps — sent in payload
  final List<ProductEntry> products;
  final int businessValuePts;
  final bool isSubmitted;

  // New fields for history API response (they come as JSON strings)
  final List<dynamic> rawJointWork;
  final List<dynamic> rawBrandDetails;
  final List<dynamic> rawSamples;
  final List<dynamic> rawPrescribedRx;
  final List<dynamic> rawNewBrandRxbed;

  VisitReport({
    this.id,
    required this.doctorId,
    required this.doctorName,
    this.doctorSpeciality = '',
    required this.visitTime,
    required this.remarks,
    this.workedWith     = const [],
    this.workedWithNames = const [],       // [ADDED] defaults empty so old callers still compile
    this.products       = const [],
    this.businessValuePts = 0,
    this.isSubmitted    = false,
    this.rawJointWork = const [],
    this.rawBrandDetails = const [],
    this.rawSamples = const [],
    this.rawPrescribedRx = const [],
    this.rawNewBrandRxbed = const [],
  });

  // Factory: From JSON (API Response)
  factory VisitReport.fromJson(Map<String, dynamic> json) {
    var productList = <ProductEntry>[];
    if (json['products'] != null) {
      productList = (json['products'] as List)
          .map((i) => ProductEntry.fromJson(i))
          .toList();
    }

    // Handle 'worked_with' being null or a list
    List<String> colleagues = [];
    if (json['worked_with'] != null) {
      colleagues = List<String>.from(json['worked_with']);
    }

    return VisitReport(
      id: json['id']?.toString(),
      // FIX: robustly parse doctor_id to string, handle null safety
      doctorId: json['doctor_id']?.toString() ?? '',
      doctorName: json['doctor_name'] ?? 'Unknown',
      doctorSpeciality: json['speciality']?.toString() ?? '',
      visitTime: DateTime.parse(json['visit_time']),
      remarks: json['remarks'] ?? '',
      workedWith: colleagues,
      products: productList,
      businessValuePts: double.tryParse(json['business_value_pts']?.toString() ?? json['dr_business_value']?.toString() ?? json['business_value']?.toString() ?? '0')?.toInt() ?? 0,
      // Handle boolean sent as 1/0 or true/false
      isSubmitted: json['is_submitted'] == 1 || json['is_submitted'] == true,
      rawJointWork: _parseJsonStringList(json['joint_work']),
      rawBrandDetails: _parseJsonStringList(json['brand_details']),
      rawSamples: _parseJsonStringList(json['samples']),
      rawPrescribedRx: _parseJsonStringList(json['prescribed_rx']),
      rawNewBrandRxbed: _parseJsonStringList(json['new_brand_rxbed']),
    );
  }

  // Helper to safely parse stringified JSON arrays
  static List<dynamic> _parseJsonStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      if (value.trim().isEmpty) return [];
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (e) {
        // Fallback for parsing errors
      }
    }
    return [];
  }

  // To JSON (For API Request) — structured payload sent to POST /api/app/visits
  Map<String, dynamic> toJson() {
    // --- 1. Split visitTime into separate date and time strings ---
    final String visitDate =
        '${visitTime.year.toString().padLeft(4, '0')}-'
        '${visitTime.month.toString().padLeft(2, '0')}-'
        '${visitTime.day.toString().padLeft(2, '0')}';

    final String visitTimeStr =
        '${visitTime.hour.toString().padLeft(2, '0')}:'
        '${visitTime.minute.toString().padLeft(2, '0')}:00';

    // --- 2. created_at timestamp in "YYYY-MM-DD HH:mm:ss" format ---
    final now = DateTime.now();
    final String createdAt =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    // --- 3. products array: only brand_id + name (no toggle/qty fields here) ---
    final productsList = products
        .map((e) => {'brand_id': e.brandId, 'brand_name': e.productName})
        .toList();

    // --- 4. is_brands_added_after_last_visit: separate array for products where toggle = Yes (1) ---
    final brandsAddedList = products
        .where((e) => e.pobQty == 1)
        .map((e) => {'brand_id': e.brandId, 'name': e.productName})
        .toList();

    // --- 5. sample: separate array for products where SPL qty > 0, includes sample_qty ---
    final sampleList = products
        .where((e) => e.sampleQty > 0)
        .map((e) => {
              'id':   e.brandId,
              'name':       e.productName,
              'sample_qty': e.sampleQty,
            })
        .toList();

    // --- 6. prescribed_rx: separate array for products where "Brands Rxbed" toggle = Yes (1) ---
    final rxbedList = products
        .where((e) => e.rxQty == 1)
        .map((e) => {'id': e.brandId, 'name': e.productName})
        .toList();

    return {
      'id':           id,
      'doctor_id':    doctorId,
      'doctor_name':  doctorName,
      'speciality':   doctorSpeciality,
      'visit_date':   visitDate,          // e.g. "2026-06-21"
      'visit_time':   visitTimeStr,       // e.g. "14:30:00"
      'remarks':      remarks,
      // [RENAMED] worked_with → joint_work  |  sends [{id, name}] for each selected colleague
      'joint_work':          workedWithNames,
      // [RENAMED] business_value_pts → dr_business_value  |  integer value entered by user
      'dr_business_value':   businessValuePts,
      'created_at':          createdAt,           // e.g. "2026-06-21 14:30:38"
      // [RENAMED] products → brand_details  |  array of {brand_id, name} for every selected product
      'brand_details':       productsList,
      // [RENAMED] is_brands_added_after_last_visit → new_brand_rxbed  |  products where "Brands Added" toggle = Yes
      'new_brand_rxbed':     brandsAddedList,
      // sample stays as-is  |  products where SPL qty > 0, includes sample_qty
      'sample':              sampleList,
      // [RENAMED] is_brands_rxbed → prescribed_rx  |  products where "Brands Rxbed" toggle = Yes
      'prescribed_rx':       rxbedList,
    };
  }
}

// Sub-model for each product entry inside a visit report
class ProductEntry {
  final String productName; // Display name of the product / brand
  final int brandId;        // [ADDED] brand_id from the master product list – sent in payload
  final int pobQty;         // 1 = Yes, 0 = No  (Brands Added After Last Visit toggle)
  final int sampleQty;      // SPL quantity given to the doctor
  final int rxQty;          // 1 = Yes, 0 = No  (Brands Rxbed toggle)

  ProductEntry({
    required this.productName,
    this.brandId = 0,   // [ADDED] defaults to 0 so old code without brandId still compiles
    this.pobQty = 0,
    this.sampleQty = 0,
    this.rxQty = 0,
  });

  factory ProductEntry.fromJson(Map<String, dynamic> json) {
    return ProductEntry(
      productName: json['product_name'] ?? '',
      // [ADDED] parse brand_id coming back from the API response
      brandId: int.tryParse(json['brand_id']?.toString() ?? '0') ?? 0,
      pobQty:     int.tryParse(json['pob_qty']?.toString()    ?? '0') ?? 0,
      sampleQty:  int.tryParse(json['sample_qty']?.toString() ?? '0') ?? 0,
      rxQty:      int.tryParse(json['rx_qty']?.toString()     ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // [ADDED] brand_id identifies which product/brand was discussed
      'brand_id': brandId,
      'name':    productName,
      'is_brands_added_after_last_visit': pobQty,
      'sample':  sampleQty,       // SPL quantity
      'is_brands_rxbed': rxQty,
    };
  }
}
