import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/report_provider.dart';
import '../../data/models/visit_report.dart';

class ReportingScreen extends StatefulWidget {
  final String doctorId; // REQUIRED: Unique ID
  final String doctorName; // For Display
  final String doctorSpeciality; // Doctor's specialization
  final VisitReport? existingReport;
  final bool isPlanned;

  const ReportingScreen({
    required this.doctorId,
    required this.doctorName,
    this.doctorSpeciality = '',
    this.existingReport,
    this.isPlanned = false,
    super.key,
  });

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  // --- STATE VARIABLES ---
  List<Map<String, dynamic>> _uiProducts = [];
  List<Map<String, dynamic>> _uiColleagues = []; // {id, name, isSelected}
  bool _isLoading = true;
  bool _timeSelected = false; // Track if user explicitly selected a time
  bool _businessValueFocused = false; // Track if business value field has focus
  final FocusNode _businessValueFocusNode = FocusNode();

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String _searchQuery = "";
  final TextEditingController _businessValueController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String? _selectedRemark;
  final TextEditingController _otherRemarkController = TextEditingController();

  final List<String> remarks = [
    "Asked for immediate availability of brand",
    "Assured for prescription initiation",
    "Asked to give reminder for a brand",
    "Inquired regarding product availability",
    "Prefers competitor product",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _businessValueFocusNode.addListener(() {
      setState(() => _businessValueFocused = _businessValueFocusNode.hasFocus);
    });
    _loadData();
  }

  @override
  void dispose() {
    _businessValueFocusNode.dispose();
    _otherRemarkController.dispose();
    _businessValueController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Strips any existing Dr/Doctor prefix and adds a clean "Dr. " prefix
  String _formatDrName(String name) {
    final cleaned = name.replaceAll(
      RegExp(r'^(dr\.?\s*|doctor\s*)', caseSensitive: false),
      '',
    ).trim();
    return 'Dr. $cleaned';
  }

  // --- DATA LOADING ---
  Future<void> _loadData() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);

