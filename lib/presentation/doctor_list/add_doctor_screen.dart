import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/report_provider.dart';
import '../../data/models/doctor.dart';
import '../../data/services/api_service.dart';

class AddDoctorScreen extends StatefulWidget {
  final Doctor? doctorToEdit;

  const AddDoctorScreen({super.key, this.doctorToEdit});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _pincodeController = TextEditingController();

  String? _selectedSpecialization;
  String? _selectedTerritoryType;

  // Area Dropdown state
  String? _selectedArea;
  List<Map<String, dynamic>> _availableAreas = [];
  bool _isLoadingAreas = true;

  // Classification Flags
  bool _isKbl = false;
  bool _isFrd = false;
  bool _isOther = false;

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _territoryTypes = ['HQ', 'EX HQ', 'OS', 'EX OS'];
  final Color _primaryColor = const Color(0xFF4A148C); // Doctor Purple Theme

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // 1. Fetch Specializations & Areas in Parallel
    final api = ApiService();
    final provider = Provider.of<ReportProvider>(context, listen: false);

    await Future.wait([provider.fetchSpecialities(), _fetchAreas(api)]);

    // 2. Pre-fill Data if Editing
    if (mounted) {
      setState(() {
        if (widget.doctorToEdit != null) {
          final doc = widget.doctorToEdit!;
          _nameController.text = doc.name;
          _mobileController.text = doc.mobile;
          _emailController.text = doc.email ?? '';
          _pincodeController.text = doc.pincode ?? '';

          _selectedSpecialization = doc.specialization;

          if (_territoryTypes.contains(doc.territoryType)) {
            _selectedTerritoryType = doc.territoryType;
          }

          // --- FIX: Safely check and assign the Area ---
          String existingArea = doc.area.trim();
          bool areaExists = _availableAreas.any(
            (a) => a['name'].toString().trim() == existingArea,
          );

          if (!areaExists && existingArea.isNotEmpty) {
            _availableAreas.add({
              'name': existingArea,
              'territory_type': doc.territoryType ?? 'HQ',
            });
          }

          if (existingArea.isNotEmpty) {
            _selectedArea = existingArea;
          }

          _isKbl = doc.isKbl;
          _isFrd = doc.isFrd;
          _isOther = doc.isOther;

          if (!_isKbl && !_isFrd && !_isOther) _isOther = true;
        }

        _isLoading = false;
      });
    }
  }

  // --- FETCH AREAS ---
  Future<void> _fetchAreas(ApiService api) async {
    try {
      final areas = await api.fetchUserAreas();
      if (mounted) {
        // --- FIX: Remove duplicates to prevent Dropdown crash ---
        final Map<String, Map<String, dynamic>> uniqueAreas = {};

        for (var area in areas) {
          String name = area['name'].toString().trim();
          if (!uniqueAreas.containsKey(name)) {
            uniqueAreas[name] = area;
            uniqueAreas[name]!['name'] = name; // ensure name is trimmed in map
          }
        }

        setState(() {
          _availableAreas = uniqueAreas.values.toList();
          _isLoadingAreas = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  // --- NEW: ADD AREA POPUP ---
  void _showAddAreaDialog() {
    final TextEditingController newAreaController = TextEditingController();
    String? newTerritoryType;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Add New Area",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newAreaController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: "Area Name",
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        color: _primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Territory Type",
                      prefixIcon: Icon(
                        Icons.map_outlined,
                        color: _primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: newTerritoryType,
                    items: _territoryTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) =>
                        setStateDialog(() => newTerritoryType = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (newAreaController.text.trim().isEmpty ||
                        newTerritoryType == null) {
                      _showSnack("Please enter Area Name and Type");
                      return;
                    }

                    Navigator.pop(ctx); // Close dialog
                    setState(() => _isLoadingAreas = true);

                    // Call API to create area
                    final newArea = await ApiService().createArea(
                      newAreaController.text.trim(),
                      newTerritoryType!,
                    );

                    if (newArea != null) {
                      await _fetchAreas(ApiService()); // Refresh area list
                      setState(() {
                        _selectedArea = newAreaController.text.trim();
                        _selectedTerritoryType = newTerritoryType;
                      });
                      _showSnack("Area Added!", color: Colors.green);
                    } else {
                      setState(() => _isLoadingAreas = false);
                      _showSnack("Failed to add area");
                    }
                  },
                  child: const Text(
                    "Save Area",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedArea == null) {
      _showSnack("Please select an Area");
      return;
    }
    if (_selectedSpecialization == null) {
      _showSnack("Please select a specialization");
      return;
    }
    if (_selectedTerritoryType == null) {
      _showSnack("Please select a Territory Type");
      return;
    }
    if (!_isKbl && !_isFrd && !_isOther) {
      _showSnack("Please select a Classification");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ApiService();

      // Create Doctor Object
      final doctorData = Doctor(
        id: widget.doctorToEdit?.id,
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        area: _selectedArea!, // USING DROPDOWN VALUE
        pincode: _pincodeController.text.trim(),
        specialization: _selectedSpecialization!,
        territoryType: _selectedTerritoryType,
        isKbl: _isKbl,
        isFrd: _isFrd,
        isOther: _isOther,
      );

      if (widget.doctorToEdit == null) {
        // --- ADD NEW ---
        await api.addDoctor(doctorData.toJson());

        if (mounted) {
          _showSnack('Doctor Added Successfully!', color: Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        // --- UPDATE EXISTING ---
        await api.updateDoctor(doctorData.toJson());

        if (mounted) {
          _showSnack('Doctor Updated Successfully!', color: Colors.blue);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {Color color = Colors.red}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // --- TOGGLE LOGIC ---
  void _toggleKbl(bool? value) {
    setState(() {
      _isKbl = value ?? false;
      if (_isKbl) {
        _isFrd = false;
        _isOther = false;
      }
    });
  }

  void _toggleFrd(bool? value) {
    setState(() {
      _isFrd = value ?? false;
      if (_isFrd) {
        _isKbl = false;
        _isOther = false;
      }
    });
  }

  void _toggleOther(bool? value) {
    setState(() {
      _isOther = value ?? false;
      if (_isOther) {
        _isKbl = false;
        _isFrd = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);

    // --- SAFE DROPDOWN FIX ---
    final List<String> specs = List.from(reportProvider.specialities);
    if (_selectedSpecialization != null &&
        _selectedSpecialization!.isNotEmpty &&
        !specs.contains(_selectedSpecialization)) {
      specs.add(_selectedSpecialization!);
    }

    final isEdit = widget.doctorToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Doctor' : 'Add New Doctor',
          style: GoogleFonts.poppins(fontSize: 18),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle("Basic Details"),
                    const SizedBox(height: 15),

                    // Name
                    _buildTextField(
                      controller: _nameController,
                      label: "Doctor Name *",
                      icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 15),

                    // Mobile
                    _buildTextField(
                      controller: _mobileController,
                      label: "Mobile Number *",
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Mobile is required";
                        if (v.length < 10) return "Enter valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: "Email ID *",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Email is required";
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(v))
                          return "Enter a valid email address";
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // --- AREA DROPDOWN + ADD BUTTON ---
                    _isLoadingAreas
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedArea,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: "Area / City *",
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                      color: _primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  items: _availableAreas.map((area) {
                                    return DropdownMenuItem<String>(
                                      value: area['name'],
                                      child: Text(area['name']),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedArea = val;
                                      // Auto-update territory type if available in API data
                                      final matchedArea = _availableAreas
                                          .firstWhere(
                                            (a) => a['name'] == val,
                                            orElse: () => {},
                                          );
                                      if (matchedArea.isNotEmpty &&
                                          matchedArea['territory_type'] !=
                                              null) {
                                        _selectedTerritoryType =
                                            matchedArea['territory_type'];
                                      }
                                    });
                                  },
                                  validator: (value) =>
                                      value == null ? "Area is required" : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                height: 55,
                                width: 55,
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.add_location_alt,
                                    color: _primaryColor,
                                  ),
                                  tooltip: "Add New Area",
                                  onPressed: _showAddAreaDialog,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 15),

                    // Pincode Field
                    _buildTextField(
                      controller: _pincodeController,
                      label: "Pincode *",
                      icon: Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return "Pincode is required";
                        if (v.length != 6) return "Enter valid 6-digit Pincode";
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),
                    _buildSectionTitle("Professional Info"),
                    const SizedBox(height: 15),

                    // Specialization
                    DropdownButtonFormField<String>(
                      value: _selectedSpecialization,
                      hint: const Text("Select Specialization *"),
                      decoration: InputDecoration(
                        labelText: "Specialization *",
                        prefixIcon: Icon(
                          Icons.workspace_premium_outlined,
                          color: _primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: specs
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSpecialization = val),
                      validator: (v) => v == null ? "Required" : null,
                    ),
                    const SizedBox(height: 15),

                    // Territory Type
                    DropdownButtonFormField<String>(
                      value: _selectedTerritoryType,
                      hint: const Text("Select Type *"),
                      decoration: InputDecoration(
                        labelText: "Territory Type *",
                        prefixIcon: Icon(
                          Icons.map_outlined,
                          color: _primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: _territoryTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedTerritoryType = val),
                      validator: (v) => v == null ? "Required" : null,
                    ),

                    const SizedBox(height: 25),
                    _buildSectionTitle("Classification * (Select One)"),
                    const SizedBox(height: 10),

                    // Classification Checkboxes
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: const Text("Is KBL?"),
                            subtitle: const Text("Key Business Leader"),
                            value: _isKbl,
                            activeColor: _primaryColor,
                            onChanged: _toggleKbl,
                          ),
                          const Divider(height: 1),
                          CheckboxListTile(
                            title: const Text("Is FRD?"),
                            subtitle: const Text("First Response Doctor"),
                            value: _isFrd,
                            activeColor: _primaryColor,
                            onChanged: _toggleFrd,
                          ),
                          const Divider(height: 1),
                          CheckboxListTile(
                            title: const Text("Other"),
                            subtitle: const Text("General Category"),
                            value: _isOther,
                            activeColor: _primaryColor,
                            onChanged: _toggleOther,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveDoctor,
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isEdit ? "UPDATE DOCTOR" : "SAVE DOCTOR",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.grey[600],
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }
}
