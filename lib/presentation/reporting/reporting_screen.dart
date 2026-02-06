import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/report_provider.dart';
import '../../data/models/visit_report.dart'; 

class ReportingScreen extends StatefulWidget {
  final String doctorName;
  final VisitReport? existingReport;

  const ReportingScreen({
    required this.doctorName,
    this.existingReport,
    super.key,
  });

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  // --- STATE VARIABLES ---
  List<Map<String, dynamic>> _uiProducts = [];
  List<Map<String, dynamic>> _uiColleagues = [];
  bool _isLoading = true;
  
  // Initialize with "Today" stripped of time (00:00:00) to prevent time mismatches
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  
  String? _selectedRemark;
  final TextEditingController _otherRemarkController = TextEditingController();

  final List<String> remarks = [
    "Asked for immediate availability of brand",
    "Assured for prescription initiation",
    "Asked to give reminder for a brand",
    "Inquired regarding product availability",
    "Prefers competitor product",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _otherRemarkController.dispose();
    super.dispose();
  }

  // Helper to compare dates without time
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- 1. DATA LOADING ---
  Future<void> _loadData() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);

    try {
      await Future.wait([
        provider.fetchProducts(),
        provider.fetchJointWorkList(),
      ]);

      if (!mounted) return;

      setState(() {
        // A. Setup Products (Preserve existing POB/Sample logic)
        _uiProducts = provider.masterProducts.map((p) {
          int initialPob = 0;
          int initialSample = 0;
          bool initialSelect = false;

          if (widget.existingReport != null) {
            final existing = widget.existingReport!.products.firstWhere(
              (ep) => ep.productName == p.name,
              orElse: () => ProductEntry(productName: '', pobQty: 0, sampleQty: 0),
            );

            if (existing.productName.isNotEmpty) {
              initialPob = existing.pobQty;
              initialSample = existing.sampleQty;
              initialSelect = true;
            }
          }

          return {
            'id': p.id,
            'name': p.name,
            'isSelected': initialSelect,
            'pob': initialPob,
            'sample': initialSample,
          };
        }).toList();

        // B. Setup Colleagues (FIXED SELECTION LOGIC)
        _uiColleagues = provider.colleagues.map((c) {
          bool isSelected = false;
          
          if (widget.existingReport != null) {
            // Robust comparison: Trim spaces and ignore case
            String currentName = c['name'].toString().trim().toLowerCase();
            
            isSelected = widget.existingReport!.workedWith.any((savedName) {
              return savedName.toString().trim().toLowerCase() == currentName;
            });
          }
          
          return {
            'id': c['id'],
            'name': c['name'], // Keep original casing for display
            'role': c['role'],
            'isSelected': isSelected,
          };
        }).toList();

        // C. Setup Remark & Date
        if (widget.existingReport != null) {
          final incomingDate = widget.existingReport!.visitTime;
          // Strip time from incoming date to ensure calendar logic works
          _selectedDate = DateTime(incomingDate.year, incomingDate.month, incomingDate.day);
          
          String savedRemark = widget.existingReport!.remarks;
          if (remarks.contains(savedRemark)) {
            _selectedRemark = savedRemark;
          } else {
            _selectedRemark = 'Other';
            _otherRemarkController.text = savedRemark;
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error loading data: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- 2. LOGIC METHODS ---

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
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
    if (picked != null) {
      // Strip time from the picked date to ensure consistency
      final normalizedPicked = DateTime(picked.year, picked.month, picked.day);
      if (normalizedPicked != _selectedDate) {
        setState(() {
          _selectedDate = normalizedPicked;
        });
      }
    }
  }

  void _adjustQty(int index, String key, int change) {
    if (!_uiProducts[index]['isSelected']) return;
    setState(() {
      int current = _uiProducts[index][key];
      int newVal = current + change;
      if (newVal < 0) newVal = 0;
      _uiProducts[index][key] = newVal;
    });
  }
  void _updateQty(int index, String key, String value) {
    if (!_uiProducts[index]['isSelected']) return;
    
    setState(() {
      // Parse the text input to an integer. If empty or invalid, default to 0.
      int newVal = int.tryParse(value) ?? 0;
      _uiProducts[index][key] = newVal;
    });
  }

  void _submitReport() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);

    // --- 1. DUPLICATE CHECK ---
    // Exception: If we are editing, we ignore the report with our own ID.
    bool isDuplicate = provider.reports.any((report) {
      bool sameDoctor = report.doctorName == widget.doctorName;
      bool sameDate = _isSameDay(report.visitTime, _selectedDate);
      
      // If editing, skip comparing against self
      if (widget.existingReport != null && report.id == widget.existingReport!.id) {
        return false; 
      }
      return sameDoctor && sameDate;
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("A report for ${DateFormat('dd MMM').format(_selectedDate)} already exists!"), 
          backgroundColor: Colors.red
        )
      );
      return;
    }

    // --- 2. VALIDATION ---
    String finalRemark = _selectedRemark ?? "Met";
    if (_selectedRemark == 'Other') {
      if (_otherRemarkController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please type your remark")));
        return;
      }
      finalRemark = _otherRemarkController.text.trim();
    }

    setState(() => _isLoading = true); // Show loading while submitting

    // --- 3. PREPARE DATA ---
    List<ProductEntry> finalProductList = _uiProducts
        .where((p) => p['isSelected'] == true)
        .map((p) => ProductEntry(
              productName: p['name'],
              pobQty: p['pob'],
              sampleQty: p['sample'],
            ))
        .toList();

    List<String> selectedColleagues = _uiColleagues
        .where((c) => c['isSelected'] == true)
        .map((c) => c['name'].toString())
        .toList();

    // Ensure ID is never null
    String reportId = widget.existingReport?.id ?? "";

    final report = VisitReport(
      id: reportId, 
      doctorName: widget.doctorName,
      visitTime: _selectedDate, 
      remarks: finalRemark,     
      products: finalProductList,
      workedWith: selectedColleagues,
      isSubmitted: false,
    );

    try {
      if (widget.existingReport != null) {
        // === UPDATE FLOW ===
        print("Updating Report ID: $reportId"); // Debug print
        await provider.updateReport(report);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Updated Successfully!")));
      } else {
        // === ADD FLOW ===
        await provider.addReport(report);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Saved!"), backgroundColor: Colors.green));
      }

      if (mounted) {
        Navigator.pop(context); 
        if (widget.existingReport == null) Navigator.pop(context); 
      }
    } catch (e) {
      print("Submission Error: $e"); // View this in your Debug Console
      if (mounted) {
        setState(() => _isLoading = false); // Stop loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- 3. UI BUILD METHOD (Same as before) ---
  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.existingReport != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit: ${widget.doctorName}" : widget.doctorName,
          style: GoogleFonts.poppins(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF4A148C),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
            tooltip: "Change Date",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // === A. Date & Joint Work Section ===
                Container(
                  color: Colors.grey.shade50,
                  child: Column(
                    children: [
                      // Date Display Strip
                      InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Visit Date:", style: GoogleFonts.poppins(color: Colors.grey[700])),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(_selectedDate),
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF4A148C)),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.edit_calendar, size: 16, color: Colors.grey),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      _buildJointWorkSection(),
                    ],
                  ),
                ),

                // === B. Products Header ===
                Container(
                  color: Colors.purple.shade50,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text("PRODUCT", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Center(child: Text("POB", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Center(child: Text("SPL", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),

                // === C. Products List ===
                Expanded(
                  child: ListView.separated(
                    itemCount: _uiProducts.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _uiProducts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: p['isSelected'],
                                    activeColor: const Color(0xFF4A148C),
                                    onChanged: (v) => setState(() => p['isSelected'] = v),
                                  ),
                                  Expanded(child: Text(p['name'], style: GoogleFonts.poppins(fontSize: 13))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildCounter(p['isSelected'], p['pob'], (v) => _updateQty(index, 'pob', v)),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildCounter(p['isSelected'], p['sample'], (v) => _updateQty(index, 'sample', v)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // === D. Footer (Remark & Button) ===
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, -3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedRemark,
                        items: remarks.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() { 
                          _selectedRemark = v;
                          if (v != 'Other') _otherRemarkController.clear();
                        }),
                        decoration: InputDecoration(
                          labelText: "Visit Remark",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      
                      if (_selectedRemark == 'Other') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _otherRemarkController,
                          decoration: InputDecoration(
                            labelText: "Type your remark...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A148C),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          isEditing ? "UPDATE REPORT" : "SUBMIT REPORT",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildJointWorkSection() {
    int count = _uiColleagues.where((c) => c['isSelected']).length;
    
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF4A148C)),
        title: Text(
          "Joint Work ${count > 0 ? '($count Selected)' : ''}", 
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)
        ),
        children: [
          Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            child: _uiColleagues.isEmpty 
              ? Center(child: Text("No colleagues found.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uiColleagues.length,
                  itemBuilder: (context, index) {
                    final person = _uiColleagues[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text("${person['name']}"),
                        selected: person['isSelected'],
                        selectedColor: Colors.purple.shade100,
                        checkmarkColor: const Color(0xFF4A148C),
                        labelStyle: TextStyle(
                          color: person['isSelected'] ? const Color(0xFF4A148C) : Colors.black87,
                          fontSize: 12
                        ),
                        onSelected: (bool selected) {
                          setState(() {
                            person['isSelected'] = selected;
                          });
                        },
                      ),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }

Widget _buildCounter(bool active, int val, Function(String) onChanged) {
    // Create a controller initialized with the current value
    // If value is 0, show empty string for cleaner UX, otherwise show the number
    final controller = TextEditingController(text: val == 0 ? '' : val.toString());
    
    // Ensure cursor stays at the end when typing
    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        enabled: active, // Only editable if product is selected
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold, 
          color: active ? Colors.black : Colors.grey[400]
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          hintText: "0",
          hintStyle: TextStyle(color: Colors.grey[300]),
          fillColor: active ? Colors.white : Colors.grey[50],
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4A148C), width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8),
             borderSide: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        onChanged: (value) {
          // Pass the string value back to be parsed
          onChanged(value);
        },
      ),
    );
  }
//   Widget _buildCounter(bool active, int val, Function(int) onChange) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         InkWell(
//           onTap: active ? () => onChange(-1) : null,
//           child: Icon(Icons.remove_circle_outline, size: 22, color: active ? Colors.red.shade300 : Colors.grey[200]),
//         ),
//         SizedBox(
//           width: 25,
//           child: Text(
//             "$val", 
//             textAlign: TextAlign.center,
//             style: TextStyle(fontWeight: FontWeight.bold, color: active ? Colors.black : Colors.grey[300])
//           ),
//         ),
//         InkWell(
//           onTap: active ? () => onChange(1) : null,
//           child: Icon(Icons.add_circle_outline, size: 22, color: active ? Colors.green : Colors.grey[200]),
//         ),
//       ],
//     );
//   }
 }