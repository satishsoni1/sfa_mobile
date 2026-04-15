import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/chemist.dart';
import '../../data/services/api_service.dart';

class AddChemistScreen extends StatefulWidget {
  final Chemist? chemistToEdit;

  const AddChemistScreen({this.chemistToEdit, super.key});

  @override
  State<AddChemistScreen> createState() => _AddChemistScreenState();
}

class _AddChemistScreenState extends State<AddChemistScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingAreas = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  String? _selectedArea;
  List<Map<String, dynamic>> _availableAreas = [];

  String? _selectedTerritoryType;
  final List<String> _territoryTypes = ['HQ', 'EX HQ', 'OS', 'EX OS'];

  final Color _primaryColor = const Color(0xFF4A148C); // Chemist Teal Theme
  final Color _bgColor = const Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final api = ApiService();
    await _fetchAreas(api);

    if (mounted) {
      setState(() {
        if (widget.chemistToEdit != null) {
          _nameController.text = widget.chemistToEdit!.name;
          _addressController.text = widget.chemistToEdit!.address ?? '';
          _pincodeController.text = widget.chemistToEdit!.pincode ?? '';
          _contactPersonController.text =
              widget.chemistToEdit!.contactPerson ?? '';
          _mobileController.text = widget.chemistToEdit!.mobile ?? '';

          if (_territoryTypes.contains(widget.chemistToEdit!.territoryType)) {
            _selectedTerritoryType = widget.chemistToEdit!.territoryType;
          }

          // --- FIX: Safely check and assign the Area ---
          String existingArea = widget.chemistToEdit!.area.trim();

          bool areaExists = _availableAreas.any(
            (a) => a['name'].toString().trim() == existingArea,
          );

          if (!areaExists && existingArea.isNotEmpty) {
            // If the chemist has an area that is NOT in the API list,
            // add it to the list locally so the Dropdown doesn't crash!
            _availableAreas.add({
              'name': existingArea,
              'territory_type': widget.chemistToEdit!.territoryType ?? 'HQ',
            });
          }

          // Set the selected area after ensuring it exists in the list exactly once
          if (existingArea.isNotEmpty) {
            _selectedArea = existingArea;
          }
        }
      });
    }
  }

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
            // Also update the map to hold the trimmed name
            uniqueAreas[name]!['name'] = name;
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

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _contactPersonController.dispose();
    _mobileController.dispose();
    super.dispose();
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
                      _showSnack(
                        "Please enter Area Name and Type",
                        Colors.orange,
                      );
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
                      _showSnack("Area Added!", Colors.green);
                    } else {
                      setState(() => _isLoadingAreas = false);
                      _showSnack("Failed to add area", Colors.red);
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

  Future<void> _saveChemist() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArea == null) {
      _showSnack("Please select an Area", Colors.orange);
      return;
    }
    if (_selectedTerritoryType == null) {
      _showSnack("Please select a Territory Type", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      'name': _nameController.text.trim(),
      'area': _selectedArea,
      'territory_type': _selectedTerritoryType,
      'address': _addressController.text.trim(),
      'pincode': _pincodeController.text.trim(),
      'contact_person': _contactPersonController.text.trim(),
      'mobile': _mobileController.text.trim(),
    };

    try {
      final api = ApiService();
      bool success;

      if (widget.chemistToEdit != null) {
        payload['id'] = widget.chemistToEdit!.id.toString();
        success = await api.updateChemist(payload);
      } else {
        success = await api.addChemist(payload);
      }

      if (success && mounted) {
        _showSnack(
          widget.chemistToEdit != null ? "Chemist Updated!" : "Chemist Added!",
          Colors.green,
        );
        Navigator.pop(context, true);
      } else {
        throw Exception("Failed to save. Please try again.");
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.chemistToEdit != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          elevation: 0,
          title: Text(
            isEditing ? "Edit Chemist" : "Add New Chemist",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        body: _isLoadingAreas
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Primary Details",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _buildTextField(
                              controller: _nameController,
                              label: "Chemist / Pharmacy Name *",
                              icon: Icons.storefront,
                              validator: (value) =>
                                  value!.isEmpty ? "Name is required" : null,
                            ),
                            const SizedBox(height: 12),

                            // --- AREA DROPDOWN + ADD BUTTON ---
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedArea,
                                    isExpanded: true,
                                    decoration: _inputDecoration(
                                      "Select Area *",
                                      Icons.location_on_outlined,
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
                                    validator: (value) => value == null
                                        ? "Area is required"
                                        : null,
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
                            const SizedBox(height: 12),

                            // DROPDOWN: Territory Type
                            DropdownButtonFormField<String>(
                              value: _selectedTerritoryType,
                              decoration: _inputDecoration(
                                "Territory Type *",
                                Icons.map_outlined,
                              ),
                              items: _territoryTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedTerritoryType = val),
                              validator: (value) => value == null
                                  ? "Territory type is required"
                                  : null,
                            ),

                            const SizedBox(height: 24),
                            Text(
                              "Contact & Location",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _buildTextField(
                              controller: _contactPersonController,
                              label: "Contact Person Name *",
                              icon: Icons.person_outline,
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? "Contact person name is required"
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            _buildTextField(
                              controller: _mobileController,
                              label: "Mobile Number *",
                              icon: Icons.phone_iphone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return "Mobile number is required";
                                if (v.length != 10) return "Enter valid 10-digit mobile number";
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            _buildTextField(
                              controller: _addressController,
                              label: "Full Address",
                              icon: Icons.home_work_outlined,
                              maxLines: 2,
                              validator: null,
                            ),
                            const SizedBox(height: 12),

                            _buildTextField(
                              controller: _pincodeController,
                              label: "Pincode",
                              icon: Icons.pin_drop_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

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
              height: 55,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChemist,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? "SAVE CHANGES" : "ADD CHEMIST",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryColor),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: keyboardType == TextInputType.text
          ? TextCapitalization.words
          : TextCapitalization.none,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(label, icon),
      validator: validator,
    );
  }
}
