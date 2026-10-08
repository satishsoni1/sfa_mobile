class SecondarySalesMultiPageUploadPage {
  final int pageNumber;
  final String filename;
  final String status;

  const SecondarySalesMultiPageUploadPage({
    required this.pageNumber,
    required this.filename,
    required this.status,
  });

  factory SecondarySalesMultiPageUploadPage.fromJson(Map<String, dynamic> json) {
    return SecondarySalesMultiPageUploadPage(
      pageNumber: _asInt(json['page_number'] ?? json['pageNumber']) ?? 0,
      filename: (json['filename'] ?? json['file_name'] ?? json['name'] ?? '')
          .toString(),
      status: (json['status'] ?? 'processing').toString(),
    );
  }
}

class SecondarySalesMultiPageUploadResponse {
  final bool success;
  final String message;
  final String? instruction;
  final int? batchId;
  final int? stockistId;
  final String? month;
  final int totalPages;
  final String status;
  final String? clientUploadId;
  final List<SecondarySalesMultiPageUploadPage> pages;

  const SecondarySalesMultiPageUploadResponse({
    required this.success,
    required this.message,
    this.instruction,
    this.batchId,
    this.stockistId,
    this.month,
    required this.totalPages,
    required this.status,
    this.clientUploadId,
    this.pages = const [],
  });

  factory SecondarySalesMultiPageUploadResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final pagesRaw = data['pages'] ?? json['pages'];
    final pages = <SecondarySalesMultiPageUploadPage>[];
    if (pagesRaw is List) {
      for (final item in pagesRaw) {
        if (item is Map) {
          pages.add(
            SecondarySalesMultiPageUploadPage.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final totalPages = _asInt(data['total_pages'] ?? data['totalPages']) ??
        (pages.isNotEmpty ? pages.length : 0);

    return SecondarySalesMultiPageUploadResponse(
      success: data['success'] == true ||
          json['success'] == true ||
          data['batch_id'] != null ||
          data['batchId'] != null,
      message: (data['message'] ?? json['message'] ?? '').toString(),
      instruction: (data['instruction'] ?? json['instruction'])?.toString(),
      batchId: _asInt(data['batch_id'] ?? data['batchId'] ?? data['id']),
      stockistId: _asInt(data['stockist_id'] ?? data['stockistId']),
      month: (data['month'] ?? data['statement_month'])?.toString(),
      totalPages: totalPages,
      status: (data['status'] ?? json['status'] ?? 'processing').toString(),
      clientUploadId:
          (data['client_upload_id'] ?? data['clientUploadId'])?.toString(),
      pages: pages,
    );
  }
}

class BatchPageStatus {
  final int pageNumber;
  final String? filename;
  final String status;

  const BatchPageStatus({
    required this.pageNumber,
    this.filename,
    required this.status,
  });

  factory BatchPageStatus.fromJson(Map<String, dynamic> json) {
    return BatchPageStatus(
      pageNumber: _asInt(json['page_number'] ?? json['pageNumber']) ?? 0,
      filename: (json['filename'] ?? json['file_name'] ?? json['name'])
          ?.toString(),
      status: (json['status'] ?? 'processing').toString(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
