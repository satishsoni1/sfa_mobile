import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_dashboard_service.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';

enum SecondarySalesRecordExistence { exists, notFound, unknown }

class SecondarySalesServerSnapshot {
  final String batchId;
  final int? batchDbId;
  final String status;
  final List<String> fileNames;
  final List<int> documentIds;
  final DateTime? createdAt;
  final int totalFiles;

  const SecondarySalesServerSnapshot({
    required this.batchId,
    this.batchDbId,
    required this.status,
    this.fileNames = const [],
    this.documentIds = const [],
    this.createdAt,
    this.totalFiles = 0,
  });
}

class SecondarySalesHistoryReconcileResult {
  final List<UploadRecord> records;
  final Set<String> removedBatchIds;

  const SecondarySalesHistoryReconcileResult({
    required this.records,
    this.removedBatchIds = const {},
  });
}

String normalizeSecondarySalesUploadStatus(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('fail') || s.contains('error') || s.contains('reject')) {
    return 'failed';
  }
  if (s.contains('complete') ||
      s.contains('success') ||
      s.contains('verified') ||
      s.contains('processed') ||
      s.contains('approved') ||
      s == 'done') {
    return 'completed';
  }
  return 'processing';
}

/// Laravel is the source of truth. Local Secondary Sales records are kept,
/// updated, or removed from that server view. Invoice POD records pass through.
SecondarySalesHistoryReconcileResult reconcileSecondarySalesHistory({
  required List<UploadRecord> local,
  required List<SecondarySalesServerSnapshot> server,
  Map<String, SecondarySalesRecordExistence> existenceByBatchId = const {},
}) {
  final invoicePod = local
      .where((r) => r.uploadType != kUploadTypeSecondarySales)
      .toList();
  final secondary = local
      .where((r) => r.uploadType == kUploadTypeSecondarySales)
      .toList();

  final serverById = <String, SecondarySalesServerSnapshot>{};
  for (final snapshot in server) {
    if (snapshot.batchId.isEmpty || snapshot.batchId == 'N/A') continue;
    final existing = serverById[snapshot.batchId];
    if (existing == null) {
      serverById[snapshot.batchId] = snapshot;
      continue;
    }
    serverById[snapshot.batchId] = SecondarySalesServerSnapshot(
      batchId: snapshot.batchId,
      batchDbId: snapshot.batchDbId ?? existing.batchDbId,
      status: snapshot.status,
      fileNames: snapshot.fileNames.isNotEmpty
          ? snapshot.fileNames
          : existing.fileNames,
      documentIds: {
        ...existing.documentIds,
        ...snapshot.documentIds,
      }.toList(),
      createdAt: snapshot.createdAt ?? existing.createdAt,
      totalFiles: snapshot.totalFiles > 0
          ? snapshot.totalFiles
          : existing.totalFiles,
    );
  }

  final kept = <UploadRecord>[];
  final removed = <String>{};
  final seen = <String>{};

  for (final record in secondary) {
    final existence = existenceByBatchId[record.batchId] ??
        (serverById.containsKey(record.batchId)
            ? SecondarySalesRecordExistence.exists
            : SecondarySalesRecordExistence.unknown);
    if (existence == SecondarySalesRecordExistence.notFound) {
      removed.add(record.batchId);
      continue;
    }
    if (!seen.add(record.batchId)) continue;
    final snapshot = serverById[record.batchId];
    kept.add(snapshot == null ? record : _merge(record, snapshot));
  }

  for (final snapshot in serverById.values) {
    if (seen.contains(snapshot.batchId)) continue;
    seen.add(snapshot.batchId);
    kept.add(_fromSnapshot(snapshot));
  }

  kept.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return SecondarySalesHistoryReconcileResult(
    records: [...kept, ...invoicePod],
    removedBatchIds: removed,
  );
}

UploadRecord _merge(UploadRecord local, SecondarySalesServerSnapshot server) {
  return local.copyWith(
    batchDbId: server.batchDbId ?? local.batchDbId,
    status: normalizeSecondarySalesUploadStatus(server.status),
    fileNames: server.fileNames.isNotEmpty ? server.fileNames : local.fileNames,
    documentIds:
        server.documentIds.isNotEmpty ? server.documentIds : local.documentIds,
    totalFiles: server.totalFiles > 0 ? server.totalFiles : local.totalFiles,
    createdAt: server.createdAt ?? local.createdAt,
    clearError: true,
  );
}

UploadRecord _fromSnapshot(SecondarySalesServerSnapshot server) {
  return UploadRecord(
    batchId: server.batchId,
    batchDbId: server.batchDbId,
    uploadType: kUploadTypeSecondarySales,
    fileNames: server.fileNames,
    documentIds: server.documentIds,
    status: normalizeSecondarySalesUploadStatus(server.status),
    createdAt: server.createdAt ?? DateTime.now(),
    totalFiles: server.totalFiles > 0
        ? server.totalFiles
        : (server.fileNames.isEmpty ? 1 : server.fileNames.length),
  );
}

