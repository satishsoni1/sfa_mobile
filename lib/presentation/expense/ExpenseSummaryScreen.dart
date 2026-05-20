import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/services/api_service.dart';
import 'ExpenseCalendarScreen.dart';
import 'ExpenseScreen.dart';

class ExpenseSummaryScreen extends StatefulWidget {
  const ExpenseSummaryScreen({super.key});

  @override
  State<ExpenseSummaryScreen> createState() => _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends State<ExpenseSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  List<dynamic> _expenses = [];
  List<dynamic> _monthlyClaims = [];
  Map<String, dynamic> _summary = {};
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService().getMonthlySummary(_selectedMonth.month, _selectedMonth.year),
        ApiService().getMonthlyClaims(_selectedMonth.month, _selectedMonth.year),
      ]);

      final summaryData = results[0] as Map<String, dynamic>;
      final claimsData = results[1] as List<dynamic>;

      setState(() {
        _expenses = summaryData['expenses'] ?? [];
        _summary = summaryData['summary'] ?? {};
        _isSubmitted = _summary['is_already_submitted'] == true;
        _monthlyClaims = claimsData;
      });
    } catch (_) {
      // Show empty state on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedMonth = next);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Expense Manager',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: _expenses.isEmpty ? null : _exportPdf),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMonthSelector(),
                _buildSummaryCard(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDailyList(),
                      _buildMonthlyClaimsList(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF4A148C),
              onPressed: () {
                if (_tabController.index == 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExpenseCalendarScreen()),
                  ).then((_) => _loadData());
                } else {
                  _showAddClaimSheet();
                }
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
      bottomNavigationBar: (!_isLoading && !_isSubmitted && _expenses.isNotEmpty)
          ? _buildSubmitBar()
          : null,
    );
  }

  // ─── Month Selector ──────────────────────────────────────────────────────────

  Widget _buildMonthSelector() {
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF4A148C)),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: isCurrentMonth ? Colors.grey.shade300 : const Color(0xFF4A148C)),
            onPressed: isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  // ─── Summary Card ────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final grandTotal = _toDouble(_summary['grand_total']);
    final totalDa = _toDouble(_summary['total_da']);
    final totalTa = _toDouble(_summary['total_ta']);
    final totalOther = _toDouble(_summary['total_other']);
    final claimsTotal = _monthlyClaims.fold<double>(
        0, (sum, c) => sum + _toDouble(c['amount']));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Total Claim',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${_fmt(grandTotal + claimsTotal)}',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('DA', totalDa, Icons.person_outline),
              _statItem('TA', totalTa, Icons.directions_car_outlined),
              _statItem('Other', totalOther, Icons.receipt_outlined),
              _statItem('Claims', claimsTotal, Icons.add_card_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    if (_isSubmitted) {
      return _badge('Submitted', Colors.green.shade400, Icons.lock_outline);
    }
    return _badge('Pending', Colors.orange.shade600, Icons.pending_outlined);
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statItem(String label, double val, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(height: 3),
        Text('₹${_fmt(val)}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  // ─── Tab Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF4A148C),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF4A148C),
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(text: 'Daily (${_expenses.length})'),
          Tab(text: 'Claims (${_monthlyClaims.length})'),
        ],
      ),
    );
  }

  // ─── Daily List ──────────────────────────────────────────────────────────────

  Widget _buildDailyList() {
    if (_expenses.isEmpty) {
      return _emptyState(Icons.receipt_long_outlined, 'No daily expenses',
          'Tap + to add expense for a date');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _expenses.length,
        itemBuilder: (_, i) => _buildDailyCard(_expenses[i]),
      ),
    );
  }

  Widget _buildDailyCard(Map<String, dynamic> item) {
    final isLocked = item['is_submitted_for_month'] == 1;
    final date = DateTime.tryParse(item['expense_date'] ?? '') ?? DateTime.now();
    final daType = (item['da_type'] ?? 'HQ').toString().toUpperCase();
    final total = _toDouble(item['da_amount']) +
        _toDouble(item['ta_amount']) +
        _toDouble(item['other_amount']);
    final fromLoc = (item['from_location'] ?? item['start_location'] ?? '').toString();
    final toLoc = (item['to_location'] ?? item['end_location'] ?? '').toString();
    final taDir = (item['ta_direction'] ?? 'one_way').toString();
    final hotelBillClaimed =
        item['hotel_bill_claimed'] == 1 || item['hotel_bill_claimed'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLocked ? null : () => _openDailyExpense(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Date block
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isLocked ? Colors.grey.shade100 : const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('dd').format(date),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isLocked ? Colors.grey : const Color(0xFF4A148C))),
                    Text(DateFormat('MMM').format(date),
                        style: TextStyle(
                            fontSize: 9,
                            color: isLocked ? Colors.grey : Colors.purple.shade400)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _daBadge(daType),
                        const Spacer(),
                        Text('₹${_fmt(total)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: const Color(0xFF4A148C))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DA ₹${_fmt(_toDouble(item['da_amount']))}  •  TA ${_fmt(_toDouble(item['ta_distance']))}km ₹${_fmt(_toDouble(item['ta_amount']))}  •  Other ₹${_fmt(_toDouble(item['other_amount']))}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (fromLoc.isNotEmpty || toLoc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 10, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              [
                                if (fromLoc.isNotEmpty) fromLoc,
                                if (toLoc.isNotEmpty) toLoc,
                              ].join(' → '),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (taDir == 'two_way') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('2-way',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          if (hotelBillClaimed) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('Hotel Bill',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLocked ? Icons.lock_outline : Icons.edit_outlined,
                color: isLocked ? Colors.grey.shade400 : Colors.purple.shade300,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _daBadge(String type) {
    final map = {
      'OS': [Colors.red.shade50, Colors.red.shade700],
      'EX': [Colors.orange.shade50, Colors.orange.shade700],
      'HQ': [const Color(0xFFEDE7F6), const Color(0xFF4A148C)],
    };
    final colors = map[type] ?? [Colors.grey.shade100, Colors.grey.shade600];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(6)),
      child: Text(type,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: colors[1])),
    );
  }

  // ─── Monthly Claims List ──────────────────────────────────────────────────────

  Widget _buildMonthlyClaimsList() {
    final total =
        _monthlyClaims.fold<double>(0, (s, c) => s + _toDouble(c['amount']));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          _buildQuickAddSection(),
          const SizedBox(height: 8),
          if (_monthlyClaims.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Icon(Icons.add_card_outlined,
                      size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No claims added yet',
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade500, fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    'Use Quick Add above or tap + for other bills',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          else ...[
            // Claims total bar
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.summarize_outlined,
                      color: Colors.teal.shade700, size: 18),
                  const SizedBox(width: 10),
                  Text('Total Claims',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700)),
                  const Spacer(),
                  Text('₹${_fmt(total)}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                          fontSize: 16)),
                ],
              ),
            ),
            ..._monthlyClaims.map((c) => _buildClaimCard(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAddSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Add Monthly Bills',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _quickAddButton(
                      'Mobile', Icons.phone_android, Colors.blue)),
              const SizedBox(width: 10),
              Expanded(
                  child: _quickAddButton('Internet', Icons.wifi, Colors.teal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAddButton(String type, IconData icon, Color color) {
    return InkWell(
      onTap: _isSubmitted ? null : () => _showAddClaimSheet(initialType: type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: _isSubmitted
              ? Colors.grey.shade100
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _isSubmitted
                  ? Colors.grey.shade300
                  : color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: _isSubmitted ? Colors.grey.shade400 : color, size: 18),
            const SizedBox(width: 6),
            Text(type,
                style: TextStyle(
                    color: _isSubmitted ? Colors.grey.shade400 : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.add_circle_outline,
                color: _isSubmitted ? Colors.grey.shade400 : color, size: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final icons = {
      'Mobile': Icons.phone_android,
      'Internet': Icons.wifi,
      'Hotel': Icons.hotel_outlined,
      'Postage': Icons.local_post_office_outlined,
      'Toll': Icons.toll_outlined,
      'Courier': Icons.local_shipping_outlined,
      'Parking': Icons.local_parking,
      'Food Bill': Icons.restaurant_outlined,
      'Misc': Icons.more_horiz,
    };
    final claimColors = {
      'Mobile': Colors.blue,
      'Internet': Colors.teal,
      'Hotel': Colors.indigo,
      'Postage': Colors.brown,
      'Toll': Colors.deepOrange,
      'Courier': Colors.cyan,
      'Parking': Colors.purple,
      'Food Bill': Colors.green,
      'Misc': Colors.grey,
    };
    final type = claim['claim_type'] ?? 'Misc';
    final icon = icons[type] ?? Icons.receipt;
    final color = claimColors[type] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(type,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          claim['bill_attachment'] != null ? 'Bill attached' : 'No bill uploaded',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: Text('₹${_fmt(_toDouble(claim['amount']))}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A148C),
                fontSize: 15)),
      ),
    );
  }

  // ─── Submit Month Bar ─────────────────────────────────────────────────────────

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(
              'Submit ${DateFormat('MMMM').format(_selectedMonth)} for Approval',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          onPressed: _confirmSubmitMonth,
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 68, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────────

  void _openDailyExpense(Map<String, dynamic>? editData) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpenseScreen(editData: editData)),
    );
    _loadData();
  }

  void _showAddClaimSheet({String? initialType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddClaimSheet(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
        initialType: initialType,
        onSuccess: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  void _confirmSubmitMonth() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            'Submit ${DateFormat('MMMM yyyy').format(_selectedMonth)}?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Once submitted, daily expenses will be locked for editing.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            _summaryRow('Daily Expenses', _expenses.length.toString(), Icons.receipt),
            _summaryRow(
                'Total Amount',
                '₹${_fmt(_toDouble(_summary['grand_total']))}',
                Icons.currency_rupee),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService().submitMonthlyExpense(
                    _selectedMonth.month, _selectedMonth.year);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Month submitted successfully!'),
                      backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child:
                const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── PDF Export ───────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final monthStr = DateFormat('MMMM yyyy').format(_selectedMonth);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Expense Statement - $monthStr',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.Text(
                    _isSubmitted ? 'SUBMITTED' : 'PENDING',
                    style: pw.TextStyle(
                        color: _isSubmitted ? PdfColors.green : PdfColors.orange,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'DA Type', 'DA ₹', 'TA km', 'TA ₹', 'Other ₹', 'Total ₹'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple100),
            data: _expenses.map((e) {
              final total = _toDouble(e['da_amount']) +
                  _toDouble(e['ta_amount']) +
                  _toDouble(e['other_amount']);
              return [
                e['expense_date'] ?? '',
                e['da_type'] ?? '',
                _fmt(_toDouble(e['da_amount'])),
                _fmt(_toDouble(e['ta_distance'])),
                _fmt(_toDouble(e['ta_amount'])),
                _fmt(_toDouble(e['other_amount'])),
                _fmt(total),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(
                    'Total DA: ₹${_fmt(_toDouble(_summary['total_da']))}'),
                pw.Text(
                    'Total TA: ₹${_fmt(_toDouble(_summary['total_ta']))}'),
                pw.Text(
                    'Other: ₹${_fmt(_toDouble(_summary['total_other']))}'),
                pw.Divider(),
                pw.Text(
                    'Grand Total: ₹${_fmt(_toDouble(_summary['grand_total']))}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
              ]),
            ],
          ),
          if (_monthlyClaims.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Monthly Claims',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Type', 'Amount', 'Bill'],
              data: _monthlyClaims.map((c) => [
                c['claim_type'] ?? '',
                '₹${_fmt(_toDouble(c['amount']))}',
                c['bill_attachment'] != null ? 'Yes' : 'No',
              ]).toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ─── Add Claim Bottom Sheet ───────────────────────────────────────────────────

class _AddClaimSheet extends StatefulWidget {
  final int month, year;
  final VoidCallback onSuccess;
  final String? initialType;

  const _AddClaimSheet(
      {required this.month, required this.year, required this.onSuccess,
      this.initialType});

  @override
  State<_AddClaimSheet> createState() => _AddClaimSheetState();
}

class _AddClaimSheetState extends State<_AddClaimSheet> {
  String _selectedType = 'Mobile';
  final _amtController = TextEditingController();
  PlatformFile? _billFile;
  bool _isSubmitting = false;
  double? _mobileRate;
  double? _internetRate;
  bool _isLoadingRate = false;

  static const _claimTypes = [
    'Mobile', 'Internet', 'Hotel', 'Postage',
    'Toll', 'Courier', 'Parking', 'Food Bill', 'Misc',
  ];
  static const _autoRatedTypes = ['Mobile', 'Internet'];

  final _claimIcons = {
    'Mobile': Icons.phone_android,
    'Internet': Icons.wifi,
    'Hotel': Icons.hotel_outlined,
    'Postage': Icons.local_post_office_outlined,
    'Toll': Icons.toll_outlined,
    'Courier': Icons.local_shipping_outlined,
    'Parking': Icons.local_parking,
    'Food Bill': Icons.restaurant_outlined,
    'Misc': Icons.more_horiz,
  };

  bool get _isAutoRated => _autoRatedTypes.contains(_selectedType);

  double get _autoRate =>
      _selectedType == 'Mobile' ? (_mobileRate ?? 0) : (_internetRate ?? 0);

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    _fetchClaimRates();
  }

  Future<void> _fetchClaimRates() async {
    setState(() => _isLoadingRate = true);
    try {
      final data = await ApiService().getMonthlyClaimRates();
      if (mounted) {
        setState(() {
          _mobileRate = (data['mobile'] as num?)?.toDouble() ?? 0;
          _internetRate = (data['internet'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {
      // rates remain null; user will see 0
    } finally {
      if (mounted) setState(() => _isLoadingRate = false);
    }
  }

  @override
  void dispose() {
    _amtController.dispose();
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
          Text('Add Monthly Claim',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Add your monthly bills for reimbursement',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),

          // Claim type chips
          Wrap(
            spacing: 8,
            children: _claimTypes.map((t) {
              final selected = _selectedType == t;
              return ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_claimIcons[t]!, size: 14,
                      color: selected ? Colors.white : const Color(0xFF4A148C)),
                  const SizedBox(width: 4),
                  Text(t),
                ]),
                selected: selected,
                onSelected: (_) => setState(() => _selectedType = t),
                selectedColor: const Color(0xFF4A148C),
                labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF4A148C),
                    fontWeight: FontWeight.w600),
                backgroundColor: const Color(0xFFEDE7F6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          if (_isAutoRated)
            _isLoadingRate
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4A148C).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF4A148C), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto-fetched from your designation rate',
                                  style: TextStyle(fontSize: 11, color: Colors.purple.shade400)),
                              const SizedBox(height: 2),
                              Text('₹${_autoRate.toStringAsFixed(0)} / month',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF4A148C))),
                            ],
                          ),
                        ),
                        Icon(Icons.lock_outline, color: Colors.purple.shade300, size: 18),
                      ],
                    ),
                  )
          else
            TextField(
              controller: _amtController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                hintText: '0.00',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4A148C))),
              ),
            ),
          const SizedBox(height: 14),

          // Bill attachment
          InkWell(
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
                final picked = await ImagePicker()
                    .pickImage(source: src, imageQuality: 70);
                if (picked != null) {
                  // CHANGED: Read bytes directly into memory for Web support
                  final bytes = await picked.readAsBytes();
                  
                  setState(() {
                    _billFile = PlatformFile(
                      name: picked.name,
                      size: bytes.length,
                      bytes: bytes,
                    );
                  });
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _billFile != null
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _billFile != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    _billFile != null ? Icons.check_circle : Icons.camera_alt_outlined,
                    color: _billFile != null ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _billFile != null ? 'Bill Attached' : 'Attach Bill Photo (Optional)',
                      style: TextStyle(
                          color: _billFile != null
                              ? Colors.green.shade700
                              : Colors.grey.shade600),
                    ),
                  ),
                  if (_billFile != null && _billFile!.bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                          _billFile!.bytes!,
                          width: 40, 
                          height: 40, 
                          fit: BoxFit.cover
                      ),
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
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Add Claim',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    double? amount;
    if (!_isAutoRated) {
      amount = double.tryParse(_amtController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().addMonthlyClaim(
        month: widget.month,
        year: widget.year,
        claimType: _selectedType,
        amount: amount, // null for Mobile/Internet — server fetches from expense_rates
        bill: _billFile,
      );
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
