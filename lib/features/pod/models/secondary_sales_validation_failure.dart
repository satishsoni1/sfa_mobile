/// Parsed FCM `stock_validation_failed` data payload (all FCM values are strings).
class SecondarySalesValidationFailure {
  const SecondarySalesValidationFailure({
    required this.raw,
    this.batchId,
    this.uploadId,
    this.validationCode,
    this.openingStock,
    this.purchases,
    this.closingStock,
    this.maximumAllowedClosingStock,
  });

  final Map<String, String> raw;
  final int? batchId;
  final String? uploadId;
  final String? validationCode;
  final String? openingStock;
  final String? purchases;
  final String? closingStock;
  final String? maximumAllowedClosingStock;

  factory SecondarySalesValidationFailure.fromMessageData(
    Map<String, dynamic> data,
  ) {
    final raw = <String, String>{};
    data.forEach((key, value) {
      if (value == null) return;
      raw[key.toString()] = value.toString();
    });

    int? asInt(String? key) {
      final v = raw[key ?? ''];
      if (v == null || v.trim().isEmpty) return null;
      return int.tryParse(v.trim());
    }

    String? asText(String key) {
      final v = raw[key]?.trim();
      if (v == null || v.isEmpty) return null;
      return v;
    }

    return SecondarySalesValidationFailure(
      raw: raw,
      batchId: asInt('batch_id') ?? asInt('batchId'),
      uploadId: asText('upload_id') ?? asText('uploadId'),
      validationCode:
          asText('validation_code') ?? asText('validationCode'),
      openingStock: asText('opening_stock') ?? asText('openingStock'),
      purchases: asText('purchases') ?? asText('purchase'),
      closingStock: asText('closing_stock') ?? asText('closingStock'),
      maximumAllowedClosingStock: asText('maximum_allowed_closing_stock') ??
          asText('maximumAllowedClosingStock') ??
          asText('max_allowed_closing_stock'),
    );
  }

  String display(String? value) =>
      (value == null || value.trim().isEmpty) ? '—' : value.trim();
}
