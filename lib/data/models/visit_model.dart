class VisitReport {
  final String id;
  final String doctorName;
  final String doctorArea;
  final DateTime visitTime;
  final String remarks;
  final Map<String, int> productPob; // Product Name : Quantity

  VisitReport({
    required this.id,
    required this.doctorName,
    required this.doctorArea,
    required this.visitTime,
    required this.remarks,
    required this.productPob,
  });
}