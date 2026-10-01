import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/batch_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_history_sync.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';

/// Result of polling Laravel for a Secondary Sales batch/statement status.
class SecondarySalesBatchPollResult {
  final String status;
  final List<int> documentIds;
  final String? stockistName;
  final String? hospitalName;
  final bool hasValidationIssue;
  final String? validationMessage;
  final String? statementDate;
  final int? batchDbId;

  const SecondarySalesBatchPollResult({
    required this.status,
    this.documentIds = const [],
    this.stockistName,
    this.hospitalName,
    this.hasValidationIssue = false,
    this.validationMessage,
    this.statementDate,
    this.batchDbId,
  });

  bool get isTerminal => isSecondarySalesTerminalUploadStatus(status);
}

/// Polls Laravel batch (preferred) or pod document endpoints.
/// Does not trigger upload/OCR — read-only status checks.
class SecondarySalesBatchStatusService {
  SecondarySalesBatchStatusService({
    ApiClient? client,
    BatchService? batchService,
  })  : _client = client ?? ApiClient(),
        _batchService = batchService ?? BatchService();

  final ApiClient _client;
  final BatchService _batchService;

  Future<SecondarySalesBatchPollResult?> poll(UploadRecord record) async {
    final fromBatch = await _pollBatch(record);
    if (fromBatch != null) return fromBatch;
    if (record.documentIds.isEmpty) return null;
    return _pollDocuments(record);
  }

  Future<SecondarySalesBatchPollResult?> _pollBatch(UploadRecord record) async {
    final key = record.batchDbId ?? int.tryParse(record.batchId);
    if (key == null) return null;
    try {
      final batch = await _batchService.fetchBatchById(key);
      final status = normalizeSecondarySalesUploadStatus(batch.status);
      final docIds = _documentIdsFromBatch(batch);
      return SecondarySalesBatchPollResult(
        status: status,
        documentIds: docIds.isNotEmpty ? docIds : record.documentIds,
        stockistName: _usableName(batch.stockistName),
        hospitalName: _usableName(batch.hospitalName),
        hasValidationIssue: batch.showsValidationIssue,
        validationMessage: batch.validationMessage,
        statementDate: batch.statementDate,
        batchDbId: batch.id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SecondarySalesBatchPollResult?> _pollDocuments(
    UploadRecord record,
  ) async {
    final statuses = <String>[];
    final liveDocIds = <int>[];
    for (final documentId in record.documentIds) {
      try {
        final uri = Uri.parse('$API_PODS_URL/$documentId');
        final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 202) {
          statuses.add('processing');
          liveDocIds.add(documentId);
          continue;
        }
        if (resp.statusCode == 404) {
          statuses.add('missing');
          continue;
        }
        if (resp.statusCode != 200) return null;
        final decoded = jsonDecode(resp.body);
        if (decoded is! Map) return null;
        final map = Map<String, dynamic>.from(decoded);
        final data = map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : map;
        statuses.add(
          normalizeSecondarySalesUploadStatus(
            (data['status'] ?? 'processing').toString(),
          ),
        );
        liveDocIds.add(documentId);
      } catch (_) {
        return null;
      }
    }
    if (statuses.isEmpty) return null;
    if (statuses.every((s) => s == 'missing')) return null;
    final live = statuses.where((s) => s != 'missing').toList();
    final status = live.any((s) => s == 'failed')
        ? 'failed'
        : (live.every((s) => s == 'completed') ? 'completed' : 'processing');
    return SecondarySalesBatchPollResult(
      status: status,
      documentIds: liveDocIds,
    );
  }

  List<int> _documentIdsFromBatch(Batch batch) {
    if (batch.documentIds.isNotEmpty) return batch.documentIds;
    final ids = <int>[];
    final meta = batch.metadata;
    for (final key in ['document_ids', 'documents', 'pods', 'pod_ids']) {
      final raw = meta[key];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final id = item['id'];
            final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
            if (parsed != null) ids.add(parsed);
          } else if (item is int) {
            ids.add(item);
          } else if (item is num) {
            ids.add(item.toInt());
          }
        }
      }
    }
    return ids;
  }

  String? _usableName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase().startsWith('unknown')) return null;
    return trimmed;
  }
}

