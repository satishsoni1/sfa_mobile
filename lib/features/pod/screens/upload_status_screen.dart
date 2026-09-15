import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/upload_record.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/services/upload_record_store.dart';
import 'package:zforce/features/pod/widgets/modern_ui_components.dart';

class UploadStatusScreen extends StatefulWidget {
  final Map<String, dynamic> uploadData;
  final int totalFiles;
  final String? batchId;
  final List<String>? fileNames;
  final String? uploadType;

  const UploadStatusScreen({
    super.key,
    required this.uploadData,
    required this.totalFiles,
    this.batchId,
    this.fileNames,
    this.uploadType,
  });

  @override
  State<UploadStatusScreen> createState() => _UploadStatusScreenState();
}

class _UploadStatusScreenState extends State<UploadStatusScreen> {
  static const Duration _pollInterval = Duration(seconds: 4);
  static const Duration _pollTimeout = Duration(minutes: 15);

  Timer? _pollTimer;
  DateTime? _pollStartedAt;
  String _status = 'processing';
  int _progressPercentage = 0;
  int _blocksCompleted = 0;
  int _blocksTotal = 0;
  int _invoicesProcessed = 0;
  String? _currentBlock;
  String _batchId = 'N/A';
  int? _batchDbId;
  Map<String, dynamic> _steps = {};
  bool _navigatedToReview = false;
  String? _terminalResult; // e.g. 'no_new_pods'
  String? _terminalMessage;
  String _uploadType = POD_CLIENT_UPLOAD_TYPE;
  List<int> _documentIds = const [];
  List<String> _fileNames = const [];
  int _totalFiles = 0;
  String? _statusError;
  DateTime _createdAt = DateTime.now();

  bool get _isSecondarySales => _uploadType == kUploadTypeSecondarySales;

  @override
  void initState() {
    super.initState();
    _totalFiles = widget.totalFiles;
    _fileNames = widget.fileNames ?? const [];
    _uploadType = widget.uploadType ?? POD_CLIENT_UPLOAD_TYPE;
    _hydrateFromArgs();
    _pollStartedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  int? _coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  void _hydrateFromArgs() {
    if (widget.uploadData.isEmpty) return;
    final payload = UploadRecord.unwrapPayload(widget.uploadData);
    final parsed = UploadRecord.tryFromUploadResponse(
      response: widget.uploadData,
      uploadType: widget.uploadType ?? POD_CLIENT_UPLOAD_TYPE,
      fileNames: widget.fileNames ?? const [],
      totalFiles: widget.totalFiles,
    );
    if (parsed != null) {
      _applyRecord(parsed);
      return;
    }
    _batchId = (payload['batch_id'] ?? widget.batchId ?? 'N/A').toString();
    _batchDbId = _coerceInt(payload['batch_db_id']) ?? _coerceInt(payload['id']);
    _status = (payload['status'] ?? _status).toString();
  }

  void _applyRecord(UploadRecord record) {
    _batchId = record.batchId;
    _batchDbId = record.batchDbId;
    _status = record.status;
    _uploadType = record.uploadType;
    _documentIds = record.documentIds;
    _fileNames = record.fileNames.isNotEmpty ? record.fileNames : _fileNames;
    _totalFiles = record.totalFiles > 0 ? record.totalFiles : _totalFiles;
    _statusError = record.error;
    _createdAt = record.createdAt;
    if (record.uploadType == kUploadTypeSecondarySales &&
        _normalizeStatus(record.status) == 'completed') {
      _progressPercentage = 100;
    }
  }

  Future<void> _bootstrap() async {
    UploadRecord? persisted;
    final lookupId = widget.batchId ??
        (_batchId.isNotEmpty && _batchId != 'N/A' ? _batchId : null);
    if (lookupId != null) {
      persisted = await UploadRecordStore.instance.getByBatchId(lookupId);
    }

    if (persisted != null) {
      final incoming = UploadRecord.tryFromUploadResponse(
        response: widget.uploadData,
        uploadType: persisted.uploadType,
        fileNames: widget.fileNames ?? persisted.fileNames,
        totalFiles: widget.totalFiles > 0 ? widget.totalFiles : persisted.totalFiles,
      );
      final merged = persisted.copyWith(
        batchDbId: incoming?.batchDbId ?? persisted.batchDbId,
        documentIds: (incoming?.documentIds.isNotEmpty ?? false)
            ? incoming!.documentIds
            : persisted.documentIds,
        fileNames: (incoming?.fileNames.isNotEmpty ?? false)
            ? incoming!.fileNames
            : persisted.fileNames,
        status: incoming?.status ?? persisted.status,
        totalFiles: incoming?.totalFiles ?? persisted.totalFiles,
      );
      if (!mounted) return;
      setState(() => _applyRecord(merged));
      await UploadRecordStore.instance.upsert(merged);
    } else {
      final created = UploadRecord.tryFromUploadResponse(
        response: widget.uploadData,
        uploadType: widget.uploadType ?? POD_CLIENT_UPLOAD_TYPE,
        fileNames: widget.fileNames ?? const [],
        totalFiles: widget.totalFiles,
      );
      if (created != null) {
        await UploadRecordStore.instance.upsert(created);
        if (!mounted) return;
        setState(() => _applyRecord(created));
      }
    }

    if (!mounted) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStatus());
    await _pollStatus();
  }

