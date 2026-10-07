import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/cme_model.dart';
import '../../data/models/doctor.dart';
import '../../data/services/api_service.dart';

class AddCmeScreen extends StatefulWidget {
  const AddCmeScreen({super.key});

  @override
  State<AddCmeScreen> createState() => _AddCmeScreenState();
}

class _DoctorOption {
  final int? id;
  final String name;
  final String specialization;
  final String area;
  final String? mobile;
  final bool isManual;

  _DoctorOption({
    this.id,
    required this.name,
    required this.specialization,
    this.area = '',
    this.mobile,
    this.isManual = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DoctorOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name.toLowerCase() == other.name.toLowerCase() &&
          isManual == other.isManual;

  @override
  int get hashCode => (id ?? name).hashCode ^ isManual.hashCode;
}

class _CostRowItem {
  final TextEditingController typeController;
  final TextEditingController amountController;

  _CostRowItem({String initialType = '', String initialAmount = ''})
      : typeController = TextEditingController(text: initialType),
        amountController = TextEditingController(text: initialAmount);

  void dispose() {
    typeController.dispose();
    amountController.dispose();
  }
}

class _AddCmeScreenState extends State<AddCmeScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  static const Color _primaryColor = Color(0xFF4A148C);

  // 1. Date
  DateTime _selectedDate = DateTime.now();

  // 2. Topic
  final _topicController = TextEditingController();

  // 3. Speaker
  _DoctorOption? _selectedSpeaker;

  // 4. Attendees
  final List<_DoctorOption> _selectedAttendees = [];

  // 5. Manual Doctors
  final List<CmeManualDoctor> _manualDoctors = [];

  // 6. Joint Work (Subordinates)
  String? _selectedSubordinateId;
  Map<String, dynamic>? _selectedSubordinate;
  List<dynamic> _subordinates = [];
  bool _isLoadingSubordinates = true;

  // 7. Doctors List (from Dr. Call API)
  List<_DoctorOption> _availableDoctors = [];
  bool _isLoadingDoctors = true;

  // 8. Cost Breakdown (Dynamic Rows)
  final List<_CostRowItem> _costRows = [];

  // 9. Extra Attendees
  final _extraAttendeesCountController = TextEditingController();
  final _extraAttendeesNotesController = TextEditingController();

  // 10. Remarks
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize with 1 cost row by default
    _costRows.add(_CostRowItem());
    _loadInitialData();
  }

  @override
  void dispose() {
    _topicController.dispose();
    for (var row in _costRows) {
      row.dispose();
    }
    _extraAttendeesCountController.dispose();
    _extraAttendeesNotesController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // 1. Fetch doctors from Dr. Call endpoint
    _fetchDoctors();

    // 2. Fetch subordinates for Joint Work
    _fetchSubordinates();
  }

