import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/report_provider.dart';
import '../../data/models/doctor.dart';

class AddDoctorScreen extends StatefulWidget {
  const AddDoctorScreen({super.key});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _areaController = TextEditingController();
  
  String? _selectedSpecialization;
  String? _selectedTerritoryType; 
  
  // Mutually Exclusive Flags
  bool _isKbl = false;
  bool _isFrd = false;
  bool _isOther = false; 

  bool _isLoading = true;

  final List<String> _territoryTypes = ['HQ', 'EX HQ', 'OS'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpecs();
    });
  }

  Future<void> _loadSpecs() async {
    await Provider.of<ReportProvider>(context, listen: false).fetchSpecialities();
    if (mounted) setState(() => _isLoading = false);
  }

  void _saveDoctor() {
    // 1. Validate Text Fields
    if (_formKey.currentState!.validate()) {
      
      // 2. Validate Dropdowns
      if (_selectedSpecialization == null) {
        _showSnack("Please select a specialization");
        return;
      }
      if (_selectedTerritoryType == null) {
        _showSnack("Please select a Territory Type");
        return;
      }

      // 3. Validate Classification (One MUST be selected)
      if (!_isKbl && !_isFrd && !_isOther) {
        _showSnack("Please select a Classification (KBL, FRD, or Other)");
        return;
      }

      // 4. Create & Save
      final newDoc = Doctor(
        name: _nameController.text,
        mobile: _mobileController.text,
        area: _areaController.text,
        specialization: _selectedSpecialization!,
        territoryType: _selectedTerritoryType,
        isKbl: _isKbl, 
        isFrd: _isFrd,
        isOther: _isOther,
      );

      Provider.of<ReportProvider>(context, listen: false).addDoctor(newDoc);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor Added Successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- 3-WAY TOGGLE LOGIC ---
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
    final specs = reportProvider.specialities;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Add New Doctor', style: GoogleFonts.poppins(fontSize: 18)),
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
                  
                  // Mobile (Now Mandatory with validation)
                  _buildTextField(
                    controller: _mobileController, 
                    label: "Mobile Number *", 
                    icon: Icons.phone_android, 
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Mobile is required";
                      if (v.length < 10) return "Enter valid 10-digit number";
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
                  
                  const SizedBox(height: 30),
                  _buildSectionTitle("Professional Info"),
                  const SizedBox(height: 15),
                  
                  // Specialization Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedSpecialization,
                    hint: const Text("Select Specialization *"),
                    decoration: InputDecoration(
                      labelText: "Specialization *",
                      prefixIcon: const Icon(Icons.workspace_premium_outlined, color: Color(0xFF4A148C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: specs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _selectedSpecialization = val),
                    validator: (v) => v == null ? "Required" : null,
                  ),

                  const SizedBox(height: 15),

                  // Territory Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTerritoryType,
                    hint: const Text("Select Type *"),
                    decoration: InputDecoration(
                      labelText: "Territory Type *",
                      prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF4A148C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _territoryTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedTerritoryType = val),
                    validator: (v) => v == null ? "Required" : null,
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Classification * (Select One)"),
                  const SizedBox(height: 10),

                  // Classification Section
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        // Highlight red if tried to submit without selecting
                        color: Colors.grey.shade300
                      )
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
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveDoctor,
                      child: Text("SAVE DOCTOR", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4A148C)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
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