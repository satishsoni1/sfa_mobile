import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';
import 'ExpenseScreen.dart';

class ExpenseCalendarScreen extends StatefulWidget {
  const ExpenseCalendarScreen({super.key});

  @override
  State<ExpenseCalendarScreen> createState() => _ExpenseCalendarScreenState();
}

class _ExpenseCalendarScreenState extends State<ExpenseCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  bool _isMonthSubmitted = false; // true → block adding new daily expenses
  Map<String, dynamic> _calendarData = {};
  // keyed by "yyyy-MM-dd" for O(1) lookup
  Map<String, Map<String, dynamic>> _expensesByDate = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService().getCalendarStatus(_selectedMonth.month, _selectedMonth.year),
        ApiService().getMonthlySummary(_selectedMonth.month, _selectedMonth.year),
      ]);
      if (!mounted) return;
      final calData = results[0] as Map<String, dynamic>;
      final summaryData = results[1] as Map<String, dynamic>;
      final expenseList = (summaryData['expenses'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final byDate = <String, Map<String, dynamic>>{};
      for (final e in expenseList) {
        final dateStr = e['expense_date']?.toString() ?? '';
        if (dateStr.isNotEmpty) byDate[dateStr] = e;
      }
      setState(() {
        _calendarData       = calData;
        _expensesByDate     = byDate;
        _isMonthSubmitted   = summaryData['is_already_submitted'] == true;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedMonth = next);
    _loadAll();
  }

  Future<void> _openDay(Map<String, dynamic> day) async {
    final type = day['type']?.toString() ?? 'open';
    final dayNum = day['day'] as int? ?? 0;
    if (dayNum == 0) return;

    final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNum);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Sundays are now allowed — fall through to normal add/edit logic
    if (type == 'holiday') {
      _showDayInfo('Holiday', day['label']?.toString() ?? 'Public holiday — no expense required.', Colors.orange);
      return;
    }
    if (type == 'leave') {
      _showDayInfo('Leave', 'You were on leave — no expense required.', Colors.amber);
      return;
    }

    // Future date (shouldn't be tappable but guard anyway)
    if (date.isAfter(DateTime.now())) {
      _showDayInfo('Future Date', 'Cannot file expense for a future date.', Colors.grey);
      return;
    }

    // Month submitted — block adding new expenses; existing ones open read-only
    if (_isMonthSubmitted && type != 'expense') {
      _showDayInfo(
        'Month Submitted',
        'This month is submitted for approval. New expenses cannot be added.',
        const Color(0xFF4A148C),
      );
      return;
    }

    final editData = type == 'expense' ? _expensesByDate[dateStr] : null;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseScreen(
          editData: editData,
          initialDate: editData == null ? date : null,
        ),
      ),
    );
    _loadAll(); // refresh after expense add/edit
  }

  void _showDayInfo(String title, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('$title: $message')),
        ],
      ),
      backgroundColor: color.withValues(alpha: 0.85),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Add Expense',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          if (_isMonthSubmitted) _buildSubmittedBanner(),
          _buildLegend(),
          _buildHint(),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(child: _buildCalendar()),
        ],
      ),
    );
  }

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
                color: isCurrentMonth
                    ? Colors.grey.shade300
                    : const Color(0xFF4A148C)),
            onPressed: isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    const items = [
      (_DayType.sunday, 'Sunday'),
      (_DayType.holiday, 'Holiday'),
      (_DayType.leave, 'Leave'),
      (_DayType.expense, 'Filed'),
      (_DayType.open, 'Open'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: items.map((pair) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: _dayColor(pair.$1),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey.shade300)),
              ),
              const SizedBox(width: 4),
              Text(pair.$2,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmittedBanner() {
    return Container(
      color: const Color(0xFF4A148C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 15, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Month submitted for approval — new expenses are locked.',
              style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      color: const Color(0xFF4A148C).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined,
              size: 15, color: const Color(0xFF4A148C)),
          const SizedBox(width: 8),
          Text(
            'Tap an open day to file expense · Tap a filed day to edit',
            style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF4A148C),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday

    final days = List<Map<String, dynamic>?>.filled(startWeekday + daysInMonth, null);
    for (var d = 1; d <= daysInMonth; d++) {
      days[startWeekday + d - 1] = _dayData(d);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((h) => Expanded(
                      child: Center(
                        child: Text(h,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: h == 'Sun'
                                    ? Colors.red.shade300
                                    : Colors.grey.shade500)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              if (day == null) return const SizedBox.shrink();
              return _buildDayCell(day);
            },
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(),
        ],
      ),
    );
  }

  Widget _buildDayCell(Map<String, dynamic> day) {
    final type = _parseType(day['type']?.toString() ?? 'open');
    final label = day['label']?.toString() ?? '';
    final dayNum = day['day']?.toString() ?? '';
    final bg = _dayColor(type);
    final fg = _dayFg(type);
    final today = DateTime.now();
    final isToday = _selectedMonth.year == today.year &&
        _selectedMonth.month == today.month &&
        day['day'] == today.day;

    // Future days are not tappable
    final dayInt = day['day'] as int? ?? 0;
    final cellDate = dayInt > 0
        ? DateTime(_selectedMonth.year, _selectedMonth.month, dayInt)
        : null;
    final isFuture = cellDate != null && cellDate.isAfter(today);
    final tappable = !isFuture && type != _DayType.sunday && type != _DayType.holiday && type != _DayType.leave;

    // Expense day gets an edit pencil indicator
    final isExpense = type == _DayType.expense;

    return GestureDetector(
      onTap: isFuture ? null : () => _openDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: isFuture ? Colors.grey.shade100 : bg,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: const Color(0xFF4A148C), width: 2)
              : tappable
                  ? Border.all(color: bg == Colors.white ? Colors.grey.shade300 : bg)
                  : Border.all(color: Colors.transparent),
          boxShadow: tappable && !isFuture
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayNum,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                          color: isFuture ? Colors.grey.shade400 : fg)),
                  if (label.isNotEmpty && !isExpense)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        label,
                        style: TextStyle(
                            fontSize: 7,
                            color: (isFuture ? Colors.grey.shade400 : fg)
                                .withValues(alpha: 0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            // Edit icon badge for filed days
            if (isExpense)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 8, color: Colors.white),
                ),
              ),
            // + badge for open tappable days
            if (type == _DayType.open && !isFuture)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                      color: const Color(0xFF4A148C),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 9, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final days = _calendarData['days'] as List? ?? [];
    int expenseCount = 0, leaveCount = 0, holidayCount = 0, openCount = 0;
    for (final d in days) {
      final t = d['type']?.toString() ?? '';
      if (t == 'expense') expenseCount++;
      if (t == 'leave') leaveCount++;
      if (t == 'holiday') holidayCount++;
      if (t == 'open') {
        // Only count past/today open days
        final dayNum = d['day'] as int? ?? 0;
        if (dayNum > 0) {
          final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayNum);
          if (!cellDate.isAfter(DateTime.now())) openCount++;
        }
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Filed', expenseCount, _dayColor(_DayType.expense), Icons.check_circle_outline),
          _summaryItem('Pending', openCount, Colors.red.shade100, Icons.radio_button_unchecked),
          _summaryItem('Leave', leaveCount, _dayColor(_DayType.leave), Icons.event_busy_outlined),
          _summaryItem('Holiday', holidayCount, _dayColor(_DayType.holiday), Icons.celebration_outlined),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text('$count',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Map<String, dynamic> _dayData(int d) {
    final days = _calendarData['days'] as List? ?? [];
    for (final item in days) {
      if (item['day'] == d) return Map<String, dynamic>.from(item);
    }
    final weekday = DateTime(_selectedMonth.year, _selectedMonth.month, d).weekday;
    return {'day': d, 'type': weekday == 7 ? 'sunday' : 'open', 'label': ''};
  }

  _DayType _parseType(String t) {
    switch (t) {
      case 'sunday': return _DayType.sunday;
      case 'holiday': return _DayType.holiday;
      case 'leave': return _DayType.leave;
      case 'expense': return _DayType.expense;
      default: return _DayType.open;
    }
  }

  Color _dayColor(_DayType type) {
    switch (type) {
      case _DayType.sunday: return Colors.grey.shade200;
      case _DayType.holiday: return Colors.orange.shade200;
      case _DayType.leave: return Colors.yellow.shade200;
      case _DayType.expense: return Colors.green.shade200;
      case _DayType.open: return Colors.white;
    }
  }

  Color _dayFg(_DayType type) {
    switch (type) {
      case _DayType.sunday: return Colors.grey.shade500;
      case _DayType.holiday: return Colors.orange.shade900;
      case _DayType.leave: return Colors.yellow.shade900;
      case _DayType.expense: return Colors.green.shade900;
      case _DayType.open: return Colors.grey.shade800;
    }
  }
}

enum _DayType { sunday, holiday, leave, expense, open }