  Future<void> _persistCurrent({String? error, bool clearError = false}) async {
    if (_batchId.isEmpty || _batchId == 'N/A') return;
    await UploadRecordStore.instance.upsert(
      UploadRecord(
        batchId: _batchId,
        batchDbId: _batchDbId,
        uploadType: _uploadType,
        fileNames: _fileNames,
        documentIds: _documentIds,
        status: _status,
        createdAt: _createdAt,
        error: clearError ? null : error ?? _statusError,
        totalFiles: _totalFiles,
      ),
    );
  }

  Future<void> _pollStatus() async {
    if (_navigatedToReview) return;
    if (_pollStartedAt != null &&
        DateTime.now().difference(_pollStartedAt!) > _pollTimeout) {
      _pollTimer?.cancel();
      return;
    }

    if (_isSecondarySales) {
      await _pollSecondarySalesStatus();
    } else {
      await _pollInvoicePodStatus();
    }
  }

  Future<void> _pollSecondarySalesStatus() async {
    if (_documentIds.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) return;

      final statuses = <String>[];
      final ids = List<int>.from(_documentIds);

      for (final documentId in ids) {
        final uri = Uri.parse('${API_PODS_URL}/$documentId');
        final resp = await http
            .get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 401 || resp.statusCode == 403) {
          if (!mounted) return;
          setState(() {
            _statusError = resp.statusCode == 401
                ? 'Session expired. Please log in again.'
                : 'You do not have permission to view this upload.';
          });
          return;
        }
        if (resp.statusCode == 404 || resp.statusCode == 202) {
          statuses.add('processing');
          continue;
        }
        if (resp.statusCode != 200) {
          return;
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map<String, dynamic>) return;
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
        statuses.add(
          _normalizeStatus((data['status'] ?? 'processing').toString()),
        );
      }

      if (statuses.isEmpty) return;
      final latestStatus = statuses.any((s) => s == 'failed')
          ? 'failed'
          : (statuses.every((s) => s == 'completed')
              ? 'completed'
              : 'processing');

      if (!mounted) return;
      setState(() {
        _status = latestStatus;
        _statusError = null;
        if (latestStatus == 'completed') {
          _progressPercentage = 100;
        }
      });
      await _persistCurrent(clearError: true);