/// Tracks one-time completion/failure notifications across screens.
class SecondarySalesCompletionTracker {
  SecondarySalesCompletionTracker._();

  static const _prefsKey = 'ss_terminal_notified_batch_ids_v1';
  static final Set<String> _memory = <String>{};

  static Future<bool> claim(String batchId) async {
    if (batchId.isEmpty || batchId == 'N/A') return false;
    if (!_memory.add(batchId)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefsKey) ?? <String>[];
      if (existing.contains(batchId)) return false;
      final next = [...existing, batchId];
      if (next.length > 120) {
        next.removeRange(0, next.length - 120);
      }
      await prefs.setStringList(_prefsKey, next);
      return true;
    } catch (_) {
      return true;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _memory.clear();
  }
}

/// Singleton background poller for active Secondary Sales uploads.
/// One timer app-wide — safe if multiple screens call [ensureStarted].
class SecondarySalesBackgroundMonitor {
  SecondarySalesBackgroundMonitor._();

  static final SecondarySalesBackgroundMonitor instance =
      SecondarySalesBackgroundMonitor._();

  static const Duration pollInterval = Duration(seconds: 5);

  final SecondarySalesBatchStatusService _statusService =
      SecondarySalesBatchStatusService();
  Timer? _timer;
  bool _inFlight = false;
  BuildContext? _messengerContext;

  void attachMessengerContext(BuildContext? context) {
    _messengerContext = context;
  }

  void ensureStarted() {
    if (!isSecondarySalesUpload) return;
    _timer ??= Timer.periodic(pollInterval, (_) {
      unawaited(tick());
    });
    unawaited(tick());
  }

  /// Stops the shared timer (tests / app teardown).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _inFlight = false;
  }

  void stopIfIdle() {
    // Timer is stopped inside tick when no active batches remain.
  }

  Future<void> tick() async {
    if (!isSecondarySalesUpload || _inFlight) return;
    _inFlight = true;
    try {
      final all = await UploadRecordStore.instance.loadAll();
      final active = secondarySalesActiveBatches(all);
      if (active.isEmpty) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      // Ensure timer keeps running while work remains.
      _timer ??= Timer.periodic(pollInterval, (_) {
        unawaited(tick());
      });

      var anyTerminal = false;
      for (final record in active) {
        final result = await _statusService.poll(record);
        if (result == null) continue;
        final next = record.copyWith(
          status: result.status,
          documentIds: result.documentIds.isNotEmpty
              ? result.documentIds
              : record.documentIds,
          batchDbId: result.batchDbId ?? record.batchDbId,
          clearError: result.status != 'failed',
          error: result.status == 'failed' ? record.error : null,
        );
        if (next.status == record.status &&
            next.documentIds.length == record.documentIds.length) {
          if (!result.isTerminal) continue;
        }
        await UploadRecordStore.instance.upsert(next);
        if (result.isTerminal) {
          anyTerminal = true;
          await _notifyTerminal(next, result);
        }
      }
      if (anyTerminal) {
        SecondarySalesDataRefresh.notify();
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _notifyTerminal(
    UploadRecord record,
    SecondarySalesBatchPollResult result,
  ) async {
    final claimed = await SecondarySalesCompletionTracker.claim(record.batchId);
    if (!claimed) return;

    final ctx = _messengerContext;
    if (ctx == null || !ctx.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;

    final stockist = result.stockistName;
    if (result.status == 'completed') {
      if (result.hasValidationIssue) {
        final msg = (result.validationMessage ?? '').trim();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              stockist != null
                  ? 'Processing completed with a validation issue\n'
                      '$stockist\n'
                      '${msg.isNotEmpty ? msg : 'See Batch Details for more information.'}'
                  : 'Processing completed with a validation issue\n'
                      '${msg.isNotEmpty ? msg : 'See Batch Details for more information.'}',
            ),
            backgroundColor: const Color(0xFFE65100),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              stockist != null
                  ? 'Processing completed\n'
                      '$stockist\n'
                      'Statement processed successfully.'
                  : 'Processing completed\n'
                      'Your Secondary Sales statement has been processed successfully.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (result.status == 'failed') {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            record.error?.trim().isNotEmpty == true
                ? 'Processing failed\n${record.error}'
                : 'Processing failed. View batches for details.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
