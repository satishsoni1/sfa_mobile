import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/cme_model.dart';
import '../../data/services/api_service.dart';
import 'add_cme_screen.dart';

class CmeHistoryScreen extends StatefulWidget {
  const CmeHistoryScreen({super.key});

  @override
  State<CmeHistoryScreen> createState() => _CmeHistoryScreenState();
}

class _CmeHistoryScreenState extends State<CmeHistoryScreen> {
  List<CmeProgram> _reports = [];
  bool _isLoading = true;
  final ApiService _api = ApiService();
  String _searchQuery = "";

  static const Color _primaryColor = Color(0xFF4A148C);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getCmeHistory();
      final List<CmeProgram> list = [];
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          list.add(CmeProgram.fromJson(item));
        } else if (item is Map) {
          list.add(CmeProgram.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      setState(() => _reports = list);
    } catch (e) {
      debugPrint("Error fetching CME history: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddScreen() async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCmeScreen()),
    );

    if (result == true) {
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _searchQuery.isEmpty
        ? _reports
        : _reports.where((r) {
            final q = _searchQuery.toLowerCase();
            return r.topicName.toLowerCase().contains(q) ||
                r.speaker.doctorName.toLowerCase().contains(q) ||
                (r.jointWork?.employeeName.toLowerCase().contains(q) ?? false);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          "CME Programs",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar if list is not empty
          if (_reports.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: "Search by topic, speaker, or colleague...",
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, size: 20, color: _primaryColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchQuery = ""),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8F9FD),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _reports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _primaryColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_outlined,
                                size: 54,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No CME programs yet",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tap '+ NEW REPORT' below to register a CME program",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : filteredReports.isEmpty
                        ? Center(
                            child: Text(
                              "No CME records match your search",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            color: _primaryColor,
                            onRefresh: _fetchHistory,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredReports.length,
                              itemBuilder: (context, index) {
                                return _buildCmeCard(filteredReports[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddScreen,
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "NEW REPORT",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCmeCard(CmeProgram cme) {
    DateTime date = DateTime.now();
    try {
      if (cme.cmeDate.isNotEmpty) {
        date = DateTime.parse(cme.cmeDate);
      }
    } catch (_) {}

    final totalCost = cme.costBreakdown?.totalCost ?? 0.0;
    final attendeeCount = cme.attendees.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCmeDetailsSheet(cme),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Box (Matching NFW Report pattern)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(date),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cme.topicName.isNotEmpty ? cme.topicName : "CME Session",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Speaker
                    Row(
                      children: [
                        const Icon(
                          Icons.record_voice_over_outlined,
                          size: 14,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            "Speaker: ${cme.speaker.doctorName}",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Chips: Attendees, Joint Work, Cost
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          icon: Icons.people_outline,
                          text: "$attendeeCount Doctors",
                          color: Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                        ),
                        if (cme.extraAttendeesCount > 0)
                          _buildBadge(
                            icon: Icons.person_add_outlined,
                            text: "+${cme.extraAttendeesCount} Extra",
                            color: Colors.purple.shade700,
                            bgColor: Colors.purple.shade50,
                          ),
                        if (cme.jointWork != null && cme.jointWork!.employeeName.isNotEmpty)
                          _buildBadge(
                            icon: Icons.handshake_outlined,
                            text: cme.jointWork!.employeeName,
                            color: Colors.teal.shade800,
                            bgColor: Colors.teal.shade50,
                          ),
                        if (totalCost > 0)
                          _buildBadge(
                            icon: Icons.currency_rupee,
                            text: "₹${totalCost.toStringAsFixed(0)}",
                            color: Colors.amber.shade900,
                            bgColor: Colors.amber.shade50,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showCmeDetailsSheet(CmeProgram cme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        DateTime date = DateTime.now();
        try {
          if (cme.cmeDate.isNotEmpty) date = DateTime.parse(cme.cmeDate);
        } catch (_) {}

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Top Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "CME Program Details",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Date & Topic
                      _buildDetailRow("Date", DateFormat('dd MMMM yyyy').format(date)),
                      const SizedBox(height: 12),
                      _buildDetailRow("Topic", cme.topicName),
                      const SizedBox(height: 16),

                      // Speaker Section
                      Text(
                        "SPEAKER",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: _primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cme.speaker.doctorName,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (cme.speaker.speciality != null && cme.speaker.speciality!.isNotEmpty)
                                    Text(
                                      cme.speaker.speciality!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                            if (cme.speaker.isManual)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Manual",
                                  style: TextStyle(fontSize: 10, color: Colors.orange.shade900),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attendees Section
                      Text(
                        "ATTENDEES (${cme.attendees.length})",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (cme.attendees.isEmpty)
                        Text(
                          "No doctor attendees listed",
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: cme.attendees.map((a) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.doctorName,
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    if (a.speciality != null && a.speciality!.isNotEmpty)
                                      Text(
                                        a.speciality!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Extra Attendees Section
                      if (cme.extraAttendeesCount > 0 || (cme.extraAttendeesNotes != null && cme.extraAttendeesNotes!.isNotEmpty)) ...[
                        Text(
                          "EXTRA ATTENDEES",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.groups_outlined, color: _primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${cme.extraAttendeesCount} Extra Attendees",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (cme.extraAttendeesNotes != null && cme.extraAttendeesNotes!.isNotEmpty)
                                      Text(
                                        cme.extraAttendeesNotes!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Joint Work Section
                      if (cme.jointWork != null && cme.jointWork!.employeeName.isNotEmpty) ...[
                        Text(
                          "JOINT WORK",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.handshake_outlined, color: Colors.teal),
                              const SizedBox(width: 12),
                              Text(
                                cme.jointWork!.employeeName,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Cost Breakdown Section
                      if (cme.costBreakdown != null && cme.costBreakdown!.hasCost) ...[
                        Text(
                          "COST BREAKDOWN",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              if (cme.costBreakdown!.items.isNotEmpty)
                                ...cme.costBreakdown!.items.map(
                                  (item) => _buildCostItem(item.type, item.amount),
                                )
                              else ...[
                                if (cme.costBreakdown!.venueAmount > 0)
                                  _buildCostItem("Venue / Hall", cme.costBreakdown!.venueAmount),
                                if (cme.costBreakdown!.cateringAmount > 0)
                                  _buildCostItem("Food & Catering", cme.costBreakdown!.cateringAmount),
                                if (cme.costBreakdown!.audiovisualAmount > 0)
                                  _buildCostItem("Audio / Visual", cme.costBreakdown!.audiovisualAmount),
                                if (cme.costBreakdown!.honorariumAmount > 0)
                                  _buildCostItem("Speaker Honorarium", cme.costBreakdown!.honorariumAmount),
                                if (cme.costBreakdown!.miscellaneousAmount > 0)
                                  _buildCostItem("Miscellaneous", cme.costBreakdown!.miscellaneousAmount),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total Cost",
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    "₹${cme.costBreakdown!.totalCost.toStringAsFixed(2)}",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Remarks
                      if (cme.remarks != null && cme.remarks!.isNotEmpty) ...[
                        Text(
                          "REMARKS",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cme.remarks!,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCostItem(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text("₹${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