  Future<void> _fetchDoctors() async {
    try {
      final data = await _api.getDoctorsEmployeeList();
      final List<_DoctorOption> docs = [];
      for (var raw in data) {
        if (raw is Map) {
          final json = Map<String, dynamic>.from(raw);
          final int? id = json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? json['doctor_id']?.toString() ?? '');
          final String name = (json['doctor_name'] ?? json['name'] ?? json['doc_name'] ?? 'Doctor').toString();
          final String spec = (json['speciality'] ?? json['specialization'] ?? json['qualification'] ?? '').toString();
          final String area = (json['area'] ?? json['geo_name'] ?? json['patch'] ?? json['territory'] ?? '').toString();
          final String? mobile = (json['mobile_no'] ?? json['mobile'] ?? json['phone'])?.toString();

          docs.add(
            _DoctorOption(
              id: id,
              name: name,
              specialization: spec,
              area: area,
              mobile: mobile,
              isManual: false,
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _availableDoctors = docs;
          _isLoadingDoctors = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading doctors from employee-list for CME: $e");
      // Fallback to getDoctors if employee-list is unavailable
      try {
        final fallbackData = await _api.getDoctors();
        final List<_DoctorOption> docs = [];
        for (var raw in fallbackData) {
          if (raw is Map) {
            final json = Map<String, dynamic>.from(raw);
            final doc = Doctor.fromJson(json);
            docs.add(
              _DoctorOption(
                id: doc.id,
                name: doc.name,
                specialization: doc.specialization,
                area: doc.area,
                mobile: doc.mobile,
                isManual: false,
              ),
            );
          }
        }
        if (mounted) {
          setState(() {
            _availableDoctors = docs;
            _isLoadingDoctors = false;
          });
        }
      } catch (fallbackError) {
        debugPrint("Fallback getDoctors also failed: $fallbackError");
        if (mounted) setState(() => _isLoadingDoctors = false);
      }
    }
  }

  Future<void> _fetchSubordinates() async {
    try {
      final subs = await _api.getSubordinates();
      if (mounted) {
        setState(() {
          _subordinates = subs;
          _isLoadingSubordinates = false;
          if (_selectedSubordinateId != null) {
            final match = _subordinates.firstWhere(
              (s) => s is Map && (s['id'] ?? s['employee_id'])?.toString() == _selectedSubordinateId,
              orElse: () => null,
            );
            if (match is Map) {
              _selectedSubordinate = Map<String, dynamic>.from(match);
            } else {
              _selectedSubordinateId = null;
              _selectedSubordinate = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading subordinates for CME: $e");
      if (mounted) setState(() => _isLoadingSubordinates = false);
    }
  }

  double get _totalCost {
    double sum = 0.0;
    for (var row in _costRows) {
      final amt = double.tryParse(row.amountController.text.trim()) ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  // --- SUBMIT CME PROGRAM ---
  Future<void> _submitCme() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSpeaker == null) {
      _showSnack("Please select a Speaker Doctor", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final validCostItems = _costRows
          .where((r) =>
              r.typeController.text.trim().isNotEmpty &&
              (double.tryParse(r.amountController.text.trim()) ?? 0.0) > 0)
          .map((r) => {
                'type': r.typeController.text.trim(),
                'amount': double.tryParse(r.amountController.text.trim()) ?? 0.0,
              })
          .toList();

      final double totalCost = _totalCost;
      final bool hasCost = validCostItems.isNotEmpty && totalCost > 0;

      final payload = {
        'cme_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'topic_name': _topicController.text.trim(),
        'speaker': {
          if (_selectedSpeaker!.id != null) 'doctor_id': _selectedSpeaker!.id,
          'doctor_name': _selectedSpeaker!.name,
          'speciality': _selectedSpeaker!.specialization,
          'is_manual': _selectedSpeaker!.isManual,
        },
        'attendees': _selectedAttendees.map((doc) {
          return {
            if (doc.id != null) 'doctor_id': doc.id,
            'doctor_name': doc.name,
            'speciality': doc.specialization,
            'area': doc.area,
            'is_manual': doc.isManual,
          };
        }).toList(),
        if (_manualDoctors.isNotEmpty)
          'manual_doctors': _manualDoctors.map((m) => m.toJson()).toList(),
        if (_selectedSubordinate != null)
          'joint_work': {
            'employee_id': _selectedSubordinate!['id'] ?? _selectedSubordinate!['employee_id'],
            'employee_name': _selectedSubordinate!['name'] ?? _selectedSubordinate!['employee_name'],
            'is_joint_work': true,
          }
        else
          'joint_work': {
            'is_joint_work': false,
          },
        if (hasCost)
          'cost_breakdown': {
            'has_cost': true,
            'items': validCostItems,
            'total_cost': totalCost,
          },
        'extra_attendees': {
          'count': int.tryParse(_extraAttendeesCountController.text) ?? 0,
          'notes': _extraAttendeesNotesController.text.trim(),
        },
        'remarks': _remarksController.text.trim(),
      };

      await _api.submitCmeProgram(payload);

      if (mounted) {
        _showSnack("CME Program submitted successfully!", isError: false);
        Navigator.pop(context, true); // Return true to refresh history
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
        _showSnack(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- MANUAL DOCTOR ADDITION DIALOG ---
  void _openAddDoctorModal() {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final hospitalCtrl = TextEditingController();

    bool asSpeaker = false;
    bool asAttendee = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add Doctor Manually",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      "Add a non-listed doctor to this CME program session.",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    // Doctor Name
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration("Dr. Full Name *", Icons.person_outline),
                    ),
                    const SizedBox(height: 12),

                    // Specialization
                    TextFormField(
                      controller: specCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration("Speciality (e.g. Cardiologist)", Icons.medical_services_outlined),
                    ),
                    const SizedBox(height: 12),

                    // Mobile & Area
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: mobileCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: _inputDecoration("Mobile No.", Icons.phone_outlined).copyWith(
                              counterText: "",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: areaCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration("City / Area", Icons.location_on_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hospital / Clinic
                    TextFormField(
                      controller: hospitalCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration("Hospital / Clinic Name", Icons.local_hospital_outlined),
                    ),
                    const SizedBox(height: 16),

                    // Role in this CME
                    Text(
                      "Assign Role in this CME:",
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: asSpeaker,
                          activeColor: _primaryColor,
                          onChanged: (val) {
                            setModalState(() {
                              asSpeaker = val ?? false;
                              if (asSpeaker) asAttendee = false;
                            });
                          },
                        ),
                        const Text("Set as Speaker"),
                        const SizedBox(width: 12),
                        Checkbox(
                          value: asAttendee,
                          activeColor: _primaryColor,
                          onChanged: (val) {
                            setModalState(() {
                              asAttendee = val ?? false;
                              if (asAttendee) asSpeaker = false;
                            });
                          },
                        ),
                        const Text("Add to Attendees"),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter Doctor's Name")),
                            );
                            return;
                          }

                          final formattedName = name.startsWith("Dr.") ? name : "Dr. $name";
                          final manualDoc = CmeManualDoctor(
                            doctorName: formattedName,
                            speciality: specCtrl.text.trim(),
                            mobileNo: mobileCtrl.text.trim(),
                            area: areaCtrl.text.trim(),
                            hospitalName: hospitalCtrl.text.trim(),
                          );

                          final doctorOption = _DoctorOption(
                            name: formattedName,
                            specialization: specCtrl.text.trim().isNotEmpty ? specCtrl.text.trim() : "General",
                            area: areaCtrl.text.trim(),
                            mobile: mobileCtrl.text.trim(),
                            isManual: true,
                          );

                          setState(() {
                            _manualDoctors.add(manualDoc);
                            _availableDoctors.insert(0, doctorOption);

                            if (asSpeaker) {
                              _selectedSpeaker = doctorOption;
                            }
                            if (asAttendee && !_selectedAttendees.contains(doctorOption)) {
                              _selectedAttendees.add(doctorOption);
                            }
                          });

                          Navigator.pop(ctx);
                          _showSnack("$formattedName added successfully!");
                        },
                        child: Text(
                          "ADD DOCTOR TO CME",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- SPEAKER SELECTOR MODAL ---
  void _openSpeakerPicker() {
    String query = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = query.isEmpty
                ? _availableDoctors
                : _availableDoctors.where((d) {
                    final q = query.toLowerCase();
                    return d.name.toLowerCase().contains(q) ||
                        d.specialization.toLowerCase().contains(q) ||
                        d.area.toLowerCase().contains(q);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Select Speaker",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.person_add_alt, size: 16, color: _primaryColor),
                            label: Text(
                              "+ Add New",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openAddDoctorModal();
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        onChanged: (val) => setPickerState(() => query = val.trim()),
                        decoration: InputDecoration(
                          hintText: "Search doctor by name or speciality...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FD),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                "No doctors found",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final doc = filtered[index];
                                final isSelected = _selectedSpeaker == doc;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: doc.isManual
                                        ? Colors.orange.shade50
                                        : _primaryColor.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: doc.isManual ? Colors.orange.shade800 : _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          doc.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? _primaryColor : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (doc.isManual)
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
                                  subtitle: Text(
                                    "${doc.specialization}${doc.area.isNotEmpty ? ' • ${doc.area}' : ''}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: _primaryColor)
                                      : null,
                                  onTap: () {
                                    setState(() => _selectedSpeaker = doc);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // --- ATTENDEES MULTI-SELECT PICKER ---
  void _openAttendeesPicker() {
    String query = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = query.isEmpty
                ? _availableDoctors
                : _availableDoctors.where((d) {
                    final q = query.toLowerCase();
                    return d.name.toLowerCase().contains(q) ||
                        d.specialization.toLowerCase().contains(q) ||
                        d.area.toLowerCase().contains(q);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Select Attendees",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              Text(
                                "${_selectedAttendees.length} doctors selected",
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.person_add_alt, size: 16, color: _primaryColor),
                            label: Text(
                              "+ Add New",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openAddDoctorModal();
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        onChanged: (val) => setPickerState(() => query = val.trim()),
                        decoration: InputDecoration(
                          hintText: "Search attendees by name or speciality...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FD),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                "No doctors found",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final doc = filtered[index];
                                final isSelected = _selectedAttendees.contains(doc);
                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: _primaryColor,
                                  secondary: CircleAvatar(
                                    backgroundColor: doc.isManual
                                        ? Colors.orange.shade50
                                        : _primaryColor.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: doc.isManual ? Colors.orange.shade800 : _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          doc.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (doc.isManual)
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
                                  subtitle: Text(
                                    "${doc.specialization}${doc.area.isNotEmpty ? ' • ${doc.area}' : ''}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  onChanged: (bool? checked) {
                                    setPickerState(() {
                                      if (checked == true) {
                                        _selectedAttendees.add(doc);
                                      } else {
                                        _selectedAttendees.remove(doc);
                                      }
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "DONE (${_selectedAttendees.length} SELECTED)",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text("New CME Program", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. DATE PICKER ──────────────────────────────────────────
              _buildSectionCard(
                title: "PROGRAM DATE",
                icon: Icons.calendar_today_outlined,
                child: InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event, color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const Icon(Icons.edit_calendar, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. TOPIC NAME ──────────────────────────────────────────
              _buildSectionCard(
                title: "TOPIC NAME",
                icon: Icons.menu_book_outlined,
                child: TextFormField(
                  controller: _topicController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter CME topic name";
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    "e.g. Advances in Hypertension & Heart Failure",
                    Icons.topic_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. SPEAKER NAME (DR LIST DROPDOWN) ──────────────────────
              _buildSectionCard(
                title: "SPEAKER NAME",
                icon: Icons.record_voice_over_outlined,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.person_add_alt, size: 15, color: _primaryColor),
                  label: Text(
                    "+ Manual Dr",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor),
                  ),
                  onPressed: _openAddDoctorModal,
                ),
                child: InkWell(
                  onTap: _isLoadingDoctors ? null : _openSpeakerPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _selectedSpeaker != null ? _primaryColor : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _primaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, size: 18, color: _primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isLoadingDoctors
                              ? const Text("Loading doctors list...", style: TextStyle(color: Colors.grey))
                              : _selectedSpeaker != null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedSpeaker!.name,
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        Text(
                                          "${_selectedSpeaker!.specialization}${_selectedSpeaker!.area.isNotEmpty ? ' • ${_selectedSpeaker!.area}' : ''}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "Select Speaker from Doctor List",
                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
                                    ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 4. ATTENDEES (DR LIST DROPDOWN/MULTI-SELECT) ────────────
              _buildSectionCard(
                title: "ATTENDEES (${_selectedAttendees.length})",
                icon: Icons.people_outline,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.person_add_alt, size: 15, color: _primaryColor),
                      label: Text(
                        "+ Manual",
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor),
                      ),
                      onPressed: _openAddDoctorModal,
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isLoadingDoctors ? null : _openAttendeesPicker,
                      child: Text(
                        "SELECT",
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedAttendees.isEmpty)
                      InkWell(
                        onTap: _openAttendeesPicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.group_add_outlined, size: 28, color: Colors.grey.shade400),
                              const SizedBox(height: 6),
                              Text(
                                "Tap to select doctors attending this CME",
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedAttendees.map((doc) {
                          return Chip(
                            backgroundColor: doc.isManual
                                ? Colors.orange.shade50
                                : _primaryColor.withValues(alpha: 0.08),
                            avatar: CircleAvatar(
                              backgroundColor: doc.isManual ? Colors.orange.shade800 : _primaryColor,
                              child: Text(
                                doc.name.isNotEmpty ? doc.name[0] : "D",
                                style: const TextStyle(fontSize: 10, color: Colors.white),
                              ),
                            ),
                            label: Text(
                              doc.name,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: doc.isManual ? Colors.orange.shade900 : _primaryColor,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _selectedAttendees.remove(doc));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 5. EXTRA ATTENDEES COLUMN ──────────────────────────────
              _buildSectionCard(
                title: "EXTRA ATTENDEES",
                icon: Icons.person_add_outlined,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _extraAttendeesCountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration("Count", Icons.numbers).copyWith(
                          hintText: "0",
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _extraAttendeesNotesController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration(
                          "Notes / staff names (e.g. 3 Residents, 2 Nurses)",
                          Icons.description_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 6. JOINT WORK (SUBORDINATES API) ───────────────────────
              _buildSectionCard(
                title: "JOINT WORK (IF APPLICABLE)",
                icon: Icons.handshake_outlined,
                child: _isLoadingSubordinates
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Loading colleagues list..."),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String?>(
                            key: ValueKey(_selectedSubordinateId),
                            initialValue: _selectedSubordinateId,
                            isExpanded: true,
                            decoration: _inputDecoration("Select Colleague (Optional)", Icons.group_outlined),
                            items: _buildSubordinateDropdownItems(),
                            onChanged: (selectedId) {
                              setState(() {
                                _selectedSubordinateId = selectedId;
                                if (selectedId == null) {
                                  _selectedSubordinate = null;
                                } else {
                                  final match = _subordinates.firstWhere(
                                    (s) => s is Map && (s['id'] ?? s['employee_id'])?.toString() == selectedId,
                                    orElse: () => null,
                                  );
                                  if (match is Map) {
                                    _selectedSubordinate = Map<String, dynamic>.from(match);
                                  } else {
                                    _selectedSubordinate = null;
                                  }
                                }
                              });
                            },
                          ),
                          if (_selectedSubordinate != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A148C).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF4A148C).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
                                    child: const Icon(Icons.handshake, size: 16, color: Color(0xFF4A148C)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Joint Work Selected",
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF4A148C),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          "${_selectedSubordinate!['name'] ?? _selectedSubordinate!['employee_name'] ?? 'Colleague'}${_selectedSubordinate!['designation'] != null ? ' (${_selectedSubordinate!['designation']})' : ''}",
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // ── 7. COSTING DETAILS ─────────────────────────────────────
              _buildSectionCard(
                title: "Costing Details",
                icon: Icons.calculate_outlined,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6EFD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Total: ₹${_totalCost.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Add dynamic cost types needed for this CME (e.g. Venue, Food, Audio/Visual, Honorarium) and their amounts.",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_costRows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "No cost breakdown added. Tap '+ Add Cost Type' below to add costs.",
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      )
                    else
                      ..._costRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Cost type / Description
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: row.typeController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: "Cost type / Description (e.g. Venue, Food)",
                                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.white,
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
                                      borderSide: const BorderSide(color: Color(0xFF0D6EFD), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Amount
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: row.amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: "Amount",
                                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        "₹",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.white,
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
                                      borderSide: const BorderSide(color: Color(0xFF0D6EFD), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Delete / Minus button
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_costRows.length > 1) {
                                      final removed = _costRows.removeAt(index);
                                      removed.dispose();
                                    } else {
                                      row.typeController.clear();
                                      row.amountController.clear();
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade400, width: 1.2),
                                    color: Colors.white,
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 4),

                    // + Add Cost Type button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D6EFD),
                          side: const BorderSide(color: Color(0xFF0D6EFD), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          "Add Cost Type",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _costRows.add(_CostRowItem());
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 8. REMARKS ─────────────────────────────────────────────
              _buildSectionCard(
                title: "REMARKS (OPTIONAL)",
                icon: Icons.comment_outlined,
                child: TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: _inputDecoration("Additional notes or doctor feedback...", Icons.notes),
                ),
              ),
              const SizedBox(height: 28),

              // ── SUBMIT BUTTON ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitCme,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "SUBMIT CME PROGRAM",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String?>> _buildSubordinateDropdownItems() {
    final List<DropdownMenuItem<String?>> items = [
      const DropdownMenuItem<String?>(
        value: null,
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text("None / Solo Work"),
          ],
        ),
      ),
    ];

    final Set<String> seenIds = {};
    for (var s in _subordinates) {
      if (s is Map) {
        final id = (s['id'] ?? s['employee_id'])?.toString();
        if (id != null && id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          final name = (s['name'] ?? s['employee_name'] ?? 'Colleague').toString();
          final desig = s['designation'] != null ? " • ${s['designation']}" : "";
          items.add(
            DropdownMenuItem<String?>(
              value: id,
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 18, color: Color(0xFF4A148C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$name$desig",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
    return items;
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                    letterSpacing: 1.1,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
