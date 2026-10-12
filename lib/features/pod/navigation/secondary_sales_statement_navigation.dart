import 'package:flutter/material.dart';
import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/services/batch_service.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';

/// Opens Statement Details (products, analytics, opening/closing) for a batch.
Future<void> openSecondarySalesBatchStatementDetails(
  BuildContext context, {
  required int batchId,
  Batch? batch,
  List<int>? knownDocumentIds,
  BatchService? batchService,
}) async {
  final podId = await resolveSecondarySalesStatementPodId(
    batchId: batchId,
    batch: batch,
    knownDocumentIds: knownDocumentIds,
    batchService: batchService,
  );

  if (!context.mounted) return;

  if (podId != null) {
    await Navigator.pushNamed(
      context,
      PodRoutes.statementDetail,
      arguments: {'podId': podId},
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        batch?.showsValidationIssue == true
            ? 'No statement was created for this batch. Check the validation message on Batch Details.'
            : batch?.isProcessingStatus == true
                ? 'This batch is still processing. Statement details will be available when extraction finishes.'
                : 'Statement product details are not available for this batch yet.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Resolves the POD/statement id used by [StatementDetailScreen].
Future<int?> resolveSecondarySalesStatementPodId({
  required int batchId,
  Batch? batch,
  List<int>? knownDocumentIds,
  BatchService? batchService,
}) async {
  if (knownDocumentIds != null && knownDocumentIds.isNotEmpty) {
    return knownDocumentIds.first;
  }
  if (batch?.primaryDocumentId != null) {
    return batch!.primaryDocumentId;
  }

  try {
    final records = await UploadRecordStore.instance.loadAll();
    for (final record in records) {
      if (!_recordMatchesBatch(record, batchId)) continue;
      if (record.documentIds.isNotEmpty) return record.documentIds.first;
    }
  } catch (_) {
    // Local history is best-effort only.
  }

  // List payloads often omit document ids — fetch batch details once.
  try {
    final fresh = await (batchService ?? BatchService()).fetchBatchById(batchId);
    return fresh.primaryDocumentId;
  } catch (_) {
    return null;
  }
}

bool _recordMatchesBatch(UploadRecord record, int batchId) {
  if (record.batchDbId == batchId) return true;
  final parsed = int.tryParse(record.batchId.trim());
  return parsed != null && parsed == batchId;
}
