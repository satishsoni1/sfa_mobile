import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:zforce/core/constants/app_colors.dart';
import 'package:zforce/data/models/attendance_models.dart';
import 'package:zforce/data/services/api_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  List<_AttendanceTeamMember> _teamMembers = [];
  String _selectedEmployeeId = '';
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadAttendanceOverview();
  }

  Future<void> _loadAttendanceOverview() async {
    setState(() => _isLoading = true);

    try {
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      final team = await _apiService.fetchTeamMembers();
      if (team.isEmpty) {
        if (!mounted) return;
        setState(() {
          _teamMembers = [];
          _selectedEmployeeId = '';
          _isLoading = false;
        });
        return;
      }

      var selectedEmployeeId = _selectedEmployeeId;
      final selectedExists = team.any(
        (member) => _teamEmployeeId(member) == selectedEmployeeId,
      );
      if (selectedEmployeeId.isEmpty || !selectedExists) {
        selectedEmployeeId = _teamEmployeeId(team.first);
      }
      final selectedTeamMember = team.firstWhere(
        (member) => _teamEmployeeId(member) == selectedEmployeeId,
        orElse: () => team.first,
      );
      final selectedEmployeeIdValue = int.tryParse(selectedEmployeeId);

      final attendance = await _apiService.fetchAttendance(
        fromDate: DateFormat('yyyy-MM-dd').format(monthStart),
        toDate: DateFormat('yyyy-MM-dd').format(monthEnd),
        employeeId: selectedEmployeeIdValue,
        employeeCode: selectedEmployeeIdValue == null
            ? _cleanText(selectedTeamMember['employee_code'])
            : null,
      );
      final selectedRecord = _recordForEmployee(attendance.records, selectedEmployeeId);

      final members = team.map((member) {
        final employeeId = _teamEmployeeId(member);
        final record = employeeId == selectedEmployeeId ? selectedRecord : null;
        return _AttendanceTeamMember(
          employeeId: employeeId,
          employeeCode: _cleanText(record?.employeeCode) ??
              _cleanText(member['employee_code']) ??
              employeeId,
          name: _cleanText(record?.employeeName) ??
              _cleanText(member['name']) ??
              employeeId,
          designation: _cleanText(record?.designation) ??
              _cleanText(member['designation']) ??
              '',
          headQtr: _cleanText(record?.headQtr) ??
              _cleanText(member['hq']) ??
              _cleanText(member['head_qtr']) ??
              '',
          division: _cleanText(record?.division) ??
              _cleanText(member['division']) ??
              '',
          zone: _cleanText(record?.zone) ?? _cleanText(member['zone']) ?? '',
          state: _cleanText(record?.state) ?? _cleanText(member['state']) ?? '',
          record: record,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _teamMembers = members;
        _selectedEmployeeId = selectedEmployeeId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teamMembers = [];
        _selectedEmployeeId = '';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load attendance overview: $e')),
      );
    }
  }

  void _selectMonth(DateTime month) {
    final selected = DateTime(month.year, month.month);
    final current = DateTime(DateTime.now().year, DateTime.now().month);
    if (selected.isAfter(current)) return;
    if (month.year == _selectedMonth.year && month.month == _selectedMonth.month) {
      return;
    }
    setState(() => _selectedMonth = selected);
    _loadAttendanceOverview();
  }

  void _selectEmployee(String employeeId) {
    if (employeeId == _selectedEmployeeId) return;
    setState(() => _selectedEmployeeId = employeeId);
    _loadAttendanceOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F9),
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAttendanceOverview,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFiltersCard(),
                  const SizedBox(height: 16),
                  if (_teamMembers.isEmpty)
                    _buildEmptyState('No team members available.')
                  else
                    ..._visibleMembers().map(_buildSummaryCard),
                ],
              ),
            ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Team Member',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedEmployeeId.isEmpty ? null : _selectedEmployeeId,
                isExpanded: true,
                items: _teamMembers.map((member) {
                    return DropdownMenuItem<String>(
                      value: member.employeeId,
                      child: Text(
                        member.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _selectEmployee(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Select Month',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dropdownBox(
                  DropdownButton<int>(
                    value: _selectedMonth.month,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem<int>(
                        value: month,
                        child: Text(DateFormat('MMMM').format(DateTime(2026, month))),
                      );
                    }),
                    onChanged: (month) {
                      if (month == null) return;
                      _selectMonth(DateTime(_selectedMonth.year, month));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdownBox(
                  DropdownButton<int>(
                    value: _selectedMonth.year,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _yearOptions().map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (year) {
                      if (year == null) return;
                      _selectMonth(DateTime(year, _selectedMonth.month));
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdownBox(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }

  List<int> _yearOptions() {
    final currentYear = DateTime.now().year;
    return List.generate(
      5,
      (index) => currentYear - index,
    );
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  String _teamEmployeeId(Map<String, String> member) {
    return _cleanText(member['employee_id']) ??
        _cleanText(member['id']) ??
        _cleanText(member['employee_code']) ??
        '';
  }

  AttendanceEmployeeData? _recordForEmployee(
    List<AttendanceEmployeeData> records,
    String employeeId,
  ) {
    for (final record in records) {
      if (record.employeeId.toString() == employeeId) return record;
    }
    return records.isNotEmpty ? records.first : null;
  }

  List<_AttendanceTeamMember> _visibleMembers() {
    return _teamMembers
        .where((member) => member.employeeId == _selectedEmployeeId)
        .toList();
  }

  Widget _buildSummaryCard(_AttendanceTeamMember member) {
    final record = member.record;
    final entries = record?.summary.entries.toList() ?? const <MapEntry<String, int>>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Code: ${member.employeeCode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${member.designation.isEmpty ? 'N/A' : member.designation}  |  HQ: ${member.headQtr.isEmpty ? 'N/A' : member.headQtr}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Zone: ${member.zone.isEmpty ? 'N/A' : member.zone}  |  State: ${member.state.isEmpty ? 'N/A' : member.state}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (member.division.isNotEmpty)
                  Text(
                    'Division: ${member.division}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const Divider(height: 24, thickness: 1),
                if (entries.isEmpty)
                  Text(
                    'No attendance summary available for this month.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: List.generate(entries.length, (index) {
                      final entry = entries[index];
                      return _dataPoint(
                        _formatSummaryKey(entry.key),
                        entry.value.toString(),
                        color: _summaryColor(entry.key, index),
                      );
                    }),
                  ),
                const Divider(height: 28, thickness: 1),
                const Center(
                  child: Text(
                    'Tap any date to view day-wise details',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCalendar(member),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(_AttendanceTeamMember member) {
    final days = _monthDays();

    return Column(
      children: [
        Row(
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = (constraints.maxWidth - 36) / 7;
            final cellHeight = cellSize + 8;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: days.map((date) {
                if (date == null) {
                  return SizedBox(width: cellSize, height: cellHeight);
                }
                return SizedBox(
                  width: cellSize,
                  height: cellHeight,
                  child: _buildDateCell(member, date),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateCell(_AttendanceTeamMember member, DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final status = _statusForDate(member, date);
    final isFuture = date.isAfter(DateTime.now());
    final isSunday = date.weekday == DateTime.sunday;
    final isAbsent = status.toUpperCase() == 'A';
    final isDisabled = isFuture || isSunday || isAbsent;
    final statusColor = isSunday
        ? Colors.purple
        : status.isEmpty
            ? Colors.grey.shade400
            : _statusColor(status);
    final statusLabel = isSunday ? 'SUN' : _calendarStatusLabel(status);

    return InkWell(
      onTap: isDisabled ? null : () => _showAttendanceDetail(member, dateKey),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        decoration: BoxDecoration(
          color: isSunday
              ? Colors.purple.withOpacity(0.10)
              : status.isEmpty
              ? Colors.grey.shade100
              : statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: statusColor.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                color: isSunday
                    ? Colors.purple
                    : isFuture
                        ? Colors.grey.shade400
                        : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusForDate(_AttendanceTeamMember member, DateTime date) {
    final record = member.record;
    if (record == null) return '';
    if (date.weekday == DateTime.sunday || date.isAfter(DateTime.now())) return '';

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    // Calendar status is intentionally not calculated on frontend.
    return record.statusForDate(dateKey)?.status ?? '';
  }

  List<DateTime?> _monthDays() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final startOffset = firstDay.weekday % 7;
    final days = <DateTime?>[
      for (int i = 0; i < startOffset; i++) null,
    ];

    for (int day = 1; day <= daysInMonth; day++) {
      days.add(DateTime(_selectedMonth.year, _selectedMonth.month, day));
    }
    return days;
  }

  void _showAttendanceDetail(_AttendanceTeamMember member, String date) {
    // Date tap opens the backend-driven day detail sheet without leaving this screen.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceDetailSheet(
        future: _apiService.fetchAttendanceDetail(
          employeeCode: member.employeeCode,
          employeeId: member.record?.employeeId ?? int.tryParse(member.employeeId),
          date: date,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(String label, String value, {required Color color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatSummaryKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _calendarStatusLabel(String status) {
    final text = status.trim().toUpperCase();
    if (text.isEmpty) return '-';
    if (text == 'HOLIDAY') return 'H';
    return text;
  }

  Color _summaryColor(String key, int index) {
    switch (key.toLowerCase()) {
      case 'present':
        return const Color(0xFF177245);
      case 'absent':
        return const Color(0xFFBE2D3F);
      case 'sunday':
        return Colors.purple;
      case 'holiday':
        return Colors.orange;
      default:
        return _summaryColors[index % _summaryColors.length];
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'P':
        return const Color(0xFF177245);
      case 'A':
        return const Color(0xFFBE2D3F);
      case 'H':
      case 'HOLIDAY':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }
}

class _AttendanceTeamMember {
  final String employeeId;
  final String employeeCode;
  final String name;
  final String designation;
  final String headQtr;
  final String division;
  final String zone;
  final String state;
  final AttendanceEmployeeData? record;

  const _AttendanceTeamMember({
    required this.employeeId,
    required this.employeeCode,
    required this.name,
    required this.designation,
    this.headQtr = '',
    this.division = '',
    this.zone = '',
    this.state = '',
    this.record,
  });

  String get displayName => name.isNotEmpty ? name : employeeCode;
}

class _AttendanceDetailSheet extends StatelessWidget {
  final Future<AttendanceDetailResponse> future;

  const _AttendanceDetailSheet({required this.future});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: FutureBuilder<AttendanceDetailResponse>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load details: ${snapshot.error}'),
              ),
            );
          }

          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('No details available.'));
          }

          return Column(
            children: [
              _sheetHeader(context, detail),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _dynamicBox('Summary', detail.summary),
                    const SizedBox(height: 12),
                    ...detail.details.entries.where((entry) {
                      return _shouldShowSection(entry.key, detail.summary);
                    }).map((entry) {
                      return _detailSection(entry.key, entry.value);
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sheetHeader(BuildContext context, AttendanceDetailResponse detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.date,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, List<Map<String, dynamic>> rows) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatKey(title),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(
                'No data',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            else
              ...rows.map((row) => _dynamicBox('', row)),
          ],
        ),
      ),
    );
  }

  bool _shouldShowSection(String key, Map<String, dynamic> summary) {
    final value = summary[_sectionFlagKey(key.toLowerCase())];
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes';
  }

  String _sectionFlagKey(String key) {
    switch (key) {
      case 'nfw':
        return 'has_nfw';
      case 'visits':
      case 'visit':
        return 'has_visit';
      case 'dcr':
        return 'has_dcr';
      case 'chemist_reports':
      case 'chemist_report':
        return 'has_chemist_report';
      default:
        return 'has_$key';
    }
  }

  Widget _dynamicBox(String title, Map<String, dynamic> values) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...values.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      _formatKey(entry.key),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _valueText(entry.value),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _valueText(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }
}

const List<Color> _summaryColors = [
  AppColors.primary,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.blue,
  Colors.red,
  Colors.teal,
  Colors.indigo,
];
