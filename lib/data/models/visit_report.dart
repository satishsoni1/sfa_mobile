class VisitReport {
  final String? id; // Nullable for new reports not yet saved to DB
  final String doctorName;
  final DateTime visitTime;
  final String remarks;
  final List<String> workedWith; // Colleagues: ["Amit (ASM)", "Rahul"]
  final List<ProductEntry> products; // Detailed product list
  final bool isSubmitted;

  VisitReport({
    this.id,
    required this.doctorName,
    required this.visitTime,
    required this.remarks,
    this.workedWith = const [],
    this.products = const [],
    this.isSubmitted = false,
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
      id: json['id'].toString(),
      doctorName: json['doctor_name'] ?? 'Unknown',
      visitTime: DateTime.parse(json['visit_time']),
      remarks: json['remarks'] ?? '',
      workedWith: colleagues,
      products: productList,
      isSubmitted: json['is_submitted'] == 1 || json['is_submitted'] == true,
    );
  }

  // To JSON (For API Request)
  Map<String, dynamic> toJson() {
    return {
      'doctor_name': doctorName,
      'visit_time': visitTime.toIso8601String(),
      'remarks': remarks,
      'worked_with': workedWith,
      'products': products.map((e) => e.toJson()).toList(),
    };
  }
}

// Sub-model for Products
class ProductEntry {
  final String productName;
  final int pobQty;
  final int sampleQty;

  ProductEntry({
    required this.productName,
    this.pobQty = 0,
    this.sampleQty = 0,
  });

  factory ProductEntry.fromJson(Map<String, dynamic> json) {
    return ProductEntry(
      productName: json['product_name'],
      pobQty: json['pob_qty'] ?? 0,
      sampleQty: json['sample_qty'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': productName,
      'pob': pobQty,
      'sample': sampleQty,
    };
  }
}