class SecondarySalesUploadHistorySync {
  SecondarySalesUploadHistorySync({
    UploadRecordStore? store,
    SecondarySalesDashboardService? dashboard,
    ApiClient? client,
    Future<http.Response> Function(Uri uri)? getter,
  })  : _store = store ?? UploadRecordStore.instance,
        _dashboard = dashboard ?? SecondarySalesDashboardService(),
        _client = client ?? ApiClient(),
        _getter = getter;

  final UploadRecordStore _store;
  final SecondarySalesDashboardService _dashboard;
  final ApiClient _client;
  final Future<http.Response> Function(Uri uri)? _getter;

  Future<List<UploadRecord>> synchronize() async {
    final local = await _store.loadAll();
    if (!isSecondarySalesUpload) return local;

    List<SecondarySalesServerSnapshot> server = const [];
    try {
      server = await _fetchServerSnapshots(local);
    } catch (_) {
      server = const [];
    }

    final existence = <String, SecondarySalesRecordExistence>{};
    for (final record in local.where(
      (r) => r.uploadType == kUploadTypeSecondarySales,
    )) {
      if (server.any((s) => s.batchId == record.batchId)) {
        existence[record.batchId] = SecondarySalesRecordExistence.exists;
        continue;
      }
      existence[record.batchId] = await checkRecordExistence(record);
    }

    final result = reconcileSecondarySalesHistory(
      local: local,
      server: server,
      existenceByBatchId: existence,
    );
    await _store.replaceSecondarySales(
      result.records
          .where((r) => r.uploadType == kUploadTypeSecondarySales)
          .toList(),
    );
    return _store.loadAll();
  }

  Future<SecondarySalesRecordExistence> checkRecordExistence(
    UploadRecord record,
  ) async {
    try {
      if (record.documentIds.isNotEmpty) {
        var sawExists = false;
        var sawUnknown = false;
        for (final id in record.documentIds) {
          final status = await _getStatus('$API_PODS_URL/$id');
          if (status == SecondarySalesRecordExistence.exists) {
            sawExists = true;
          } else if (status == SecondarySalesRecordExistence.unknown) {
            sawUnknown = true;
          }
        }
        if (sawExists) return SecondarySalesRecordExistence.exists;
        if (sawUnknown) return SecondarySalesRecordExistence.unknown;
        return SecondarySalesRecordExistence.notFound;
      }

      final batchKey = record.batchDbId?.toString() ?? record.batchId;
      return _getStatus('$API_BATCHES_URL/$batchKey');
    } on SocketException {
      return SecondarySalesRecordExistence.unknown;
    } catch (_) {
      return SecondarySalesRecordExistence.unknown;
    }
  }

  Future<List<SecondarySalesServerSnapshot>> _fetchServerSnapshots(
    List<UploadRecord> local,
  ) async {
    final months = <String>{
      DateFormat('yyyy-MM').format(DateTime.now()),
    };
    for (final record in local) {
      if (record.uploadType != kUploadTypeSecondarySales) continue;
      months.add(DateFormat('yyyy-MM').format(record.createdAt.toLocal()));
    }

    final grouped = <String, SecondarySalesServerSnapshot>{};
    for (final month in months) {
      try {
        final docs = await _dashboard.fetchRecent(month: month);
        for (final doc in docs) {
          final batchId = (doc.batchId ?? doc.id?.toString() ?? '').trim();
          if (batchId.isEmpty) continue;
          final createdAt = DateTime.tryParse(doc.uploadedAt ?? '');
          final existing = grouped[batchId];
          grouped[batchId] = SecondarySalesServerSnapshot(
            batchId: batchId,
            batchDbId: int.tryParse(batchId) ?? existing?.batchDbId,
            status: doc.status,
            fileNames: {
              ...?existing?.fileNames,
              if (doc.name.isNotEmpty) doc.name,
            }.toList(),
            documentIds: {
              ...?existing?.documentIds,
              if (doc.id != null) doc.id!,
            }.toList(),
            createdAt: createdAt ?? existing?.createdAt,
            totalFiles: {
              ...?existing?.fileNames,
              if (doc.name.isNotEmpty) doc.name,
            }.length,
          );
        }
      } catch (_) {
        // A single month failure is not proof of deletion.
      }
    }
    return grouped.values.toList();
  }

  Future<SecondarySalesRecordExistence> _getStatus(String url) async {
    try {
      final uri = Uri.parse(url);
      final getter = _getter;
      final response =
          getter != null ? await getter(uri) : await _client.get(uri);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        return SecondarySalesRecordExistence.exists;
      }
      if (response.statusCode == 404) {
        return SecondarySalesRecordExistence.notFound;
      }
      return SecondarySalesRecordExistence.unknown;
    } on UnauthorizedException {
      return SecondarySalesRecordExistence.unknown;
    } on SocketException {
      return SecondarySalesRecordExistence.unknown;
    } catch (_) {
      return SecondarySalesRecordExistence.unknown;
    }
  }
}

bool secondarySalesShouldRemoveAfterMissingPolls(int consecutiveMissing) {
  return consecutiveMissing >= 3;
}
