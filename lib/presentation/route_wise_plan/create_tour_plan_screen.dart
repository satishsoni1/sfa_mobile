import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class CreateRouteTourPlanScreen extends StatefulWidget {
  final DateTime date;
  final int? userId;
  final String userName;
  final dynamic existingData;

  const CreateRouteTourPlanScreen({
    required this.date,
    this.userId,
    required this.userName,
    this.existingData,
    super.key,
  });

  @override
  State<CreateRouteTourPlanScreen> createState() =>
      _CreateRouteTourPlanScreenState();
}

class _CreateRouteTourPlanScreenState extends State<CreateRouteTourPlanScreen> {
  bool _isActivity = false;
  String? _selectedActivity;
  Set<String> _selectedAreas = {};

  final TextEditingController _remarkController = TextEditingController();

  // For Joint Work / Subordinate Territory Selection
  String? _selectedWorkingWithId; 
  dynamic _selectedSubordinate; // Holds the selected subordinate's data
  Map<String, dynamic>? _subordinatePlanForDate;

  // New State variables for Subordinates
  List<dynamic> _subordinates = [];
  bool _isLoadingSubordinates = true;

  final List<String> _activities = [
    'Meeting',
    'Leave',
    'Holiday',
    'Admin Work',
    'Transit',
  ];

  final Color _primaryColor = const Color(0xFF2E3192);
  List<Map<String, dynamic>> _availableAreas = [];
  bool _isLoadingAreas = true;

