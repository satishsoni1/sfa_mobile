import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/report_provider.dart';
import '../../data/models/visit_report.dart';

class ReportingScreen extends StatefulWidget {
  final String doctorId; // REQUIRED: Unique ID
  final String doctorName; // For Display
  final VisitReport? existingReport;
  final bool isPlanned;

  const ReportingScreen({
    required this.doctorId,
    required this.doctorName,
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

  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

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
    _loadData();
  }

  @override
  void dispose() {
    _otherRemarkController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
            final existing = widget.existingReport!.products.firstWhere(
              (ep) => ep.productName == p.name,
              // Note: Ensure ProductEntry has rxQty in your model
              orElse: () => ProductEntry(
                productName: '',
                pobQty: 0,
                sampleQty: 0,
                rxQty: 0,
              ),
            );

            if (existing.productName.isNotEmpty) {
              initialPob = existing.pobQty;
              initialSample = existing.sampleQty;
              initialRx = existing.rxQty;
              initialSelect = true;
            }
          }

          return {
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

          if (widget.existingReport != null) {
            isSelected = widget.existingReport!.workedWith.contains(empId);
          }

          return {
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

  void _updateQty(int index, String key, String value) {
    int newVal = int.tryParse(value) ?? 0;
    _uiProducts[index][key] = newVal;
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

    String finalRemark = _selectedRemark ?? "Met";
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
            pobQty: p['pob'],
            sampleQty: p['sample'],
            rxQty: p['rx'], // Uncomment when added to model
          ),
        )
        .toList();

    List<String> selectedColleagueIds = _uiColleagues
        .where((c) => c['isSelected'] == true)
        .map((c) => c['id'].toString())
        .toList();

    final report = VisitReport(
      id: widget.existingReport?.id ?? "",
      doctorId: widget.existingReport?.doctorId ?? widget.doctorId,
      doctorName: widget.doctorName,
      visitTime: _selectedDate,
      remarks: finalRemark,
      products: finalProductList,
      workedWith: selectedColleagueIds,
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
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                  // === TOP CARD ===
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A148C),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.doctorName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.isPlanned)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(
                                          0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "Planned Visit",
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat(
                                        'dd MMM',
                                      ).format(_selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildJointWorkSelectorButton(), // NEW SELECTION BUTTON
                      ],
                    ),
                  ),

                  // === PRODUCTS HEADER (NOW INCLUDES RX) ===
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            "PRODUCT",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "POB",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "SPL",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              "RX",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === PRODUCTS LIST ===
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _uiProducts.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = _uiProducts[index];
                        return ProductRowItem(
                          key: ValueKey(p['id']),
                          product: p,
                          onCheckChanged: (val) {
                            setState(() {
                              p['isSelected'] = val;
                              if (!val) {
                                p['pob'] = 0;
                                p['sample'] = 0;
                                p['rx'] = 0; // Reset Rx too
                              }
                            });
                          },
                          onPobChanged: (val) => _updateQty(index, 'pob', val),
                          onSampleChanged: (val) =>
                              _updateQty(index, 'sample', val),
                          onRxChanged: (val) =>
                              _updateQty(index, 'rx', val), // Rx Handler
                        );
                      },
                    ),
                  ),

                  // === BOTTOM SHEET (REMARKS & SUBMIT) ===
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 15,
                          color: Colors.black.withOpacity(0.08),
                          offset: const Offset(0, -5),
                        ),
                      ],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedRemark,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down_circle,
                            color: Color(0xFF4A148C),
                          ),
                          items: remarks
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedRemark = v;
                            if (v != 'Other') _otherRemarkController.clear();
                          }),
                          decoration: InputDecoration(
                            labelText: "Visit Outcome / Remark",
                            labelStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                          ),
                        ),
                        if (_selectedRemark == 'Other') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otherRemarkController,
                            decoration: InputDecoration(
                              labelText: "Type custom remark...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A148C),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                              fontSize: 16,
                              letterSpacing: 1,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.group_add, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count > 0
                    ? "Joint Work: $count Selected"
                    : "Tap to select Joint Work...",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: count > 0 ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.search, color: Colors.white70, size: 18),
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
  late TextEditingController _pobController;
  late TextEditingController _sampleController;
  late TextEditingController _rxController; // NEW

  @override
  void initState() {
    super.initState();
    _pobController = TextEditingController(
      text: widget.product['pob'] == 0 ? '' : widget.product['pob'].toString(),
    );
    _sampleController = TextEditingController(
      text: widget.product['sample'] == 0
          ? ''
          : widget.product['sample'].toString(),
    );
    _rxController = TextEditingController(
      text: widget.product['rx'] == 0 ? '' : widget.product['rx'].toString(),
    ); // NEW
  }

  @override
  void didUpdateWidget(ProductRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.product['isSelected']) {
      if (_pobController.text.isNotEmpty) _pobController.clear();
      if (_sampleController.text.isNotEmpty) _sampleController.clear();
      if (_rxController.text.isNotEmpty) _rxController.clear(); // NEW
    }
  }

  @override
  void dispose() {
    _pobController.dispose();
    _sampleController.dispose();
    _rxController.dispose(); // NEW
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
            child: _buildMiniInput(
              _pobController,
              isSelected,
              widget.onPobChanged,
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
            child: _buildMiniInput(
              _rxController,
              isSelected,
              widget.onRxChanged,
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
      height: 40,
      decoration: BoxDecoration(
        color: active ? Colors.grey.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        enabled: active,
        keyboardType: TextInputType.number,
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
