import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class ExpenseCalendarScreen extends StatefulWidget {
  const ExpenseCalendarScreen({super.key});

  @override
  State<ExpenseCalendarScreen> createState() => _ExpenseCalendarScreenState();
}

class _ExpenseCalendarScreenState extends State<ExpenseCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic> _calendarData = {};

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getCalendarStatus(
          _selectedMonth.month, _selectedMonth.year);
      if (mounted) setState(() => _calendarData = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    final next =
        DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedMonth = next);
    _loadCalendar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('Expense Calendar',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildLegend(),
          const SizedBox(height: 8),
          _isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()))
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
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
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
      (_DayType.expense, 'Expense Filed'),
      (_DayType.open, 'Open'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: items.map((pair) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: _dayColor(pair.$1),
                    borderRadius: BorderRadius.circular(3)),
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

  Widget _buildCalendar() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday

    final days = List<Map<String, dynamic>?>.filled(
        startWeekday + daysInMonth, null);
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
          // Calendar grid
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

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: const Color(0xFF4A148C), width: 2)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dayNum,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isToday ? FontWeight.bold : FontWeight.w600,
                  color: fg)),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                style: TextStyle(fontSize: 7, color: fg.withValues(alpha: 0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final days = _calendarData['days'] as List? ?? [];
    int expenseCount = 0, leaveCount = 0, holidayCount = 0, sundayCount = 0;
    for (final d in days) {
      final t = d['type']?.toString() ?? '';
      if (t == 'expense') expenseCount++;
      if (t == 'leave') leaveCount++;
      if (t == 'holiday') holidayCount++;
      if (t == 'sunday') sundayCount++;
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
          _summaryItem('Expenses', expenseCount, _dayColor(_DayType.expense)),
          _summaryItem('Leaves', leaveCount, _dayColor(_DayType.leave)),
          _summaryItem('Holidays', holidayCount, _dayColor(_DayType.holiday)),
          _summaryItem('Sundays', sundayCount, _dayColor(_DayType.sunday)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Center(
            child: Text('$count',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Map<String, dynamic> _dayData(int d) {
    final days = _calendarData['days'] as List? ?? [];
    for (final item in days) {
      if (item['day'] == d) return Map<String, dynamic>.from(item);
    }
    // Determine if Sunday locally
    final weekday =
        DateTime(_selectedMonth.year, _selectedMonth.month, d).weekday;
    return {
      'day': d,
      'type': weekday == 7 ? 'sunday' : 'open',
      'label': '',
    };
  }

  _DayType _parseType(String t) {
    switch (t) {
      case 'sunday':
        return _DayType.sunday;
      case 'holiday':
        return _DayType.holiday;
      case 'leave':
        return _DayType.leave;
      case 'expense':
        return _DayType.expense;
      default:
        return _DayType.open;
    }
  }

  Color _dayColor(_DayType type) {
    switch (type) {
      case _DayType.sunday:
        return Colors.grey.shade300;
      case _DayType.holiday:
        return Colors.orange.shade200;
      case _DayType.leave:
        return Colors.yellow.shade200;
      case _DayType.expense:
        return Colors.green.shade200;
      case _DayType.open:
        return Colors.white;
    }
  }

  Color _dayFg(_DayType type) {
    switch (type) {
      case _DayType.sunday:
        return Colors.grey.shade600;
      case _DayType.holiday:
        return Colors.orange.shade900;
      case _DayType.leave:
        return Colors.yellow.shade900;
      case _DayType.expense:
        return Colors.green.shade900;
      case _DayType.open:
        return Colors.grey.shade800;
    }
  }
}

enum _DayType { sunday, holiday, leave, expense, open }
