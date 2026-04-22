import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/report_provider.dart';
import '../../data/models/chemist_report.dart';

class ChemistReportingScreen extends StatefulWidget {
  final String chemistId;
  final String chemistName;
  final ChemistReport? existingReport;
  final bool isPlanned;

  const ChemistReportingScreen({
    required this.chemistId,
    required this.chemistName,
    this.existingReport,
    this.isPlanned = false,
    super.key,
  });

  @override
  State<ChemistReportingScreen> createState() => _ChemistReportingScreenState();
}

class _ChemistReportingScreenState extends State<ChemistReportingScreen> {
  List<Map<String, dynamic>> _uiProducts = [];
  List<Map<String, dynamic>> _uiColleagues = [];
  bool _isLoading = true;
  String _productSearchQuery = '';

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // NEW: Only one text controller for typing remarks
  final TextEditingController _remarkController = TextEditingController();

  final Color _primaryColor = const Color(0xFF4A148C);

  int get _totalOrderPob => _uiProducts
      .where((p) => p['isSelected'] == true)
      .fold<int>(
        0,
        (sum, p) =>
            sum + (((p['sale'] as int?) ?? 0) + ((p['free'] as int?) ?? 0)),
      );

  int get _totalValuePob => _uiProducts
      .where((p) => p['isSelected'] == true)
      .fold<int>(0, (sum, p) => sum + ((p['value_pob'] as int?) ?? 0));