  @override
  void initState() {
    super.initState();
    
    // Load existing data if editing a plan
    if (widget.existingData != null) {
      _isActivity = widget.existingData['type'] == 'activity';
      _remarkController.text = widget.existingData['remark'] ?? '';

      if (_isActivity) {
        _selectedActivity = widget.existingData['activity_name'];
      } else {
        _selectedWorkingWithId = widget.existingData['worked_with_id']?.toString();
      }
    }

    _loadSubordinates(); // Fetch the manager's team independently
    _loadAreasForUser();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  // --- NEW: Fetch Subordinates Directly ---
  Future<void> _loadSubordinates() async {
    try {
      final subs = await ApiService().getSubordinates();
      if (mounted) {
        setState(() {
          _subordinates = subs;
          _isLoadingSubordinates = false;

          // Auto-select the subordinate if one was previously saved
          if (_selectedWorkingWithId != null && _subordinates.isNotEmpty) {
            try {
              _selectedSubordinate = _subordinates.firstWhere(
                (s) => s['id'].toString() == _selectedWorkingWithId
              );
            } catch (_) {
              _selectedSubordinate = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading subordinates: $e");
      if (mounted) {
        setState(() => _isLoadingSubordinates = false);
      }
    }
  }

  // Fetch areas based on the selected subordinate (or self)
  Future<void> _loadAreasForUser() async {
    setState(() => _isLoadingAreas = true);

    int? targetUserId = _selectedWorkingWithId != null 
        ? int.parse(_selectedWorkingWithId!) 
        : widget.userId;

    final areas = await ApiService().fetchUserAreas(userId: targetUserId);

    // If a subordinate is selected, fetch their plan for this specific date
    if (_selectedWorkingWithId != null) {
      final subMonthData = await ApiService().getMonthlyAreaPlans(widget.date, userId: targetUserId);
      String dKey = DateFormat('yyyy-MM-dd').format(widget.date);
      
      var plans = subMonthData['plans'];
      if (plans != null && plans is Map) {
         _subordinatePlanForDate = plans[dKey];
      } else {
         _subordinatePlanForDate = null;
      }
    } else {
      _subordinatePlanForDate = null;
    }

    if (mounted) {
      setState(() {
        _availableAreas = areas.map((a) {
          String displayName = a['name'];
          if (a['territory_type'] != null && a['territory_type'].toString().trim().isNotEmpty) {
            displayName = "$displayName (${a['territory_type']})";
          }

          // Check if the subordinate already planned this area today
          bool plannedBySub = false;
          if (_subordinatePlanForDate != null && _subordinatePlanForDate!['type'] == 'field') {
            List<String> subAreas = List<String>.from(_subordinatePlanForDate!['areas'] ?? []);
            if (subAreas.any((sa) => displayName.contains(sa) || sa.contains(displayName))) {
              plannedBySub = true;
            }
          }

          return {
            "id": a['id'].toString(),
            "name": displayName,
            "dr_count": a['dr_count'] ?? 0,
            "planned_by_sub": plannedBySub,
          };
        }).toList();

        // Restore previously selected areas
        if (widget.existingData != null && !_isActivity && widget.existingData['areas'] != null) {
          List<String> existingNames = List<String>.from(widget.existingData['areas']);
          for (var existingName in existingNames) {
            var matchedArea = _availableAreas.firstWhere(
              (area) => area['name'].toString().contains(existingName) || existingName.contains(area['name'].toString()),
              orElse: () => {},
            );
            if (matchedArea.isNotEmpty) {
              _selectedAreas.add(matchedArea['id']);
            }
          }
        }

        _isLoadingAreas = false;
      });
    }
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
        onSelect: (sub) {
          setState(() {
            _selectedSubordinate = sub;
            _selectedWorkingWithId = sub?['id']?.toString();
            _selectedAreas.clear(); // Clear areas when switching territory
          });
          _loadAreasForUser(); // Fetch areas for the newly selected person
        },
      ),
    );
  }

  void _showAddAreaDialog() {
    final TextEditingController newAreaController = TextEditingController();
    String? selectedTerritoryType;
    final List<String> territoryTypes = ['HQ', 'EX HQ', 'OS', 'EX OS'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Create New Area"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newAreaController,
                    decoration: const InputDecoration(labelText: "Area Name", border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Territory Type", border: OutlineInputBorder()),
                    value: selectedTerritoryType,
                    hint: const Text("Select Type"),
                    items: territoryTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedTerritoryType = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  onPressed: () async {
                    if (newAreaController.text.trim().isEmpty || selectedTerritoryType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoadingAreas = true);

                    final newArea = await ApiService().createArea(newAreaController.text.trim(), selectedTerritoryType!);

                    if (newArea != null) {
                      _loadAreasForUser(); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Area Added!"), backgroundColor: Colors.green));
                    } else {
                      setState(() => _isLoadingAreas = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add area"), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("Add", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _savePlan() async {
    if (!_isActivity && _selectedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one area.")));
      return;
    }

    if (_isActivity && _selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an activity.")));
      return;
    }

    final payload = {
      "plan_date": DateFormat('yyyy-MM-dd').format(widget.date),
      "type": _isActivity ? "activity" : "field",
      "areas": _selectedAreas.toList(),
      "activity_name": _selectedActivity,
      "remark": _remarkController.text.trim(),
      "worked_with_id": _selectedWorkingWithId, // Send who the manager is working with to the API
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool success = await ApiService().saveAreaTourPlan(payload);

    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Saved Successfully!"), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save plan."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Plan for ${DateFormat('dd MMM yyyy').format(widget.date)}", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
            Text(widget.userName, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTab("Field Work (Area)", !_isActivity),
                const SizedBox(width: 12),
                _buildTab("Other Activity", _isActivity),
              ],
            ),
          ),
          
          // --- SUBORDINATE SELECTION BAR ---
          if (!_isActivity)
            if (_isLoadingSubordinates)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SizedBox(
                    height: 24, 
                    width: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                ),
              )
            else if (_subordinates.isNotEmpty)
              _buildSubordinateBar(),

          Expanded(child: _isActivity ? _buildActivitySelector() : _buildAreaList()),
          
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                labelText: "Add Remark (Optional)",
                prefixIcon: const Icon(Icons.notes, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              maxLines: 2,
              minLines: 1,
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _savePlan,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text("SAVE PLAN", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isActivity = label.contains("Activity")),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? _primaryColor : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade600)),
        ),
      ),
    );
  }

  Widget _buildSubordinateBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        onTap: _showSubordinatePicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.handshake, color: _primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Working With / Territory",
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _selectedSubordinate?['name'] ?? "Self (My Territory)",
                      style: GoogleFonts.poppins(color: _primaryColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down_circle, color: _primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaList() {
    if (_isLoadingAreas) return Center(child: CircularProgressIndicator(color: _primaryColor));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedWorkingWithId == null ? "Select Specific Areas" : "Select Subordinate's Areas", 
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)
              ),
              // Only allow adding new areas if working in own territory
              if (_selectedWorkingWithId == null)
                TextButton.icon(
                  onPressed: _showAddAreaDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Add Area"),
                  style: TextButton.styleFrom(foregroundColor: _primaryColor),
                ),
            ],
          ),
        ),
        Expanded(
          child: _availableAreas.isEmpty
              ? Center(child: Text("No areas available.", style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _availableAreas.length,
                  itemBuilder: (ctx, i) {
                    final area = _availableAreas[i];
                    final isSelected = _selectedAreas.contains(area['id']);
                    final isPlannedBySub = area['planned_by_sub'] == true;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? _primaryColor : (isPlannedBySub ? Colors.green.shade300 : Colors.grey.shade200), 
                          width: isSelected || isPlannedBySub ? 2 : 1
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        activeColor: _primaryColor,
                        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedAreas.add(area['id']);
                            else _selectedAreas.remove(area['id']);
                          });
                        },
                        title: Row(
                          children: [
                            Expanded(child: Text(area['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                            
                            // Highlight if the subordinate has also planned to visit this area today
                            if (isPlannedBySub)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text("Planned by Subordinate", style: TextStyle(fontSize: 9, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.medical_services_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text("${area['dr_count']} Doctors Tagged", style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivitySelector() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Activity Type", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text("Choose Activity..."),
                value: _selectedActivity,
                items: _activities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => setState(() => _selectedActivity = val),
              ),
            ),
          ),
        ],
      ),
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
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              children: [
                Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Select Territory", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: "Search team member...",
                    prefixIcon: Icon(Icons.search, color: widget.primaryColor),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                  if (_searchQuery.isNotEmpty && !"self".contains(_searchQuery.toLowerCase())) {
                    return const SizedBox.shrink();
                  }
                  bool isSelected = widget.selectedSubordinate == null;
                  return _buildSubordinateTile(
                    name: "Self",
                    subtitle: "My Own Territory",
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelect(null);
                    },
                  );
                }

                var sub = _filteredList[index - 1];
                bool isSelected = widget.selectedSubordinate?['id'] == sub['id'];

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
        color: isSelected ? widget.primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? widget.primaryColor : Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade100,
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null ? Icon(Icons.person, color: Colors.grey.shade400) : null,
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: isSelected ? widget.primaryColor : Colors.black87),
        ),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
        trailing: isSelected ? Icon(Icons.check_circle, color: widget.primaryColor) : null,
      ),
    );
  }
}