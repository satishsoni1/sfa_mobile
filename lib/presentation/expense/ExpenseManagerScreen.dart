import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class ExpenseManagerScreen extends StatefulWidget {
  const ExpenseManagerScreen({super.key});

  @override
  State<ExpenseManagerScreen> createState() => _ExpenseManagerScreenState();
}

class _ExpenseManagerScreenState extends State<ExpenseManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, String>> _subordinates = [];
  Map<String, String>? _selectedSub;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool _isLoadingSubs = true;
  bool _isLoadingExpenses = false;
  bool _isApproving = false;
  bool _isRejecting = false;

  Map<String, dynamic> _summary = {};
  List<dynamic> _dailyExpenses = [];
  String? _approvalStatus; // null | 'submitted' | 'approved' | 'rejected'
  String? _rejectionReason;
  String? _approverName;
  String? _approverDesignation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubordinates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubordinates() async {
    try {
      final subs = await ApiService().getSubordinatesUpload();
      if (mounted) setState(() { _subordinates = subs; _isLoadingSubs = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubs = false);
    }
  }

  Future<void> _loadExpenses() async {
    if (_selectedSub == null) return;
    setState(() => _isLoadingExpenses = true);
    try {
      final userId = int.parse(_selectedSub!['id']!);
      final data = await ApiService().getSubordinateMonthlyExpenses(
          userId, _selectedMonth.month, _selectedMonth.year);
      final daily = await ApiService().getSubordinateDailyExpenses(
          userId, _selectedMonth.month, _selectedMonth.year);
      if (mounted) {
        setState(() {
          _summary = data['summary'] ?? {};
          _dailyExpenses = data['expenses'] ?? daily;
          _approvalStatus       = _summary['approval_status']?.toString();
          _rejectionReason      = _summary['rejection_reason']?.toString();
          _approverName         = _summary['approver_name']?.toString();
          _approverDesignation  = _summary['approver_designation']?.toString();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingExpenses = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _isApproving = true);
    try {
      final userId = int.parse(_selectedSub!['id']!);
      await ApiService().approveSubordinateExpense(
          userId, _selectedMonth.month, _selectedMonth.year);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Expense approved'), backgroundColor: Colors.green));
        _loadExpenses();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _showRejectDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expense'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter rejection reason...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    setState(() => _isRejecting = true);
    try {
      final userId = int.parse(_selectedSub!['id']!);
      await ApiService().rejectSubordinateExpense(
          userId, _selectedMonth.month, _selectedMonth.year, ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Expense rejected'), backgroundColor: Colors.orange));
        _loadExpenses();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedMonth = next);
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Team Expenses',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Subordinate + Month selectors ──
          Container(
            color: const Color(0xFF4A148C),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildSubordinatePicker(),
                const SizedBox(height: 10),
                _buildMonthPicker(),
              ],
            ),
          ),
          // ── Content ──
          Expanded(
            child: _selectedSub == null
                ? _buildEmptyState()
                : _isLoadingExpenses
                    ? const Center(child: CircularProgressIndicator())
                    : _buildExpenseContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubordinatePicker() {
    if (_isLoadingSubs) {
      return const Center(
          child: SizedBox(
              height: 44,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<Map<String, String>>(
        value: _selectedSub,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF4A148C),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        hint: const Text('Select team member',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        items: _subordinates
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s['name'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ))
            .toList(),
        onChanged: (val) {
          setState(() {
            _selectedSub = val;
            _summary = {};
            _dailyExpenses = [];
            _approvalStatus = null;
          });
          _loadExpenses();
        },
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Select a team member to view expenses',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildExpenseContent() {
    final isSubmitted = _approvalStatus == 'submitted';
    final isApproved = _approvalStatus == 'approved';
    final isRejected = _approvalStatus == 'rejected';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status banner
                if (isApproved)
                  _statusBanner(
                    Icons.check_circle,
                    Colors.green,
                    'Approved',
                    (_approverName != null && _approverDesignation != null)
                        ? 'Approved by $_approverName · $_approverDesignation'
                        : _approverName != null
                            ? 'Approved by $_approverName'
                            : 'This month\'s expense has been approved.',
                  )
                else if (isRejected)
                  _statusBanner(Icons.cancel, Colors.red, 'Rejected',
                      _rejectionReason ?? 'Rejected by manager.')
                else if (isSubmitted)
                  _statusBanner(Icons.hourglass_top, Colors.orange,
                      'Pending Approval', 'Awaiting your review.')
                else
                  _statusBanner(Icons.edit_note, Colors.grey, 'Not Submitted',
                      'Member hasn\'t submitted this month yet.'),

                const SizedBox(height: 14),

                // Summary cards
                _buildSummaryCards(),
                const SizedBox(height: 14),

                // Tab bar + list
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF4A148C),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF4A148C),
                        tabs: const [
                          Tab(text: 'Daily Expenses'),
                          Tab(text: 'Summary'),
                        ],
                      ),
                      SizedBox(
                        height: 340,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDailyList(),
                            _buildSummaryTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Approve / Reject bar
        if (isSubmitted)
          _buildApproveBar(),
      ],
    );
  }

  Widget _statusBanner(IconData icon, Color color, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final items = [
      ('DA', _toDouble(_summary['total_da']), Colors.purple),
      ('TA', _toDouble(_summary['total_ta']), Colors.teal),
      ('Other', _toDouble(_summary['total_other']), Colors.orange),
      ('Total', _toDouble(_summary['total_amount']), const Color(0xFF4A148C)),
    ];
    return Row(
      children: items.map((item) {
        final (label, amount, color) = item;
        final isTotal = label == 'Total';
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: item == items.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isTotal ? color : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isTotal ? color : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: isTotal ? Colors.white70 : Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text('₹${_fmt(amount)}',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isTotal ? Colors.white : color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyList() {
    if (_dailyExpenses.isEmpty) {
      return Center(
          child: Text('No expenses recorded',
              style: TextStyle(color: Colors.grey.shade400)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: _dailyExpenses.length,
      itemBuilder: (_, i) {
        final e = _dailyExpenses[i] as Map<String, dynamic>;
        final date = e['expense_date']?.toString() ?? '';
        final daType = (e['da_type'] ?? '').toString().toUpperCase();
        final daAmt  = _toDouble(e['da_amount']);
        final taAmt  = _toDouble(e['ta_amount']);
        final otherAmt = _toDouble(e['other_amount']);
        final total  = _toDouble(e['total_amount'] ?? (daAmt + taAmt + otherAmt));
        final mode   = e['mode_of_travel']?.toString() ?? '';
        final km     = _toDouble(e['ta_distance']);
        final from   = e['from_location']?.toString() ?? '';
        final to     = e['to_location']?.toString() ?? '';
        final remarks = e['remarks']?.toString() ?? '';
        final pocket  = _toDouble(e['pocket_allowance']);
        final hotel   = _toDouble(e['hotel_amount']);
        final meal    = _toDouble(e['meal_amount']);

        final color = daType.contains('OS')
            ? Colors.red
            : daType.contains('EX') ? Colors.orange : const Color(0xFF4A148C);

        DateTime? parsedDate = DateTime.tryParse(date);
        final dayNum  = parsedDate != null ? DateFormat('d').format(parsedDate) : '?';
        final dayLabel = parsedDate != null ? DateFormat('EEE, dd MMM').format(parsedDate) : date;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text(dayNum,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                ),
              ),
              title: Text(dayLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Row(children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(daType,
                      style: TextStyle(
                          fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                ),
              ]),
              trailing: Text('₹${_fmt(total)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF4A148C))),
              children: [
                const Divider(height: 1),
                const SizedBox(height: 8),

                // From → To route
                if (from.isNotEmpty || to.isNotEmpty)
                  _detailRow(
                    Icons.route_outlined,
                    [from, to].where((s) => s.isNotEmpty).join(' → '),
                    null,
                    iconColor: Colors.blueGrey,
                    isSubtle: true,
                  ),

                // DA row
                _detailRow(
                  Icons.person_outline,
                  'DA${daType.isNotEmpty ? ' ($daType)' : ''}',
                  daAmt,
                  iconColor: color,
                ),

                // TA row
                _detailRow(
                  Icons.directions_car_outlined,
                  'TA${mode.isNotEmpty ? ' · ${_modeLabel(mode)}' : ''}${km > 0 ? ' · ${km.toStringAsFixed(1)} km' : ''}',
                  taAmt,
                  iconColor: Colors.teal,
                ),

                // Other breakdown
                if (pocket > 0)
                  _detailRow(Icons.wallet_outlined, 'Pocket Allowance', pocket,
                      iconColor: Colors.indigo),
                if (hotel > 0)
                  _detailRow(Icons.hotel_outlined, 'Hotel/Stay', hotel,
                      iconColor: Colors.brown),
                if (meal > 0)
                  _detailRow(Icons.restaurant_outlined, 'Meals', meal,
                      iconColor: Colors.deepOrange),
                if (otherAmt > 0)
                  _detailRow(Icons.receipt_outlined, 'Other', otherAmt,
                      iconColor: Colors.grey),

                // Total
                const Divider(height: 12),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 15, color: Color(0xFF4A148C)),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13))),
                    Text('₹${_fmt(total)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF4A148C))),
                  ],
                ),

                // Remarks
                if (remarks.isNotEmpty && !remarks.startsWith('[ADMIN')) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_outlined, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(remarks,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, double? amount,
      {Color iconColor = Colors.grey, bool isSubtle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: isSubtle ? 11 : 12,
                    color: isSubtle ? Colors.grey.shade500 : Colors.grey.shade700)),
          ),
          if (amount != null)
            Text('₹${_fmt(amount)}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: amount == 0 ? Colors.grey.shade400 : Colors.black87)),
        ],
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode.toLowerCase()) {
      case 'own_vehicle': return 'Own Vehicle';
      case 'public_transport': return 'Public Transport';
      case 'company_vehicle': return 'Company Vehicle';
      case 'train': return 'Train';
      case 'auto': return 'Auto';
      default: return mode;
    }
  }

  Widget _buildSummaryTab() {
    final da     = _toDouble(_summary['total_da']);
    final ta     = _toDouble(_summary['total_ta']);
    final other  = _toDouble(_summary['total_other']);
    final claims = _toDouble(_summary['total_claims']);
    final total  = _toDouble(_summary['total_amount']);

    final rows = [
      (Icons.person_outline,        'Daily Allowance (DA)',  da,     Colors.purple),
      (Icons.directions_car_outlined,'Travel Allowance (TA)', ta,     Colors.teal),
      (Icons.receipt_outlined,       'Other Expenses',        other,  Colors.orange),
      (Icons.add_card_outlined,      'Monthly Claims',        claims, Colors.indigo),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        ...rows.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: r.$4.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(r.$1, size: 16, color: r.$4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(r.$2,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ),
                  Text('₹${_fmt(r.$3)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: r.$3 == 0 ? Colors.grey.shade400 : Colors.black87)),
                ],
              ),
            )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 20, color: Colors.white70),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Grand Total',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              Text('₹${_fmt(total)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApproveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))]),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isRejecting || _isApproving ? null : _showRejectDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isRejecting
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isApproving || _isRejecting ? null : _approve,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isApproving
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
