import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/api_service.dart';
import 'tp_deviation_form_screen.dart';

class TpDeviationHistoryScreen extends StatefulWidget {
  const TpDeviationHistoryScreen({super.key});

  @override
  State<TpDeviationHistoryScreen> createState() => _TpDeviationHistoryScreenState();
}

class _TpDeviationHistoryScreenState extends State<TpDeviationHistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = false;
  List<dynamic> _history = [];
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      final data = await _api.getTpDeviationHistory(monthStr);
      if (mounted) {
        setState(() {
          _history = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load history', style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
    _fetchHistory();
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange; // pending
  }

  String _formatDateTimeStr(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dt = DateFormat("yyyy-MM-dd HH:mm:ss").parse(dateTimeStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('TP Deviation Request', style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _history.isEmpty
                    ? Center(
                        child: Text(
                          'No deviation requests found for this month.',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final status = item['status']?.toString() ?? 'Pending';
                          final statusColor = _getStatusColor(status);
                          final createdAt = _formatDateTimeStr(item['created_at']?.toString());
                          
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- TOP HEADER ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDateStr(item['date']?.toString()),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: statusColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: statusColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // --- TIMESTAMPS ---
                                  Text(
                                    "Requested on: $createdAt",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  
                                  const Divider(height: 24, thickness: 1),
                                  
                                  // --- ROUTES ---
                                  _dataPoint("Original Route", item['old_route']?.toString() ?? 'N/A', Colors.black87),
                                  const SizedBox(height: 12),
                                  _dataPoint("Requested Deviation", item['new_route_name']?.toString() ?? 'N/A', AppColors.primary),
                                  
                                  const Divider(height: 24, thickness: 1),
                                  
                                  // --- REMARKS ---
                                  _dataPoint("Reason", item['user_remark']?.toString() ?? 'N/A', Colors.black87),
                                  
                                  if (item['manager_remark'] != null || item['approved_at'] != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Manager Response', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                                          if (item['manager_remark'] != null && item['manager_remark'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(item['manager_remark'].toString(), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatDateTimeStr(item['approved_at']?.toString()),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TpDeviationFormScreen()),
          );
          if (result == true) {
            _fetchHistory();
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Request', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _dataPoint(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