  @override
  void initState() {
    super.initState();
    // Load chemist reports for today just in case we need to check duplicates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(
        context,
        listen: false,
      ).fetchChemistReportsByDate(_selectedDate);
    });
    _loadData();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadData() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);

    try {
      await Future.wait([
        provider.fetchProducts(),
        provider.fetchJointWorkList(),
      ]);

      if (!mounted) return;

      setState(() {
        // Setup Products (Only POB matters)
        _uiProducts = provider.masterProducts.map((p) {
          int initialSale = 0;
          int initialFree = 0;
          int initialValuePob = 0;
          String initialSuppliedThrough = '';
          bool initialSelect = false;

          if (widget.existingReport != null) {
            final existing = widget.existingReport!.products.firstWhere(
              (ep) => ep.productName == p.name,
              orElse: () => ChemistProductEntry(
                productName: '',
                saleQty: 0,
                freeQty: 0,
                pobQty: 0,
                valuePob: 0,
                suppliedThrough: '',
              ), // <--- NEW MODEL
            );

            if (existing.productName.isNotEmpty) {
              initialSale = existing.saleQty;
              initialFree = existing.freeQty;
              initialValuePob = existing.valuePob;
              initialSuppliedThrough = existing.suppliedThrough;
              initialSelect = true;
            }
          }

          return {
            'id': p.id,
            'name': p.name,
            'isSelected': initialSelect,
            'sale': initialSale,
            'free': initialFree,
            'value_pob': initialValuePob,
            'supplied_through': initialSuppliedThrough,
          };
        }).toList();

        // Setup Colleagues
        _uiColleagues = provider.colleagues.map((c) {
          //final String empId = c['id'].toString();
          //final String empName = c['name']?.toString() ?? '';
          bool isSelected =
              widget.existingReport != null &&
              // (widget.existingReport!.workedWith.contains(empId) ||
              //     widget.existingReport!.workedWith.contains(empName));
              widget.existingReport!.workedWith.contains(c['id'].toString());
          return {
            'id': c['id'].toString(),
            //'id': empId,
            'name': c['name'],
            'role': c['role'],
            'isSelected': isSelected,
          };
        }).toList();

        // Setup Date, Time & Remarks
        if (widget.existingReport != null) {
          final incomingDate = widget.existingReport!.visitTime;
          _selectedDate = DateTime(
            incomingDate.year,
            incomingDate.month,
            incomingDate.day,
          );
          _selectedTime = TimeOfDay(
            hour: incomingDate.hour,
            minute: incomingDate.minute,
          );

          _remarkController.text = widget.existingReport!.remarks;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _pickDateAndTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
        builder: (context, child) => Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
        // Check duplicates for newly selected date
        Provider.of<ReportProvider>(
          context,
          listen: false,
        ).fetchChemistReportsByDate(pickedDate);
      }
    }
  }

  void _updateSaleQty(int index, String value) {
    setState(() {
      _uiProducts[index]['sale'] = int.tryParse(value) ?? 0;
    });
  }

  void _updateFreeQty(int index, String value) {
    setState(() {
      _uiProducts[index]['free'] = int.tryParse(value) ?? 0;
    });
  }

  void _updateValuePob(int index, String value) {
    setState(() {
      _uiProducts[index]['value_pob'] = int.tryParse(value) ?? 0;
    });
  }

  void _updateSuppliedThrough(int index, String value) {
    setState(() {
      _uiProducts[index]['supplied_through'] = value;
    });
  }

  List<int> get _filteredProductIndexes {
    if (_productSearchQuery.trim().isEmpty) {
      return List<int>.generate(_uiProducts.length, (i) => i);
    }
    final query = _productSearchQuery.toLowerCase().trim();
    final List<int> indexes = [];
    for (int i = 0; i < _uiProducts.length; i++) {
      final name = (_uiProducts[i]['name'] ?? '').toString().toLowerCase();
      if (name.contains(query)) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  void _showJointWorkPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JointWorkSearchSheet(
        colleagues: _uiColleagues,
        primaryColor: _primaryColor,
        onApply: () => setState(() {}),
      ),
    );
  }

  void _submitReport() async {
    final provider = Provider.of<ReportProvider>(context, listen: false);

    bool isDuplicate = provider.chemistReports.any((report) {
      bool sameChemist =
          report.chemistId ==
          widget.chemistId; // Reusing doctorId for chemistId
      bool sameDate = _isSameDay(report.visitTime, _selectedDate);
      if (widget.existingReport != null &&
          report.id == widget.existingReport!.id)
        return false;
      return sameChemist && sameDate;
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Report for this chemist on selected date already exists!",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedProducts = _uiProducts.where((p) => p['isSelected'] == true).toList();
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one product"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    for (final p in selectedProducts) {
      final int saleQty = (p['sale'] as int?) ?? 0;
      final int invoiceValue = (p['value_pob'] as int?) ?? 0;
      final String suppliedThrough = (p['supplied_through'] ?? '').toString().trim();

      if (saleQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please enter Sale units for ${p['name']}"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (invoiceValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please enter POBS At Invoice Value for ${p['name']}"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (suppliedThrough.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please enter Supplied Through for ${p['name']}"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Combine Date and Time
    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    List<ChemistProductEntry> finalProductList = _uiProducts
        .where((p) => p['isSelected'] == true)
        .map(
          (p) => ChemistProductEntry(
            productName: p['name'],
            saleQty: p['sale'],
            freeQty: p['free'],
            pobQty: (p['sale'] ?? 0) + (p['free'] ?? 0),
            valuePob: p['value_pob'],
            suppliedThrough: (p['supplied_through'] ?? '').toString().trim(),
          ),
        )
        .toList();

    //List<String> selectedColleagueNames = _uiColleagues
    List<String> selectedColleagueIds = _uiColleagues
        .where((c) => c['isSelected'] == true)
        .map((c) => c['id'].toString())
        //.map((c) => c['name'].toString())
        .toList();

    final report = ChemistReport(
      id: widget.existingReport?.id ?? "",
      chemistId: widget.chemistId,
      chemistName: widget.chemistName,
      visitTime: combinedDateTime,
      remarks: _remarkController.text.trim(),
      products: finalProductList,
      //workedWith: selectedColleagueNames,
      workedWith: selectedColleagueIds,
      isSubmitted: false,
    );

    try {
      if (widget.existingReport != null) {
        // You can add updateChemistReport to provider later if editing is needed
        await provider.addChemistReport(report, selectedDate: combinedDateTime);
      } else {
        await provider.addChemistReport(report, selectedDate: combinedDateTime);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chemist Report Saved!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            widget.existingReport != null
                ? "Edit Chemist Report"
                : "Personal Order Booked & Supplied",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _primaryColor,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : Column(
                children: [
                  // === TOP CARD ===
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: const BorderRadius.vertical(
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
                                    widget.chemistName,
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
                              onTap: _pickDateAndTime,
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
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat(
                                            'dd MMM',
                                          ).format(_selectedDate),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _selectedTime.format(context),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
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
                        const SizedBox(height: 16),
                        _buildJointWorkSelectorButton(),
                        const SizedBox(height: 12),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _productSearchQuery = value;
                              });
                            },
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search products",
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white70,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === PRODUCTS HEADER ===
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
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
                          flex: 4,
                          child: Column(
                            children: [
                              Text(
                                "UNITS (POBS)",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Sales",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Free",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Text(
                              "POBS At Invoice Value",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: Text(
                              "Supplied Through (Stockist)",
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
                      itemCount: _filteredProductIndexes.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final actualIndex = _filteredProductIndexes[index];
                        final p = _uiProducts[actualIndex];
                        return ChemistProductRowItem(
                          key: ValueKey(p['id']),
                          product: p,
                          primaryColor: _primaryColor,
                          onCheckChanged: (val) {
                            setState(() {
                              p['isSelected'] = val;
                              if (!val) {
                                p['sale'] = 0;
                                p['free'] = 0;
                                p['value_pob'] = 0;
                                p['supplied_through'] = '';
                              }
                            });
                          },
                          onSaleChanged: (val) => _updateSaleQty(actualIndex, val),
                          onFreeChanged: (val) => _updateFreeQty(actualIndex, val),
                          onValuePobChanged: (val) =>
                              _updateValuePob(actualIndex, val),
                          onSuppliedThroughChanged: (val) =>
                              _updateSuppliedThrough(actualIndex, val),
                        );
                      },
                    ),
                  ),

                  // === BOTTOM SHEET (ONLY TYPED REMARKS & SUBMIT) ===
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isKeyboardOpen ? 12 : 20,
                      20,
                      isKeyboardOpen ? 12 : 20,
                    ),
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
                        if (!isKeyboardOpen) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Total units (POBS): $_totalOrderPob",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    "Total Value (POBS): $_totalValuePob",
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          "Visit Remark",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _remarkController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                "Type your observation or order details here...",
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
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
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
// CUSTOM CHEMIST PRODUCT ROW WIDGET (ONLY POB)
// =========================================================================

class ChemistProductRowItem extends StatefulWidget {
  final Map<String, dynamic> product;
  final Function(bool) onCheckChanged;
  final Function(String) onSaleChanged;
  final Function(String) onFreeChanged;
  final Function(String) onValuePobChanged;
  final Function(String) onSuppliedThroughChanged;
  final Color primaryColor;

  const ChemistProductRowItem({
    required Key key,
    required this.product,
    required this.onCheckChanged,
    required this.onSaleChanged,
    required this.onFreeChanged,
    required this.onValuePobChanged,
    required this.onSuppliedThroughChanged,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<ChemistProductRowItem> createState() => _ChemistProductRowItemState();
}

class _ChemistProductRowItemState extends State<ChemistProductRowItem> {
  late TextEditingController _saleController;
  late TextEditingController _freeController;
  late TextEditingController _valuePobController;
  late TextEditingController _suppliedThroughController;

  @override
  void initState() {
    super.initState();
    _saleController = TextEditingController(
      text: widget.product['sale'] == 0 ? '' : widget.product['sale'].toString(),
    );
    _freeController = TextEditingController(
      text: widget.product['free'] == 0 ? '' : widget.product['free'].toString(),
    );
    _valuePobController = TextEditingController(
      text: widget.product['value_pob'] == 0
          ? ''
          : widget.product['value_pob'].toString(),
    );
    _suppliedThroughController = TextEditingController(
      text: (widget.product['supplied_through'] ?? '').toString(),
    );
  }

  @override
  void didUpdateWidget(ChemistProductRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.product['isSelected']) {
      if (_saleController.text.isNotEmpty) _saleController.clear();
      if (_freeController.text.isNotEmpty) _freeController.clear();
      if (_valuePobController.text.isNotEmpty) _valuePobController.clear();
      if (_suppliedThroughController.text.isNotEmpty) {
        _suppliedThroughController.clear();
      }
    }
  }

  @override
  void dispose() {
    _saleController.dispose();
    _freeController.dispose();
    _valuePobController.dispose();
    _suppliedThroughController.dispose();
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
          color: isSelected ? widget.primaryColor : Colors.transparent,
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
          // Name and Checkbox (Flex 7)
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: widget.primaryColor,
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
                      fontSize: 12,
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
          // Sale / Free (Flex 4)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniInput(
                    _saleController,
                    isSelected,
                    widget.onSaleChanged,
                    widget.primaryColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniInput(
                    _freeController,
                    isSelected,
                    widget.onFreeChanged,
                    widget.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _buildMiniInput(
              _valuePobController,
              isSelected,
              widget.onValuePobChanged,
              widget.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _buildTextInput(
              _suppliedThroughController,
              isSelected,
              widget.onSuppliedThroughChanged,
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
    Color activeColor,
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
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: active ? activeColor : Colors.grey[400],
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

  Widget _buildTextInput(
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
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.black87 : Colors.grey[400],
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
  final Color primaryColor;

  const _JointWorkSearchSheet({
    required this.colleagues,
    required this.onApply,
    required this.primaryColor,
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
      _filteredList = widget.colleagues
          .where(
            (c) =>
                c['name']?.toString().toLowerCase().contains(
                  query.toLowerCase(),
                ) ??
                false,
          )
          .toList();
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
                          color: widget.primaryColor,
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
                    prefixIcon: Icon(Icons.search, color: widget.primaryColor),
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
                        activeColor: widget.primaryColor,
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
                        onChanged: (bool? val) =>
                            setState(() => person['isSelected'] = val ?? false),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
