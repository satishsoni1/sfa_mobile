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
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _dailyExpenses.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = _dailyExpenses[i] as Map<String, dynamic>;
        final date = e['expense_date']?.toString() ?? '';
        final daType = (e['da_type'] ?? '').toString().toUpperCase();
        final total = _toDouble(e['total_amount'] ?? (
          _toDouble(e['da_amount']) + _toDouble(e['ta_amount']) + _toDouble(e['other_amount'])
        ));
        final color = daType == 'OS'
            ? Colors.red
            : daType == 'EX' ? Colors.orange : const Color(0xFF4A148C);

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(
                DateFormat('d').format(DateTime.tryParse(date) ?? DateTime.now()),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 15),
              ),
            ),
          ),
          title: Text(
            date.isNotEmpty
                ? DateFormat('EEE, dd MMM').format(DateTime.tryParse(date) ?? DateTime.now())
                : 'Unknown date',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(daType,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          trailing: Text('₹${_fmt(total)}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF4A148C))),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    final rows = [
      ('Daily Allowance', _toDouble(_summary['total_da'])),
      ('Travel Allowance', _toDouble(_summary['total_ta'])),
      ('Other Expenses', _toDouble(_summary['total_other'])),
      ('Monthly Claims', _toDouble(_summary['total_claims'])),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                      child: Text(r.$1,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                  Text('₹${_fmt(r.$2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            )),
        const Divider(),
        Row(
          children: [
            const Expanded(
                child: Text('TOTAL',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14))),
            Text('₹${_fmt(_toDouble(_summary['total_amount']))}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF4A148C))),
          ],
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
