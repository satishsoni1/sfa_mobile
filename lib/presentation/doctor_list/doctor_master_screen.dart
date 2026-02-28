import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Services & Models
import '../../data/services/api_service.dart';
import '../../data/models/doctor.dart';

// Screens
import 'add_doctor_screen.dart';
import 'doctor_history_screen.dart';

class DoctorMasterScreen extends StatefulWidget {
  const DoctorMasterScreen({super.key});

  @override
  State<DoctorMasterScreen> createState() => _DoctorMasterScreenState();
}

class _DoctorMasterScreenState extends State<DoctorMasterScreen> {
  final ApiService _api = ApiService();
  
  bool _isLoading = true;
  List<dynamic> _doctors = [];
  List<dynamic> _filteredDoctors = [];
  
  // Hierarchy Data
  List<dynamic> _hierarchy = [];
  dynamic _selectedSub; // Null = Myself
  
  final TextEditingController _searchController = TextEditingController();

  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  // Summary Metrics
  int _totalDoctors = 0;
  int _totalKbl = 0;
  int _totalFrd = 0;
  int _fullyCompleted = 0;
  int _incompleteProfile = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_filterLocalDoctors);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- API INTEGRATION ---

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final subs = await _api.getSubordinates();
      setState(() => _hierarchy = subs);
      await _fetchDoctors();
    } catch (e) {
      debugPrint("Init Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDoctors() async {
    setState(() => _isLoading = true);
    try {
      int? targetId = _selectedSub?['id'];
      final response = await _api.getDoctorsMaster(userId: targetId);
      
      if (mounted) {
        setState(() {
          _doctors = response;
          _filteredDoctors = response;
          _calculateMetrics();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching doctors: $e");
      _showSnack("Failed to fetch doctors");
    }
  }

  // --- LOGIC ---

  void _filterLocalDoctors() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDoctors = _doctors.where((doc) {
        final name = (doc['doctor_name'] ?? '').toString().toLowerCase();
        final area = (doc['area'] ?? '').toString().toLowerCase();
        final speciality = (doc['speciality'] ?? '').toString().toLowerCase();
        return name.contains(query) || area.contains(query) || speciality.contains(query);
      }).toList();
    });
  }

  void _calculateMetrics() {
    _totalDoctors = _doctors.length;
    _totalKbl = 0;
    _totalFrd = 0;
    _fullyCompleted = 0;
    _incompleteProfile = 0;

    for (var doc in _doctors) {
      if (doc['is_kbl'] == 1) _totalKbl++;
      if (doc['is_frd'] == 1) _totalFrd++;

      // Profile Completion Check
      bool isComplete = _checkIfComplete(doc);
      if (isComplete) {
        _fullyCompleted++;
      } else {
        _incompleteProfile++;
      }
    }
  }

  bool _checkIfComplete(Map<String, dynamic> doc) {
    final name = doc['doctor_name']?.toString() ?? '';
    final email = doc['email']?.toString() ?? '';
    final phone = doc['mobile_no']?.toString() ?? '';
    final pincode = doc['pincode']?.toString() ?? '';
    final area = doc['area']?.toString() ?? '';
    final speciality = doc['speciality']?.toString() ?? '';
    final hasTag = (doc['is_kbl'] == 1 || doc['is_frd'] == 1 || doc['is_other'] == 1);

    return name.isNotEmpty && email.isNotEmpty && phone.isNotEmpty && 
           pincode.isNotEmpty && area.isNotEmpty && speciality.isNotEmpty && hasTag;
  }

  void _showSnack(String msg) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          elevation: 0,
          title: Text(
            "Doctor Master",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                final result = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AddDoctorScreen())
                );
                if (result == true) {
                  _fetchDoctors();
                }
              },
            )
          ],
        ),
        body: Column(
          children: [
            if (_hierarchy.isNotEmpty) _buildHierarchyPicker(),
            _buildSummaryCard(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryColor))
                  : _filteredDoctors.isEmpty
                      ? Center(child: Text("No doctors found.", style: GoogleFonts.poppins(color: Colors.grey)))
                      : _buildDoctorList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHierarchyPicker() {
    return Container(
      height: 65,
      color: _primaryColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _hierarchy.length + 1,
        itemBuilder: (context, index) {
          bool isMyself = index == 0;
          var sub = isMyself ? null : _hierarchy[index - 1];
          bool isSelected = isMyself ? _selectedSub == null : _selectedSub?['id'] == sub['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(isMyself ? "Myself" : sub['name'], style: TextStyle(color: isSelected ? Colors.black : Colors.black)),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedSub = sub);
                _fetchDoctors();
              },
              selectedColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? _primaryColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
              backgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn("Total", _totalDoctors.toString(), Colors.white),
              Container(height: 40, width: 1, color: Colors.white30),
              _buildMetricColumn("KBL", _totalKbl.toString(), Colors.purple.shade200),
              Container(height: 40, width: 1, color: Colors.white30),
              _buildMetricColumn("FRD", _totalFrd.toString(), Colors.orange.shade300),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text("Profile Complete", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("$_fullyCompleted", style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text("Incomplete", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("$_incompleteProfile", style: GoogleFonts.poppins(color: Colors.redAccent.shade100, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search by Name, Area, or Speciality...",
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredDoctors.length,
      itemBuilder: (context, index) {
        final doc = _filteredDoctors[index];
        final bool isComplete = _checkIfComplete(doc);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      radius: 22,
                      child: Icon(Icons.person, color: _primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['doctor_name'] ?? 'Unknown',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            "${doc['speciality'] ?? 'No Speciality'} • ${doc['area'] ?? 'No Area'}",
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    
                    // --- ACTION BUTTONS (EDIT & HISTORY) ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Button
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          tooltip: "Edit Doctor",
                          onPressed: () async {
                            final doctorToEdit = Doctor(
                              id: doc['id'],
                              name: doc['doctor_name'] ?? '',
                              mobile: doc['mobile_no'] ?? '',
                              email: doc['email'] ?? '',
                              area: doc['area'] ?? '',
                              pincode: doc['pincode'] ?? '',
                              specialization: doc['speciality'] ?? '',
                              territoryType: doc['territory_type'] ?? 'HQ',
                              isKbl: doc['is_kbl'] == 1,
                              isFrd: doc['is_frd'] == 1,
                              isOther: doc['is_other'] == 1,
                            );
                            
                            final result = await Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => AddDoctorScreen(doctorToEdit: doctorToEdit)
                              )
                            );

                            if (result == true) {
                              _fetchDoctors();
                            }
                          },
                        ),
                        // History Button
                        IconButton(
                          icon: Icon(Icons.history, color: Colors.orange.shade600, size: 20),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          tooltip: "Visit History",
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DoctorHistoryScreen(
                                  doctorId: doc['id'].toString(),
                                  doctorName: doc['doctor_name'] ?? 'Unknown',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (doc['is_kbl'] == 1) _buildMiniBadge("KBL", Colors.purple),
                        if (doc['is_kbl'] == 1 && doc['is_frd'] == 1) const SizedBox(width: 6),
                        if (doc['is_frd'] == 1) _buildMiniBadge("FRD", Colors.orange),
                        if (doc['is_other'] == 1) _buildMiniBadge("Standard", Colors.grey),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          isComplete ? Icons.verified : Icons.error_outline, 
                          color: isComplete ? Colors.green : Colors.redAccent, 
                          size: 16
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isComplete ? "Complete" : "Incomplete",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isComplete ? Colors.green : Colors.redAccent,
                          ),
                        ),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color.shade700),
      ),
    );
  }
}