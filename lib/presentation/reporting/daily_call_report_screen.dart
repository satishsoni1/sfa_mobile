import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class DailyCallReportScreen extends StatefulWidget {
  const DailyCallReportScreen({super.key});

  @override
  State<DailyCallReportScreen> createState() => _DailyCallReportScreenState();
}

class _DailyCallReportScreenState extends State<DailyCallReportScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _hierarchy = [];
  dynamic _selectedSub; // Null = Myself

  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};

  final ApiService _api = ApiService();
  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final subs = await _api.getSubordinates();
      setState(() => _hierarchy = subs);
      await _fetchReportData();
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      int? targetId = _selectedSub?['id'];
      final data = await _api.getDailyCallReport(_selectedDate, userId: targetId);
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Fetch Error: $e");
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Daily Call Report", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(
              "${DateFormat('EEE, dd MMM yyyy').format(_selectedDate)} • ${_selectedSub?['name'] ?? 'Myself'}", 
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _selectDate),
        ],
      ),
      body: Column(
        children: [
          if (_hierarchy.isNotEmpty) _buildHierarchyPicker(),
          
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : RefreshIndicator(
                  onRefresh: _fetchReportData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildSummarySection()),
                      _buildDetailsList(),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHierarchyPicker() {
    return Container(
      height: 65,
      color: _primaryColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _hierarchy.length + 1,
        itemBuilder: (context, index) {
          bool isMyself = index == 0;
          var sub = isMyself ? null : _hierarchy[index - 1];
          bool isSelected = isMyself ? _selectedSub == null : _selectedSub?['id'] == sub['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(isMyself ? "Myself" : sub['name'], style: TextStyle(color: isSelected ? Colors.black : Colors.black)),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedSub = sub);
                _fetchReportData();
              },
              selectedColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? _primaryColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
              backgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummarySection() {
    final summary = _reportData['summary'] ?? {};
    final int planned = summary['total_planned'] ?? 0;
    final int totalVisited = summary['total_visited'] ?? 0;
    final int plannedVisited = summary['planned_visited'] ?? 0;
    final int unplannedVisited = summary['unplanned_visited'] ?? 0;
    final double productivity = (summary['productivity'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Analytics Summary", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCircle(productivity, "Productivity", Colors.green),
                    Container(height: 50, width: 1, color: Colors.grey.shade200),
                    _buildSimpleStat("$totalVisited / $planned", "Total Executed", Icons.checklist, Colors.blue),
                  ],
                ),
                const Divider(height: 20),
                // --- NEW: Breakdown of Planned vs Unplanned ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCategoryBadge("Planned Visited", plannedVisited, Colors.teal),
                    _buildCategoryBadge("Unplanned", unplannedVisited, Colors.orange),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCategoryBadge("FRD Met", summary['frd_met'] ?? 0, Colors.indigo),
                    _buildCategoryBadge("KBL Met", summary['kbl_met'] ?? 0, Colors.purple),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsList() {
    final List details = _reportData['details'] ?? [];

    if (details.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text("No calls reported for this date.", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final call = details[index];
            final String statusStr = call['status']?.toString().toLowerCase() ?? '';
            
            // --- Determine Status Colors dynamically ---
            final bool isUnplanned = statusStr.contains('unplanned');
            final bool isVisited = statusStr.contains('visited') || isUnplanned;
            final bool isMissed = statusStr.contains('missed');

            Color statusColor = Colors.grey;
            Color statusBgColor = Colors.grey.shade50;
            IconData statusIcon = Icons.access_time;

            if (isUnplanned) {
              statusColor = Colors.orange;
              statusBgColor = Colors.orange.shade50;
              statusIcon = Icons.bolt;
            } else if (isVisited) {
              statusColor = Colors.green;
              statusBgColor = Colors.green.shade50;
              statusIcon = Icons.check_circle;
            } else if (isMissed) {
              statusColor = Colors.red;
              statusBgColor = Colors.red.shade50;
              statusIcon = Icons.cancel;
            }
            
            // Extract new data points
            final String workedWith = call['worked_with']?.toString() ?? '';
            final bool isJfw = call['is_jfw'] == true || workedWith.isNotEmpty;
            final List products = call['products'] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: statusColor.withOpacity(0.4), width: 1)
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Doctor Name & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            call['doctor_name'] ?? 'Unknown',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                call['status']?.toUpperCase() ?? 'N/A',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${call['specialization']} • ${call['area']}",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Divider(height: 24),

                    // --- Joint Work Details ---
                    if (isJfw) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.group, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Joint Work: ${workedWith.isNotEmpty ? workedWith : 'Yes'}",
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --- Product Details ---
                    if (products.isNotEmpty) ...[
                      Text("Products Detailed:", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: products.map<Widget>((p) {
                          final pName = p['product_name'] ?? 'Unknown';
                          final sampleQty = p['sample_qty'] ?? 0;
                          final pobQty = p['pob_qty'] ?? 0;
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade100)
                            ),
                            child: Text(
                              "$pName (S: $sampleQty | POB: $pobQty)",
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.purple.shade800, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --- Remarks ---
                    if (call['remarks'] != null && call['remarks'].toString().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text("Remark: ${call['remarks']}", style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
          childCount: details.length,
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildStatCircle(double percent, String label, Color color) {
    return Column(
      children: [
        SizedBox(
          height: 60, width: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Center(child: Text("${percent.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSimpleStat(String val, String label, IconData icon, Color col) {
    return Column(
      children: [
        Icon(icon, color: col, size: 28),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCategoryBadge(String label, int count, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text("$label: $count", style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}