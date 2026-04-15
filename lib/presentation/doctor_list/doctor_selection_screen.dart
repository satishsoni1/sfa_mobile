import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Services & Models (Adjust these imports to match your project structure)
import '../../data/services/api_service.dart';

class DoctorSelectionScreen extends StatefulWidget {
  final String division; // e.g., 'Z Force 1', 'Z Force 2', 'Z Force 1 KTP'
  final bool isManager; 

  const DoctorSelectionScreen({
    super.key,
    required this.division,
    this.isManager = false,
  });

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _doctors = [];
  
  // State Map: doctor_id -> Category String ('CORE_3', 'FRD_2', 'KBL')
  final Map<int, String> _assignedCategories = {};

  // Hierarchy Data
  List<dynamic> _subordinates = [];
  dynamic _selectedSubordinate; // Null = Viewing own list

  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  final Color _primaryColor = const Color(0xFF4A148C);
  final Color _bgColor = const Color(0xFFF4F6F9);

  // Targets (Safe default values to prevent Hot Reload crashes)
  int _targetCore3Visit = 30;
  int _targetFrd2Visit = 45;
  int _targetKbl = 10;
  Map<String, int> _specialityTargets = {};

  // Dynamic getters for overall counts
  int get _selectedCore3 => _assignedCategories.values.where((c) => c == 'CORE_3').length;
  int get _selectedFrd2 => _assignedCategories.values.where((c) => c == 'FRD_2').length;
  int get _selectedKbl => _assignedCategories.values.where((c) => c == 'KBL').length;

// Add this inside _DoctorSelectionScreenState
  bool _isListApproved = false;

