import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/services/api_service.dart';
import '../../providers/report_provider.dart'; // Import the provider

class ChemistHistoryScreen extends StatefulWidget {
  final String chemistId;
  final String chemistName;
  final int? targetUserId;

  const ChemistHistoryScreen({
    required this.chemistId,
    required this.chemistName,
    this.targetUserId,
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
      final data = await ApiService().getChemistHistory(widget.chemistId, userId: widget.targetUserId);
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

  Widget _buildProductStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
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
    List doctors = record['doctors'] ?? [];
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

    List<String> jointWorkNames = [];
    for (var id in workedWithIds) {
      final match = colleagues.firstWhere(
        (c) => c['id'].toString() == id.toString(),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty && match['name'] != null) {
        jointWorkNames.add(match['name']);
      } else {
        jointWorkNames.add("Emp #$id");
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.calendar_today, size: 16, color: _primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                  formattedDate,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                      fontSize: 14,
                    color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (jointWorkNames.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Icon(Icons.groups, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Joint Work:",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: jointWorkNames.map<Widget>((name) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 12),
                ],

                if (doctors.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.medical_services, size: 18, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          " Doctors:",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: doctors.map<Widget>((doc) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.teal.shade100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.teal.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${doc['doctor_name']} (${doc['specialty_practice_type']})",
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.teal.shade900,
                                          fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
              const SizedBox(height: 16),
            ],

                if (products.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.shopping_bag, size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "Orders / POB:",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...products.map<Widget>((p) {
                    final String productName = (p['name'] ?? '-').toString();
                    final int sale = int.tryParse((p['sale'] ?? 0).toString()) ?? 0;
                    final int free = int.tryParse((p['free'] ?? 0).toString()) ?? 0;
                    final bool hasLegacyOnlyUnits = sale == 0 && free == 0;
                    final int safeSale = hasLegacyOnlyUnits ? (int.tryParse((p['pob'] ?? 0).toString()) ?? 0) : sale;
                    final int safeFree = hasLegacyOnlyUnits ? 0 : free;
                    final int units = hasLegacyOnlyUnits ? (int.tryParse((p['pob'] ?? 0).toString()) ?? 0) : (sale + free);
                    final int value = int.tryParse((p['value_pob'] ?? 0).toString()) ?? 0;
                    final String suppliedThrough = (p['supplied_through'] ?? p['suppliedThrough'] ?? '-').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.medication, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "PRODUCT : $productName",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildProductStat("Sale", safeSale.toString()),
                                    _buildProductStat("Free", safeFree.toString()),
                                    _buildProductStat("Total", units.toString()),
                                    _buildProductStat("Value", value.toString()),
                                  ],
                                ),
                                if (suppliedThrough.isNotEmpty && suppliedThrough != '-') ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Divider(height: 1),
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "SUPPLIED THROUGH (STOCKIST): $suppliedThrough",
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  // Totals
            Container(
              width: double.infinity,
                    margin: const EdgeInsets.only(top: 4, bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              "Total Units (POB)",
                              style: GoogleFonts.poppins(fontSize: 11, color: _primaryColor),
                            ),
                            Text(
                              totalUnits.toString(),
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor),
                            ),
                          ],
                        ),
                        Container(height: 30, width: 1, color: _primaryColor.withOpacity(0.2)),
                        Column(
                          children: [
                            Text(
                              "Total Value (POB)",
                              style: GoogleFonts.poppins(fontSize: 11, color: _primaryColor),
                            ),
                            Text(
                              "₹$totalValue",
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remarks : ",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      remark,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}
