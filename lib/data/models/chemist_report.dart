class ChemistProductEntry {
  final String productName;
  final int pobQty;

  ChemistProductEntry({required this.productName, required this.pobQty});

  factory ChemistProductEntry.fromJson(Map<String, dynamic> json) {
    return ChemistProductEntry(
      productName: json['name'] ?? '',
      pobQty: json['pob'] is int
          ? json['pob']
          : int.tryParse(json['pob'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'name': productName, 'pob': pobQty};
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
