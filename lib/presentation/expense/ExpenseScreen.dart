import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

// Represents one itemized other-expense entry (Toll, Courier, Parking, etc.)
class OtherExpenseItem {
  String type;
  final TextEditingController amountController;
  File? bill;

  OtherExpenseItem({required this.type, String amount = '', this.bill})
      : amountController = TextEditingController(text: amount);

  void dispose() => amountController.dispose();

  double get amount => double.tryParse(amountController.text) ?? 0;
}

class ExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const ExpenseScreen({super.key, this.editData});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _remarkController = TextEditingController();
  final _manualDaController = TextEditingController();
  final _manualKmController = TextEditingController();
  final _manualTaController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _calcData;
  String? _expenseMode; // 'FIELD', 'NFW', 'TRANSIT'
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<File> _attachments = [];
  double _displayTotal = 0.0;
  bool _isLocked = false;

  // Travel details
  String _modeOfTravel = 'Bike';
  String? _startLocation;
  String? _endLocation;
  String? _fromLocation; // NFW / TRANSIT from dropdown
  double? _endLocationKm; // km_from_hq of selected end location
  List<Map<String, dynamic>> _taRoutes = [];
  String? _userHq;
  double _autoTaKm = 0;
  double _autoTaFare = 0;
  double _nfwDaAmount = 0;
  bool _nfwRateLoaded = false;
  bool _isLoadingNfwRate = false;
  String _nfwType = 'Meeting'; // 'Meeting' | 'Training'
  String? _transitFromTown; // last DCR area or HQ for TRANSIT
  bool _isLoadingTransitFrom = false;
  Map<String, dynamic> _allRates = {}; // all DA rates from expense_rates by designation
  String? _destStationType; // station_type of selected destination: HQ | EXHQ | OS
  String? _selectedFrom; // user-selected from location (overrides auto-detected)
  bool _isTwoWay = false;
  double _baseRouteKm = 0;
  double _baseRouteFare = 0;
  bool _isRecalculating = false; // true while server recalc API call is in flight
  String _serverTaMode = 'road'; // 'road' | 'train' — returned by recalculate API

  // Itemized other expenses (Toll, Courier, Parking, Food Bill, Others)
  List<OtherExpenseItem> _otherExpenses = [];
  // DA overrides when user selects a destination (field mode)
  String? _fieldDaTypeOverride;
  double? _fieldDaAmountOverride;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      final d = widget.editData!;
      // Restore legacy single other_amount as one item for backward compat
      final legacyOther = double.tryParse((d['other_amount'] ?? '0').toString()) ?? 0;
      if (legacyOther > 0) {
        final item = OtherExpenseItem(type: 'Other', amount: legacyOther.toStringAsFixed(2));
        item.amountController.addListener(_recalculateTotal);
        _otherExpenses.add(item);
      }
      _remarkController.text = d['remarks'] ?? '';
      _selectedDate = DateTime.tryParse(d['expense_date'] ?? '') ?? DateTime.now();
      _isLocked = d['is_submitted_for_month'] == 1;

      final daType = (d['da_type'] ?? '').toString().toUpperCase();
      if (daType == 'NFW' || daType == 'MEETING' || daType == 'TRAINING' ||
          daType == 'TRANSIT_DA') {
        _expenseMode = 'NFW';
        _nfwType = daType == 'TRAINING'
            ? 'Training'
            : daType == 'TRANSIT_DA'
                ? 'Transit'
                : 'Meeting';
        _manualDaController.text = (d['da_amount'] ?? '0').toString();
      } else if (daType == 'TRANSIT') {
        _expenseMode = 'TRANSIT';
        _manualKmController.text = (d['ta_distance'] ?? '0').toString();
        _manualTaController.text = (d['ta_amount'] ?? '0').toString();
        _transitFromTown = d['start_location']?.toString();
        _selectedFrom = d['start_location']?.toString();
      }
      _modeOfTravel = (d['mode_of_travel'] ?? 'Bike').toString();
      _startLocation = (d['start_location'] ?? 'HQ').toString();
      _endLocation = d['end_location']?.toString();
      _fromLocation = d['start_location']?.toString();
    }
    _manualDaController.addListener(_recalculateTotal);
    _manualTaController.addListener(_recalculateTotal);
    _loadTaRoutes();
    _loadAllExpenseRates();
    _fetchCalculation();
  }

  @override
  void dispose() {
    _manualDaController.removeListener(_recalculateTotal);
    _manualTaController.removeListener(_recalculateTotal);
    for (final e in _otherExpenses) { e.dispose(); }
    _remarkController.dispose();
    _manualDaController.dispose();
    _manualKmController.dispose();
    _manualTaController.dispose();
    super.dispose();
  }

  double get _totalOtherAmount =>
      _otherExpenses.fold(0.0, (sum, e) => sum + e.amount);

  void _recalculateTotal() {
    double da = 0, ta = 0;
    if (_expenseMode == 'FIELD' && _calcData != null) {
      da = _fieldDaAmountOverride ?? _toDouble(_calcData!['da_amount']);
      // SFA route TA takes precedence over DCR-based TA when destination selected
      ta = _autoTaFare > 0
          ? _autoTaFare
          : _toDouble(_calcData!['ta_amount']);
    } else if (_expenseMode == 'NFW') {
      da = double.tryParse(_manualDaController.text) ?? _nfwDaAmount;
      // Include TA when user has selected a destination for travel
      ta = _autoTaFare;
    } else if (_expenseMode == 'TRANSIT') {
      ta = _autoTaFare > 0
          ? _autoTaFare
          : (double.tryParse(_manualTaController.text) ?? 0);
    }
    setState(() => _displayTotal = da + ta + _totalOtherAmount);
  }

  Future<void> _fetchCalculation() async {
    if (_expenseMode == 'NFW' || _expenseMode == 'TRANSIT') {
      _recalculateTotal();
      return;
    }
    setState(() {
      _isLoading = true;
      _calcData = null;
    });
    try {
      final data = await ApiService()
          .calculateExpense(DateFormat('yyyy-MM-dd').format(_selectedDate));
      setState(() {
        _calcData = data;
        _expenseMode = 'FIELD';
        final dt = (_calcData!['da_type'] ?? '').toString().toUpperCase();
        _startLocation = (dt == 'HQ' || dt == 'EX')
            ? 'HQ'
            : (_calcData!['start_location']?.toString() ?? 'HQ');
      });
      _recalculateTotal();
    } catch (_) {
      // No DCR — show expense type selector
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
                  if (_expenseMode == 'FIELD' && _calcData != null) ...[
                    _buildRouteTimeline(),
                    const SizedBox(height: 14),
                    _buildFieldTravelSection(),
                    const SizedBox(height: 14),
                    _buildAllowanceCards(),
                    const SizedBox(height: 14),
                    if (!_isLocked)
                      _buildManualInputCard()
                    else
                      _buildLockedDetailsCard(),
                  ] else if (_expenseMode == 'NFW') ...[
                    _buildNfwBanner(),
                    const SizedBox(height: 14),
                    if (!_isLocked)
                      _buildNfwInputCard()
                    else
                      _buildLockedDetailsCard(),
                  ] else if (_expenseMode == 'TRANSIT') ...[
                    _buildTransitBanner(),
                    const SizedBox(height: 14),
                    if (!_isLocked)
                      _buildTransitInputCard()
                    else
                      _buildLockedDetailsCard(),
                  ] else
                    _buildExpenseTypeSelector(),
                ],
              ),
            ),
      bottomSheet: _expenseMode != null ? _buildBottomBar() : null,
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
                setState(() {
                  _selectedDate = d;
                  _expenseMode = null; // reset on date change
                });
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

  // ─── Expense Type Selector (no DCR found) ─────────────────────────────────────

  Widget _buildExpenseTypeSelector() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No field work DCR found for this date. Select the type of expense you want to claim:',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTypeOptionCard(
          title: 'Non-Field Work (NFW)',
          subtitle: 'Office work, training, admin, meetings, etc.',
          icon: Icons.business_center_outlined,
          color: Colors.blue,
          onTap: () {
            setState(() => _expenseMode = 'NFW');
            _fetchNfwDaRate();
          },
        ),
        const SizedBox(height: 12),
        _buildTypeOptionCard(
          title: 'In Transit',
          subtitle: 'Traveling to / from outstation without field visits',
          icon: Icons.directions_bus_outlined,
          color: Colors.orange,
          onTap: () {
            setState(() => _expenseMode = 'TRANSIT');
            _loadTransitFromLocation();
          },
        ),
      ],
    );
  }

  Widget _buildTypeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7), size: 22),
          ],
        ),
      ),
    );
  }

  // ─── NFW Banner ───────────────────────────────────────────────────────────────

  Widget _buildNfwBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.business_center_outlined,
              color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Non-Field Work (NFW)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        fontSize: 13)),
                Text('Claiming DA for non-field activity',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade600)),
              ],
            ),
          ),
          if (!_isLocked)
            TextButton(
              onPressed: () => setState(() => _expenseMode = null),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32)),
              child: const Text('Change', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ─── Transit Banner ───────────────────────────────────────────────────────────

  Widget _buildTransitBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_outlined,
              color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('In Transit',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontSize: 13)),
                Text('Travel allowance for transit day',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade600)),
              ],
            ),
          ),
          if (!_isLocked)
            TextButton(
              onPressed: () => setState(() => _expenseMode = null),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32)),
              child: const Text('Change', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ─── NFW Input Card ───────────────────────────────────────────────────────────

  Widget _buildNfwInputCard() {
    final daAmt =
        double.tryParse(_manualDaController.text) ?? _nfwDaAmount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NFW Details',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          // NFW Type selector
          Text('Activity Type',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Row(
            children: ['Meeting', 'Training', 'Transit'].map((type) {
              final sel = _nfwType == type;
              final icon = type == 'Training'
                  ? Icons.school_outlined
                  : type == 'Transit'
                      ? Icons.directions_bus_outlined
                      : Icons.groups_outlined;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: _isLocked
                      ? null
                      : () {
                          if (_nfwType != type) {
                            setState(() {
                              _nfwType = type;
                              _nfwRateLoaded = false;
                            });
                            _fetchNfwDaRate();
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF4A148C) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF4A148C)
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 15,
                            color: sel ? Colors.white : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(type,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // From + To — drives TA and (for Meeting) DA rate
          _buildFromToSection(accent: Colors.blue.shade600),
          if (_autoTaKm > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_car_outlined,
                      color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 10),
                  Text('${_fmt(_autoTaKm)} km',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                  const SizedBox(width: 12),
                  Text('TA: ₹${_fmt(_autoTaFare)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: 15)),
                  if (_modeOfTravel == 'Bike') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('₹3.5/km',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // DA Amount — auto-filled from expense_rates by designation
          _isLoadingNfwRate
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nfwType == 'Training'
                                  ? 'Training Allowance'
                                  : _nfwType == 'Transit'
                                      ? 'Transit Day Allowance'
                                      : 'Meeting Allowance (HQ)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade600),
                            ),
                            Text('₹${_fmt(daAmt)}',
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800)),
                            Text(
                              _nfwType == 'Training'
                                  ? 'From: expense_rates → training'
                                  : _nfwType == 'Transit'
                                      ? 'From: expense_rates → transit'
                                      : 'From: expense_rates → da_hq_non_metro',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade400),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.lock_outline,
                          size: 16, color: Colors.blue.shade300),
                    ],
                  ),
                ),
          const SizedBox(height: 12),
          Text('Mode of Travel',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          _buildModeChips(),
          const SizedBox(height: 12),
          _buildOtherExpensesSection(),
          const SizedBox(height: 12),
          TextField(
            controller: _remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Remarks / Activity Description',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF4A148C))),
            ),
          ),
          const SizedBox(height: 14),
          _buildAttachmentsSection(),
        ],
      ),
    );
  }

  // ─── Transit Input Card ───────────────────────────────────────────────────────

  Widget _buildTransitInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transit Details',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 14),

          // From + To — user selects both; auto-detects mode and calculates TA
          if (_isLoadingTransitFrom)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            _buildFromToSection(accent: Colors.orange.shade600),
          const SizedBox(height: 12),

          Text('Mode of Travel',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          _buildModeChips(),
          const SizedBox(height: 14),

          // Auto-calculated km + TA summary (also shown locked at 0 when same location)
          if (_autoTaKm > 0 || _isSameLocation()) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Distance',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade600)),
                        const SizedBox(height: 2),
                        Text('${_fmt(_autoTaKm)} km',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.orange.shade200),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Travel Allowance',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.orange.shade600)),
                            const SizedBox(width: 4),
                            if (_modeOfTravel == 'Bike')
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: const Text('₹3.5/km',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('₹${_fmt(_autoTaFare)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.orange.shade800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Manual entry when no route found or editing old record
            TextField(
              controller: _manualKmController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              onChanged: (_) => _recalculateTotal(),
              decoration: InputDecoration(
                labelText: 'Distance Traveled',
                suffixText: 'km',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.orange.shade600)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualTaController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                labelText: 'Travel Allowance Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.orange.shade600)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          _buildOtherExpensesSection(),
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
          _buildAttachmentsSection(),
        ],
      ),
    );
  }

  // ─── Locations ───────────────────────────────────────────────────────────────

  Future<void> _loadTaRoutes() async {
    try {
      final result = await ApiService().getTaRoutes();
      if (!mounted) return;
      final routes = List<Map<String, dynamic>>.from(
          result['routes'] as List? ?? []);
      final hqLocation = result['hq_location'] as String?;
      setState(() {
        _taRoutes = routes;
        // Prefer from_town_code from first route; fallback to gst_employee_profile.head_qtr
        _userHq = routes.isNotEmpty
            ? routes.first['from_town_code']?.toString()
            : hqLocation;
        _userHq ??= hqLocation;
      });
      if (_expenseMode == 'TRANSIT' && _endLocation != null) {
        _updateTaFromSelection();
      }
    } catch (_) {}
  }

  Future<void> _loadAllExpenseRates() async {
    try {
      final data = await ApiService().getAllExpenseRates();
      if (mounted) setState(() => _allRates = data);
    } catch (_) {}
  }

  Future<void> _loadTransitFromLocation() async {
    setState(() => _isLoadingTransitFrom = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await ApiService().getTransitFromLocation(dateStr);
      if (!mounted) return;
      setState(() {
        _transitFromTown = data['from_town']?.toString();
      });
      if (_endLocation != null) _updateTaFromSelection();
    } catch (_) {
      if (mounted) {
        setState(() {
          _transitFromTown = _userHq;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingTransitFrom = false);
    }
  }

  Future<void> _fetchNfwDaRate() async {
    if (widget.editData != null) return;
    setState(() => _isLoadingNfwRate = true);
    try {
      final data = await ApiService().getNfwDaRate(type: _nfwType);
      if (!mounted) return;
      final amount = (data['da_amount'] as num?)?.toDouble() ?? 0;
      setState(() {
        _nfwDaAmount = amount;
        _nfwRateLoaded = true;
        _manualDaController.text = amount.toStringAsFixed(2);
      });
      _recalculateTotal();
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingNfwRate = false);
    }
  }

  // Unified destination selection handler — called by all three expense modes.
  // Determines station_type → DA, and kms/fare → TA from expense_rates_ta.
  bool _isSameLocation() {
    final from = (_selectedFrom ?? _transitFromTown ?? _userHq ?? '').toLowerCase();
    final to = (_endLocation ?? '').toLowerCase();
    return from.isNotEmpty && to.isNotEmpty && from == to;
  }

  void _onDestinationSelected(String? town) {
    if (town == null) return;

    final from = _selectedFrom ?? _transitFromTown ?? _userHq ?? '';

    // Same from/to → zero km
    if (from.isNotEmpty && from.toLowerCase() == town.toLowerCase()) {
      _baseRouteKm = 0;
      _baseRouteFare = 0;
      setState(() {
        _endLocation = town;
        _destStationType = null;
        _autoTaKm = 0;
        _autoTaFare = 0;
        _fieldDaTypeOverride = null;
        _fieldDaAmountOverride = null;
        _manualKmController.clear();
        _manualTaController.clear();
      });
      _recalculateTotal();
      return;
    }

    setState(() => _endLocation = town);

    // FIELD mode: server recalculates full day route with all policies applied
    if (_expenseMode == 'FIELD') {
      _recalculateFromServer(town);
    } else {
      // NFW / TRANSIT: local lookup from _taRoutes
      _recalculateFromLocalRoutes(town);
    }
  }

  /// Called when last location changes in FIELD mode.
  /// Hits recalculate-location API which applies:
  ///   FIXED mode → fare, road km >150 → train slab, else km×3.5
  ///   DA from station_type (OS > EX > HQ)
  Future<void> _recalculateFromServer(String toTown) async {
    // Resolve the from location the same way _onDestinationSelected does
    final fromTown = _selectedFrom ?? _transitFromTown ?? _userHq ?? '';
    if (fromTown.isEmpty) {
      _recalculateFromLocalRoutes(toTown);
      return;
    }

    setState(() => _isRecalculating = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final result  = await ApiService()
          .recalculateOnLastLocation(dateStr, fromTown, toTown);
      if (!mounted) return;

      final totalKm  = (result['total_km']  as num?)?.toDouble() ?? 0;
      final fare     = (result['ta_amount'] as num?)?.toDouble() ?? 0;
      final taMode   = result['ta_mode']?.toString() ?? 'road';
      final daType   = (result['da_type']?.toString() ?? 'HQ').toUpperCase();
      final daAmount = (result['da_amount'] as num?)?.toDouble() ?? 0;

      // Use station_type from server response when available;
      // otherwise derive it from da_type for the badge display
      final rawStation = result['station_type']?.toString() ?? '';
      String stationType;
      if (rawStation.contains('OS') || rawStation.contains('OUT')) {
        stationType = 'OS';
      } else if (rawStation.contains('EX')) {
        stationType = 'EXHQ';
      } else {
        stationType = daType == 'OS' ? 'OS' : daType == 'EX' ? 'EXHQ' : 'HQ';
      }

      _baseRouteKm   = totalKm;
      _baseRouteFare = fare;

      setState(() {
        _serverTaMode          = taMode;
        _destStationType       = stationType;
        _fieldDaTypeOverride   = daType;
        _fieldDaAmountOverride = daAmount;
        _autoTaKm   = _isTwoWay ? totalKm * 2 : totalKm;
        _autoTaFare = _isTwoWay ? fare    * 2 : fare;
        _manualKmController.text = _autoTaKm.toStringAsFixed(1);
        _manualTaController.text = _autoTaFare.toStringAsFixed(2);
      });
      _recalculateTotal();
    } catch (_) {
      // Fallback to local route table if server call fails
      _recalculateFromLocalRoutes(toTown);
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  /// NFW / TRANSIT local fare lookup from _taRoutes.
  /// Supports A→B and B→A vice-versa.
  /// FIXED mode_of_travel → uses fare column directly.
  void _recalculateFromLocalRoutes(String town) {
    final from = _selectedFrom ?? _transitFromTown ?? _userHq ?? '';

    // Resolve station_type for DA
    final locationRoutes = _taRoutes.where((r) {
      final to = (r['to_town_code']?.toString() ?? '').toLowerCase();
      final fr = (r['from_town_code']?.toString() ?? '').toLowerCase();
      return to == town.toLowerCase() || fr == town.toLowerCase();
    }).toList();

    String stationType = 'HQ';
    if (locationRoutes.isNotEmpty) {
      final raw = (locationRoutes.first['station_type']?.toString() ?? '').toUpperCase();
      if (raw.contains('OS') || raw.contains('OUT')) {
        stationType = 'OS';
      } else if (raw.contains('EX')) {
        stationType = 'EXHQ';
      }
    }

    // Route candidates: A→B then B→A (vice versa)
    bool matches(Map r, String f, String t) =>
        (r['from_town_code']?.toString() ?? '').toLowerCase() == f.toLowerCase() &&
        (r['to_town_code']?.toString() ?? '').toLowerCase() == t.toLowerCase();

    var candidates = _taRoutes.where((r) => matches(r, from, town)).toList();
    if (candidates.isEmpty) {
      candidates = _taRoutes.where((r) => matches(r, town, from)).toList();
    }
    if (candidates.isEmpty) {
      candidates = locationRoutes;
    }

    double km = 0, ta = 0;
    if (candidates.isNotEmpty) {
      final autoMode = _normalizeModeOfTravel(
          candidates.first['mode_of_travel']?.toString() ?? '');
      if (autoMode != null) _modeOfTravel = autoMode;

      final route = candidates.firstWhere(
        (r) => (r['mode_of_travel']?.toString() ?? '').toLowerCase() ==
            _modeOfTravel.toLowerCase(),
        orElse: () => candidates.first,
      );

      km = double.tryParse(route['kms']?.toString() ?? '0') ?? 0;
      final fareRaw = route['fare']?.toString() ?? '';
      final fareFromTable = (fareRaw == 'EMPTY' || fareRaw.isEmpty)
          ? 0.0
          : (double.tryParse(fareRaw) ?? 0.0);
      final modeUpper = (route['mode_of_travel']?.toString() ?? '').toUpperCase();

      // Fare policy: FIXED → table fare, Bike → km×3.5, others → table fare or km×3.5
      if (modeUpper == 'FIXED') {
        ta = fareFromTable;
      } else if (_modeOfTravel == 'Bike') {
        ta = km * 3.5;
      } else {
        ta = fareFromTable > 0 ? fareFromTable : km * 3.5;
      }
    }

    // DA: NFW Meeting adjusts by station_type
    if (_expenseMode == 'NFW' && _nfwType == 'Meeting') {
      final daAmount = stationType == 'OS'
          ? ((_allRates['da_os'] as num?)?.toDouble() ?? _nfwDaAmount)
          : stationType == 'EXHQ'
              ? ((_allRates['da_exhq'] as num?)?.toDouble() ?? _nfwDaAmount)
              : ((_allRates['da_hq_non_metro'] as num?)?.toDouble() ?? _nfwDaAmount);
      _nfwDaAmount = daAmount;
      _manualDaController.text = daAmount.toStringAsFixed(2);
    }

    _baseRouteKm  = km;
    _baseRouteFare = ta;
    setState(() {
      _destStationType = stationType;
      _autoTaKm   = _isTwoWay ? km * 2 : km;
      _autoTaFare = _isTwoWay ? ta * 2 : ta;
      _manualKmController.text = _autoTaKm.toStringAsFixed(1);
      _manualTaController.text = _autoTaFare.toStringAsFixed(2);
    });
    _recalculateTotal();
  }

  void _applyWayMultiplier() {
    if (_baseRouteKm <= 0) return;
    setState(() {
      _autoTaKm = _isTwoWay ? _baseRouteKm * 2 : _baseRouteKm;
      _autoTaFare = _isTwoWay ? _baseRouteFare * 2 : _baseRouteFare;
      _manualKmController.text = _autoTaKm.toStringAsFixed(1);
      _manualTaController.text = _autoTaFare.toStringAsFixed(2);
    });
    _recalculateTotal();
  }

  String? _normalizeModeOfTravel(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('train') || m.contains('rail')) return 'Train';
    if (m.contains('bike') || m.contains('motor') || m.contains('two')) return 'Bike';
    if (m.contains('car') || m.contains('taxi') || m.contains('cab')) return 'Car';
    if (m.contains('bus')) return 'Bus';
    if (m.contains('auto')) return 'Auto';
    return null;
  }

  // Kept for backward compatibility — delegates to unified handler
  void _updateTaFromSelection() => _onDestinationSelected(_endLocation);


  // ─── Shared: Station Type Badge ───────────────────────────────────────────────

  Widget _buildStationTypeBadge(String? type) {
    final t = type?.toUpperCase() ?? 'HQ';
    Color bg, fg;
    String label;
    if (t == 'OS') {
      bg = Colors.red.shade100; fg = Colors.red.shade700; label = 'Outstation';
    } else if (t == 'EXHQ') {
      bg = Colors.orange.shade100; fg = Colors.orange.shade700; label = 'Ex-HQ';
    } else {
      bg = const Color(0xFFEDE7F6); fg = const Color(0xFF4A148C); label = 'HQ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ─── Shared: From + To Route Section ─────────────────────────────────────────

  // All unique locations — union of from_town_code and to_town_code
  List<String> _allLocations() {
    final locs = <String>{};
    for (final r in _taRoutes) {
      final f = r['from_town_code']?.toString() ?? '';
      final t = r['to_town_code']?.toString() ?? '';
      if (f.isNotEmpty) locs.add(f);
      if (t.isNotEmpty) locs.add(t);
    }
    return locs.toList()..sort();
  }

  Widget _buildFromToSection({required Color accent}) {
    final allLocs = _allLocations();
    if (allLocs.isEmpty) return const SizedBox.shrink();

    final autoFrom = _selectedFrom ?? _transitFromTown ?? _userHq;
    final safeFrom = allLocs.contains(autoFrom) ? autoFrom : null;
    final safeTo = allLocs.contains(_endLocation) ? _endLocation : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeFrom,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.my_location, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          hint: Text('Select origin',
              style:
                  TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          items: allLocs
              .map((f) => DropdownMenuItem<String>(
                    value: f,
                    child: Text(f, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: _isLocked
              ? null
              : (val) {
                  setState(() {
                    _selectedFrom = val;
                    _endLocation = null;
                    _autoTaKm = 0;
                    _autoTaFare = 0;
                    _baseRouteKm = 0;
                    _baseRouteFare = 0;
                    _destStationType = null;
                    _fieldDaTypeOverride = null;
                    _fieldDaAmountOverride = null;
                    _manualKmController.clear();
                    _manualTaController.clear();
                  });
                  _recalculateTotal();
                },
        ),
        const SizedBox(height: 12),
        Text('To',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: safeTo,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.location_on_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                hint: Text('Select destination',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13)),
                items: allLocs
                    .map((d) => DropdownMenuItem<String>(
                          value: d,
                          child:
                              Text(d, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _isLocked ? null : _onDestinationSelected,
              ),
            ),
            if (_destStationType != null) ...[
              const SizedBox(width: 8),
              _buildStationTypeBadge(_destStationType),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // One Way / Two Way toggle
        Row(
          children: [
            Text('Journey Type',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(width: 12),
            _buildWayChip(label: 'One Way', selected: !_isTwoWay, onTap: () {
              if (_isTwoWay) {
                setState(() => _isTwoWay = false);
                _applyWayMultiplier();
              }
            }),
            const SizedBox(width: 8),
            _buildWayChip(label: 'Two Way', selected: _isTwoWay, onTap: () {
              if (!_isTwoWay) {
                setState(() => _isTwoWay = true);
                _applyWayMultiplier();
              }
            }),
            if (_isTwoWay && _autoTaKm > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Text('× 2 = ${_fmt(_autoTaKm)} km',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWayChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isLocked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A148C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFF4A148C) : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  // ─── Mode of Travel Chips ─────────────────────────────────────────────────────

  Widget _buildModeChips() {
    const modes = ['Bike', 'Car', 'Bus', 'Train', 'Auto'];
    const icons = {
      'Bike': Icons.two_wheeler,
      'Car': Icons.directions_car,
      'Bus': Icons.directions_bus,
      'Train': Icons.train,
      'Auto': Icons.electric_rickshaw,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: modes.map((m) {
        final sel = _modeOfTravel == m;
        return GestureDetector(
          onTap: _isLocked
              ? null
              : () {
                  setState(() => _modeOfTravel = m);
                  if (_expenseMode == 'TRANSIT') _updateTaFromSelection();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF4A148C) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel
                      ? const Color(0xFF4A148C)
                      : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icons[m]!,
                    size: 14,
                    color: sel ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(m,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.grey.shade700)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Field Travel Section ─────────────────────────────────────────────────────

  Widget _buildFieldTravelSection() {
    // Prefer SFA route KM when destination selected; fallback to DCR total_km
    final autoKm = _autoTaKm > 0 ? _autoTaKm : _toDouble(_calcData!['total_km']);
    final kmSource = _autoTaKm > 0 ? 'SFA Route' : 'DCR Route';

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
              const Icon(Icons.swap_horiz, color: Color(0xFF4A148C), size: 18),
              const SizedBox(width: 8),
              Text('Travel Details',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),

          // From + To — shared picker used across all expense types
          _buildFromToSection(accent: const Color(0xFF4A148C)),
          const SizedBox(height: 14),

          // Mode of Travel
          Text('Mode of Travel',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          _buildModeChips(),
          const SizedBox(height: 14),

          // KM — read-only when route km found; manual entry only when
          // destination is selected but no matching route exists in expense_rates_ta
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Distance ($kmSource)',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 4),
              _endLocation != null && _autoTaKm == 0 && !_isSameLocation()
                  ? TextField(
                      controller: _manualKmController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => _recalculateTotal(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        suffixText: 'km',
                        hintText: 'Enter distance',
                        helperText:
                            'No route found for this destination — enter km manually',
                        helperStyle:
                            TextStyle(fontSize: 10, color: Colors.orange.shade600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF4A148C))),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten,
                              size: 14, color: Color(0xFF4A148C)),
                          const SizedBox(width: 6),
                          Text('${_fmt(autoKm)} km',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A148C))),
                          const Spacer(),
                          Icon(Icons.lock_outline,
                              size: 12, color: Colors.purple.shade300),
                        ],
                      ),
                    ),
            ],
          ),
        ],
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
    final daType = (_fieldDaTypeOverride ?? (_calcData!['da_type'] ?? 'HQ')).toString().toUpperCase();
    final daAmount = _fieldDaAmountOverride ?? _toDouble(_calcData!['da_amount']);
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
    final sfaBased = _autoTaKm > 0;
    final isTrain  = _serverTaMode == 'train';
    final totalKm  = sfaBased ? _autoTaKm  : _toDouble(_calcData!['total_km']);
    final taAmount = sfaBased ? _autoTaFare : _toDouble(_calcData!['ta_amount']);

    final taColor = isTrain ? Colors.indigo : (sfaBased ? Colors.teal : Colors.green);
    final taLabel = isTrain
        ? 'Travel Allowance (Train)'
        : sfaBased
            ? 'Travel Allowance (SFA Route)'
            : 'Travel Allowance (DCR Route)';
    final taIcon = isTrain ? Icons.train : Icons.directions_car_outlined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isTrain
                  ? Colors.indigo.shade200
                  : sfaBased
                      ? Colors.teal.shade200
                      : Colors.grey.shade200)),
      child: _isRecalculating
          ? const SizedBox(
              height: 72,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Recalculating fare…',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: taColor.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(taIcon, color: taColor.shade700, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(taLabel,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          if (isTrain) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.indigo.shade600,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('TRAIN',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ] else if (sfaBased && _modeOfTravel == 'Bike') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.teal.shade600,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('₹3.5/km',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('₹${_fmt(taAmount)}',
                          style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: taColor.shade700)),
                      if (sfaBased && _destStationType != null)
                        Row(children: [
                          _buildStationTypeBadge(_destStationType),
                          const SizedBox(width: 6),
                          Text('→ $_endLocation',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                        ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_fmt(totalKm)} km',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: taColor.shade700)),
                    Text(isTrain ? 'train km' : sfaBased ? 'SFA km' : 'DCR km',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
    );
  }

  // ─── Manual Input Card (FIELD mode) ──────────────────────────────────────────

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
          _buildOtherExpensesSection(),
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
          _buildAttachmentsSection(),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Bills / Receipts',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600)),
            const Spacer(),
            if (_attachments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200)),
                child: Text('${_attachments.length} attached',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
              ),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_attachments.length, (i) {
              final file = _attachments[i];
              final ext = file.path.split('.').last.toLowerCase();
              final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    child: isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.file(file,
                                fit: BoxFit.cover, width: 68, height: 68),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf,
                                  color: Colors.red.shade400, size: 26),
                              const SizedBox(height: 2),
                              Text(ext.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => setState(() => _attachments.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: _isLocked ? null : _pickAttachment,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline,
                    color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 8),
                Text('Add Bill / Receipt / Document',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Other Expenses Section ───────────────────────────────────────────────────

  Widget _buildOtherExpensesSection() {
    final total = _totalOtherAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Other Expenses',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600)),
            const Spacer(),
            if (!_isLocked)
              TextButton.icon(
                onPressed: _showAddOtherExpenseSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4A148C),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
          ],
        ),
        if (_otherExpenses.isEmpty)
          InkWell(
            onTap: _isLocked ? null : _showAddOtherExpenseSheet,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.grey.shade400, size: 16),
                  const SizedBox(width: 8),
                  Text('Toll, Parking, Courier, Food Bill…',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          ...List.generate(_otherExpenses.length,
              (i) => _buildOtherExpenseRow(i, _otherExpenses[i])),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Other',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text('₹${_fmt(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtherExpenseRow(int index, OtherExpenseItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item.type,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A148C))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: item.amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isLocked,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (item.bill != null) ...[
            const SizedBox(width: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(item.bill!, width: 30, height: 30, fit: BoxFit.cover),
            ),
          ],
          if (!_isLocked) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                item.dispose();
                setState(() => _otherExpenses.removeAt(index));
                _recalculateTotal();
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration:
                    const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddOtherExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOtherExpenseSheet(
        onAdd: (type, amount, bill) {
          final item = OtherExpenseItem(
              type: type, amount: amount.toStringAsFixed(2), bill: bill);
          item.amountController.addListener(_recalculateTotal);
          setState(() => _otherExpenses.add(item));
          _recalculateTotal();
        },
      ),
    );
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, 'camera')),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery (multiple)'),
                onTap: () => Navigator.pop(context, 'gallery')),
            ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('File / PDF'),
                onTap: () => Navigator.pop(context, 'file')),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'camera') {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked != null && mounted) {
        setState(() => _attachments.add(File(picked.path)));
      }
    } else if (choice == 'gallery') {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
      if (mounted) {
        setState(() {
          for (final img in picked) {
            _attachments.add(File(img.path));
          }
        });
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (result != null && mounted) {
        setState(() {
          for (final f in result.files) {
            if (f.path != null) _attachments.add(File(f.path!));
          }
        });
      }
    }
  }

  // ─── Locked Details Card ──────────────────────────────────────────────────────

  Widget _buildLockedDetailsCard() {
    final d = widget.editData!;
    final daType = (d['da_type'] ?? '').toString().toUpperCase();

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
              Text('Details (Locked)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
            ],
          ),
          const Divider(height: 16),
          if ((d['start_location'] ?? '').toString().isNotEmpty)
            _lockedRow('From', d['start_location'].toString()),
          if ((d['end_location'] ?? '').toString().isNotEmpty)
            _lockedRow('To', d['end_location'].toString()),
          if ((d['mode_of_travel'] ?? '').toString().isNotEmpty)
            _lockedRow('Mode of Travel', d['mode_of_travel'].toString()),
          if (daType == 'NFW') ...[
            _lockedRow('Daily Allowance (NFW)',
                '₹${_fmt(_toDouble(d['da_amount']))}'),
          ] else if (daType == 'TRANSIT') ...[
            _lockedRow('Distance Traveled',
                '${_fmt(_toDouble(d['ta_distance']))} km'),
            _lockedRow('Travel Allowance',
                '₹${_fmt(_toDouble(d['ta_amount']))}'),
          ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 38, vertical: 16),
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
      final Map<String, String> payload;

      final travelFields = {
        'mode_of_travel': _modeOfTravel,
        'start_location':
            _expenseMode == 'FIELD' ? (_startLocation ?? 'HQ') : (_fromLocation ?? 'HQ'),
        'end_location': _endLocation ?? '',
      };

      if (_expenseMode == 'FIELD') {
        final kmManual = _manualKmController.text.trim();
        // Route km from expense_rates_ta takes priority; manual if no route matched; DCR as fallback
        final kmAuto = _autoTaKm > 0
            ? _autoTaKm.toStringAsFixed(2)
            : (kmManual.isNotEmpty
                ? kmManual
                : _calcData!['total_km'].toString());
        payload = {
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'da_type': _fieldDaTypeOverride ?? _calcData!['da_type'].toString(),
          'da_amount': (_fieldDaAmountOverride ?? _toDouble(_calcData!['da_amount'])).toStringAsFixed(2),
          'ta_distance': kmAuto,
          'ta_amount': (_autoTaFare > 0 ? _autoTaFare : _toDouble(_calcData!['ta_amount'])).toStringAsFixed(2),
          'other_amount': _totalOtherAmount.toStringAsFixed(2),
          'remarks': _remarkController.text.trim(),
          ...travelFields,
        };
      } else if (_expenseMode == 'NFW') {
        final daAmt = double.tryParse(_manualDaController.text.trim()) ??
            _nfwDaAmount;
        payload = {
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'da_type': _nfwType == 'Transit'
              ? 'TRANSIT_DA'
              : _nfwType.toUpperCase(),
          'da_amount': daAmt.toStringAsFixed(2),
          'ta_distance': _autoTaKm.toStringAsFixed(2),
          'ta_amount': _autoTaFare.toStringAsFixed(2),
          'other_amount': _totalOtherAmount.toStringAsFixed(2),
          'remarks': _remarkController.text.trim(),
          'mode_of_travel': _modeOfTravel,
          'start_location': _userHq ?? 'HQ',
          'end_location': '',
        };
      } else {
        // TRANSIT — prefer auto-calculated values, fall back to manual
        final kmTransit = _autoTaKm > 0
            ? _autoTaKm.toStringAsFixed(2)
            : (_manualKmController.text.trim().isEmpty
                ? (_endLocationKm != null
                    ? _endLocationKm!.toStringAsFixed(2)
                    : '0')
                : _manualKmController.text.trim());
        final taTransit = _autoTaFare > 0
            ? _autoTaFare.toStringAsFixed(2)
            : (_manualTaController.text.trim().isEmpty
                ? '0'
                : _manualTaController.text.trim());
        payload = {
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'da_type': 'TRANSIT',
          'da_amount': '0',
          'ta_distance': kmTransit,
          'ta_amount': taTransit,
          'other_amount': _totalOtherAmount.toStringAsFixed(2),
          'remarks': _remarkController.text.trim(),
          'mode_of_travel': _modeOfTravel,
          'start_location': _transitFromTown ?? _userHq ?? 'HQ',
          'end_location': _endLocation ?? '',
        };
      }

      await ApiService().submitExpense(
        payload,
        _attachments,
        otherItems: _otherExpenses
            .map((e) => {'type': e.type, 'amount': e.amount.toStringAsFixed(2), 'bill': e.bill})
            .toList(),
      );

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

// ─── Add Other Expense Bottom Sheet ──────────────────────────────────────────

class _AddOtherExpenseSheet extends StatefulWidget {
  final void Function(String type, double amount, File? bill) onAdd;
  const _AddOtherExpenseSheet({required this.onAdd});

  @override
  State<_AddOtherExpenseSheet> createState() => _AddOtherExpenseSheetState();
}

class _AddOtherExpenseSheetState extends State<_AddOtherExpenseSheet> {
  static const _types = ['Toll', 'Courier', 'Parking', 'Food Bill', 'Others'];
  String _selectedType = 'Toll';
  final _amtController = TextEditingController();
  final _customTypeController = TextEditingController();
  File? _bill;

  @override
  void dispose() {
    _amtController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Add Other Expense',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),

          // Type chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _types.map((t) {
              final sel = _selectedType == t;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF4A148C) : const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF4A148C))),
                ),
              );
            }).toList(),
          ),

          if (_selectedType == 'Others') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customTypeController,
              decoration: InputDecoration(
                labelText: 'Describe expense',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF4A148C))),
              ),
            ),
          ],
          const SizedBox(height: 14),

          TextField(
            controller: _amtController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4A148C))),
            ),
          ),
          const SizedBox(height: 12),

          // Bill attachment
          InkWell(
            onTap: () async {
              final choice = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Camera'),
                          onTap: () => Navigator.pop(context, 'camera')),
                      ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Gallery'),
                          onTap: () => Navigator.pop(context, 'gallery')),
                    ],
                  ),
                ),
              );
              if (choice == null || !mounted) return;
              final picked = await ImagePicker().pickImage(
                source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
                imageQuality: 70,
              );
              if (picked != null && mounted) setState(() => _bill = File(picked.path));
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: _bill != null ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _bill != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    _bill != null ? Icons.check_circle : Icons.camera_alt_outlined,
                    color: _bill != null ? Colors.green : Colors.grey.shade500,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _bill != null ? 'Bill Attached' : 'Attach Bill (Optional)',
                      style: TextStyle(
                          color: _bill != null
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          fontSize: 13),
                    ),
                  ),
                  if (_bill != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(_bill!, width: 36, height: 36, fit: BoxFit.cover),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A148C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amount = double.tryParse(_amtController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')));
                  return;
                }
                final type =
                    _selectedType == 'Others' && _customTypeController.text.trim().isNotEmpty
                        ? _customTypeController.text.trim()
                        : _selectedType;
                Navigator.pop(context);
                widget.onAdd(type, amount, _bill);
              },
              child: Text('Add Expense',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
