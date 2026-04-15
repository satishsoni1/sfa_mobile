class ChemistProductEntry {
  final String productName;
  final int saleQty;
  final int freeQty;
  final int pobQty;
  final int valuePob;
  final String suppliedThrough;

  ChemistProductEntry({
    required this.productName,
    this.saleQty = 0,
    this.freeQty = 0,
    required this.pobQty,
    this.valuePob = 0,
    this.suppliedThrough = '',
  });

  factory ChemistProductEntry.fromJson(Map<String, dynamic> json) {
    final int parsedSale =
        json['sale'] is int
            ? json['sale']
            : int.tryParse(json['sale']?.toString() ?? '0') ?? 0;
    final int parsedFree =
        json['free'] is int
            ? json['free']
            : int.tryParse(json['free']?.toString() ?? '0') ?? 0;
    final int parsedPob =
        json['pob'] is int
            ? json['pob']
            : int.tryParse(json['pob']?.toString() ?? '0') ?? 0;

    // Keep old payloads working: if sale/free are absent, fallback to legacy pob.
    final int finalSale = (parsedSale == 0 && parsedFree == 0) ? parsedPob : parsedSale;
    final int finalFree = (parsedSale == 0 && parsedFree == 0) ? 0 : parsedFree;

    return ChemistProductEntry(
      productName: json['name'] ?? '',
      saleQty: finalSale,
      freeQty: finalFree,
      pobQty: finalSale + finalFree,
      valuePob: json['value_pob'] is num
          ? (json['value_pob'] as num).toInt()
          : int.tryParse(json['value_pob']?.toString() ?? '0') ?? 0,
      suppliedThrough:
          (json['supplied_through'] ?? json['suppliedThrough'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': productName,
    'sale': saleQty,
    'free': freeQty,
    'pob': saleQty + freeQty,
    'value_pob': valuePob,
    'supplied_through': suppliedThrough,
  };
}

class ChemistReport {
  final String id;
  final String chemistId;
  final String chemistName;
  final DateTime visitTime;
  final String remarks;
  final List<ChemistProductEntry> products;
  final List<String> workedWith;
  final bool isSubmitted;

  ChemistReport({
    required this.id,
    required this.chemistId,
    required this.chemistName,
    required this.visitTime,
    required this.remarks,
    required this.products,
    required this.workedWith,
    this.isSubmitted = false,
  });

  factory ChemistReport.fromJson(Map<String, dynamic> json) {
    var prodList = json['products'] as List? ?? [];
    var colleaguesList = json['worked_with'] as List? ?? [];

    return ChemistReport(
      id: json['id']?.toString() ?? "",
      chemistId: json['chemist_id']?.toString() ?? "",
      chemistName: json['chemist_name'] ?? "",
      visitTime: json['visit_time'] != null
          ? DateTime.parse(json['visit_time'])
          : DateTime.now(),
      remarks: json['remarks'] ?? "",
      products: prodList.map((p) => ChemistProductEntry.fromJson(p)).toList(),
      workedWith: colleaguesList.map((c) => c.toString()).toList(),
      isSubmitted: json['is_submitted'] == 1 || json['is_submitted'] == true,
    );
  }
}
