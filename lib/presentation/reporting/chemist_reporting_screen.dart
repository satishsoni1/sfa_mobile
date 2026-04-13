import 'package:flutter/material.dart';
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

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // NEW: Only one text controller for typing remarks
  final TextEditingController _remarkController = TextEditingController();

  final Color _primaryColor = const Color(0xFF4A148C);

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
          int initialPob = 0;
          bool initialSelect = false;

          if (widget.existingReport != null) {
            final existing = widget.existingReport!.products.firstWhere(
              (ep) => ep.productName == p.name,
              orElse: () => ChemistProductEntry(
                productName: '',
                pobQty: 0,
              ), // <--- NEW MODEL
            );

            if (existing.productName.isNotEmpty) {
              initialPob = existing.pobQty;
              initialSelect = true;
            }
          }

          return {
            'id': p.id,
            'name': p.name,
            'isSelected': initialSelect,
            'pob': initialPob,
          };
        }).toList();

        // Setup Colleagues
        _uiColleagues = provider.colleagues.map((c) {
          bool isSelected =
              widget.existingReport != null &&
              widget.existingReport!.workedWith.contains(c['id'].toString());
          return {
            'id': c['id'].toString(),
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

  void _updateQty(int index, String key, String value) {
    _uiProducts[index][key] = int.tryParse(value) ?? 0;
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

    if (_remarkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please type a remark"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
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
          (p) => ChemistProductEntry(productName: p['name'], pobQty: p['pob']),
        )
        .toList();

    List<String> selectedColleagueIds = _uiColleagues
        .where((c) => c['isSelected'] == true)
        .map((c) => c['id'].toString())
        .toList();

    final report = ChemistReport(
      id: widget.existingReport?.id ?? "",
      chemistId: widget.chemistId,
      chemistName: widget.chemistName,
      visitTime: combinedDateTime,
      remarks: _remarkController.text.trim(),
      products: finalProductList,
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: Text(
            widget.existingReport != null
                ? "Edit Chemist Report"
                : "New Chemist Report",
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
                      ],
                    ),
                  ),

                  // === PRODUCTS HEADER (ONLY POB) ===
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
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
                          flex: 3,
                          child: Center(
                            child: Text(
                              "ORDER (POB)",
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
                        return ChemistProductRowItem(
                          key: ValueKey(p['id']),
                          product: p,
                          primaryColor: _primaryColor,
                          onCheckChanged: (val) {
                            setState(() {
                              p['isSelected'] = val;
                              if (!val) p['pob'] = 0;
                            });
                          },
                          onPobChanged: (val) => _updateQty(index, 'pob', val),
                        );
                      },
                    ),
                  ),

                  // === BOTTOM SHEET (ONLY TYPED REMARKS & SUBMIT) ===
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
  final Function(String) onPobChanged;
  final Color primaryColor;

  const ChemistProductRowItem({
    required Key key,
    required this.product,
    required this.onCheckChanged,
    required this.onPobChanged,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<ChemistProductRowItem> createState() => _ChemistProductRowItemState();
}

class _ChemistProductRowItemState extends State<ChemistProductRowItem> {
  late TextEditingController _pobController;

  @override
  void initState() {
    super.initState();
    _pobController = TextEditingController(
      text: widget.product['pob'] == 0 ? '' : widget.product['pob'].toString(),
    );
  }

  @override
  void didUpdateWidget(ChemistProductRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.product['isSelected']) {
      if (_pobController.text.isNotEmpty) _pobController.clear();
    }
  }

  @override
  void dispose() {
    _pobController.dispose();
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
            flex: 7,
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
          // POB Input (Flex 3)
          Expanded(
            flex: 3,
            child: _buildMiniInput(
              _pobController,
              isSelected,
              widget.onPobChanged,
              widget.primaryColor,
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
