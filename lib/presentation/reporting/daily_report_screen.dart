import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/report_provider.dart';
import 'reporting_screen.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReportsForDate();
    });
  }

  void _fetchReportsForDate() {
    Provider.of<ReportProvider>(
      context,
      listen: false,
    ).fetchReportsByDate(_selectedDate);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A148C),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchReportsForDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final reports = reportProvider.reports;

    return GestureDetector(
      // Close keyboard if tapping outside (just in case)
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        resizeToAvoidBottomInset:
            true, // IMPORTANT: Allows UI to resize when keyboard opens
        appBar: AppBar(
          title: Text(
            'Daily Summary',
            style: GoogleFonts.poppins(fontSize: 18),
          ),
          backgroundColor: const Color(0xFF4A148C),
          elevation: 0,
        ),
        body: Column(
          children: [
            // 1. HEADER SUMMARY (Fixed at top)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF4A148C),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Visits",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "${reports.length}",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Date Picker Button
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. REPORT LIST (Flexible area)
            Expanded(
              child: reportProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No visits found for ${DateFormat('dd MMM').format(_selectedDate)}",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      // Add extra padding at bottom so last card isn't hidden behind the button
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final r = reports[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (reportProvider.isDaySubmitted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Cannot edit. Day is already submitted.",
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportingScreen(
                                      doctorId: r.id.toString(),
                                      doctorName: r.doctorName,
                                      existingReport: r,
                                    ),
                                  ),
                                ).then((_) => _fetchReportsForDate());
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFF4A148C),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.doctorName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat(
                                                'h:mm a',
                                              ).format(r.visitTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                r.remarks,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!reportProvider.isDaySubmitted)
                                    const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.grey,
                                      size: 20,
                                    )
                                  else
                                    const Icon(
                                      Icons.lock_outline,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 3. FINAL SUBMIT BUTTON (Sticky Footer)
            // SafeArea ensures it doesn't get hidden behind browser nav bars
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: reportProvider.isDaySubmitted
                          ? Colors.grey
                          : const Color(0xFF4A148C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        (reports.isEmpty || reportProvider.isDaySubmitted)
                        ? null
                        : () async {
                            bool? confirm = await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Submit Final Report?"),
                                content: Text(
                                  "Submitting for ${DateFormat('dd MMM').format(_selectedDate)}. You cannot edit after this.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Confirm"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await reportProvider.submitDayReports(
                                date: _selectedDate,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Day Submitted Successfully!',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: Text(
                      reportProvider.isDaySubmitted
                          ? "SUBMITTED"
                          : "SUBMIT FINAL REPORT",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
