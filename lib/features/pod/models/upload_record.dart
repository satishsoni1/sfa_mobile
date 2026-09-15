// Persisted upload identity for POD / Secondary Sales.
// Each accepted upload is stored independently (keyed by batch_id).

class UploadRecord {
  final String batchId;
  final int? batchDbId;
  final String uploadType;
  final List<String> fileNames;
  final List<int> documentIds;
  final String status;
  final DateTime createdAt;
  final String? error;
  final int totalFiles;

  const UploadRecord({
    required this.batchId,
    this.batchDbId,
    required this.uploadType,
    required this.fileNames,
    required this.documentIds,
    required this.status,
    required this.createdAt,
    this.error,
    required this.totalFiles,
  });

  UploadRecord copyWith({
    String? batchId,
    int? batchDbId,
    String? uploadType,
    List<String>? fileNames,
    List<int>? documentIds,
    String? status,
    DateTime? createdAt,
    String? error,
    int? totalFiles,
    bool clearError = false,
  }) {
    return UploadRecord(
      batchId: batchId ?? this.batchId,
      batchDbId: batchDbId ?? this.batchDbId,
      uploadType: uploadType ?? this.uploadType,
      fileNames: fileNames ?? this.fileNames,
      documentIds: documentIds ?? this.documentIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      error: clearError ? null : (error ?? this.error),
      totalFiles: totalFiles ?? this.totalFiles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_id': batchId,
      'batch_db_id': batchDbId,
      'upload_type': uploadType,
      'file_names': fileNames,
      'document_ids': documentIds,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'error': error,
      'total_files': totalFiles,
    };
  }

  factory UploadRecord.fromJson(Map<String, dynamic> json) {
    return UploadRecord(
      batchId: (json['batch_id'] ?? '').toString(),
      batchDbId: _coerceInt(json['batch_db_id']),
      uploadType: (json['upload_type'] ?? kFallbackUploadType).toString(),
      fileNames: _stringList(json['file_names']),
      documentIds: _intList(json['document_ids']),
      status: (json['status'] ?? 'processing').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      error: json['error']?.toString(),
      totalFiles: _coerceInt(json['total_files']) ??
          _stringList(json['file_names']).length,
    );
  }

  static const String kFallbackUploadType = 'secondary_sales';

  /// Accepts both the flat Secondary Sales payload and the nested POD `data` wrapper.
  static Map<String, dynamic> unwrapPayload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic> &&
        (data.containsKey('batch_id') ||
            data.containsKey('documents') ||
            data.containsKey('batch_db_id') ||
            data.containsKey('status'))) {
      return data;
    }
    return response;
  }

  static UploadRecord? tryFromUploadResponse({
    required Map<String, dynamic> response,
    required String uploadType,
    required List<String> fileNames,
    required int totalFiles,
  }) {
    final payload = unwrapPayload(response);
    final batchId = (payload['batch_id'] ?? payload['id'] ?? '').toString();
    if (batchId.isEmpty || batchId == 'null') return null;

    final documents = payload['documents'];
    final documentIds = <int>[];
    if (documents is List) {
      for (final item in documents) {
        if (item is Map) {
          final id = _coerceInt(item['id']);
          if (id != null) documentIds.add(id);
        }
      }
    }

    return UploadRecord(
      batchId: batchId,
      batchDbId: _coerceInt(payload['batch_db_id']) ?? _coerceInt(payload['id']),
      uploadType: uploadType,
      fileNames: fileNames,
      documentIds: documentIds,
      status: (payload['status'] ?? 'processing').toString(),
      createdAt: DateTime.now(),
      totalFiles: totalFiles,
    );
  }

  static int? _coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  static List<int> _intList(dynamic v) {
    if (v is! List) return const [];
    return v.map(_coerceInt).whereType<int>().toList();
  }
}
