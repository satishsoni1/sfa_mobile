import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/services/api_service.dart';
import '../../providers/report_provider.dart'; // Import the provider

class ChemistHistoryScreen extends StatefulWidget {
  final String chemistId;
  final String chemistName;

  const ChemistHistoryScreen({
    required this.chemistId,
    required this.chemistName,
    super.key,
  });

  @override
  State<ChemistHistoryScreen> createState() => _ChemistHistoryScreenState();
}

class _ChemistHistoryScreenState extends State<ChemistHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  final Color _primaryColor = const Color(0xFF4A148C); // Teal theme

  @override
  void initState() {
    super.initState();
    // Ensure the colleagues list is loaded so we can map IDs to Names
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchJointWorkList();
    });
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getChemistHistory(widget.chemistId);
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching history: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get colleagues from provider to map the IDs
    final colleagues = Provider.of<ReportProvider>(context).colleagues;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Visit History",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.chemistName,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _history.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final record = _history[index];
                return _buildHistoryCard(record, colleagues);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No visit history found",
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Past visits for this chemist will appear here.",
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    dynamic record,
    List<Map<String, dynamic>> colleagues,
  ) {
    DateTime visitTime = DateTime.parse(record['visit_time']);
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(visitTime);

    List products = record['products'] ?? [];
    List workedWithIds = record['worked_with'] ?? [];
    String remark = record['remarks'] ?? 'No remark provided';
    final int totalUnits = products.fold<int>(0, (sum, p) {
      final int sale = int.tryParse((p['sale'] ?? 0).toString()) ?? 0;
      final int free = int.tryParse((p['free'] ?? 0).toString()) ?? 0;
      if (sale == 0 && free == 0) {
        return sum + (int.tryParse((p['pob'] ?? 0).toString()) ?? 0);
      }
      return sum + sale + free;
    });
    final int totalValue = products.fold<int>(0, (sum, p) {
      return sum + (int.tryParse((p['value_pob'] ?? 0).toString()) ?? 0);
    });

    // --- TRANSLATE IDs TO NAMES ---
    List<String> jointWorkNames = [];
    for (var id in workedWithIds) {
      final match = colleagues.firstWhere(
        (c) => c['id'].toString() == id.toString(),
        orElse: () => <String, dynamic>{}, // Return empty map if not found
      );

      if (match.isNotEmpty && match['name'] != null) {
        jointWorkNames.add(match['name']);
      } else {
        jointWorkNames.add("Emp #$id"); // Fallback if name is missing
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Time Header
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Joint Work Section (Names instead of IDs)
            if (jointWorkNames.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.group, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Joint Work: ${jointWorkNames.join(', ')}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Products / POB Section
            if (products.isNotEmpty) ...[
              Text(
                "Orders / POB:",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: products.map<Widget>((p) {
                  final String productName = (p['name'] ?? '-').toString();
                  final int sale =
                      int.tryParse((p['sale'] ?? 0).toString()) ?? 0;
                  final int free =
                      int.tryParse((p['free'] ?? 0).toString()) ?? 0;
                  final bool hasLegacyOnlyUnits = sale == 0 && free == 0;
                  final int safeSale = hasLegacyOnlyUnits
                      ? (int.tryParse((p['pob'] ?? 0).toString()) ?? 0)
                      : sale;
                  final int safeFree = hasLegacyOnlyUnits ? 0 : free;
                  final int units =
                      hasLegacyOnlyUnits
                          ? (int.tryParse((p['pob'] ?? 0).toString()) ?? 0)
                          : (sale + free);
                  final int value =
                      int.tryParse((p['value_pob'] ?? 0).toString()) ?? 0;
                  final String suppliedThrough =
                      (p['supplied_through'] ?? p['suppliedThrough'] ?? '-')
                          .toString();

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PRODUCT : $productName",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "UNITS: [sale: $safeSale Free: $safeFree]  Total: $units",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "VALUE : $value",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "SUPPLIED THROUGH (STOCKIST): $suppliedThrough",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Totals Section (Above remark)
            if (products.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Total units (POB): $totalUnits",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Total Value(POB): $totalValue",
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Remarks Section
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
                  Text(
                    "Remark:",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remark,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
