import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/navigation/secondary_sales_statement_navigation.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/batch_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_data_refresh.dart';
import 'package:zforce/features/pod/widgets/modern_ui_components.dart';

class BatchDetailScreen extends StatefulWidget {
  final int batchId;
  final Batch? batch; // Optional: if provided, use it directly without API call

  const BatchDetailScreen({super.key, required this.batchId, this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final BatchService _batchService = BatchService();
  Batch? _batch;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _dateUpdated = false;
  bool _updatingDate = false;

  List<Map<String, dynamic>> _failed = [];
  final Set<String> _selectedFailed = {};
  bool _failedLoading = false;
  bool _retrying = false;

  static final DateFormat _displayDateFormat = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    // If batch data is provided, show it immediately, then refresh from API
    // so date/validation fields are never stale after a server-side update.
    if (widget.batch != null) {
      _batch = widget.batch;
      _isLoading = false;
      _loadBatchDetails(quiet: true);
    } else {
      _loadBatchDetails();
    }
    _loadFailed();
  }

  Future<void> _loadFailed() async {
    setState(() => _failedLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final uri = Uri.parse(
        '${API_BASE_URL}pod/upload-batch/${widget.batchId}/failed',
      );
      final resp = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        if (mounted) setState(() => _failed = []);
        return;
      }
      final decoded = jsonDecode(resp.body);
      final data = (decoded is Map) ? decoded['data'] : null;
      final list = data is Map ? data['failed'] : null;
      if (list is! List) {
        if (mounted) setState(() => _failed = []);
        return;
      }
      final rows = list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (!mounted) return;
      setState(() {
        _failed = rows;
        _selectedFailed.removeWhere(
          (inv) => !rows.any((r) => r['invoice_no']?.toString() == inv),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = []);
    } finally {
      if (mounted) setState(() => _failedLoading = false);
    }
  }

  Future<void> _retrySelected({bool all = false}) async {
    final targets = all
        ? _failed.map((r) => r['invoice_no']?.toString()).whereType<String>().toList()
        : _selectedFailed.toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one failed document to retry')),
      );
      return;
    }

    setState(() => _retrying = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final uri = Uri.parse(
        '${API_BASE_URL}pod/upload-batch/${widget.batchId}/retry-failed',
      );
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'invoice_numbers': targets}),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      final decoded = jsonDecode(resp.body);
      final msg = (decoded is Map && decoded['message'] != null)
          ? decoded['message'].toString()
          : (resp.statusCode >= 200 && resp.statusCode < 300
              ? 'Retry dispatched'
              : 'Retry failed (${resp.statusCode})');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: resp.statusCode >= 200 && resp.statusCode < 300
              ? Colors.green
              : Colors.red,
        ),
      );
      _selectedFailed.clear();
      // Give workers a moment to pick up and start, then refresh.
      await Future.delayed(const Duration(seconds: 2));
      await _loadFailed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _loadBatchDetails({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final batch = await _batchService.fetchBatchById(widget.batchId);
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _hasError = false;
      });
    } catch (e) {
      print('Error loading batch details: $e');
      if (!mounted) return;
      if (!quiet) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted && !quiet) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return const Color(0xFF4CAF50);
      case 'processing':
      case 'in_progress':
      case 'pending':
      case 'queued':
        return const Color(0xFF2196F3);
      case 'failed':
      case 'error':
        return const Color(0xFFE53935);
      case 'cancelled':
        return Colors.grey;
      default:
        return const Color(0xFFFFA000);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return Icons.check_circle_rounded;
      case 'processing':
      case 'in_progress':
      case 'pending':
      case 'queued':
        return Icons.hourglass_empty_rounded;
      case 'failed':
      case 'error':
        return Icons.error_outline_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateString;
    }
  }

  String _formatDuration(String? start, String? end) {
    if (start == null || end == null) return 'N/A';
    try {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      final duration = endDate.difference(startDate);
      if (duration.inMinutes < 60) {
        return '${duration.inMinutes} minutes';
      } else {
        return '${duration.inHours}h ${duration.inMinutes % 60}m';
      }
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatStatementDate(DateTime? date) {
    if (date == null) return 'N/A';
    return _displayDateFormat.format(date);
  }

  bool get _canShowChangeDate {
    if (!isSecondarySalesUpload) return false;
    final batch = _batch;
    if (batch == null) return false;
    return batch.canChangeStatementDate && !_updatingDate;
  }

  Future<void> _onChangeDatePressed() async {
    final batch = _batch;
    if (batch == null || _updatingDate) return;
    if (!batch.canChangeStatementDate) return;

    final initial = batch.effectiveStatementDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select statement date',
    );
    if (picked == null || !mounted) return;

    final currentDay = DateTime(initial.year, initial.month, initial.day);
    final newDay = DateTime(picked.year, picked.month, picked.day);
    if (currentDay == newDay) return;

    final confirmed = await _confirmDateChange(
      currentDate: currentDay,
      newDate: newDay,
    );
    if (confirmed != true || !mounted) return;

    await _submitDateChange(newDay);
  }

  Future<bool?> _confirmDateChange({
    required DateTime currentDate,
    required DateTime newDate,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !_updatingDate,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change statement date?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current date:\n${_formatStatementDate(currentDate)}'),
              const SizedBox(height: 12),
              Text('New date:\n${_formatStatementDate(newDate)}'),
              const SizedBox(height: 16),
              Text(
                'Changing the date will update this existing statement and its '
                'month grouping. The document will not be re-processed.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Date'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitDateChange(DateTime newDate) async {
    if (_updatingDate) return;
    setState(() => _updatingDate = true);

    // Non-blocking progress hint while the API call runs.
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating statement date...'),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final updated = await _batchService.updateStatementDate(
        batchId: widget.batchId,
        date: newDate,
      );
      if (!mounted) return;

      setState(() {
        _batch = updated;
        _dateUpdated = true;
        _hasError = false;
      });

      // Always refetch so validation flags / month fields match Laravel.
      await _loadBatchDetails(quiet: true);
      SecondarySalesDataRefresh.notify();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Statement date updated successfully.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } on UnauthorizedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } on BatchDateUpdateException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty ? message : 'Unable to update statement date.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingDate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_dateUpdated);
      },
      child: Scaffold(
        appBar: ModernUIComponents.buildModernAppBar(
          title: 'Batch Details',
          subtitle: 'Batch #${widget.batchId}',
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF1E88E5),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _updatingDate ? null : () => _loadBatchDetails(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_dateUpdated),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
        ),
      );
    }
    if (_hasError) {
      return _buildError();
    }
    if (_batch == null) {
      return const Center(child: Text('Batch not found'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadBatchDetails();
        await _loadFailed();
      },
      color: const Color(0xFF1E88E5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBatchHeader(_batch!),
            if (isSecondarySalesUpload) ...[
              const SizedBox(height: 16),
              _buildViewStatementDetailsButton(_batch!),
            ],
            const SizedBox(height: 24),
            _buildBatchInfo(_batch!),
            const SizedBox(height: 24),
            _buildFailedSection(),
            const SizedBox(height: 24),
            _buildStepsSection(_batch!),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedSection() {
    if (_failedLoading && _failed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Checking for failed documents…',
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ],
        ),
      );
    }

    if (_failed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No failed documents in this batch',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          title: Text(
            'Failed Documents (${_failed.length})',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.red.shade800,
            ),
          ),
          subtitle: const Text('Retry will reuse already-extracted data'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            ..._failed.map(_buildFailedRow),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retrying ? null : () => _retrySelected(all: false),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _selectedFailed.isEmpty
                          ? 'Retry selected'
                          : 'Retry ${_selectedFailed.length} selected',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _retrying ? null : () => _retrySelected(all: true),
                    icon: _retrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.replay_circle_filled_rounded),
                    label: Text(_retrying ? 'Retrying…' : 'Retry all'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedRow(Map<String, dynamic> row) {
    final invoiceNo = row['invoice_no']?.toString() ?? 'N/A';
    final invoiceDate = row['invoice_date']?.toString();
    final customer = row['customer_name']?.toString();
    final amount = row['total_amount'];
    final reason = (row['reason'] ?? 'pod_not_created').toString();
    final isDuplicate = reason == 'duplicate_invoice';
    final isSelected = _selectedFailed.contains(invoiceNo);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        value: isSelected,
        onChanged: isDuplicate
            ? null
            : (v) {
                setState(() {
                  if (v == true) {
                    _selectedFailed.add(invoiceNo);
                  } else {
                    _selectedFailed.remove(invoiceNo);
                  }
                });
              },
        title: Text(
          invoiceNo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer != null && customer.isNotEmpty)
              Text(customer, maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(
              children: [
                if (invoiceDate != null && invoiceDate.isNotEmpty)
                  Text(
                    invoiceDate,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                if (amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '₹$amount',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDuplicate
                        ? Colors.amber.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDuplicate ? 'DUPLICATE' : 'NOT CREATED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDuplicate
                          ? Colors.amber.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewStatementDetailsButton(Batch batch) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => openSecondarySalesBatchStatementDetails(
          context,
          batchId: widget.batchId,
          batch: batch,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF450095),
          side: const BorderSide(color: Color(0xFF450095), width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '→',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchHeader(Batch batch) {
    final statusColor = _getStatusColor(batch.status);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getStatusIcon(batch.status),
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch #${batch.id}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        batch.displayStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSecondarySalesUpload) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatStatementDate(batch.effectiveStatementDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                if (_updatingDate)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (batch.canChangeStatementDate)
                  TextButton.icon(
                    onPressed: _canShowChangeDate ? _onChangeDatePressed : null,
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Change Date'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatBox('Total Files', batch.totalFiles.toString(), Icons.insert_drive_file_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox('Success', batch.successfulFiles.toString(), Icons.check_circle_rounded, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox('Failed', batch.failedFiles.toString(), Icons.error_outline_rounded, Colors.red),
              ),
            ],
          ),
          if (batch.showsValidationIssue) ...[
            const SizedBox(height: 16),
            _buildValidationIssueCard(batch),
          ],
        ],
      ),
    );
  }

  Widget _buildValidationIssueCard(Batch batch) {
    final message = (batch.validationMessage ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF57C00),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Validation Issue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5D4037),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, [Color? color]) {
    final statColor = color ?? const Color(0xFF1E88E5);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: statColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchInfo(Batch batch) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Batch Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Hospital / Company',
                batch.hospitalName,
                Icons.local_hospital_rounded,
              ),
              const Divider(height: 24),
              _buildInfoRow('Stockist', batch.stockistName, Icons.store_rounded),
              const Divider(height: 24),
              _buildInfoRow('User', batch.userName, Icons.person_rounded),
              const Divider(height: 24),
              _buildInfoRow(
                'Started At',
                _formatDate(batch.startedAt),
                Icons.access_time_rounded,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                'Completed At',
                _formatDate(batch.completedAt),
                Icons.check_circle_outline_rounded,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                'Duration',
                _formatDuration(batch.startedAt, batch.completedAt),
                Icons.timer_rounded,
              ),
            ],
          ),
        ),
        if (isSecondarySalesUpload) ...[
          const SizedBox(height: 16),
          _buildStatementInfo(batch),
        ],
      ],
    );
  }

  Widget _buildStatementInfo(Batch batch) {
    final periodFrom = _formatPeriodDate(batch.periodFrom);
    final periodTo = _formatPeriodDate(batch.periodTo);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statement Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Statement Date',
            _formatStatementDate(batch.effectiveStatementDate),
            Icons.event_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            'Statement Month',
            batch.displayStatementMonth ?? '—',
            Icons.calendar_month_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            'Period From',
            periodFrom,
            Icons.date_range_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            'Period To',
            periodTo,
            Icons.date_range_rounded,
          ),
        ],
      ),
    );
  }

  String _formatPeriodDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final date = DateTime.parse(raw);
      return _displayDateFormat.format(date);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1E88E5), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepsSection(Batch batch) {
    final steps = batch.steps;
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Processing Steps',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          ...steps.entries.map((entry) => _buildStepCard(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildStepCard(String stepName, dynamic stepData) {
    if (stepData is! Map) return const SizedBox.shrink();

    try {
      final stepMap = Map<String, dynamic>.from(stepData);
      final status = _safeString(stepMap['status']) ?? 'unknown';
      final statusColor = _getStatusColor(status);
      final stepTitle = _formatStepName(stepName);
      final isCompleted = status.toLowerCase() == 'completed';

      // Extract errors from result if they exist
      final result = stepMap['result'];
      List<dynamic> errors = [];
      if (result is Map) {
        final resultMap = Map<String, dynamic>.from(result);
        if (resultMap['errors'] is List) {
          errors = resultMap['errors'] as List<dynamic>;
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted ? statusColor.withOpacity(0.3) : Colors.grey.shade300,
            width: isCompleted ? 2 : 1,
          ),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stepTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted ? 'Completed successfully' : 'In progress',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            // Show errors only if they exist
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Errors (${errors.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...errors.take(5).map((error) {
                      String errorText = '';
                      if (error is Map) {
                        final errorMap = Map<String, dynamic>.from(error);
                        if (errorMap['error'] != null) {
                          errorText = errorMap['error'].toString();
                        } else {
                          errorText = error.toString();
                        }
                      } else {
                        errorText = error.toString();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4, right: 8),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                errorText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (errors.length > 5)
                      Text(
                        '... and ${errors.length - 5} more error(s)',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.red.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      print('Error building step card for $stepName: $e');
      return const SizedBox.shrink();
    }
  }

  String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value.toString();
  }

  String _formatStepName(String stepName) {
    return stepName
        .replaceAll('_', ' ')
        .replaceAll('step', 'Step')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 12),
            const Text(
              'Failed to load batch details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBatchDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

