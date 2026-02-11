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
  final _areaController = TextEditingController();
  final _pincodeController = TextEditingController(); // NEW: Pincode Controller
  
  String? _selectedSpecialization;
  String? _selectedTerritoryType; 
  
  // Classification Flags
  bool _isKbl = false;
  bool _isFrd = false;
  bool _isOther = false; 

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _territoryTypes = ['HQ', 'EX HQ', 'OS', 'EX OS'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    // 1. Load Specializations
    await Provider.of<ReportProvider>(context, listen: false).fetchSpecialities();
    
    // 2. Pre-fill Data if Editing
    if (widget.doctorToEdit != null) {
      final doc = widget.doctorToEdit!;
      _nameController.text = doc.name;
      _mobileController.text = doc.mobile; 
      _areaController.text = doc.area;
      _pincodeController.text = doc.pincode ?? ''; // NEW: Pre-fill Pincode
      
      _selectedSpecialization = doc.specialization;
      
      if (_territoryTypes.contains(doc.territoryType)) {
        _selectedTerritoryType = doc.territoryType;
      }

      _isKbl = doc.isKbl;
      _isFrd = doc.isFrd;
      _isOther = doc.isOther;
      
      if (!_isKbl && !_isFrd && !_isOther) _isOther = true;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveDoctor() async {
    if (!_formKey.currentState!.validate()) return;

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
        area: _areaController.text.trim(),
        pincode: _pincodeController.text.trim(), // NEW: Save Pincode
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color)
    );
  }

  // --- TOGGLE LOGIC ---
  void _toggleKbl(bool? value) {
    setState(() {
      _isKbl = value ?? false;
      if (_isKbl) { _isFrd = false; _isOther = false; }
    });
  }

  void _toggleFrd(bool? value) {
    setState(() {
      _isFrd = value ?? false;
      if (_isFrd) { _isKbl = false; _isOther = false; }
    });
  }

  void _toggleOther(bool? value) {
    setState(() {
      _isOther = value ?? false;
      if (_isOther) { _isKbl = false; _isFrd = false; }
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
        title: Text(isEdit ? 'Edit Doctor' : 'Add New Doctor', style: GoogleFonts.poppins(fontSize: 18)),
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
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
                    validator: (v) => v!.isEmpty ? "Name is required" : null
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
                    }
                  ),
                  const SizedBox(height: 15),
                  
                  // Area
                  _buildTextField(
                    controller: _areaController, 
                    label: "Area / City *", 
                    icon: Icons.location_on_outlined,
                    validator: (v) => v!.isEmpty ? "Area is required" : null
                  ),
                  const SizedBox(height: 15),

                  // NEW: Pincode Field
                  _buildTextField(
                    controller: _pincodeController, 
                    label: "Pincode *", // Visual indicator
                    icon: Icons.pin_drop_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6, // Restrict input length
                    validator: (v) {
                      // 1. Check if empty
                      if (v == null || v.isEmpty) {
                        return "Pincode is required";
                      }
                      // 2. Check strict length
                      if (v.length != 6) {
                        return "Enter valid 6-digit Pincode";
                      }
                      return null;
                    }
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
                      prefixIcon: const Icon(Icons.workspace_premium_outlined, color: Color(0xFF4A148C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: specs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _selectedSpecialization = val),
                    validator: (v) => v == null ? "Required" : null,
                  ),

                  const SizedBox(height: 15),

                  // Territory Type
                  DropdownButtonFormField<String>(
                    value: _selectedTerritoryType,
                    hint: const Text("Select Type *"),
                    decoration: InputDecoration(
                      labelText: "Territory Type *",
                      prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF4A148C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: _territoryTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedTerritoryType = val),
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
                      border: Border.all(color: Colors.grey.shade300)
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text("Is KBL?"),
                          subtitle: const Text("Key Business Leader"),
                          value: _isKbl,
                          activeColor: const Color(0xFF4A148C),
                          onChanged: _toggleKbl,
                        ),
                        const Divider(height: 1),
                        CheckboxListTile(
                          title: const Text("Is FRD?"),
                          subtitle: const Text("First Response Doctor"),
                          value: _isFrd,
                          activeColor: const Color(0xFF4A148C),
                          onChanged: _toggleFrd,
                        ),
                        const Divider(height: 1),
                        CheckboxListTile(
                          title: const Text("Other"),
                          subtitle: const Text("General Category"),
                          value: _isOther,
                          activeColor: const Color(0xFF4A148C),
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
                        backgroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveDoctor,
                      child: _isSaving 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isEdit ? "UPDATE DOCTOR" : "SAVE DOCTOR", 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)
                          ),
                    ),
                  )
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
    int? maxLength
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4A148C)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        letterSpacing: 1.2
      )
    );
  }
}