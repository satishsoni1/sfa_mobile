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
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9), // Softer background color
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            'Daily Summary',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF4A148C),
          elevation: 0,
        ),
        body: Column(
          children: [
            // 1. HEADER SUMMARY (Modern Curved Design)
            Container(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 30,
                top: 10,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF4A148C),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Visits Executed",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${reports.length}",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
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
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.calendar_month_rounded,
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

            // 2. REPORT LIST
            Expanded(
              child: reportProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A148C),
                      ),
                    )
                  : reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No visits found for ${DateFormat('dd MMM').format(_selectedDate)}",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 20,
                        left: 16,
                        right: 16,
                        bottom: 100,
                      ), // Extra bottom padding for button
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final r = reports[index];
                        final bool isSubmitted = reportProvider.isDaySubmitted;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (isSubmitted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Cannot edit. Day is already submitted.",
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportingScreen(
                                      doctorId: r.doctorId,
                                      doctorName: r.doctorName,
                                      existingReport: r,
                                    ),
                                  ),
                                ).then((_) => _fetchReportsForDate());
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 45,
                                        width: 45,
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.purple.shade100,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF4A148C),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          r.doctorName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSubmitted
                                              ? Colors.grey.shade100
                                              : Colors.blue.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isSubmitted
                                              ? Icons.lock_outline
                                              : Icons.edit_outlined,
                                          color: isSubmitted
                                              ? Colors.grey
                                              : Colors.blueAccent,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // REMARKS SECTION
                                  if (r.remarks != null &&
                                      r.remarks.toString().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade100,
                                        ),
                                      ),
                                      child: Text(
                                        "Remark: ${r.remarks}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),

        // 3. FINAL SUBMIT BUTTON
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: reportProvider.isDaySubmitted
                      ? Colors.grey.shade400
                      : const Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (reports.isEmpty || reportProvider.isDaySubmitted)
                    ? null
                    : () async {
                        // Show customized dialog returning an integer (null if cancelled, >=0 if confirmed)
                        int? finalChemistCount = await showDialog<int>(
                          context: context,
                          builder: (ctx) {
                            bool visitedChemist = false;
                            final TextEditingController chemistCountController =
                                TextEditingController();
                            String? errorText;

                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Text(
                                    "Submit Final Report?",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Submitting for ${DateFormat('dd MMM yyyy').format(_selectedDate)}. You cannot edit reports after submission.",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        // Chemist Toggle
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: CheckboxListTile(
                                            title: Text(
                                              "Did you visit any chemists?",
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            value: visitedChemist,
                                            activeColor: const Color(
                                              0xFF4A148C,
                                            ),
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                            onChanged: (val) {
                                              setDialogState(() {
                                                visitedChemist = val ?? false;
                                                if (!visitedChemist) {
                                                  chemistCountController
                                                      .clear();
                                                  errorText = null;
                                                }
                                              });
                                            },
                                          ),
                                        ),

                                        // Chemist Count Input (Shown conditionally)
                                        if (visitedChemist) ...[
                                          const SizedBox(height: 16),
                                          TextField(
                                            controller: chemistCountController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText:
                                                  "Number of chemists visited",
                                              labelStyle: GoogleFonts.poppins(
                                                fontSize: 14,
                                              ),
                                              errorText: errorText,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF4A148C),
                                                  width: 2,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              prefixIcon: const Icon(
                                                Icons.storefront_outlined,
                                              ),
                                            ),
                                            onChanged: (val) {
                                              if (errorText != null) {
                                                setDialogState(
                                                  () => errorText = null,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(
                                        ctx,
                                        null,
                                      ), // Returns null to cancel
                                      child: Text(
                                        "Cancel",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4A148C,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        int chemistCount = 0;
                                        if (visitedChemist) {
                                          chemistCount =
                                              int.tryParse(
                                                chemistCountController.text,
                                              ) ??
                                              0;
                                          if (chemistCount <= 0) {
                                            setDialogState(() {
                                              errorText =
                                                  "Please enter a valid number greater than 0.";
                                            });
                                            return;
                                          }
                                        }
                                        // Returns the chemist count (0 if checkbox wasn't checked)
                                        Navigator.pop(ctx, chemistCount);
                                      },
                                      child: Text(
                                        "Confirm",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );

                        // If the user confirmed the dialog (returned an int instead of null)
                        if (finalChemistCount != null) {
                          await reportProvider.submitDayReports(
                            date: _selectedDate,
                            chemistCount:
                                finalChemistCount ??
                                0, // Falls back to 0 if not entered
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Day Submitted Successfully!',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: Text(
                  reportProvider.isDaySubmitted
                      ? "DAY SUBMITTED"
                      : "SUBMIT FINAL REPORT",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
