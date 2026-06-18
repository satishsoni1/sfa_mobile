import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

// Per-attachment GST metadata
class _AttachmentMeta {
  bool isGst = false;
  String billType = 'other';
  String gstNumber = '';
  String vendorName = '';
  double billAmount = 0;

  Map<String, dynamic> toJson() => {
        'is_gst': isGst ? 1 : 0,
        'bill_type': billType,
        'gst_number': gstNumber,
        'vendor_name': vendorName,
        'bill_amount': billAmount,
      };
}

// Represents one itemized other-expense entry (Toll, Courier, Parking, etc.)
class OtherExpenseItem {
  String type;
  final TextEditingController amountController;
  PlatformFile? bill;

  OtherExpenseItem({required this.type, String amount = '', this.bill})
      : amountController = TextEditingController(text: amount);

  void dispose() => amountController.dispose();

  double get amount => double.tryParse(amountController.text) ?? 0;
}

class ExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final DateTime? initialDate;
  const ExpenseScreen({super.key, this.editData, this.initialDate});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _remarkController = TextEditingController();
  final _manualDaController = TextEditingController();
  final _manualKmController = TextEditingController();
  final _manualTaController = TextEditingController();

  late DateTime _selectedDate;
  Map<String, dynamic>? _calcData;
  String? _expenseMode; // 'FIELD', 'NFW', 'TRANSIT'
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<PlatformFile> _attachments = [];
  double _displayTotal = 0.0;
  bool _isLocked = false;

  // Travel details
  String _modeOfTravel = 'Bike';
  String? _startLocation;
  String? _endLocation;
  String? _fromLocation; // NFW / TRANSIT from dropdown
  double? _endLocationKm;
  List<Map<String, dynamic>> _taRoutes = [];
  bool _hasOwnPolicy = true;           // true → employee has own expense_rates_ta entries
  List<String> _subordinateLocations = []; // town codes from subordinates (managers only)
  String? _userHq;
  double _nfwDaAmount = 0;
  double _nfwDaPolicy = 0;        // server policy (ceiling) for current location
  bool _nfwDaTypeOverride = false; // true = user picked a lower DA type
  String _nfwOverrideDaType = ''; // user's selected lower type (HQ/EX/OS)
  bool _isLoadingNfwRate = false;
  String _nfwType = 'Meeting'; // 'Meeting' | 'Training'
  String _nfwTaDirection = 'one_way'; // user-selected direction for NFW TA
  String? _transitFromTown; // last DCR area or HQ for TRANSIT
  bool _isLoadingTransitFrom = false;
  String? _selectedFrom; // user-selected from location (overrides auto-detected)
  bool _isTwoWay = false; // display only — auto-set from backend ta_direction
  bool _isRecalculating = false;
  String _serverTaMode = 'road'; // 'road' | 'train'

  // All calculation values come from backend — no client-side math
  String _serverDaType = 'HQ';
  double _serverDaAmount = 0;
  double _serverTaKm = 0;
  double _serverTaAmount = 0;

  // New SFA fields from backend
  bool _hotelBillClaimed = false;
  bool _isOsReturn = false;
  double _osReturnAmount = 0; // from expense_rates.os_return
  String _taDirection = 'one_way'; // 'one_way' | 'two_way' — auto from DCR
  // Hotel / meal bill fields (OS/EX_OS with hotel_bill_flag=1)
  bool _hotelBillFlag = false;
  double _pocketAllowance = 0;
  double _hotelBillLimit = 0;   // active limit based on city class
  double _hotelBillALimit = 0;  // hotel_a_bill from rates (A-class city)
  double _hotelBillBLimit = 0;  // hotel_b_bill from rates (B-class city)
  String _hotelCityClass = '';  // 'A', 'B', 'metro', ''
  double _mealBillLimit = 0;
  double _hotelAmount = 0;
  double _mealAmount = 0;
  final TextEditingController _hotelAmountController = TextEditingController();
  final TextEditingController _mealAmountController = TextEditingController();
  List<_AttachmentMeta> _attachmentsMeta = [];

  // Multi-stop route (FIELD mode)
  List<String?> _fieldWaypoints = [null, null]; // first=from, last=to, any middle=via
  bool _userDirectionOverride = false; // user explicitly chose one/two-way for EX/EX_OS
  bool _userPrefersOneWay = false;
  int _recalcToken = 0; // incremented on each recalc; stale async results are discarded

  // Per-segment km breakdown for multi-stop routes [{from, to, km, mode}]
  List<Map<String, dynamic>> _segmentDetails = [];

  // Manual DA selection (when no DCR and allow_da_selection = 1 in expense_rates)
  bool _allowDaSelection = false;
  bool _isDaTypeManual = false;
  Map<String, double> _manualDaRates = {};
  // Route not found: no km found for selected from/to; allow manual entry
  bool _routeNotFound = false;
  // Route found but came from another employee's data (not own profile) — show "Add Route"
  bool _routeFromOtherEmployee = false;
  bool _taOverrideByUser = false; // user typed manual km/ta when route not found

  // Train TA — user can override amount; ticket attachment is required
  PlatformFile? _trainTicketFile;
  final _trainTaController = TextEditingController();

  // NFW admin-work types (from DB)
  List<Map<String, dynamic>> _adminWorkTypes = [];
  bool _isLoadingAdminWork = false;
  int? _selectedAdminWorkId;
  double _adminWorkAllowance = 0;

  // NFW travel arrangement: 'self' (km-based TA) | 'company' (no TA)
  String _nfwTravelBy = 'self';

  // Itemized other expenses (Toll, Courier, Parking, Food Bill, Others)
  List<OtherExpenseItem> _otherExpenses = [];

  @override
  void initState() {
    super.initState();
    // Initialise date: edit data wins, then explicit initialDate, then today
    _selectedDate = widget.editData != null
        ? (DateTime.tryParse(widget.editData!['expense_date'] ?? '') ?? DateTime.now())
        : (widget.initialDate ?? DateTime.now());
    if (widget.editData != null) {
      _restoreEditData(widget.editData!);
    }
    _manualDaController.addListener(_recalculateTotal);
    _manualTaController.addListener(_recalculateTotal);
    _loadTaRoutes();
    _fetchCalculation();
  }

  /// Restores all saved expense fields into state. Called on init (edit mode)
  /// and again inside _fetchCalculation() after the API result so that fresh
  /// config values (hotel_bill_limit etc.) are kept but saved amounts win.
  void _restoreEditData(Map<String, dynamic> d) {
    // _selectedDate already set in initState from expense_date
    _isLocked = d['is_submitted_for_month'] == 1;
    _modeOfTravel = (d['mode_of_travel'] ?? 'Bike').toString();
    _remarkController.text = d['remarks'] ?? '';

    // Locations
    final savedFrom = d['from_location']?.toString()
        ?? d['start_location']?.toString();
    final savedTo   = d['to_location']?.toString()
        ?? d['end_location']?.toString();
    _selectedFrom  = savedFrom;
    _startLocation = (d['start_location'] ?? 'HQ').toString();
    _endLocation   = savedTo?.isNotEmpty == true ? savedTo : null;
    _fromLocation  = savedFrom;

    // Restore multi-stop waypoints: JSON array wins, otherwise fall back to from/to pair
    final savedWp = d['waypoints']?.toString() ?? '';
    bool wpRestored = false;
    if (savedWp.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedWp) as List;
        final wps = decoded.map((w) => w?.toString()).toList();
        if (wps.length >= 2) {
          _fieldWaypoints = List<String?>.from(wps);
          wpRestored = true;
        }
      } catch (_) {}
    }
    if (!wpRestored) {
      _fieldWaypoints = [
        savedFrom?.isNotEmpty == true ? savedFrom : null,
        savedTo?.isNotEmpty == true ? savedTo : null,
      ];
    }

    // Direction
    _taDirection = d['ta_direction']?.toString() ?? 'one_way';
    _isTwoWay    = _taDirection == 'two_way';

    // OS return
    _isOsReturn     = d['is_os_return'] == 1 || d['is_os_return'] == '1';

    // Hotel / meal bill
    _hotelBillClaimed = d['hotel_bill_claimed'] == 1 || d['hotel_bill_claimed'] == '1';
    _hotelAmount = _toDouble(d['hotel_amount']);
    _mealAmount  = _toDouble(d['meal_amount']);
    if (_hotelAmount > 0) {
      _hotelAmountController.text = _hotelAmount.toStringAsFixed(2);
    }
    if (_mealAmount > 0) {
      _mealAmountController.text = _mealAmount.toStringAsFixed(2);
    }

    // DA type determines expense mode
    final daType = (d['da_type'] ?? '').toString().toUpperCase();
    if (daType == 'NFW' || daType == 'MEETING' || daType == 'TRAINING' ||
        daType == 'TRANSIT_DA') {
      _expenseMode = 'NFW';
      _nfwType = daType == 'TRAINING'
          ? 'Training'
          : daType == 'TRANSIT_DA'
              ? 'Transit'
              : 'Meeting';
      _nfwDaAmount = _toDouble(d['da_amount']);
      _manualDaController.text = _nfwDaAmount.toStringAsFixed(2);
      // TA fields for NFW
      _serverTaKm     = _toDouble(d['ta_distance']);
      _serverTaAmount = _toDouble(d['ta_amount']);
      _manualKmController.text = _serverTaKm.toStringAsFixed(1);
      _manualTaController.text = _serverTaAmount.toStringAsFixed(2);
    } else if (daType == 'TRANSIT') {
      _expenseMode    = 'TRANSIT';
      _serverTaKm     = _toDouble(d['ta_distance']);
      _serverTaAmount = _toDouble(d['ta_amount']);
      _manualKmController.text = _serverTaKm.toStringAsFixed(1);
      _manualTaController.text = _serverTaAmount.toStringAsFixed(2);
      _transitFromTown = savedFrom;
    } else {
      // FIELD mode — set saved financial values; _fetchCalculation() will add
      // the route timeline from DCR but we'll re-apply these amounts after.
      _serverDaType   = daType.isEmpty ? 'HQ' : daType;
      _serverDaAmount = _toDouble(d['da_amount']);
      _serverTaKm     = _toDouble(d['ta_distance']);
      _serverTaAmount = _toDouble(d['ta_amount']);
      _serverTaMode   = (d['ta_mode'] ?? 'road').toString();
      _manualKmController.text = _serverTaKm.toStringAsFixed(1);
      _manualTaController.text = _serverTaAmount.toStringAsFixed(2);
    }

    // Restore legacy other_amount as one item (only on first call from initState)
    if (_otherExpenses.isEmpty) {
      final legacyOther = _toDouble(d['other_amount']);
      if (legacyOther > 0) {
        final item = OtherExpenseItem(
            type: 'Other', amount: legacyOther.toStringAsFixed(2));
        item.amountController.addListener(_recalculateTotal);
        _otherExpenses.add(item);
      }
    }
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
    _trainTaController.dispose();
    _hotelAmountController.dispose();
    _mealAmountController.dispose();
    super.dispose();
  }

  double get _totalOtherAmount =>
      _otherExpenses.fold(0.0, (sum, e) => sum + e.amount);

  void _recalculateTotal() {
    double da = 0, ta = 0;
    if (_expenseMode == 'FIELD' && _calcData != null) {
      if (_isOsReturn) {
        // OS Return replaces the regular OS/EX_OS DA entirely
        da = _osReturnAmount;
      } else if (_hotelBillClaimed && _hotelBillFlag) {
        // DA = pocket_allowance (fixed) + user hotel bill + user meal bill
        da = _pocketAllowance + _hotelAmount + _mealAmount;
      } else {
        da = _serverDaAmount;
      }
      ta = _serverTaAmount;
    } else if (_expenseMode == 'NFW') {
      da = double.tryParse(_manualDaController.text) ?? _nfwDaAmount;
      ta = _serverTaAmount;
    } else if (_expenseMode == 'TRANSIT') {
      ta = _serverTaAmount > 0
          ? _serverTaAmount
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
        _calcData    = data;
        _expenseMode = 'FIELD';
        // Fresh values from backend (used for new expense)
        _serverTaMode    = data['ta_mode']?.toString() ?? 'road';
        _osReturnAmount  = (data['os_return_amount'] as num?)?.toDouble() ?? 0;
        _hotelBillFlag   = data['hotel_bill_flag'] == 1 || data['hotel_bill_flag'] == true;
        _pocketAllowance = (data['pocket_allowance'] as num?)?.toDouble() ?? 0;
        _hotelBillALimit = (data['hotel_a_limit'] as num?)?.toDouble() ?? 0;
        _hotelBillBLimit = (data['hotel_b_limit'] as num?)?.toDouble() ?? 0;
        _hotelCityClass  = data['hotel_city_class']?.toString() ?? '';
        _hotelBillLimit  = (data['hotel_bill_limit'] as num?)?.toDouble() ?? 0;
        _mealBillLimit   = (data['meal_bill_limit']  as num?)?.toDouble() ?? 0;

        if (widget.editData != null) {
          // Edit mode: route timeline comes from DCR (above), but financial
          // values come from the saved record — don't overwrite them.
          // _restoreEditData already ran in initState; re-apply FIELD amounts
          // in case _fetchCalculation setState() would reset them.
          final d = widget.editData!;
          final savedDaType = (d['da_type'] ?? '').toString().toUpperCase();
          final isField = savedDaType.isNotEmpty
              && !['NFW','MEETING','TRAINING','TRANSIT_DA','TRANSIT'].contains(savedDaType);
          if (isField) {
            _serverDaType   = savedDaType.isEmpty ? 'HQ' : savedDaType;
            _serverDaAmount = _toDouble(d['da_amount']);
            _serverTaKm     = _toDouble(d['ta_distance']);
            _serverTaAmount = _toDouble(d['ta_amount']);
            _serverTaMode   = (d['ta_mode'] ?? 'road').toString();
            _taDirection    = d['ta_direction']?.toString() ?? 'one_way';
            _isTwoWay       = _taDirection == 'two_way';
            _isOsReturn     = d['is_os_return'] == 1 || d['is_os_return'] == '1';
            _hotelBillClaimed = d['hotel_bill_claimed'] == 1 || d['hotel_bill_claimed'] == '1';
            _hotelAmount    = _toDouble(d['hotel_amount']);
            _mealAmount     = _toDouble(d['meal_amount']);
          }
        } else {
          // New expense: use fresh API values
          _serverDaType   = (data['da_type'] ?? 'HQ').toString().toUpperCase();
          _serverDaAmount = (data['da_amount'] as num?)?.toDouble() ?? 0;
          _serverTaKm     = (data['total_km']  as num?)?.toDouble() ?? 0;
          _serverTaAmount = (data['ta_amount'] as num?)?.toDouble() ?? 0;
          _taDirection    = data['ta_direction']?.toString() ?? 'one_way';
          _isTwoWay       = _taDirection == 'two_way';
          _isOsReturn     = false;
          _hotelBillClaimed = false;
          _hotelAmount = 0;
          _mealAmount  = 0;
          _hotelAmountController.clear();
          _mealAmountController.clear();
          final dt = _serverDaType;
          _startLocation = (dt == 'HQ' || dt == 'EX')
              ? 'HQ'
              : (data['start_location']?.toString() ?? 'HQ');
        }
        _manualKmController.text = _serverTaKm.toStringAsFixed(1);
        _manualTaController.text = _serverTaAmount.toStringAsFixed(2);
      });
      _recalculateTotal();
    } catch (_) {
      // No DCR found for this date.
      // For edit mode: if the saved da_type is a field type, restore manual FIELD mode
      if (widget.editData != null) {
        final daType = (widget.editData!['da_type'] ?? '').toString().toUpperCase();
        final isFieldType = daType.isNotEmpty &&
            !['NFW', 'MEETING', 'TRAINING', 'TRANSIT_DA', 'TRANSIT'].contains(daType);
        if (isFieldType && mounted) {
          setState(() {
            _expenseMode = 'FIELD';
            _calcData = {'route': []};
            _isDaTypeManual = true;
          });
          _recalculateTotal();
          return;
        }
      }
      // _allowDaSelection is already set by _loadTaRoutes() which runs in initState
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
                    if (_isDaTypeManual) ...[
                      _buildManualDaBanner(),
                      const SizedBox(height: 14),
                    ] else
                      _buildRouteTimeline(),
                    const SizedBox(height: 14),
                    _buildFieldTravelSection(),
                    const SizedBox(height: 14),
                    if (_isDaTypeManual || _bothWaypointsReady) ...[
                      _buildAllowanceCards(),
                      const SizedBox(height: 14),
                    ] else
                      _buildSelectBothLocationsHint(),
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
        if (_allowDaSelection) ...[
          const SizedBox(height: 12),
          // _buildTypeOptionCard(
          //   title: 'Field Expense (Manual)',
          //   subtitle: 'Select DA type: HQ, Ex-HQ, Outstation, or Ex-Outstation',
          //   icon: Icons.work_history_outlined,
          //   color: Colors.green,
          //   onTap: () => _showDaTypePickerSheet(),
          // ),
        ],
      ],
    );
  }

  // Hierarchy level: higher = more senior DA type (cannot upgrade to higher)
  static const _daHierarchy = {'HQ': 1, 'EX': 2, 'OS': 3, 'EX_OS': 4};

  void _showDaTypePickerSheet() {
    final serverLevel = _daHierarchy[_serverDaType] ?? 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select DA Type',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'You may select the policy-assigned type or a lower category. Upgrades are not allowed.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildDaTypeOption(
              type: 'HQ',
              title: 'HQ',
              subtitle: 'Headquarter territory',
              color: const Color(0xFF4A148C),
              disabled: (_daHierarchy['HQ']! > serverLevel),
            ),
            const SizedBox(height: 10),
            _buildDaTypeOption(
              type: 'EX',
              title: 'Ex-HQ',
              subtitle: 'Beyond headquarter territory',
              color: Colors.orange.shade700,
              disabled: (_daHierarchy['EX']! > serverLevel),
            ),
            const SizedBox(height: 10),
            _buildDaTypeOption(
              type: 'OS',
              title: 'Outstation (OS)',
              subtitle: 'Outstation area',
              color: Colors.red.shade700,
              disabled: (_daHierarchy['OS']! > serverLevel),
            ),
            const SizedBox(height: 10),
            _buildDaTypeOption(
              type: 'EX_OS',
              title: 'Ex-Outstation (EX OS)',
              subtitle: 'Ex-outstation area',
              color: Colors.deepOrange.shade700,
              disabled: (_daHierarchy['EX_OS']! > serverLevel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaTypeOption({
    required String type,
    required String title,
    required String subtitle,
    required Color color,
    bool disabled = false,
    void Function(String)? onSelect,
  }) {
    final rate = _manualDaRates[type] ?? 0;
    final effectiveColor = disabled ? Colors.grey.shade400 : color;
    return InkWell(
      onTap: disabled ? null : () => (onSelect ?? _selectManualDaType)(type),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.location_on_outlined, color: effectiveColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      disabled ? '$subtitle — not allowed (upgrade restricted)' : subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (disabled)
                Icon(Icons.block, color: Colors.grey.shade400, size: 20)
              else if (rate > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('₹${_fmt(rate)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                )
              else
                Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _selectManualDaType(String type) {
    Navigator.pop(context);
    setState(() {
      _expenseMode = 'FIELD';
      _calcData = {'route': []};
      _serverDaType = type;
      _serverDaAmount = _manualDaRates[type] ?? 0;
      _isDaTypeManual = true;
    });
    _recalculateTotal();
  }

  // ─── NFW Meeting DA lower-type picker ─────────────────────────────────────────

  void _showNfwDaTypePickerSheet() {
    final serverLevel = _daHierarchy[_serverDaType] ?? 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Lower Allowance Type',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Policy type: $_serverDaType. You may claim at a lower category; upgrades are not allowed.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildDaTypeOption(
              type: 'HQ',
              title: 'HQ',
              subtitle: 'Headquarter territory',
              color: const Color(0xFF4A148C),
              disabled: (_daHierarchy['HQ']! > serverLevel),
              onSelect: _selectNfwDaType,
            ),
            const SizedBox(height: 10),
            _buildDaTypeOption(
              type: 'EX',
              title: 'Ex-HQ',
              subtitle: 'Beyond headquarter territory',
              color: Colors.orange.shade700,
              disabled: (_daHierarchy['EX']! > serverLevel),
              onSelect: _selectNfwDaType,
            ),
            const SizedBox(height: 10),
            _buildDaTypeOption(
              type: 'OS',
              title: 'Outstation (OS)',
              subtitle: 'Outstation area',
              color: Colors.red.shade700,
              disabled: (_daHierarchy['OS']! > serverLevel),
              onSelect: _selectNfwDaType,
            ),
          ],
        ),
      ),
    );
  }

  void _selectNfwDaType(String type) {
    Navigator.pop(context);
    final amount = _manualDaRates[type] ?? 0;
    setState(() {
      _nfwDaTypeOverride = true;
      _nfwOverrideDaType = type;
      _nfwDaAmount       = amount;
      _manualDaController.text = amount.toStringAsFixed(2);
    });
    _recalculateTotal();
  }

  // ─── Manual DA Banner (shown in FIELD mode when DA type was manually selected) ─

  Widget _buildManualDaBanner() {
    const labels = {
      'HQ': 'HQ',
      'EX': 'Ex-HQ',
      'OS': 'Outstation',
      'EX_OS': 'Ex-Outstation',
    };
    const colors = {
      'HQ': Color(0xFF4A148C),
      'EX': Colors.orange,
      'OS': Colors.red,
      'EX_OS': Colors.deepOrange,
    };
    final label = labels[_serverDaType] ?? _serverDaType;
    final color = colors[_serverDaType] ?? const Color(0xFF4A148C);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.work_history_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Field Expense — $label',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                Text('DA type manually selected',
                    style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (!_isLocked)
            TextButton(
              onPressed: () {
                setState(() {
                  _expenseMode = null;
                  _isDaTypeManual = false;
                  _calcData = null;
                  _serverDaType = 'HQ';
                  _serverDaAmount = 0;
                });
              },
              style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32)),
              child: const Text('Change', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
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
          // NFW Type selector — fixed types + admin_work types from DB
          Text('Activity Type',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Fixed types
              ...['Meeting', 'Training', 'Transit'].map((type) {
                final sel = _selectedAdminWorkId == null && _nfwType == type;
                final icon = type == 'Training'
                    ? Icons.school_outlined
                    : type == 'Transit'
                        ? Icons.directions_bus_outlined
                        : Icons.groups_outlined;
                return _buildNfwTypeChip(
                  label: type,
                  icon: icon,
                  selected: sel,
                  onTap: _isLocked ? null : () {
                    setState(() {
                      _nfwType = type;
                      _selectedAdminWorkId = null;
                      _adminWorkAllowance  = 0;
                    });
                    if (_endLocation != null) {
                      _recalculateFromServer(_endLocation!);
                    } else {
                      _fetchNfwDaRate();
                    }
                  },
                );
              }),
              // Admin work types from DB
              if (_isLoadingAdminWork)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ..._adminWorkTypes.map((w) {
                  final id  = w['id'] as int? ?? 0;
                  final nm  = (w['name'] ?? '').toString();
                  final sel = _selectedAdminWorkId == id;
                  return _buildNfwTypeChip(
                    label: nm,
                    icon: Icons.work_outline,
                    selected: sel,
                    onTap: _isLocked ? null : () {
                      setState(() {
                        _selectedAdminWorkId = id;
                        _adminWorkAllowance  = (w['allowance_amount'] as num?)?.toDouble() ?? 0;
                        _nfwType = 'Meeting';
                      });
                      if (_endLocation != null) {
                        _recalculateFromServer(_endLocation!);
                      } else {
                        _fetchNfwDaRate();
                      }
                    },
                  );
                }),
            ],
          ),
          const SizedBox(height: 14),

          // Travel Arrangement — only relevant when a destination is set
          if (_endLocation != null || _serverTaKm > 0) ...[
            Text('Travel Arranged By',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Row(
              children: ['self', 'company'].map((opt) {
                final sel  = _nfwTravelBy == opt;
                final icon = opt == 'company'
                    ? Icons.business_outlined
                    : Icons.person_outlined;
                final lbl  = opt == 'company' ? 'Company' : 'Self';
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: _isLocked ? null : () {
                      if (_nfwTravelBy != opt) {
                        setState(() => _nfwTravelBy = opt);
                        if (opt == 'company') {
                          setState(() {
                            _serverTaKm     = 0;
                            _serverTaAmount = 0;
                            _manualKmController.clear();
                            _manualTaController.text = '0.00';
                          });
                          _recalculateTotal();
                        } else if (_endLocation != null) {
                          _recalculateFromServer(_endLocation!);
                        }
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? (opt == 'company' ? Colors.orange.shade600 : const Color(0xFF4A148C))
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? (opt == 'company' ? Colors.orange.shade600 : const Color(0xFF4A148C))
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14,
                              color: sel ? Colors.white : Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(lbl, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_nfwTravelBy == 'company') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Company-arranged travel — TA not applicable.',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                  ],
                ),
              ),
            ],
            // Journey Direction toggle — only for self-arranged travel
            if (_nfwTravelBy == 'self') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Journey Type',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(width: 12),
                  _buildWayChip(
                    label: 'One Way',
                    selected: _nfwTaDirection == 'one_way',
                    onTap: () {
                      if (_nfwTaDirection != 'one_way') {
                        setState(() => _nfwTaDirection = 'one_way');
                        if (_endLocation != null) {
                          _recalculateFromServer(_endLocation!, taDirection: 'one_way');
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildWayChip(
                    label: 'Two Way',
                    selected: _nfwTaDirection == 'two_way',
                    onTap: () {
                      if (_nfwTaDirection != 'two_way') {
                        setState(() => _nfwTaDirection = 'two_way');
                        if (_endLocation != null) {
                          _recalculateFromServer(_endLocation!, taDirection: 'two_way');
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),

          // From + To — drives TA and (for Meeting) DA rate
          _buildFromToSection(accent: Colors.blue.shade600),
          if (_serverTaKm > 0) ...[
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
                  Text('${_fmt(_serverTaKm)} km',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800)),
                  const SizedBox(width: 12),
                  Text('TA: ₹${_fmt(_serverTaAmount)}',
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

          // DA Amount — policy rate display + user-editable claim field
          _isLoadingNfwRate
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                                      ? 'Training Allowance (Policy)'
                                      : _nfwType == 'Transit'
                                          ? 'Transit Day Allowance (Policy)'
                                          : _endLocation != null
                                              ? 'Meeting DA — Policy ($_serverDaType)'
                                              : 'Meeting Allowance — Policy (HQ)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade600),
                                ),
                                _isRecalculating
                                    ? const SizedBox(
                                        height: 28,
                                        child: Center(
                                            child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2))))
                                    : Text('₹${_fmt(_nfwDaPolicy > 0 ? _nfwDaPolicy : daAmt)}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800)),
                                Text(
                                  _endLocation != null
                                      ? 'Policy for ${_endLocation!} ($_nfwType)'
                                      : _nfwType == 'Training'
                                          ? 'Fixed: expense_rates → training'
                                          : _nfwType == 'Transit'
                                              ? 'Fixed: expense_rates → transit'
                                              : 'Fixed: expense_rates → da_hq_non_metro',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade400),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_downward,
                              size: 16, color: Colors.blue.shade400),
                        ],
                      ),
                    ),
                    // DA type lower-selector — Meeting type only, when a lower type has rates
                    if (!_isLocked && _nfwType == 'Meeting' && _endLocation != null &&
                        _manualDaRates.isNotEmpty && (_daHierarchy[_serverDaType] ?? 0) > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _nfwDaTypeOverride
                                ? 'Claiming at: ${_nfwOverrideDaType == 'EX' ? 'Ex-HQ' : _nfwOverrideDaType}'
                                : 'Allowance type: $_serverDaType (policy)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showNfwDaTypePickerSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_downward, size: 13, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text('Lower Type',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_nfwDaTypeOverride) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _nfwDaTypeOverride = false;
                              _nfwOverrideDaType = '';
                              _nfwDaAmount = _nfwDaPolicy;
                              _manualDaController.text = _nfwDaPolicy.toStringAsFixed(2);
                            });
                            _recalculateTotal();
                          },
                          child: Text('Reset to policy rate (₹${_nfwDaPolicy.toStringAsFixed(0)})',
                              style: TextStyle(fontSize: 10, color: Colors.blue.shade400,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ],
                  ],
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
          if (_serverTaKm > 0 || _isSameLocation()) ...[
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
                        Text('${_fmt(_serverTaKm)} km',
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
                        Text('₹${_fmt(_serverTaAmount)}',
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
      final routes     = List<Map<String, dynamic>>.from(result['routes'] as List? ?? []);
      final hqLocation = result['hq_location'] as String?;
      final hasOwn     = result['has_own_policy'] as bool? ?? true;
      final subLocs    = List<String>.from(result['subordinate_locations'] as List? ?? []);
      final allowDaSel = result['allow_da_selection'] == 1 || result['allow_da_selection'] == true;
      setState(() {
        _taRoutes              = routes;
        _hasOwnPolicy          = hasOwn;
        _subordinateLocations  = subLocs;
        // hq_location from API is authoritative
        _userHq = hqLocation ?? (routes.isNotEmpty ? routes.first['from_town_code']?.toString() : null);
        // Pre-fill "From" waypoint with HQ when not yet chosen
        if (_userHq != null && _fieldWaypoints.isNotEmpty && _fieldWaypoints[0] == null) {
          _fieldWaypoints[0] = _userHq;
        }
        _allowDaSelection = allowDaSel;
        // Always populate rates — needed for NFW meeting lower-type selector
        _manualDaRates = {
          'HQ':    _toDouble(result['da_hq']),
          'EX':    _toDouble(result['da_ex_hq']) > 0
                       ? _toDouble(result['da_ex_hq'])
                       : _toDouble(result['da_ex']),
          'OS':    _toDouble(result['da_os']),
          'EX_OS': _toDouble(result['da_ex_os']),
        };
      });
      if (_expenseMode == 'TRANSIT' && _endLocation != null) {
        _updateTaFromSelection();
      }
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
    // Load admin work types on first NFW open
    if (_adminWorkTypes.isEmpty) _loadAdminWorkTypes();
    setState(() => _isLoadingNfwRate = true);
    try {
      // Admin work type: DA comes from the selected type's allowance, not expense_rates
      if (_selectedAdminWorkId != null && _adminWorkAllowance > 0) {
        setState(() {
          _nfwDaAmount = _adminWorkAllowance;
          _manualDaController.text = _adminWorkAllowance.toStringAsFixed(2);
        });
        _recalculateTotal();
        return;
      }
      final data = await ApiService().getNfwDaRate(
          type: _nfwType, location: _endLocation);
      if (!mounted) return;
      final amount = (data['da_amount'] as num?)?.toDouble() ?? 0;
      setState(() {
        _nfwDaPolicy             = amount;
        _nfwDaTypeOverride       = false;
        _nfwOverrideDaType       = '';
        _nfwDaAmount             = amount;
        _manualDaController.text = amount.toStringAsFixed(2);
      });
      _recalculateTotal();
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingNfwRate = false);
    }
  }

  Future<void> _loadAdminWorkTypes() async {
    setState(() => _isLoadingAdminWork = true);
    try {
      final types = await ApiService().getAdminWorkTypes();
      if (mounted) setState(() => _adminWorkTypes = types);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingAdminWork = false);
    }
  }

  // True when FIELD mode has both a valid FROM (explicit or HQ pre-fill) and a TO set.
  bool get _bothWaypointsReady {
    final from = _fieldWaypoints.isNotEmpty ? (_fieldWaypoints[0] ?? _userHq) : _userHq;
    final to   = _fieldWaypoints.isNotEmpty ? _fieldWaypoints.last : null;
    return from != null && from.isNotEmpty && to != null && to.isNotEmpty;
  }

  // Unified destination selection handler — called by all three expense modes.
  // Determines station_type → DA, and kms/fare → TA from expense_rates_ta.
  bool _isSameLocation() {
    final from = (_selectedFrom ?? _transitFromTown ?? _userHq ?? '').toLowerCase();
    final to = (_endLocation ?? '').toLowerCase();
    return from.isNotEmpty && to.isNotEmpty && from == to;
  }

  void _onDestinationSelected(String? town) {
    print('Selected destination: $town');
    if (town == null) return;

    final from = _selectedFrom ?? _transitFromTown ?? _userHq ?? '';

    // Same from/to → zero km
    if (from.isNotEmpty && from.toLowerCase() == town.toLowerCase()) {
      setState(() {
        _endLocation = town;
        _serverTaKm = 0;
        _serverTaAmount = 0;
        _segmentDetails = [];
        _manualKmController.clear();
        _manualTaController.clear();
      });
      _recalculateTotal();
      //return;
    }

    setState(() => _endLocation = town);

    // All modes: backend calculates DA/TA with correct policy and direction
    _recalculateFromServer(town);
  }

  /// Called whenever from/to changes. Backend applies all policies:
  ///   FIXED fare, road km >150 → train slab, else km×3.5, direction multiplier.
  Future<void> _recalculateFromServer(String toTown, {String? taDirection}) async {
    final fromTown = _selectedFrom ?? _transitFromTown ?? _userHq ?? '';
    // Capture direction immediately — caller may pass explicit value to avoid
    // reading stale state if a concurrent call updates _taDirection mid-flight.
    // For NFW, use the user-chosen direction unless caller overrides explicitly
    final capturedDir = taDirection ?? (_expenseMode == 'NFW' ? _nfwTaDirection : _taDirection);
    print('Recalculating from: $fromTown to: $toTown dir: $capturedDir');
    if (fromTown.isEmpty) return;

    setState(() => _isRecalculating = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      // Pass NFW type so backend returns the correct fixed DA (training/transit)
      // or station-type-based DA (meeting).
      final String? nfwTypeParam = _expenseMode == 'NFW'
          ? (_selectedAdminWorkId != null ? 'admin_work' : _nfwType.toLowerCase())
          : null;
      final result = await ApiService().recalculateOnLastLocation(
          dateStr, fromTown, toTown,
          nfwType: nfwTypeParam,
          taDirection: capturedDir);
      if (!mounted) return;

      final daType   = (result['da_type']?.toString() ?? 'HQ').toUpperCase();
      final daAmount = (result['da_amount'] as num?)?.toDouble() ?? 0;
      final taKm     = (result['total_km']  as num?)?.toDouble() ?? 0;
      final taAmount = (result['ta_amount'] as num?)?.toDouble() ?? 0;
      final taMode   = result['ta_mode']?.toString() ?? 'road';
      final taDir    = result['ta_direction']?.toString() ?? 'one_way';

      // For NFW: DA always updates from server, unless admin_work type (fixed from table)
      if (_expenseMode == 'NFW') {
        final effectiveDa = (_selectedAdminWorkId != null && _adminWorkAllowance > 0)
            ? _adminWorkAllowance
            : daAmount;
        _nfwDaPolicy             = effectiveDa;
        _nfwDaTypeOverride       = false; // reset override when route/location changes
        _nfwOverrideDaType       = '';
        _nfwDaAmount             = effectiveDa;
        _manualDaController.text = effectiveDa.toStringAsFixed(2);
      }

      final flag = result['hotel_bill_flag'] == 1 || result['hotel_bill_flag'] == true;
      setState(() {
        // In manual DA mode or user override, keep the selected DA type and amount
        if (!_isDaTypeManual) {
          _serverDaType   = daType;
          _serverDaAmount = daAmount;
        }
        if (!_taOverrideByUser) {
          final src = result['route_source']?.toString() ?? '';
          _routeNotFound           = src == 'none';
          _routeFromOtherEmployee  = src == 'other';
        }
        _osReturnAmount  = (result['os_return_amount'] as num?)?.toDouble() ?? _osReturnAmount;
        _serverTaKm      = taKm;
        _serverTaAmount  = taAmount;
        _serverTaMode    = taMode;
        _taDirection     = taDir;
        _isTwoWay        = taDir == 'two_way';
        _hotelBillFlag   = flag;
        _pocketAllowance = (result['pocket_allowance'] as num?)?.toDouble() ?? 0;
        _hotelBillALimit = (result['hotel_a_limit'] as num?)?.toDouble() ?? 0;
        _hotelBillBLimit = (result['hotel_b_limit'] as num?)?.toDouble() ?? 0;
        _hotelCityClass  = result['hotel_city_class']?.toString() ?? '';
        // Active limit driven by city class
        final cityClass = _hotelCityClass;
        if (_hotelBillALimit > 0 && cityClass == 'A') {
          _hotelBillLimit = _hotelBillALimit;
        } else if (_hotelBillBLimit > 0 && cityClass == 'B') {
          _hotelBillLimit = _hotelBillBLimit;
        } else {
          _hotelBillLimit = (result['hotel_bill_limit'] as num?)?.toDouble() ?? 0;
        }
        _mealBillLimit   = (result['meal_bill_limit']   as num?)?.toDouble() ?? 0;
        // Reset hotel/meal claims when route changes
        if (!flag) {
          _hotelBillClaimed = false;
          _hotelAmount = 0;
          _mealAmount = 0;
          _hotelAmountController.clear();
          _mealAmountController.clear();
        }
        _manualKmController.text = taKm.toStringAsFixed(1);
        _manualTaController.text = taAmount.toStringAsFixed(2);
      });
      // Company-arranged travel → zero out TA regardless of route result
      if (_expenseMode == 'NFW' && _nfwTravelBy == 'company') {
        setState(() {
          _serverTaKm     = 0;
          _serverTaAmount = 0;
          _manualKmController.clear();
          _manualTaController.text = '0.00';
        });
      }
      _recalculateTotal();
    } catch (_) {
      // Server unavailable — leave current values
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  void _updateTaFromSelection() => _onDestinationSelected(_endLocation);


  // ─── Multi-stop Route (FIELD mode) ────────────────────────────────────────────

  /// Finds a route entry for two towns in either direction.
  Map<String, dynamic>? _findRoute(String a, String b) {
    final au = a.toUpperCase(), bu = b.toUpperCase();
    for (final r in _taRoutes) {
      final f = (r['from_town_code']?.toString() ?? '').toUpperCase();
      final t = (r['to_town_code']?.toString() ?? '').toUpperCase();
      if ((f == au && t == bu) || (f == bu && t == au)) return r;
    }
    return null;
  }

  void _onWaypointChanged(int index, String? value) {
    print('Waypoint $index changed to: $value');
    setState(() => _fieldWaypoints[index] = value);
    _recalcFieldRoute();
  }

  /// Client-side KM sum across all waypoint segments.
  /// Calls server for DA type+amount using first→last stop.
  /// Uses a cancel token so only the most-recent call applies its result.
  Future<void> _recalcFieldRoute() async {
    print(_expenseMode);
    if (_expenseMode != 'FIELD') return;

    final myToken = ++_recalcToken;

    // ── 1. Client-side KM calculation (instant) ─────────────────────────────
    const stPriority = {'EX_OS': 4, 'OS': 3, 'EX': 2, 'EX_HQ': 2, 'HQ': 1};
    double roadKm = 0;
    String topStation = '';

    // Resolve effective waypoints: use _userHq for null first slot
    final resolved = List<String?>.from(_fieldWaypoints);
    if (resolved.isNotEmpty && resolved[0] == null && _userHq != null) {
      resolved[0] = _userHq;
    }
    final stops = resolved.where((w) => w != null && w.isNotEmpty).cast<String>().toList();

    final segDetails = <Map<String, dynamic>>[];
    for (int i = 0; i < stops.length - 1; i++) {
      final route = _findRoute(stops[i], stops[i + 1]);
      if (route == null) {
        segDetails.add({'from': stops[i], 'to': stops[i + 1], 'km': 0.0, 'mode': ''});
        continue;
      }
      final km = double.tryParse(route['kms']?.toString() ?? '') ?? 0;
      final mode = (route['mode_of_travel']?.toString() ?? '').toUpperCase();
      final st = (route['station_type']?.toString() ?? '').toUpperCase().replaceAll('-', '_');
      final segKm = mode == 'FIXED' ? 0.0 : km;
      roadKm += segKm;
      segDetails.add({'from': stops[i], 'to': stops[i + 1], 'km': segKm, 'mode': mode});
      final existingP = stPriority[topStation] ?? 0;
      final newP = stPriority[st] ?? 0;
      if (newP > existingP) topStation = st;
    }

    final isEx = topStation == 'EX' || topStation == 'EX_OS' || topStation == 'EX_HQ';
    final dirMult = isEx
        ? (_userDirectionOverride ? (_userPrefersOneWay ? 1 : 2) : 2)
        : 1;

    final totalRoadKm = roadKm * dirMult;
    final taDir = dirMult == 2 ? 'two_way' : 'one_way';

    if (!mounted || myToken != _recalcToken) return;

    // Apply client-side KM + direction immediately so UI is responsive.
    // TA amount is intentionally NOT set here — it must come from the server
    // because train-slab / fixed-fare logic lives only in the controller.
    setState(() {
      _serverTaKm     = totalRoadKm;
      _taDirection    = taDir;
      _isTwoWay       = dirMult == 2;
      _serverDaType   = topStation.isEmpty ? 'HQ' : topStation;
      _selectedFrom   = stops.isNotEmpty ? stops.first : _selectedFrom;
      _endLocation    = stops.length > 1 ? stops.last : null;
      _segmentDetails = segDetails;
    });
    _recalculateTotal();
    // ── 2. Server call for DA amount + hotel flags ───────────────────────────
    // Only fire when both from and to are set
    if (stops.length < 2) return;

    // Debounce: wait briefly so rapid selections don't spam the server
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || myToken != _recalcToken) return;

    setState(() => _isRecalculating = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      // Send all waypoints so server processes each segment individually
      final result = await ApiService().recalculateWithWaypoints(
          dateStr, stops, taDirection: taDir);

      // Discard if a newer call has already started
      if (!mounted || myToken != _recalcToken) return;

      setState(() {
        if (!_isDaTypeManual) {
          _serverDaType   = (result['da_type']?.toString() ?? _serverDaType).toUpperCase();
          _serverDaAmount = (result['da_amount'] as num?)?.toDouble() ?? _serverDaAmount;
        }
        final newKm = (result['total_km'] as num?)?.toDouble() ?? _serverTaKm;
        _serverTaKm      = newKm;
        _serverTaAmount  = (result['ta_amount']  as num?)?.toDouble() ?? _serverTaAmount;
        // Detect route-not-found: server returned km=0 for valid non-identical stops
        if (!_taOverrideByUser) {
          final src = result['route_source']?.toString() ?? '';
          _routeNotFound           = src == 'none';
          _routeFromOtherEmployee  = src == 'other';
        }
        _serverTaMode    = result['ta_mode']?.toString() ?? _serverTaMode;
        final serverDir  = result['ta_direction']?.toString() ?? _taDirection;
        _taDirection     = serverDir;
        _isTwoWay        = serverDir == 'two_way';
        _osReturnAmount  = (result['os_return_amount'] as num?)?.toDouble() ?? _osReturnAmount;
        _hotelBillFlag   = result['hotel_bill_flag'] == 1 || result['hotel_bill_flag'] == true;
        _pocketAllowance = (result['pocket_allowance'] as num?)?.toDouble() ?? 0;
        _hotelBillALimit = (result['hotel_a_limit'] as num?)?.toDouble() ?? 0;
        _hotelBillBLimit = (result['hotel_b_limit'] as num?)?.toDouble() ?? 0;
        _hotelCityClass  = result['hotel_city_class']?.toString() ?? '';
        if (_hotelBillALimit > 0 && _hotelCityClass == 'A') {
          _hotelBillLimit = _hotelBillALimit;
        } else if (_hotelBillBLimit > 0 && _hotelCityClass == 'B') {
          _hotelBillLimit = _hotelBillBLimit;
        } else {
          _hotelBillLimit = (result['hotel_bill_limit'] as num?)?.toDouble() ?? 0;
        }
        _mealBillLimit = (result['meal_bill_limit'] as num?)?.toDouble() ?? 0;
        if (!_hotelBillFlag) {
          _hotelBillClaimed = false;
          _hotelAmount = 0;
          _mealAmount  = 0;
          _hotelAmountController.clear();
          _mealAmountController.clear();
        }
        // If server returns per-segment breakdown, use it; otherwise keep client-side
        if (result['segments'] is List) {
          _segmentDetails = List<Map<String, dynamic>>.from(
            (result['segments'] as List).map((s) => {
              'from': s['from']?.toString() ?? '',
              'to'  : s['to']?.toString() ?? '',
              'km'  : (s['km'] as num?)?.toDouble() ?? 0.0,
              'mode': s['mode']?.toString() ?? '',
            }),
          );
        }
      });
      _recalculateTotal();
    } catch (_) {
      // Server unreachable — KM shown but TA amount stays 0 until server responds
    } finally {
      if (mounted && myToken == _recalcToken) {
        setState(() => _isRecalculating = false);
      }
    }
  }

  Widget _buildFieldRouteSection() {
    final allLocs = _allLocations();
    if (allLocs.isEmpty) return const SizedBox.shrink();

    final isExType = _serverDaType == 'EX' || _serverDaType == 'EX_OS';
    final effectiveOneWay = _userDirectionOverride ? _userPrefersOneWay : !_isTwoWay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route, size: 15, color: Color(0xFF4A148C)),
            const SizedBox(width: 6),
            Text('Route (drag to reorder)',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const Spacer(),
            if (!_isLocked)
              TextButton.icon(
                onPressed: () {
                  setState(() => _fieldWaypoints.insert(_fieldWaypoints.length - 1, null));
                },
                icon: const Icon(Icons.add_location_alt_outlined, size: 15),
                label: const Text('Add Stop', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4A148C),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 0),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fieldWaypoints.length,
          onReorder: _isLocked
              ? (_, __) {}
              : (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _fieldWaypoints.removeAt(oldIndex);
                    _fieldWaypoints.insert(newIndex, item);
                  });
                  _recalcFieldRoute();
                },
          itemBuilder: (context, index) {
            final isFirst = index == 0;
            final isLast  = index == _fieldWaypoints.length - 1;
            // For the "From" slot, fall back to HQ when not yet chosen
            final val  = _fieldWaypoints[index] ?? (isFirst ? _userHq : null);
            final safe = allLocs.contains(val) ? val : null;
            final icon    = isFirst ? Icons.my_location : isLast ? Icons.location_on : Icons.radio_button_unchecked;
            final iconColor = isFirst ? Colors.green.shade600 : isLast ? Colors.red.shade600 : Colors.blue.shade400;
            final hint    = isFirst ? 'From' : isLast ? 'To' : 'Via';

            return Padding(
              key: ValueKey('wp_$index'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (!_isLocked)
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 20),
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 6),
                  Icon(icon, color: iconColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLocationPicker(
                      value: safe,
                      locations: allLocs,
                      hint: hint,
                      leadingIcon: icon,
                      iconColor: iconColor,
                      locked: _isLocked,
                      onChanged: (v) => _onWaypointChanged(index, v),
                    ),
                  ),
                  if (!isFirst && !isLast && !_isLocked) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () {
                        setState(() => _fieldWaypoints.removeAt(index));
                        _recalcFieldRoute();
                      },
                      icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ] else
                    const SizedBox(width: 36),
                ],
              ),
            );
          },
        ),

        // Route KM summary
        if (_serverTaKm > 0 || _isRecalculating) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isRecalculating
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Calculating…', style: TextStyle(fontSize: 12, color: Color(0xFF4A148C))),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Per-segment breakdown (shown when 3+ stops)
                      if (_segmentDetails.length > 1) ...[
                        ...(_segmentDetails.map((seg) {
                          final km = (seg['km'] as double?) ?? 0.0;
                          final isFixed = (seg['mode']?.toString() ?? '') == 'FIXED';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Text(
                                  '${seg['from']} → ${seg['to']}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                                const Spacer(),
                                Text(
                                  isFixed ? 'Fixed' : '${_fmt(km)} km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isFixed ? Colors.orange.shade700 : const Color(0xFF4A148C),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })),
                        const Divider(height: 8, thickness: 0.5),
                      ],
                      // Total km + TA row
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 14, color: Color(0xFF4A148C)),
                          const SizedBox(width: 6),
                          Text('${_fmt(_serverTaKm)} km total',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C), fontSize: 13)),
                          const SizedBox(width: 12),
                          Text('TA: ₹${_fmt(_serverTaAmount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C), fontSize: 13)),
                          if (_isTwoWay) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF4A148C), borderRadius: BorderRadius.circular(4)),
                              child: const Text('2-way', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
        ],

        // One Way / Two Way selector — only for EX / EX_OS
        if (isExType && _serverTaKm > 0 && !_isLocked) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Journey Type', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
              _buildWayChip(
                label: 'One Way',
                selected: effectiveOneWay,
                onTap: () {
                  _userDirectionOverride = true;
                  _userPrefersOneWay = true;
                  _recalcFieldRoute();
                },
              ),
              const SizedBox(width: 8),
              _buildWayChip(
                label: 'Two Way',
                selected: !effectiveOneWay,
                onTap: () {
                  _userDirectionOverride = true;
                  _userPrefersOneWay = false;
                  _recalcFieldRoute();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── NFW Type Chip helper ────────────────────────────────────────────────────

  Widget _buildNfwTypeChip({
    required String label,
    required IconData icon,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A148C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4A148C) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  // ─── Shared: Station Type Badge ───────────────────────────────────────────────

  Widget _buildStationTypeBadge(String? type) {
    print(type);
    final t = type?.toUpperCase() ?? 'HQ';
    Color bg, fg;
    String label;
    if (t == 'EX-OS' || t == 'EX_OS') {
      bg = Colors.red.shade100; fg = Colors.red.shade700; label = 'EX_OS';
    } else if (t == 'OS') {
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

  // All unique locations — union of own routes, subordinate locations, and HQ.
  // When the employee has no own policy routes, subordinate town codes fill the
  // dropdown so they can still pick from/to for the "Add Route" flow.
  List<String> _allLocations() {
    final locs = <String>{};
    if (_userHq != null && _userHq!.isNotEmpty) locs.add(_userHq!);
    for (final r in _taRoutes) {
      final f = r['from_town_code']?.toString() ?? '';
      final t = r['to_town_code']?.toString() ?? '';
      if (f.isNotEmpty) locs.add(f);
      if (t.isNotEmpty) locs.add(t);
    }
    // When no own policy routes, supplement with subordinate locations so managers
    // and employees without personal routes can still select from/to in dropdowns.
    if (!_hasOwnPolicy || _taRoutes.isEmpty) {
      for (final loc in _subordinateLocations) {
        if (loc.isNotEmpty) locs.add(loc);
      }
    }
    return locs.toList()..sort();
  }

  Future<String?> _showLocationSearch(List<String> locations, String? current) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LocationSearchSheet(
            locations: locations, current: current),
      );

  Widget _buildLocationPicker({
    required String? value,
    required List<String> locations,
    required String hint,
    required IconData leadingIcon,
    Color? iconColor,
    required bool locked,
    required ValueChanged<String?> onChanged,
  }) {
    final col = iconColor ?? const Color(0xFF4A148C);
    return InkWell(
      onTap: locked
          ? null
          : () async {
              final picked = await _showLocationSearch(locations, value);
              if (picked != null) onChanged(picked);
            },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
          color: locked ? Colors.grey.shade50 : Colors.white,
        ),
        child: Row(
          children: [
            Icon(leadingIcon, size: 18, color: col),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value?.isNotEmpty == true ? value! : hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value?.isNotEmpty == true
                      ? Colors.black87
                      : Colors.grey.shade400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.search, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
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
        _buildLocationPicker(
          value: safeFrom,
          locations: allLocs,
          hint: 'Select origin',
          leadingIcon: Icons.my_location,
          iconColor: accent,
          locked: _isLocked,
          onChanged: (val) {
            setState(() {
              _selectedFrom           = val;
              _endLocation            = null;
              _serverTaKm             = 0;
              _serverTaAmount         = 0;
              _serverDaAmount         = 0;
              _segmentDetails         = [];
              _routeNotFound          = false;
              _routeFromOtherEmployee = false;
              _taOverrideByUser       = false;
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
              child: _buildLocationPicker(
                value: safeTo,
                locations: allLocs,
                hint: 'Select destination',
                leadingIcon: Icons.location_on_outlined,
                iconColor: accent,
                locked: _isLocked,
                onChanged: (v) => _onDestinationSelected(v),
              ),
            ),
            if (_serverDaType.isNotEmpty && _endLocation != null) ...[
              const SizedBox(width: 8),
              _buildStationTypeBadge(_serverDaType == 'EX-OS' || _serverDaType == 'EX_OS' ? 'EX-OS' : _serverDaType == 'OS' ? 'OS' : _serverDaType == 'EX' ? 'EXHQ' : 'HQ'),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Journey Type toggle — hidden for NFW (has its own toggle); for FIELD only EX/EX_OS are interactive
        if (_expenseMode != 'NFW')
        Builder(builder: (ctx) {
          final isExType = _serverDaType == 'EX' || _serverDaType == 'EX_OS';
          return Row(
            children: [
              Text('Journey Type',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
              _buildWayChip(
                label: 'One Way',
                selected: !_isTwoWay,
                enabled: isExType,
                onTap: () {
                  if (_isTwoWay) {
                    setState(() { _isTwoWay = false; _taDirection = 'one_way'; });
                    if (_endLocation != null) _recalculateFromServer(_endLocation!, taDirection: 'one_way');
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildWayChip(
                label: 'Two Way',
                selected: _isTwoWay,
                enabled: isExType,
                onTap: () {
                  if (!_isTwoWay) {
                    setState(() { _isTwoWay = true; _taDirection = 'two_way'; });
                    if (_endLocation != null) _recalculateFromServer(_endLocation!, taDirection: 'two_way');
                  }
                },
              ),
              if (_isTwoWay && _serverTaKm > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.deepPurple.shade200),
                  ),
                  child: Text('${_fmt(_serverTaKm)} km (2-way)',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700)),
                ),
              ],
              if (_expenseMode == 'FIELD' && _taDirection.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Auto: ${_taDirection == 'two_way' ? '2-way' : '1-way'}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700),
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWayChip({required String label, required bool selected, required VoidCallback onTap, bool enabled = true}) {
    final active = enabled && !_isLocked;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (active ? const Color(0xFF4A148C) : Colors.grey.shade400)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? (active ? const Color(0xFF4A148C) : Colors.grey.shade400)
                  : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : (active ? Colors.grey.shade700 : Colors.grey.shade400))),
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

          // Multi-stop draggable route
          _buildFieldRouteSection(),
          const SizedBox(height: 14),

          // Mode of Travel
          Text('Mode of Travel',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          _buildModeChips(),
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

  Widget _buildSelectBothLocationsHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A148C).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_searching, color: const Color(0xFF4A148C), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select both From and To locations to view DA & TA allowances.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllowanceCards() {
    return Column(
      children: [
        if ((_serverDaType == 'OS' || _serverDaType == 'EX_OS') && !_isLocked) ...[
          _buildOsReturnToggle(),
          const SizedBox(height: 10),
        ],
        _buildDaCard(),
        const SizedBox(height: 10),
        _buildTaCard(),
      ],
    );
  }

  Widget _buildOsReturnToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isOsReturn ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isOsReturn ? Colors.orange.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_outlined,
              color: _isOsReturn ? Colors.orange.shade700 : Colors.grey.shade500,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('OS Return Allowance',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isOsReturn
                                ? Colors.orange.shade800
                                : Colors.grey.shade700,
                            fontSize: 13)),
                    if (_osReturnAmount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isOsReturn
                              ? Colors.orange.shade600
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('₹${_fmt(_osReturnAmount)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _isOsReturn
                      ? 'OS/EX_OS DA replaced by return allowance ₹${_fmt(_osReturnAmount)}'
                      : 'Claim OS return allowance (replaces OS/EX_OS DA)',
                  style: TextStyle(
                      fontSize: 11,
                      color: _isOsReturn
                          ? Colors.orange.shade700
                          : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(
            value: _isOsReturn,
            onChanged: (v) {
              _isOsReturn = v;
              _recalculateTotal(); // calls setState internally
            },
            activeThumbColor: Colors.orange.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildDaCard() {
    final daType = _serverDaType;
    final isOsType = daType == 'OS' || daType == 'EX_OS';
    // Hotel bill section only shown when OS return is NOT active
    final showHotelBill = isOsType && _hotelBillFlag && !_isLocked && !_isOsReturn;

    // Effective DA shown in header — OS return takes priority over everything
    final effectiveDa = _isOsReturn
        ? _osReturnAmount
        : (_hotelBillClaimed && showHotelBill)
            ? _pocketAllowance + _hotelAmount + _mealAmount
            : _serverDaAmount;

    final Map<String, String> labels = {
      'HQ':    'HQ Daily Allowance',
      'EX':    'Ex-HQ Daily Allowance',
      'OS':    _isOsReturn ? 'OS Return Allowance' : (_hotelBillClaimed ? 'Claimed DA (Hotel + Meal + Pocket)' : 'Outstation Daily Allowance'),
      'EX_OS': _isOsReturn ? 'OS Return Allowance' : (_hotelBillClaimed ? 'Claimed DA (Hotel + Meal + Pocket)' : 'Ex-Outstation Daily Allowance'),
    };
    final Map<String, Color> colors = {
      'OS':    Colors.red,
      'EX_OS': Colors.deepOrange,
      'EX':    Colors.orange,
      'HQ':    const Color(0xFF4A148C),
    };
    final label = labels[daType] ?? 'Daily Allowance';
    final color = colors[daType] ?? const Color(0xFF4A148C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
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
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('₹${_fmt(effectiveDa)}',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A148C))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
            ],
          ),

          // ── Hotel bill toggle (OS / EX_OS only when flag=1) ─────────
          if (showHotelBill) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.hotel_outlined, size: 18, color: Colors.teal.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Claim Hotel / Meal Bill',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800)),
                      Text(
                        _hotelBillClaimed
                            ? 'Flat DA ₹${_fmt(_serverDaAmount)} removed — enter actual bills below'
                            : 'Flat OS DA ₹${_fmt(_serverDaAmount)} applies. Toggle to claim bills.',
                        style: TextStyle(
                            fontSize: 11,
                            color: _hotelBillClaimed
                                ? Colors.teal.shade700
                                : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hotelBillClaimed,
                  onChanged: (v) {
                    setState(() {
                      _hotelBillClaimed = v;
                      if (!v) {
                        _hotelAmount = 0;
                        _mealAmount = 0;
                        _hotelAmountController.clear();
                        _mealAmountController.clear();
                      }
                    });
                    _recalculateTotal();
                  },
                  activeThumbColor: Colors.teal.shade600,
                ),
              ],
            ),

            // ── Bill entry fields (visible only when claimed) ─────────
            if (_hotelBillClaimed) ...[
              const SizedBox(height: 14),
              // Pocket allowance chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.wallet_outlined,
                        size: 16, color: Colors.teal.shade700),
                    const SizedBox(width: 8),
                    Text('Pocket Allowance:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.teal.shade700)),
                    const Spacer(),
                    Text('₹${_fmt(_pocketAllowance)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Hotel bill input
              TextField(
                controller: _hotelAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  setState(() => _hotelAmount = double.tryParse(v) ?? 0);
                  _recalculateTotal();
                },
                decoration: InputDecoration(
                  labelText: 'Hotel Bill Amount',
                  prefixText: '₹ ',
                  suffixText: _hotelBillLimit > 0 ? 'Limit ₹${_fmt(_hotelBillLimit)}' : null,
                  suffixStyle: TextStyle(
                    fontSize: 11,
                    color: (_hotelBillLimit > 0 && _hotelAmount > _hotelBillLimit)
                        ? Colors.red.shade600
                        : Colors.grey.shade500,
                  ),
                  helperText: (_hotelBillLimit > 0 && _hotelAmount > _hotelBillLimit)
                      ? '₹${_fmt(_hotelAmount - _hotelBillLimit)} above limit — may need manager approval'
                      : (_hotelCityClass.isNotEmpty ? 'Class-$_hotelCityClass city limit applies' : null),
                  helperStyle: TextStyle(
                    fontSize: 10,
                    color: (_hotelBillLimit > 0 && _hotelAmount > _hotelBillLimit)
                        ? Colors.red.shade600
                        : Colors.orange.shade700,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: (_hotelBillLimit > 0 && _hotelAmount > _hotelBillLimit)
                            ? Colors.red.shade400
                            : Colors.teal.shade600,
                      )),
                ),
              ),
              const SizedBox(height: 10),
              // Meal bill input
              TextField(
                controller: _mealAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  setState(() => _mealAmount = double.tryParse(v) ?? 0);
                  _recalculateTotal();
                },
                decoration: InputDecoration(
                  labelText: 'Meal Bill Amount',
                  prefixText: '₹ ',
                  suffixText: _mealBillLimit > 0 ? 'Limit ₹${_fmt(_mealBillLimit)}' : null,
                  suffixStyle: TextStyle(
                    fontSize: 11,
                    color: (_mealBillLimit > 0 && _mealAmount > _mealBillLimit)
                        ? Colors.red.shade600
                        : Colors.grey.shade500,
                  ),
                  helperText: (_mealBillLimit > 0 && _mealAmount > _mealBillLimit)
                      ? '₹${_fmt(_mealAmount - _mealBillLimit)} above limit — may need manager approval'
                      : null,
                  helperStyle: TextStyle(fontSize: 10, color: Colors.red.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: (_mealBillLimit > 0 && _mealAmount > _mealBillLimit)
                            ? Colors.red.shade400
                            : Colors.teal.shade600,
                      )),
                ),
              ),
              const SizedBox(height: 12),
              // DA breakdown summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    _daBreakdownRow('Pocket Allowance', _pocketAllowance, Colors.teal),
                    if (_hotelAmount > 0)
                      _daBreakdownRow('Hotel Bill', _hotelAmount, Colors.indigo),
                    if (_mealAmount > 0)
                      _daBreakdownRow('Meal Bill', _mealAmount, Colors.deepOrange),
                    const Divider(height: 12),
                    Row(
                      children: [
                        const Text('Total DA',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        Text(
                            '₹${_fmt(_pocketAllowance + _hotelAmount + _mealAmount)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF4A148C))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _daBreakdownRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const Spacer(),
          Text('₹${_fmt(amount)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildTaCard() {
    final isTrain   = _serverTaMode == 'train';
    final hasRoute  = _endLocation != null && _serverTaKm > 0;
    final taColor   = isTrain ? Colors.indigo : (hasRoute ? Colors.teal : Colors.green);
    final taLabel   = isTrain
        ? 'Travel Allowance (Train)'
        : hasRoute
            ? 'Travel Allowance (Route)'
            : 'Travel Allowance (DCR)';
    final taIcon    = isTrain ? Icons.train : Icons.directions_car_outlined;
    // Derive station type badge from server DA type
    print('Server DA Type: $_serverDaType');
    final stationType = _serverDaType == 'EX-OS' || _serverDaType == 'EX_OS' ? 'EX_OS'
        : _serverDaType == 'OS' ? 'OS'
        : _serverDaType == 'EX' ? 'EX' : 'HQ';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isTrain ? Colors.indigo.shade200
                  : hasRoute ? Colors.teal.shade200 : Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _isRecalculating
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
                    Text('Recalculating…',
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
                      Row(children: [
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
                        ],
                        if (_isTwoWay) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.deepPurple.shade200)),
                            child: Text('2-way',
                                style: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text('₹${_fmt(_serverTaAmount)}',
                          style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: taColor.shade700)),
                      if (_endLocation != null)
                        Row(children: [
                          _buildStationTypeBadge(stationType),
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
                    Text('${_fmt(_serverTaKm)} km',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: taColor.shade700)),
                    Text(isTrain ? 'train km' : 'km',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),  // end Row (else branch of ternary)

          // Show "Add Route" when: (a) no route found at all, or (b) km came from another employee
          if ((_routeNotFound || _routeFromOtherEmployee) && !_isLocked) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _routeFromOtherEmployee
                    ? Colors.blue.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _routeFromOtherEmployee
                        ? Colors.blue.shade200
                        : Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _routeFromOtherEmployee
                        ? Icons.person_search_outlined
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: _routeFromOtherEmployee
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _routeFromOtherEmployee
                          ? 'Km from another employee\'s route. Save to your profile for accurate TA.'
                          : 'Route not found. Add this route to calculate TA.',
                      style: TextStyle(
                          fontSize: 11,
                          color: _routeFromOtherEmployee
                              ? Colors.blue.shade800
                              : Colors.orange.shade800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showAddRouteSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _routeFromOtherEmployee
                            ? Colors.blue.shade600
                            : Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_road, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Add Route',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Train: amount override field always shown; ticket required only on override
          if (isTrain && !_isLocked) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Editable TA amount
            TextField(
              controller: _trainTaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Actual Train Fare (₹)',
                prefixText: '₹ ',
                hintText: _serverTaAmount.toStringAsFixed(2),
                helperText: 'Override if actual fare differs from slab rate',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.indigo.shade600)),
              ),
              onChanged: (v) {
                final val = double.tryParse(v);
                if (val != null) {
                  setState(() => _serverTaAmount = val);
                  _recalculateTotal();
                }
              },
            ),
            // Ticket attachment — only required when user overrides the slab fare
            if (_trainTaController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                    withData: true);
                if (result != null && result.files.isNotEmpty) {
                  setState(() => _trainTicketFile = result.files.first);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _trainTicketFile != null
                      ? Colors.indigo.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _trainTicketFile != null
                          ? Colors.indigo.shade300
                          : Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _trainTicketFile != null
                          ? Icons.check_circle_outline
                          : Icons.upload_file_outlined,
                      color: _trainTicketFile != null
                          ? Colors.indigo.shade700
                          : Colors.red.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _trainTicketFile != null
                            ? _trainTicketFile!.name
                            : 'Attach Train Ticket (required) *',
                        style: TextStyle(
                          fontSize: 12,
                          color: _trainTicketFile != null
                              ? Colors.indigo.shade700
                              : Colors.red.shade700,
                          fontWeight: _trainTicketFile == null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_trainTicketFile != null)
                      GestureDetector(
                        onTap: () => setState(() => _trainTicketFile = null),
                        child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                      ),
                  ],
                ),
              ),
            ),
            ],  // closes: if (_trainTaController.text.trim().isNotEmpty)
          ],    // closes: if (isTrain && !_isLocked)
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
          ...List.generate(_attachments.length, (i) => _buildAttachmentRow(i)),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentRow(int i) {
    final file = _attachments[i];
    final meta = _attachmentsMeta[i];
    final ext = file.extension?.toLowerCase() ?? '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: meta.isGst ? Colors.green.shade300 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: isImage && file.bytes != null
                      ? Image.memory(file.bytes!, width: 48, height: 48, fit: BoxFit.cover)
                      : Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf,
                                  color: Colors.red.shade400, size: 22),
                              Text(ext.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 8, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(file.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                if (!_isLocked) ...[
                  GestureDetector(
                    onTap: () => _showGstSheet(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: meta.isGst
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: meta.isGst
                                ? Colors.green.shade400
                                : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            meta.isGst
                                ? Icons.verified_outlined
                                : Icons.receipt_long_outlined,
                            size: 12,
                            color: meta.isGst
                                ? Colors.green.shade700
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            meta.isGst ? 'GST' : 'No GST',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: meta.isGst
                                    ? Colors.green.shade700
                                    : Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _attachments.removeAt(i);
                      _attachmentsMeta.removeAt(i);
                    }),
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
          ),
          if (meta.isGst)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  const SizedBox(width: 58),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              _capitalize(meta.billType),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (meta.vendorName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(meta.vendorName,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ]),
                        if (meta.gstNumber.isNotEmpty)
                          Text('GST: ${meta.gstNumber}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (meta.billAmount > 0)
                    Text('₹${_fmt(meta.billAmount)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A148C))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showGstSheet(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GstDetailsSheet(meta: _attachmentsMeta[index]),
    ).then((_) => setState(() {}));
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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
          if (item.bill != null && item.bill!.bytes != null) ...[
            const SizedBox(width: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(item.bill!.bytes!, width: 30, height: 30, fit: BoxFit.cover),
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _attachments.addAll(result.files);
        _attachmentsMeta.addAll(result.files.map((_) => _AttachmentMeta()));
      });
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
    // Ticket required only when user has overridden the slab train fare
    if (_serverTaMode == 'train' &&
        _trainTaController.text.trim().isNotEmpty &&
        _trainTicketFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please attach your train ticket when overriding the fare.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
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
        final kmFinal = _serverTaKm > 0
            ? _serverTaKm.toStringAsFixed(2)
            : (kmManual.isNotEmpty ? kmManual : (_calcData!['total_km'] ?? '0').toString());
        final daAmt = _hotelBillClaimed
            ? ((_calcData!['pocket_allowance'] as num?)?.toDouble() ?? _serverDaAmount)
            : _serverDaAmount;
        final activeWaypoints = _fieldWaypoints
            .where((w) => w != null && w.isNotEmpty)
            .cast<String>()
            .toList();
        payload = {
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'da_type': _serverDaType,
          'da_amount': daAmt.toStringAsFixed(2),
          'ta_distance': kmFinal,
          'ta_amount': _serverTaAmount.toStringAsFixed(2),
          'ta_mode': _serverTaMode,
          'waypoints': jsonEncode(activeWaypoints),
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
          'ta_distance': _serverTaKm.toStringAsFixed(2),
          'ta_amount': _serverTaAmount.toStringAsFixed(2),
          'other_amount': _totalOtherAmount.toStringAsFixed(2),
          'remarks': _remarkController.text.trim(),
          'mode_of_travel': _modeOfTravel,
          'start_location': _userHq ?? 'HQ',
          'end_location': _endLocation ?? '',
        };
      } else {
        // TRANSIT — prefer server-calculated values, fall back to manual
        final kmTransit = _serverTaKm > 0
            ? _serverTaKm.toStringAsFixed(2)
            : (_manualKmController.text.trim().isEmpty
                ? (_endLocationKm != null ? _endLocationKm!.toStringAsFixed(2) : '0')
                : _manualKmController.text.trim());
        final taTransit = _serverTaAmount > 0
            ? _serverTaAmount.toStringAsFixed(2)
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

      // New SFA fields — common across all expense modes
      payload.addAll({
        'hotel_bill_claimed': _hotelBillClaimed ? '1' : '0',
        'hotel_amount': _hotelAmount.toStringAsFixed(2),
        'meal_amount': _mealAmount.toStringAsFixed(2),
        'is_os_return': _isOsReturn ? '1' : '0',
        'ta_direction': _taDirection,
        'from_location': _selectedFrom ?? _transitFromTown ?? _userHq ?? '',
        'to_location': _endLocation ?? '',
        'nfw_travel_by': _nfwTravelBy,
        'attachments_meta':
            jsonEncode(_attachmentsMeta.map((m) => m.toJson()).toList()),
      });

      // Build final attachment list + meta (append train ticket when present)
      final submitAttachments = List<PlatformFile>.from(_attachments);
      final submitMeta        = List<_AttachmentMeta>.from(_attachmentsMeta);
      if (_trainTicketFile != null) {
        submitAttachments.add(_trainTicketFile!);
        submitMeta.add(_AttachmentMeta()
          ..billType   = 'travel'
          ..billAmount = _serverTaAmount);
        // Re-encode meta to include train ticket entry
        payload['attachments_meta'] =
            jsonEncode(submitMeta.map((m) => m.toJson()).toList());
      }

      await ApiService().submitExpense(
        payload,
        submitAttachments,
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

  // ─── Add Route Sheet ──────────────────────────────────────────────────────────

  Future<void> _showAddRouteSheet() async {
    if (!mounted) return;
    final from = _selectedFrom ?? _userHq ?? '';
    final to   = _endLocation ?? '';

    // When the km already came from another employee's route, use it directly.
    // Only call the suggestion API when there is no km at all (route truly not found).
    double? suggestedKm;
    if (_serverTaKm > 0) {
      // km is already known from another employee's route — use it as the suggestion
      suggestedKm = _serverTaKm;
    } else if (from.isNotEmpty && to.isNotEmpty) {
      try {
        final hint = await ApiService().getRouteKmSuggestion(fromTown: from, toTown: to);
        if (hint['found'] == true && hint['suggested_km'] != null) {
          suggestedKm = (hint['suggested_km'] as num).toDouble();
        }
      } catch (_) {}
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRouteSheet(
        fromTown: from,
        toTown: to,
        initialKm: null,   // always use suggestedKm so the hint banner is shown
        suggestedKm: suggestedKm,
        initialMode: _modeOfTravel,
        onSaved: () async {
          await _loadTaRoutes();
          if (!mounted) return;
          setState(() {
            _routeNotFound          = false;
            _routeFromOtherEmployee = false;
            _taOverrideByUser       = false;
            _manualKmController.clear();
            _manualTaController.text = '0.00';
          });
          if (_expenseMode == 'FIELD') {
            _recalcFieldRoute();
          } else {
            _updateTaFromSelection();
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Route added. TA recalculated.'),
            backgroundColor: Colors.green,
          ));
        },
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ─── Searchable Location Picker Sheet ────────────────────────────────────────

class _LocationSearchSheet extends StatefulWidget {
  final List<String> locations;
  final String? current;
  const _LocationSearchSheet({required this.locations, this.current});

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.locations;
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.locations
          : widget.locations
              .where((l) => l.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 8,
      ),
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search location…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchCtrl.clear())
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No locations found',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final loc = _filtered[i];
                      final isCurrent = loc == widget.current;
                      return ListTile(
                        dense: true,
                        title: Text(loc,
                            style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? const Color(0xFF4A148C)
                                    : Colors.black87)),
                        trailing: isCurrent
                            ? const Icon(Icons.check,
                                color: Color(0xFF4A148C), size: 18)
                            : null,
                        onTap: () => Navigator.pop(context, loc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Other Expense Bottom Sheet ──────────────────────────────────────────

class _AddOtherExpenseSheet extends StatefulWidget {
  final void Function(String type, double amount, PlatformFile? bill) onAdd;
  const _AddOtherExpenseSheet({required this.onAdd});

  @override
  State<_AddOtherExpenseSheet> createState() => _AddOtherExpenseSheetState();
}

class _AddOtherExpenseSheetState extends State<_AddOtherExpenseSheet> {
  static const _types = ['Toll', 'Courier', 'Parking', 'Food Bill', 'Others'];
  String _selectedType = 'Toll';
  final _amtController = TextEditingController();
  final _customTypeController = TextEditingController();
  PlatformFile? _bill;

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
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                withData: true,
              );
              if (result != null && result.files.isNotEmpty && mounted) {
                setState(() => _bill = result.files.first);
              }
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
                  if (_bill != null && _bill!.bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(_bill!.bytes!, width: 36, height: 36, fit: BoxFit.cover),
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

// ─── GST Details Bottom Sheet ─────────────────────────────────────────────────

class _GstDetailsSheet extends StatefulWidget {
  final _AttachmentMeta meta;
  const _GstDetailsSheet({required this.meta});

  @override
  State<_GstDetailsSheet> createState() => _GstDetailsSheetState();
}

class _GstDetailsSheetState extends State<_GstDetailsSheet> {
  static const _types = ['hotel', 'food', 'travel', 'other'];

  late bool _isGst;
  late String _billType;
  final _gstController = TextEditingController();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isGst = widget.meta.isGst;
    _billType = widget.meta.billType;
    _gstController.text = widget.meta.gstNumber;
    _vendorController.text = widget.meta.vendorName;
    _amountController.text =
        widget.meta.billAmount > 0 ? widget.meta.billAmount.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    _gstController.dispose();
    _vendorController.dispose();
    _amountController.dispose();
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
          Text('Bill Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('GST Invoice'),
            subtitle: const Text('Vendor is GST-registered',
                style: TextStyle(fontSize: 11)),
            value: _isGst,
            activeColor: const Color(0xFF4A148C),
            onChanged: (v) => setState(() => _isGst = v),
          ),
          Text('Bill Type',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _types.map((t) {
              final sel = _billType == t;
              return GestureDetector(
                onTap: () => setState(() => _billType = t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF4A148C)
                        : const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : const Color(0xFF4A148C)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Bill Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF4A148C))),
            ),
          ),
          if (_isGst) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _vendorController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Vendor Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF4A148C))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gstController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'GST Number',
                hintText: '22AAAAA0000A1Z5',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF4A148C))),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A148C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.meta.isGst = _isGst;
                widget.meta.billType = _billType;
                widget.meta.gstNumber = _gstController.text.trim();
                widget.meta.vendorName = _vendorController.text.trim();
                widget.meta.billAmount =
                    double.tryParse(_amountController.text) ?? 0;
                Navigator.pop(context);
              },
              child: Text('Save',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add New Route Sheet ──────────────────────────────────────────────────────

class _AddRouteSheet extends StatefulWidget {
  final String fromTown;
  final String toTown;
  final double? initialKm;
  // Min km found for this pair in other employees' routes — shown as a hint/pre-fill
  final double? suggestedKm;
  final String? initialMode;
  final VoidCallback onSaved;

  const _AddRouteSheet({
    required this.fromTown,
    required this.toTown,
    this.initialKm,
    this.suggestedKm,
    this.initialMode,
    required this.onSaved,
  });

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  late final TextEditingController _kmController;
  String _mode = 'Bike';
  String _stationType = 'HQ';
  bool _saving = false;
  String _empCode = '';
  String _positionCode = '';

  static const _modes = ['Bike', 'Car', 'Bus', 'Train', 'Auto'];
  static const _stationTypes = ['HQ', 'EX', 'OS', 'EX_OS'];
  static const _stationLabels = {'HQ': 'HQ', 'EX': 'EX-HQ', 'OS': 'Outstation', 'EX_OS': 'Ex-Outstation'};

  @override
  void initState() {
    super.initState();
    // initialKm wins (edit/recalc result); suggestedKm is the fallback hint from other employees
    final km = widget.initialKm ?? widget.suggestedKm;
    _kmController = TextEditingController(
      text: (km ?? 0) > 0 ? km!.toStringAsFixed(1) : "0.0",
    );
    if (widget.initialMode != null && _modes.contains(widget.initialMode)) {
      _mode = widget.initialMode!;
    }
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService().getUser();
    if (mounted && user != null) {
      setState(() {
        _empCode = user.employeeCode;
        _positionCode = user.designation ?? '';
      });
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final km = double.tryParse(_kmController.text.trim()) ?? 0;
    if (km < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid distance.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService().saveExpenseRoute(
        fromTown: widget.fromTown,
        toTown: widget.toTown,
        modeOfTravel: _mode,
        kms: km,
        stationType: _stationType,
      );
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A148C))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            Text('Add New Route',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('This route will be saved to your profile for future filings.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),

            // From / To (read-only)
            _infoTile('From', widget.fromTown.isNotEmpty ? widget.fromTown : '—'),
            const SizedBox(height: 8),
            _infoTile('To', widget.toTown.isNotEmpty ? widget.toTown : '—'),
            const SizedBox(height: 8),
            // Employee / Position (auto from login)
            _infoTile('Employee Code', _empCode.isNotEmpty ? _empCode : '…'),
            const SizedBox(height: 8),
            _infoTile('Position Code', _positionCode.isNotEmpty ? _positionCode : '…'),
            const SizedBox(height: 16),

            // KM input — locked when km is known from another employee's route
            TextField(
              controller: _kmController,
              readOnly: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Distance (km)',
                suffixText: 'km',
                suffixIcon: Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
                filled: widget.suggestedKm != null && widget.suggestedKm! > 0,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color:Colors.grey.shade400
                        ),
              ),
              ),
              ),
            if (widget.suggestedKm != null && widget.suggestedKm! > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    'Km set from existing route data — cannot be changed.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Mode of Travel
            Text('Mode of Travel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _modes.map((m) {
                final sel = m == _mode;
                return ChoiceChip(
                  label: Text(m),
                  selected: sel,
                  onSelected: (_) => setState(() => _mode = m),
                  selectedColor: const Color(0xFF4A148C),
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: sel ? Colors.white : Colors.grey.shade800,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Station Type
            Text('Station Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _stationTypes.map((s) {
                final sel = s == _stationType;
                return ChoiceChip(
                  label: Text(_stationLabels[s]!),
                  selected: sel,
                  onSelected: (_) => setState(() => _stationType = s),
                  selectedColor: const Color(0xFF4A148C),
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: sel ? Colors.white : Colors.grey.shade800,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save Route',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
