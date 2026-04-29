import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class ExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const ExpenseScreen({super.key, this.editData});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _otherAmtController = TextEditingController();
  final _remarkController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _calcData;
  bool _isLoading = false;
  bool _isSubmitting = false;
  File? _attachment;
  double _displayTotal = 0.0;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      final d = widget.editData!;
      _otherAmtController.text = (d['other_amount'] ?? '0').toString();
      _remarkController.text = d['remarks'] ?? '';
      _selectedDate = DateTime.tryParse(d['expense_date'] ?? '') ?? DateTime.now();
      _isLocked = d['is_submitted_for_month'] == 1;
    }
    _otherAmtController.addListener(_recalculateTotal);
    _fetchCalculation();
  }

  @override
  void dispose() {
    _otherAmtController.removeListener(_recalculateTotal);
    _otherAmtController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _recalculateTotal() {
    if (_calcData == null) return;
    final da = _toDouble(_calcData!['da_amount']);
    final ta = _toDouble(_calcData!['ta_amount']);
    final other = double.tryParse(_otherAmtController.text) ?? 0;
    setState(() => _displayTotal = da + ta + other);
  }

  Future<void> _fetchCalculation() async {
    setState(() {
      _isLoading = true;
      _calcData = null;
    });
    try {
      final data = await ApiService()
          .calculateExpense(DateFormat('yyyy-MM-dd').format(_selectedDate));
      setState(() => _calcData = data);
      _recalculateTotal();
    } catch (_) {
      // Show empty state
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Expense' : 'Daily Claim',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLocked) _buildLockedBanner(),
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  if (_calcData != null) ...[
                    _buildRouteTimeline(),
                    const SizedBox(height: 14),
                    _buildAllowanceCards(),
                    const SizedBox(height: 14),
                    if (!_isLocked) _buildManualInputCard() else _buildLockedDetailsCard(),
                  ] else
                    _buildEmptyState(),
                ],
              ),
            ),
      bottomSheet: _calcData != null ? _buildBottomBar() : null,
    );
  }

  // ─── Locked Banner ────────────────────────────────────────────────────────────

  Widget _buildLockedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This expense is locked — month has been submitted for approval.',
              style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date Picker ──────────────────────────────────────────────────────────────

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _isLocked
          ? null
          : () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: Color(0xFF4A148C)),
                  ),
                  child: child!,
                ),
              );
              if (d != null) {
                setState(() => _selectedDate = d);
                _fetchCalculation();
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today,
                  color: Color(0xFF4A148C), size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expense Date',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Spacer(),
            if (!_isLocked)
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ─── Route Timeline ───────────────────────────────────────────────────────────

  Widget _buildRouteTimeline() {
    final route = List<Map<String, dynamic>>.from(_calcData!['route'] ?? []);
    if (route.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF4A148C), size: 18),
              const SizedBox(width: 8),
              Text("Today's Route",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${route.length} stops',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF4A148C))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: route.length,
              itemBuilder: (_, i) {
                final stop = route[i];
                final color = _typeColor(stop['type']);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(stop['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(stop['area'] ?? '',
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    if (i < route.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 42),
                        child: Row(
                          children: List.generate(
                            4,
                            (_) => Container(
                              width: 5,
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'OS':
        return Colors.red;
      case 'EX':
        return Colors.orange;
      default:
        return const Color(0xFF4A148C);
    }
  }

  // ─── DA + TA Cards ────────────────────────────────────────────────────────────

  Widget _buildAllowanceCards() {
    return Column(
      children: [
        _buildDaCard(),
        const SizedBox(height: 10),
        _buildTaCard(),
      ],
    );
  }

  Widget _buildDaCard() {
    final daType = (_calcData!['da_type'] ?? 'HQ').toString().toUpperCase();
    final daAmount = _toDouble(_calcData!['da_amount']);
    final labels = {
      'HQ': 'HQ Daily Allowance',
      'EX': 'Ex-HQ Daily Allowance',
      'OS': 'Outstation Daily Allowance',
    };
    final colors = {
      'OS': Colors.red,
      'EX': Colors.orange,
      'HQ': const Color(0xFF4A148C),
    };
    final label = labels[daType] ?? 'Daily Allowance';
    final color = colors[daType] ?? const Color(0xFF4A148C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.person_outline, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text('₹${_fmt(daAmount)}',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4A148C))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(daType,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaCard() {
    final totalKm = _toDouble(_calcData!['total_km']);
    final taAmount = _toDouble(_calcData!['ta_amount']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.directions_car_outlined,
                color: Colors.green.shade700, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Travel Allowance (SFC Based)',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text('₹${_fmt(taAmount)}',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fmt(totalKm)} km',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Distance',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Manual Input Card ────────────────────────────────────────────────────────

  Widget _buildManualInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional Details',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          TextField(
            controller: _otherAmtController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Other Expenses (Toll, Parking, Misc)',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF4A148C))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Remarks',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF4A148C))),
            ),
          ),
          const SizedBox(height: 14),
          _buildAttachmentButton(),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton() {
    return InkWell(
      onTap: () async {
        final src = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () =>
                        Navigator.pop(context, ImageSource.camera)),
                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () =>
                        Navigator.pop(context, ImageSource.gallery)),
              ],
            ),
          ),
        );
        if (src != null) {
          final picked =
              await ImagePicker().pickImage(source: src, imageQuality: 70);
          if (picked != null) setState(() => _attachment = File(picked.path));
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _attachment != null ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _attachment != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              _attachment != null
                  ? Icons.check_circle
                  : Icons.camera_alt_outlined,
              color: _attachment != null ? Colors.green : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _attachment != null
                    ? 'Bill / Receipt Attached'
                    : 'Attach Bill or Receipt',
                style: TextStyle(
                    color: _attachment != null
                        ? Colors.green.shade700
                        : Colors.grey.shade600),
              ),
            ),
            if (_attachment != null)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(_attachment!,
                        width: 42, height: 42, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _attachment = null),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.red),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ─── Locked Details Card ──────────────────────────────────────────────────────

  Widget _buildLockedDetailsCard() {
    final d = widget.editData!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('Additional Details (Locked)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
            ],
          ),
          const Divider(height: 16),
          _lockedRow(
              'Other Expenses', '₹${_fmt(_toDouble(d['other_amount']))}'),
          if ((d['remarks'] ?? '').toString().isNotEmpty)
            _lockedRow('Remarks', d['remarks']),
        ],
      ),
    );
  }

  Widget _lockedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_outlined,
                size: 68, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text('No visits found for this date',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'Please ensure the DCR is submitted for this date before claiming expense.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Claim',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text(
                '₹${_displayTotal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A148C)),
              ),
            ],
          ),
          const Spacer(),
          if (!_isLocked)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A148C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('SAVE',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
        ],
      ),
    );
  }

  // ─── Submit ───────────────────────────────────────────────────────────────────

  void _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'da_type': _calcData!['da_type'].toString(),
        'da_amount': _calcData!['da_amount'].toString(),
        'ta_distance': _calcData!['total_km'].toString(),
        'ta_amount': _calcData!['ta_amount'].toString(),
        'other_amount':
            _otherAmtController.text.trim().isEmpty ? '0' : _otherAmtController.text.trim(),
        'remarks': _remarkController.text.trim(),
      };

      await ApiService().submitExpense(payload, _attachment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Expense saved successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
