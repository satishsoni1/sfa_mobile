import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/upload_record.dart';

/// Local persistence for accepted uploads.
/// Uses the existing SharedPreferences mechanism — no new storage package.
class UploadRecordStore {
  UploadRecordStore._();
  static final UploadRecordStore instance = UploadRecordStore._();

  static const String _prefsKey = 'pod_upload_records';
  static const int _maxRecords = 50;

  Future<List<UploadRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => UploadRecord.fromJson(Map<String, dynamic>.from(m)))
          .where((r) => r.batchId.isNotEmpty && r.batchId != 'N/A')
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<UploadRecord?> getByBatchId(String batchId) async {
    if (batchId.isEmpty || batchId == 'N/A') return null;
    final all = await loadAll();
    for (final record in all) {
      if (record.batchId == batchId) return record;
    }
    return null;
  }

  Future<void> upsert(UploadRecord record) async {
    if (record.batchId.isEmpty || record.batchId == 'N/A') return;

    final all = List<UploadRecord>.from(await loadAll());
    final index = all.indexWhere((r) => r.batchId == record.batchId);
    if (index >= 0) {
      all[index] = record;
    } else {
      all.insert(0, record);
    }

    if (all.length > _maxRecords) {
      all.removeRange(_maxRecords, all.length);
    }

    await _write(all);
  }

  Future<void> removeByBatchId(String batchId) async {
    if (batchId.isEmpty || batchId == 'N/A') return;
    final all = await loadAll();
    final next = all.where((r) => r.batchId != batchId).toList();
    if (next.length == all.length) return;
    await _write(next);
  }

  /// Replaces Secondary Sales history only. Invoice POD records are kept.
  Future<void> replaceSecondarySales(List<UploadRecord> secondary) async {
    final all = await loadAll();
    final others = all
        .where((r) => r.uploadType != kUploadTypeSecondarySales)
        .toList();
    final cleaned = <UploadRecord>[];
    final seen = <String>{};
    for (final record in secondary) {
      if (record.uploadType != kUploadTypeSecondarySales) continue;
      if (record.batchId.isEmpty || record.batchId == 'N/A') continue;
      if (!seen.add(record.batchId)) continue;
      cleaned.add(record);
    }
    await _write([...cleaned, ...others]);
  }

  Future<void> _write(List<UploadRecord> all) async {
    final trimmed = all.length > _maxRecords
        ? all.sublist(0, _maxRecords)
        : all;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }
}