  // Update the Read-Only getter to lock the screen if it's already approved
  bool get _isReadOnly => (widget.isManager && _selectedSubordinate != null) || _isListApproved;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _initializeTargets();
    _loadInitialData();
    _searchController.addListener(() => setState(() {}));
  }

  void _initializeTargets() {
    bool isKTP = widget.division.contains('KTP');
    _targetCore3Visit = isKTP ? 35 : 30;
    _targetFrd2Visit = isKTP ? 45 : 45;
    _targetKbl = isKTP ? 15 : 10;

    if (widget.division.toLowerCase() == 'z1') {
      _specialityTargets = {
        'Paediatrician': 8,
        'Consulting Physician/Diab/Card/Chest': 9,
        'Gynaecologist': 5,
        'Gen. Surgeon': 2,
        'ENT': 2,
        'Orthopedicians': 2,
        'GASTRO PHY': 2
      };
    } else if (widget.division.toLowerCase() == 'z1-ktp') {
      _specialityTargets = {
        'Paediatrician': 10,
        'Consulting Physician/Diab/Card': 8,
        'Chest Physician': 2,
        'Gynaecologist': 5,
        'GASTRO PHY': 2,
        'Orthopedicians': 4,
        'ENT': 4
      };
    }  else if (widget.division.toLowerCase() == 'z1-asam') {
      _specialityTargets = {
        'Consulting Physician/Card/Chest': 10,
        'Paediatrician': 8,
        'Gynaecologist': 6,
        'Gen. Surgeon': 2,
        'ENT': 2,
        'Orthopedicians': 2
      };
    }  else if (widget.division.toLowerCase() == 'z3-asam') {
      _specialityTargets = {
        'Consulting Physician/Intv/Chest/Nephro': 10,
        'Paediatrician': 5,
        'Gynaecologist': 2,
        'Gen. Surgeon': 2,
        'Orthopedicians': 3,
        'Cardiologist': 3,
        'Diabetologist': 2,
        'GASTRO PHY': 2,
        'ENT': 1
      };
    } 
     else if (widget.division.toLowerCase() == 'z1-up') {
      _specialityTargets = {
         'Paediatrician': 8,
         'Consulting Physician/Chest': 9,
         'Gynaecologist': 7,
         'Gen. Surgeon': 2,
         'Orthopedicians': 2,
         'ENT': 2
      };
    } 
     else if (widget.division.toLowerCase() == 'z3-up') {
      _specialityTargets = {
         'Paediatrician': 8,
         'Consulting Physician/Intv/Chest/Nephro': 9,
         'Gynaecologist': 5,
         'Gen. Surgeon': 2,
         'Orthopedicians': 2,
         'Diabetologist': 2,
         'Cardiologist': 1,
         'GASTRO PHY': 1
      };
    } 
    else if (widget.division.toLowerCase() == 'z2') {
      _specialityTargets = {
        'Consulting Physician': 7,
        'Paediatrician': 5,
        'Orthopedicians': 6,
        'ENT': 6,
        'Chest Physician': 6,
      };
    } else {
      _specialityTargets = {};
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- API INTEGRATION ---

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isManager) {
        final subs = await _api.getSubordinates();
        setState(() => _subordinates = subs);
      }
      await _fetchDoctors();
    } catch (e) {
      debugPrint("Init Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDoctors() async {
    setState(() => _isLoading = true);
    try {
      int? targetId = _selectedSubordinate?['id'];
      final response = await _api.getDoctorsMaster(userId: targetId);

      if (mounted) {
        setState(() {
          _doctors = response;
          _assignedCategories.clear();
          _isListApproved = false; // Reset approval state
          
          for (var doc in _doctors) {
            if (doc['selected_category'] != null && doc['selected_category'] != '') {
              _assignedCategories[doc['id']] = doc['selected_category'];
              
              // If ANY assigned doctor is approved, mark the whole list as approved
              if (doc['is_approved'] == 1 || doc['is_approved'] == true) {
                _isListApproved = true;
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack("Failed to fetch doctors", isError: true);
    }
  }

  Future<void> _saveSelection() async {
    setState(() => _isSaving = true);
    
    int? subId = _selectedSubordinate?['id'];
    bool success = await _api.saveDoctorSelection(
      subordinateId: subId, 
      selections: _assignedCategories
    );

    setState(() => _isSaving = false);

    if (success) {
      _showSnack("Selection saved successfully.");
    } else {
      _showSnack("Failed to save selection. Please try again.", isError: true);
    }
  }

  Future<void> _approveSelection() async {
    if (_selectedSubordinate == null) return;
    
    setState(() => _isSaving = true);
    
    bool success = await _api.approveDoctorSelection(
      subordinateId: _selectedSubordinate['id']
    );

    setState(() => _isSaving = false);

    if (success) {
      _showSnack("List approved successfully!", isError: false);
      _fetchDoctors(); // Refresh to lock the UI into Read-Only mode
    } else {
      _showSnack("Failed to approve list.", isError: true);
    }
  }

  // --- LOGIC ---
final Map<String, List<String>> specialityKeywords = {
  'card': ['card', 'cardio', 'cardiologist'],
  'diab': ['diab', 'diabetes', 'diabetologist'],
  'chest': ['chest', 'pulmo', 'pulmonologist'],
  'physician': ['physician', 'consulting physician', 'general'],
  'paediatrician': ['paediatrician', 'pediatrician', 'child'],
  'gynaecologist': ['gynaecologist', 'gynecologist'],
  'ent': ['ent', 'ear', 'nose', 'throat'],
  'orthopedicians': ['ortho', 'orthopedic'],
  'gastro': ['gastro', 'gastroenterologist'],
  'nephro': ['nephro', 'nephrologist'],
};
String? _getMatchedSpecialityKey(String docSpec) {
  if (docSpec.isEmpty) return null;

  String lowerDocSpec = docSpec.toLowerCase();

  for (String key in _specialityTargets.keys) {
    List<String> keyParts = key.toLowerCase().split('/');

    for (String part in keyParts) {
      part = part.trim();

      // Direct match
      if (lowerDocSpec.contains(part)) {
        return key;
      }

      // Keyword mapping match
      for (var entry in specialityKeywords.entries) {
        String normalizedKey = entry.key;
        List<String> aliases = entry.value;

        if (aliases.any((alias) => lowerDocSpec.contains(alias))) {
          if (part.contains(normalizedKey)) {
            return key;
          }
        }
      }
    }
  }

  return null;
}
  // String? _getMatchedSpecialityKey(String docSpec) {
  //   if (docSpec.isEmpty) return null;
  //   String lowerDocSpec = docSpec.toLowerCase();
  //   //print("Matching '$docSpec' against targets: ${_specialityTargets.keys.join(', ')}");

  //   for (String key in _specialityTargets.keys) {
  //     String lowerKey = key.toLowerCase();
  //     print("Checking if '$lowerDocSpec' contains '$lowerKey' or vice versa");
  //     print("Result: ${lowerDocSpec.contains(lowerKey)} || ${lowerKey.contains(lowerDocSpec)}");
  //     if (lowerDocSpec.contains(lowerKey) || lowerKey.contains(lowerDocSpec)) {
  //       return key;
  //     }
  //   }
  //   return null;
  // }

  int _getCoreSpecialityCount(String targetSpecialityKey) {
    int count = 0;
    for (var doc in _doctors) {
      if (_assignedCategories[doc['id']] == 'CORE_3') {
        String docSpec = doc['speciality']?.toString() ?? '';
        String? matchedKey = _getMatchedSpecialityKey(docSpec);
        
        if (matchedKey == targetSpecialityKey) {
          count++;
        }
      }
    }
    return count;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red.shade800 : Colors.black87,
          duration: const Duration(seconds: 2),
        )
      );
    }
  }

  // --- SUBORDINATE SELECTION LOGIC ---
  void _onSubordinateChanged(dynamic sub) {
    setState(() {
      _selectedSubordinate = sub;
      _searchController.clear();
      _tabController.animateTo(0);
    });
    // Re-fetch doctors specifically for the selected subordinate
    _fetchDoctors(); 
  }

  void _showSubordinatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SubordinateSearchSheet(
        subordinates: _subordinates,
        selectedSubordinate: _selectedSubordinate,
        primaryColor: _primaryColor,
        onSelect: _onSubordinateChanged,
      ),
    );
  }

  void _promptAssignCategory(Map<String, dynamic> doc) {
    if (_isReadOnly) return;

    String docSpec = doc['speciality'] ?? 'Unknown';
    String? matchedSpecKey = _getMatchedSpecialityKey(docSpec);

    bool isCoreSpecRestricted = false;
    if (matchedSpecKey == null) {
      isCoreSpecRestricted = true; 
    } else {
      int limit = _specialityTargets[matchedSpecKey]!;
      int current = _getCoreSpecialityCount(matchedSpecKey);
      if (current >= limit) {
        isCoreSpecRestricted = true; 
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Assign Category", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text("Where do you want to add ${doc['doctor_name']} ($docSpec)?"),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAssignButton(
                  catId: 'CORE_3', 
                  label: "3-Visit Core FRD", 
                  current: _selectedCore3, 
                  max: _targetCore3Visit, 
                  docId: doc['id'],
                  isRestrictedBySpec: isCoreSpecRestricted, 
                ),
                const SizedBox(height: 8),
                _buildAssignButton(
                  catId: 'FRD_2', 
                  label: "2-Visit FRD", 
                  current: _selectedFrd2, 
                  max: _targetFrd2Visit, 
                  docId: doc['id']
                ),
                const SizedBox(height: 8),
                _buildAssignButton(
                  catId: 'KBL', 
                  label: "KBL", 
                  current: _selectedKbl, 
                  max: _targetKbl, 
                  docId: doc['id']
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Widget _buildAssignButton({
    required String catId,
    required String label,
    required int current,
    required int max,
    required int docId,
    bool isRestrictedBySpec = false,
  }) {
    bool isTotalFull = current >= max;
    bool isDisabled = isTotalFull || isRestrictedBySpec;

    String buttonText = "$label ($current/$max)";
    if (isRestrictedBySpec) {
      buttonText = "$label (Spec. Restricted)";
    } else if (isTotalFull) {
      buttonText = "$label (Limit Reached)";
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? Colors.grey.shade300 : _primaryColor,
        foregroundColor: isDisabled ? Colors.grey.shade600 : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: isDisabled
          ? null
          : () {
              setState(() => _assignedCategories[docId] = catId);
              Navigator.pop(context);
              _showSnack("Moved to $label");
            },
      child: Text(buttonText),
    );
  }

  void _removeFromCategory(int docId) {
    if (_isReadOnly) return;
    setState(() {
      _assignedCategories.remove(docId);
    });
    _showSnack("Moved back to Remaining");
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
            "Doctor Selection",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            if (widget.isManager && _subordinates.isNotEmpty) _buildSubordinateFilter(),
            
            _buildSelectionSummaryCard(),
            if (_specialityTargets.isNotEmpty) _buildSpecialityWiseSummary(),

            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: _primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _primaryColor,
                isScrollable: true,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: "3-Visit Core FRD"),
                  Tab(text: "2-Visit FRD"),
                  Tab(text: "KBL"),
                  Tab(text: "Remaining"),
                ],
              ),
            ),
            
            _buildSearchBar(),

            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDoctorListForTab('CORE_3'),
                        _buildDoctorListForTab('FRD_2'),
                        _buildDoctorListForTab('KBL'),
                        _buildDoctorListForTab('REMAINING'),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomAction(),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildBottomAction() {
    if (_isLoading) return const SizedBox.shrink();

    // IF APPROVED, SHOW A BADGE INSTEAD OF BUTTONS
    if (_isListApproved) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  "LIST APPROVED",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // IF NOT APPROVED, SHOW SAVE/APPROVE BUTTONS
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isReadOnly ? Colors.green.shade600 : _primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isSaving ? null : (_isReadOnly ? _approveSelection : _saveSelection),
          child: _isSaving 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                _isReadOnly ? "APPROVE LIST" : "SAVE SELECTION",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
        ),
      ),
    );
  }
  Widget _buildSubordinateFilter() {
    return Container(
      color: _primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: InkWell(
        onTap: _showSubordinatePicker, // Trigger the Bottom Sheet
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedSubordinate?['name'] ?? "Select a Team Member",
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
              ),
              const Icon(Icons.arrow_drop_down_circle, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSummaryCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      color: _primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTargetMetric("3-Visit", _selectedCore3, _targetCore3Visit, Colors.blueAccent.shade100),
          Container(height: 30, width: 1, color: Colors.white30),
          _buildTargetMetric("2-Visit", _selectedFrd2, _targetFrd2Visit, Colors.orangeAccent.shade100),
          Container(height: 30, width: 1, color: Colors.white30),
          _buildTargetMetric("KBL", _selectedKbl, _targetKbl, Colors.purpleAccent.shade100),
        ],
      ),
    );
  }

  Widget _buildTargetMetric(String label, int current, int target, Color valueColor) {
    bool isComplete = current == target;
    bool isOver = current > target; 
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$current",
              style: GoogleFonts.poppins(
                color: isComplete ? Colors.greenAccent : (isOver ? Colors.redAccent : valueColor),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              " / $target",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSpecialityWiseSummary() {
    return Container(
      width: double.infinity,
      color: _primaryColor,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Core 3-Visit Targets (${widget.division})",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _specialityTargets.keys.length,
              itemBuilder: (context, index) {
                String spec = _specialityTargets.keys.elementAt(index);
                int target = _specialityTargets[spec]!;
                int current = _getCoreSpecialityCount(spec);
                bool isMet = current >= target;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMet ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isMet ? Colors.greenAccent : Colors.white24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        spec.length > 15 ? "${spec.substring(0, 15)}..." : spec,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                      ),
                      Text(
                        "$current / $target",
                        style: GoogleFonts.poppins(
                          color: isMet ? Colors.greenAccent : Colors.white70, 
                          fontSize: 13, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search doctors...",
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorListForTab(String tabCategory) {
    final query = _searchController.text.toLowerCase();
    
    final list = _doctors.where((doc) {
      final currentAssignedCat = _assignedCategories[doc['id']];
      
      if (tabCategory == 'REMAINING') {
        if (currentAssignedCat != null) return false;
      } else {
        if (currentAssignedCat != tabCategory) return false;
      }

      final name = (doc['doctor_name'] ?? '').toString().toLowerCase();
      final spec = (doc['speciality'] ?? '').toString().toLowerCase();
      return name.contains(query) || spec.contains(query);
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Text(
          tabCategory == 'REMAINING' ? "No remaining doctors." : "No doctors added here yet.", 
          style: GoogleFonts.poppins(color: Colors.grey)
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final doc = list[index];
        final isRemainingTab = tabCategory == 'REMAINING';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isRemainingTab ? Colors.grey.shade200 : _primaryColor.withOpacity(0.5)),
          ),
          child: InkWell(
            onTap: _isReadOnly ? null : () {
              if (isRemainingTab) {
                _promptAssignCategory(doc);
              } else {
                _removeFromCategory(doc['id']);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isRemainingTab ? Colors.grey.shade100 : _primaryColor.withOpacity(0.1),
                    child: Icon(
                      isRemainingTab ? Icons.person_add_alt_1 : Icons.check_circle, 
                      color: isRemainingTab ? Colors.grey.shade400 : _primaryColor
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc['doctor_name'] ?? 'Unknown',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        Text(
                          "${doc['speciality'] ?? 'No Spec.'}",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (!_isReadOnly)
                    Icon(
                      isRemainingTab ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: isRemainingTab ? Colors.blue : Colors.redAccent,
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// CUSTOM SUBORDINATE SEARCH BOTTOM SHEET
// =========================================================================

class _SubordinateSearchSheet extends StatefulWidget {
  final List<dynamic> subordinates;
  final dynamic selectedSubordinate;
  final Function(dynamic) onSelect;
  final Color primaryColor;

  const _SubordinateSearchSheet({
    required this.subordinates,
    this.selectedSubordinate,
    required this.onSelect,
    required this.primaryColor,
  });

  @override
  State<_SubordinateSearchSheet> createState() => _SubordinateSearchSheetState();
}

class _SubordinateSearchSheetState extends State<_SubordinateSearchSheet> {
  String _searchQuery = "";
  late List<dynamic> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = widget.subordinates;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.subordinates.where((sub) {
        final name = sub['name']?.toString().toLowerCase() ?? '';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      "Select Team Member",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search name...",
                    prefixIcon: Icon(Icons.search, color: widget.primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade100,
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredList.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  if (_searchQuery.isNotEmpty &&
                      !"myself".contains(_searchQuery.toLowerCase())) {
                    return const SizedBox.shrink();
                  }
                  bool isSelected = widget.selectedSubordinate == null;
                  return _buildSubordinateTile(
                    name: "Myself",
                    subtitle: "My Territory",
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelect(null);
                    },
                  );
                }

                var sub = _filteredList[index - 1];
                bool isSelected =
                    widget.selectedSubordinate?['id'] == sub['id'];

                return _buildSubordinateTile(
                  name: sub['name']?.toString() ?? 'Unknown',
                  subtitle: sub['designation']?.toString() ?? 'Team Member',
                  imageUrl: sub['photo']?.toString(),
                  isSelected: isSelected,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(sub);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubordinateTile({
    required String name,
    required String subtitle,
    String? imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? widget.primaryColor.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? widget.primaryColor : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade100,
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null
              ? Icon(Icons.person, color: Colors.grey.shade400)
              : null,
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isSelected ? widget.primaryColor : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: widget.primaryColor)
            : null,
      ),
    );
  }
}