    try {
      await Future.wait([
        provider.fetchProducts(),
        provider.fetchJointWorkList(),
      ]);

      if (!mounted) return;

      setState(() {
        // 1. Setup Products
        _uiProducts = provider.masterProducts.map((p) {
          int initialPob = 0;
          int initialSample = 0;
          int initialRx = 0; // NEW: Rx Qty
          bool initialSelect = false;

          if (widget.existingReport != null) {
            final report = widget.existingReport!;
            
            // 1. Try old way (Local DB or old API structure)
            final existing = report.products.firstWhere(
              (ep) => ep.productName == p.name || ep.brandId == p.id,
              orElse: () => ProductEntry(
                productName: '',
                pobQty: 0,
                sampleQty: 0,
                rxQty: 0,
              ),
            );

            if (existing.productName.isNotEmpty || existing.brandId != 0) {
              initialPob = existing.pobQty;
              initialSample = existing.sampleQty;
              initialRx = existing.rxQty;
              initialSelect = true;
            } else {
              // 2. Try new API structure mapping
              // Is product selected? (exists in brand_details or samples)
              bool inBrandDetails = report.rawBrandDetails.any((b) => b['brand_id'] == p.id || b['name'] == p.name);
              
              final sampleItem = report.rawSamples.firstWhere(
                (s) => s['brand_id'] == p.id || s['id'] == p.id || s['name'] == p.name,
                orElse: () => null,
              );
              
              if (inBrandDetails || sampleItem != null) {
              initialSelect = true;
              }
              
              // Samples
              if (sampleItem != null) {
                initialSample = int.tryParse(sampleItem['sample_qty']?.toString() ?? '0') ?? 0;
              }
              
              // Brands Added (pob)
              bool inBrandsAdded = report.rawNewBrandRxbed.any((b) => b['brand_id'] == p.id || b['name'] == p.name);
              if (inBrandsAdded) initialPob = 1;
              
              // Brands Rxbed (rx)
              bool inBrandsRxbed = report.rawPrescribedRx.any((b) => b['brand_id'] == p.id || b['id'] == p.id || b['name'] == p.name);
              if (inBrandsRxbed) initialRx = 1;
            }
          }

          return <String, dynamic>{
            'id': p.id,
            'name': p.name,
            'isSelected': initialSelect,
            'pob': initialPob,
            'sample': initialSample,
            'rx': initialRx, // NEW: Rx Qty
          };
        }).toList();

        // 2. Setup Colleagues
        _uiColleagues = provider.colleagues.map((c) {
          bool isSelected = false;
          final String empId = c['id'].toString();
         // final String empName = c['name']?.toString() ?? '';

          if (widget.existingReport != null) {
            isSelected = widget.existingReport!.workedWith.contains(empId);
            
            // Check new API response format if not found in old format
            if (!isSelected) {
              isSelected = widget.existingReport!.rawJointWork.any((j) => j['id']?.toString() == empId);
            }
          }

          return <String, dynamic>{
            'id': empId,
            'name': c['name'],
            'role': c['role'],
            'isSelected': isSelected,
          };
        }).toList();

        // 3. Setup Date & Remarks
        if (widget.existingReport != null) {
          final incomingDate = widget.existingReport!.visitTime;
          _selectedDate = DateTime(
            incomingDate.year,
            incomingDate.month,
            incomingDate.day,
          );
          _selectedTime = TimeOfDay(hour: incomingDate.hour, minute: incomingDate.minute);
          _timeSelected = true; // Mark time as selected when loading an existing report

          String savedRemark = widget.existingReport!.remarks;
          if (remarks.contains(savedRemark)) {
            _selectedRemark = savedRemark;
          } else {
            _selectedRemark = 'Other';
            _otherRemarkController.text = savedRemark;
          }
          
          _businessValueController.text = widget.existingReport!.businessValuePts > 0 
              ? widget.existingReport!.businessValuePts.toString() 
              : '';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- LOGIC ---
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
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final normalizedPicked = DateTime(picked.year, picked.month, picked.day);
      if (normalizedPicked != _selectedDate) {
        setState(() => _selectedDate = normalizedPicked);
      }
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A148C),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeSelected = true; // mark time as explicitly selected
      });
    }
  }

  void _updateQty(int index, String key, String value) {
    int newVal = int.tryParse(value) ?? 0;
    if (key == 'pob' || key == 'rx') {
      setState(() {
        _uiProducts[index][key] = newVal;
      });
    } else {
      _uiProducts[index][key] = newVal;
    }
  }

  void _showJointWorkPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JointWorkSearchSheet(
        colleagues: _uiColleagues,
        onApply: () {
          // Rebuild parent to update the count
          setState(() {});
        },
      ),
    );
  }

  void _submitReport() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);

    bool isDuplicate = provider.reports.any((report) {
      bool sameDoctor = report.doctorId == widget.doctorId;
      bool sameDate = _isSameDay(report.visitTime, _selectedDate);

      if (widget.existingReport != null &&
          report.id == widget.existingReport!.id) {
        return false;
      }
      return sameDoctor && sameDate;
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Report for this doctor on selected date already exists!",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // --- VALIDATION: Visit Time must be explicitly selected ---
    if (!_timeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select the Visit Time"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int ptsValue = int.tryParse(_businessValueController.text.trim()) ?? 0;
    if (_businessValueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Doctor Business Value as per PTS")),
      );
      return;
    }

    String finalRemark = _selectedRemark ?? "Met";
    if (_selectedRemark == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Visit Outcome / Remark")),
      );
      return;
    }
    if (_selectedRemark == 'Other') {
      if (_otherRemarkController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please type your remark")),
        );
        return;
      }
      finalRemark = _otherRemarkController.text.trim();
    }

    setState(() => _isLoading = true);

    List<ProductEntry> finalProductList = _uiProducts
        .where((p) => p['isSelected'] == true)
        .map(
          (p) => ProductEntry(
            productName: p['name'],
            // p['id'] holds the brand_id from the master product list (set during _loadData)
            // Without this, brandId defaults to 0 and is sent as 0 in every product payload
            brandId:   p['id'] is int ? p['id'] : int.tryParse(p['id'].toString()) ?? 0,
            pobQty:    p['pob'],    // 1 = Yes, 0 = No  (Brands Added After Last Visit which is sent in payload as new_brands_rxbed)
            sampleQty: p['sample'], // SPL quantity entered by user
            rxQty:     p['rx'],     // 1 = Yes, 0 = No  (Brands Rxbed which also sent in the payload as prescribed_rx  )
          ),
        )
        .toList();
        
    if (finalProductList.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one product")),
      );
      return;
    }

    // Keep ID-only list — used internally to restore selection on edit
    List<String> selectedColleagueIds = _uiColleagues
        .where((c) => c['isSelected'] == true)
        .map((c) => c['id'].toString())
        .toList();

    // [ADDED] id+name maps — this is what gets sent in the payload under worked_with
    List<Map<String, dynamic>> selectedColleagueDetails = _uiColleagues
        .where((c) => c['isSelected'] == true)
        .map((c) => <String, dynamic>{
              'id':   c['id'].toString(),
              'name': c['name']?.toString() ?? '',
            })
        .toList();

    DateTime finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final report = VisitReport(
      id: widget.existingReport?.id ?? "",
      doctorId: widget.existingReport?.doctorId ?? widget.doctorId,
      doctorName: widget.doctorName,
      doctorSpeciality: widget.doctorSpeciality,
      visitTime: finalDateTime,
      remarks: finalRemark,
      products: finalProductList,
      workedWith:      selectedColleagueIds,      // IDs — used for internal selection restore
      workedWithNames: selectedColleagueDetails,  // [ADDED] id+name — sent in payload
      businessValuePts: ptsValue,
      isSubmitted: false,
    );

    try {
      if (widget.existingReport != null) {
        await provider.updateReport(report);
      } else {
        await provider.addReport(report);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report Saved!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ));
      }
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: Text(
            widget.existingReport != null ? "Edit Report" : "New Report",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF4A148C),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // === TOP CARD (compact) ===
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A148C),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Doctor name
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDrName(widget.doctorName),
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (widget.isPlanned)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "Planned",
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Calendar button
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd MMM').format(_selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Joint work + visit time on the same row
                        Row(
                          children: [
                            Expanded(
                              child: _buildJointWorkSelectorButton(),
                            ),
                            const SizedBox(width: 8),
                            // Visit Time picker
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white38,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Colors.white70, size: 14),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _timeSelected
                                              ? "Visit Time *"
                                              : "Set Visit Time *",
                                          style: GoogleFonts.poppins(
                                            fontSize: _timeSelected ? 9 : 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        if (_timeSelected)
                                        Text(
                                          _selectedTime.format(context),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // === SEARCH BOX ===
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: "Search Brands...",
                        hintStyle: GoogleFonts.poppins(fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFF4A148C), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),

                  // === PRODUCTS HEADER ===
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            "Brands *",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4A148C),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "Brand Added\nAfter Last Visit",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "Sample",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "Brand\nRxbed",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === PRODUCTS LIST (scrollable, expands to fill space) ===
                  Expanded(
                    child: Builder(builder: (context) {
                      final filteredProducts = _uiProducts
                          .where((p) => p['name']
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        itemCount: filteredProducts.length,
                        separatorBuilder: (c, i) =>
                            const SizedBox(height: 5),
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          final origIndex = _uiProducts.indexOf(p);
                          return ProductRowItem(
                            key: ValueKey(p['id']),
                            product: p,
                            onCheckChanged: (val) {
                              setState(() {
                                p['isSelected'] = val;
                                if (!val) {
                                  p['pob'] = 0;
                                  p['sample'] = 0;
                                  p['rx'] = 0;
                                }
                              });
                            },
                            onPobChanged: (val) =>
                                _updateQty(origIndex, 'pob', val),
                            onSampleChanged: (val) =>
                                _updateQty(origIndex, 'sample', val),
                            onRxChanged: (val) =>
                                _updateQty(origIndex, 'rx', val),
                          );
                        },
                      );
                    }),
                  ),

                  // === BOTTOM SECTION: hidden when keyboard up (unless typing business value) ===
                  if (MediaQuery.of(context).viewInsets.bottom == 0 || _businessValueFocused)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 12,
                          color: Colors.black.withOpacity(0.07),
                          offset: const Offset(0, -4),
                        ),
                      ],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Business Value
                        SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _businessValueController,
                            focusNode: _businessValueFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: GoogleFonts.poppins(fontSize: 13),
                            decoration: InputDecoration(
                              labelText:
                                  "Dr. Business Value as per PTS *",
                              labelStyle: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Remark Dropdown
                        SizedBox(
                          height: 44,
                          child: DropdownButtonFormField<String>(
                            value: _selectedRemark,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down_circle,
                              color: Color(0xFF4A148C),
                              size: 18,
                            ),
                            items: remarks
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      r,
                                      style:
                                          GoogleFonts.poppins(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedRemark = v;
                              if (v != 'Other')
                                _otherRemarkController.clear();
                            }),
                            decoration: InputDecoration(
                              labelText: "Visit Outcome / Remark *",
                              labelStyle: GoogleFonts.poppins(
                                  fontSize: 11, color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                            ),
                          ),
                        ),
                        if (_selectedRemark == 'Other') ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _otherRemarkController,
                              style: GoogleFonts.poppins(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: "Type custom remark...",
                                labelStyle: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[600]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A148C),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            widget.existingReport != null
                                ? "UPDATE REPORT"
                                : "SUBMIT REPORT",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
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

  // --- NEW SLEEK JOINT WORK BUTTON ---
  Widget _buildJointWorkSelectorButton() {
    int count = _uiColleagues.where((c) => c['isSelected']).length;

    return InkWell(
      onTap: _showJointWorkPicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.group_add, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count > 0
                    ? "Joint Work: $count Selected"
                    : "Tap to select Joint Work...",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: count > 0 ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// CUSTOM PRODUCT ROW WIDGET (UPDATED FOR RX)
// =========================================================================

class ProductRowItem extends StatefulWidget {
  final Map<String, dynamic> product;
  final Function(bool) onCheckChanged;
  final Function(String) onPobChanged;
  final Function(String) onSampleChanged;
  final Function(String) onRxChanged; // NEW

  const ProductRowItem({
    required Key key,
    required this.product,
    required this.onCheckChanged,
    required this.onPobChanged,
    required this.onSampleChanged,
    required this.onRxChanged, // NEW
  }) : super(key: key);

  @override
  State<ProductRowItem> createState() => _ProductRowItemState();
}

class _ProductRowItemState extends State<ProductRowItem> {
  late TextEditingController _sampleController;

  @override
  void initState() {
    super.initState();
    _sampleController = TextEditingController(
      text: widget.product['sample'] == 0
          ? ''
          : widget.product['sample'].toString(),
    );
  }

  @override
  void didUpdateWidget(ProductRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.product['isSelected']) {
      if (_sampleController.text.isNotEmpty) _sampleController.clear();
    }
  }

  @override
  void dispose() {
    _sampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isSelected = widget.product['isSelected'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF4A148C) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          // Name and Checkbox (Flex 4)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF4A148C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (v) => widget.onCheckChanged(v!),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.product['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 12, // Slightly smaller to fit better
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? Colors.black87 : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Three Inputs (Flex 2 each)
          Expanded(
            flex: 2,
            child: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: widget.product['pob'] == 1,
                onChanged: isSelected ? (val) {
                  widget.onPobChanged(val ? "1" : "0");
                } : null,
                activeColor: const Color(0xFF4A148C),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: _buildMiniInput(
              _sampleController,
              isSelected,
              widget.onSampleChanged,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: widget.product['rx'] == 1,
                onChanged: isSelected ? (val) {
                  widget.onRxChanged(val ? "1" : "0");
                } : null,
                activeColor: const Color(0xFF4A148C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInput(
    TextEditingController controller,
    bool active,
    Function(String) onChanged,
  ) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: active ? Colors.grey.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        enabled: active,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: active ? const Color(0xFF4A148C) : Colors.grey[400],
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.only(bottom: 8),
          border: InputBorder.none,
          hintText: "-",
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// =========================================================================
// CUSTOM JOINT WORK SEARCH BOTTOM SHEET
// =========================================================================

class _JointWorkSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> colleagues;
  final VoidCallback onApply;

  const _JointWorkSearchSheet({
    required this.colleagues,
    required this.onApply,
  });

  @override
  State<_JointWorkSearchSheet> createState() => _JointWorkSearchSheetState();
}

class _JointWorkSearchSheetState extends State<_JointWorkSearchSheet> {
  String _searchQuery = "";
  late List<Map<String, dynamic>> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = widget.colleagues;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.colleagues.where((c) {
        final name = c['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header & Search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Joint Work",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onApply();
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Done",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A148C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search colleagues...",
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF4A148C),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List View
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "No colleagues found",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      var person = _filteredList[index];
                      bool isSelected = person['isSelected'];

                      return CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
                        activeColor: const Color(0xFF4A148C),
                        title: Text(
                          person['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: person['role'] != null
                            ? Text(
                                person['role'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : null,
                        value: isSelected,
                        onChanged: (bool? val) {
                          setState(() {
                            person['isSelected'] = val ?? false;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