      if (latestStatus == 'completed' || latestStatus == 'failed') {
        _pollTimer?.cancel();
      }
    } on TimeoutException {
      // keep PROCESSING — do not re-upload
    } catch (_) {
      // transient status failure must not discard the accepted batch
    }
  }

  String _normalizeStatus(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('fail') || s.contains('error') || s.contains('reject')) {
      return 'failed';
    }
    if (s.contains('complete') || s.contains('success') || s == 'done') {
      return 'completed';
    }
    return 'processing';
  }

  Future<void> _pollInvoicePodStatus() async {
    final pollKey = _batchDbId?.toString() ?? _batchId;
    if (pollKey.isEmpty || pollKey == 'N/A') {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final uri = Uri.parse('${API_BASE_URL}pod/upload-background/$pollKey');

      final resp = await http
          .get(
            uri,
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return;

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final newStatus = (data['status'] ?? _status).toString();
      final rawProgress = _coerceInt(data['progress_percentage']) ?? _progressPercentage;
      final newProgress = rawProgress.clamp(0, 100);
      final blockProgress = data['block_progress'] as Map<String, dynamic>?;
      final steps = data['steps'] as Map<String, dynamic>? ?? _steps;

      if (!mounted) return;
      setState(() {
        _status = newStatus;
        _progressPercentage = newProgress;
        _steps = steps;
        if (blockProgress != null) {
          _blocksCompleted = _coerceInt(blockProgress['blocks_completed']) ?? 0;
          _blocksTotal = _coerceInt(blockProgress['blocks_total']) ?? 0;
          _invoicesProcessed = _coerceInt(blockProgress['invoices_processed']) ?? 0;
          _currentBlock = blockProgress['current_block']?.toString();
        }
      });
      await _persistCurrent();

      final review = data['review'] as Map<String, dynamic>?;
      final hospitals = review == null ? null : review['hospitals'] as List?;
      final hasHospitals = hospitals != null && hospitals.isNotEmpty;
      final failedFiles = review == null ? null : review['failed_files'] as List?;
      final hasFailedFiles = failedFiles != null && failedFiles.isNotEmpty;
      final terminalResult = data['result']?.toString();

      if (newStatus == 'completed' && (hasHospitals || hasFailedFiles)) {
        _navigatedToReview = true;
        _pollTimer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          PodRoutes.podReview,
          arguments: {'review': review},
        );
      } else if (newStatus == 'completed' && terminalResult != null) {
        // Terminal: batch finished but no new PODs were created (e.g. all
        // invoices were already uploaded earlier). Stop polling; the UI will
        // render a completion message.
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _terminalResult = terminalResult;
          _terminalMessage = data['result_message']?.toString();
        });
      } else if (newStatus == 'failed') {
        _pollTimer?.cancel();
      }
      // If status=completed but review is still empty, keep polling —
      // child jobs may still be persisting POD records.
    } on TimeoutException {
      // ignore; next tick will retry
    } catch (_) {
      // ignore transient errors; polling continues
    }
  }

  /// Invoice POD keeps using API progress_percentage.
  /// Secondary Sales has no progress payload — derive the bar from status.
  double? _displayProgressValue(bool isCompleted, bool isFailed) {
    if (_isSecondarySales) {
      if (isCompleted) return 1.0;
      if (isFailed) return _progressPercentage > 0 ? _progressPercentage / 100 : 0.0;
      return null;
    }
    return _progressPercentage > 0 ? _progressPercentage / 100 : null;
  }

  String _displayProgressLabel(bool isCompleted, bool isFailed) {
    if (_isSecondarySales) {
      if (isCompleted) return '100%  •  Processing complete';
      if (isFailed) return 'Failed';
      return 'Processing your statement...';
    }
    return _progressPercentage > 0 ? '$_progressPercentage%' : 'Starting…';
  }

  @override
  Widget build(BuildContext context) {
    final hasTerminal = _terminalResult != null;
    final isProcessing = !hasTerminal && (_status == 'processing' || _status == 'pending');
    final isCompleted = _status == 'completed' || hasTerminal;
    final isFailed = _status == 'failed';

    return Scaffold(
      appBar: ModernUIComponents.buildModernAppBar(
        title: _isSecondarySales ? 'Secondary Sales Upload' : 'Upload Status',
        subtitle: isCompleted
            ? (_isSecondarySales ? 'Processing complete' : 'Extraction complete')
            : (isFailed
                ? (_isSecondarySales ? 'Processing failed' : 'Extraction failed')
                : 'Processing…'),
        icon: Icons.cloud_upload,
        color: const Color(0xFF450095),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.withOpacity(0.05), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(isProcessing, isCompleted, isFailed),
              const SizedBox(height: 20),
              _buildSectionCard(
                icon: Icons.info_outline,
                title: 'Upload Summary',
                child: Column(
                  children: [
                    _buildInfoRow('Total Files', _totalFiles.toString()),
                    _buildInfoRow('Batch ID', _batchId),
                    _buildInfoRow('Status', _status.toUpperCase()),
                    if (_fileNames.isNotEmpty)
                      _buildInfoRow('Files', _fileNames.join(', ')),
                    if (_isSecondarySales && _documentIds.isNotEmpty)
                      _buildInfoRow(
                        'Document ID',
                        _documentIds.join(', '),
                      ),
                    if (!_isSecondarySales && _blocksTotal > 0)
                      _buildInfoRow(
                        'Blocks',
                        '$_blocksCompleted / $_blocksTotal'
                            '${_currentBlock != null ? '  •  $_currentBlock' : ''}',
                      ),
                    if (!_isSecondarySales && _invoicesProcessed > 0)
                      _buildInfoRow('Invoices Extracted', _invoicesProcessed.toString()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _displayProgressValue(isCompleted, isFailed),
                minHeight: 8,
                backgroundColor: Colors.teal.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF450095)),
              ),
              const SizedBox(height: 8),
              Text(
                _displayProgressLabel(isCompleted, isFailed),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              if (_steps.isNotEmpty)
                _buildSectionCard(
                  icon: Icons.timeline,
                  title: 'Processing Steps',
                  child: Column(
                    children: _steps.entries
                        .map((entry) => _buildProcessingStep(
                              entry.key,
                              entry.value is Map
                                  ? (entry.value['status']?.toString() ?? '')
                                  : entry.value.toString(),
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 20),
              _buildNoticeCard(isCompleted, isFailed),
              const SizedBox(height: 20),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(bool isProcessing, bool isCompleted, bool isFailed) {
    final color = isFailed
        ? Colors.red
        : (isCompleted ? Colors.green : Colors.teal);
    final icon = isFailed
        ? Icons.error
        : (isCompleted ? Icons.check_circle : Icons.hourglass_top);
    final isTerminalNoNew = _terminalResult == 'no_new_pods';
    final title = isFailed
        ? (_isSecondarySales ? 'Secondary Sales Failed' : 'Extraction Failed')
        : (isTerminalNoNew
            ? 'No New Invoices'
            : (isCompleted
                ? (_isSecondarySales
                    ? 'Secondary Sales Complete'
                    : 'Extraction Complete')
                : 'Files Uploaded'));
    final subtitle = isFailed
        ? (_statusError ??
            'Something went wrong during processing. Try again.')
        : (isTerminalNoNew
            ? (_terminalMessage ??
                'All invoices in this upload were already recorded earlier.')
            : (isCompleted
                ? (_isSecondarySales
                    ? 'Statement processing finished. You can view details or go to the dashboard.'
                    : 'Redirecting to the review screen…')
                : 'Background processing is running. You can leave this screen.'));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.shade400, color.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF450095), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStep(String stepKey, String stepValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStepColor(stepValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepKey.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  stepValue,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(bool isCompleted, bool isFailed) {
    final color = isFailed
        ? Colors.red
        : (isCompleted ? Colors.green : Colors.blue);
    final isTerminalNoNew = _terminalResult == 'no_new_pods';
    final text = isFailed
        ? (_statusError ??
            'Processing failed. Please retry the upload or contact support.')
        : (isTerminalNoNew
            ? (_terminalMessage ??
                'No new documents were created — the invoices in this upload match records that already exist. Use the dashboard to review existing documents.')
            : (isCompleted
                ? (_isSecondarySales
                    ? 'Processing finished. Open the statement details or review it from the dashboard document list.'
                    : 'Extraction finished. You will be redirected to review the hospitals detected in the invoices.')
                : 'Your files are being processed in the background. Leaving this screen will not cancel processing.'));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.shade50,
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: color.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: color.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final canViewDetails =
        _isSecondarySales && _status == 'completed' && _documentIds.isNotEmpty;

    return Column(
      children: [
        if (canViewDetails) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  PodRoutes.statementDetail,
                  arguments: {'podId': _documentIds.first},
                );
              },
              icon: const Icon(Icons.description_outlined),
              label: const Text('View Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.dashboard),
            label: const Text('Go to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF450095),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStepColor(String stepValue) {
    final v = stepValue.toLowerCase();
    if (v.contains('completed') || v.contains('success')) return Colors.green;
    if (v.contains('progress') || v.contains('processing')) return Colors.orange;
    if (v.contains('pending')) return Colors.grey;
    if (v.contains('failed') || v.contains('error')) return Colors.red;
    return Colors.blue;
  }
}
