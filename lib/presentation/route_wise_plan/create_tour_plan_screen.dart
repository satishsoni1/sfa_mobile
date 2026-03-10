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

  // NEW: Controller for Daily Remark
  final TextEditingController _remarkController = TextEditingController();

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
    _loadAreas();

    if (widget.existingData != null) {
      _isActivity = widget.existingData['type'] == 'activity';

      // Load Existing Remark
      _remarkController.text = widget.existingData['remark'] ?? '';

      if (_isActivity) {
        _selectedActivity = widget.existingData['activity_name'];
      }
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);

    final areas = await ApiService().fetchUserAreas();

    setState(() {
      _availableAreas = areas.map((a) {
        // 1. Combine Name and Territory Type if type exists
        String displayName = a['name'];
        if (a['territory_type'] != null &&
            a['territory_type'].toString().trim().isNotEmpty) {
          displayName = "$displayName (${a['territory_type']})";
        }

        return {
          "id": a['id'].toString(),
          "name": displayName, // Now shows "Andheri West (HQ)"
          "dr_count": a['dr_count'] ?? 0,
          "already_planned": false,
        };
      }).toList();

      // 2. Match existing area names to the newly fetched IDs
      if (widget.existingData != null && !_isActivity) {
        if (widget.existingData['areas'] != null) {
          List<String> existingNames = List<String>.from(
            widget.existingData['areas'],
          );

          for (var existingName in existingNames) {
            // Find the area ID that matches the combined name
            var matchedArea = _availableAreas.firstWhere(
              (area) => area['name'] == existingName,
              orElse: () => {},
            );

            if (matchedArea.isNotEmpty) {
              _selectedAreas.add(matchedArea['id']);
            }
          }
        }
      }

      _isLoadingAreas = false;
    });
  }

  // --- Add Area to Server ---
  void _showAddAreaDialog() {
    final TextEditingController newAreaController = TextEditingController();
    String? selectedTerritoryType;
    final List<String> territoryTypes = ['HQ', 'EX HQ', 'OS', 'EX OS'];

    showDialog(
      context: context,
      builder: (ctx) {
        // StatefulBuilder is required here to update the Dropdown UI inside the Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Create New Area"),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min, // Prevents taking full screen height
                children: [
                  TextField(
                    controller: newAreaController,
                    decoration: const InputDecoration(
                      labelText: "Area Name",
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // NEW: Territory Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Territory Type",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedTerritoryType,
                    hint: const Text("Select Type"),
                    items: territoryTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedTerritoryType = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                  ),
                  onPressed: () async {
                    if (newAreaController.text.trim().isEmpty ||
                        selectedTerritoryType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please fill all fields.",
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoadingAreas = true);

                    // Call API to create area (Passing the territory type)
                    final newArea = await ApiService().createArea(
                      newAreaController.text.trim(),
                      selectedTerritoryType!, // NEW PARAMETER
                    );

                    if (newArea != null) {
                      _loadAreas(); // Reload the list so the new area appears
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Area Added!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      setState(() => _isLoadingAreas = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Failed to add area"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "Add",
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

  void _savePlan() async {
    if (!_isActivity && _selectedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one area.")),
      );
      return;
    }

    if (_isActivity && _selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an activity.")),
      );
      return;
    }

    // Build Payload for Laravel
    final payload = {
      "plan_date": DateFormat('yyyy-MM-dd').format(widget.date),
      "type": _isActivity ? "activity" : "field",
      "areas": _selectedAreas.toList(),
      "activity_name": _selectedActivity,
      "remark": _remarkController.text.trim(), // NEW: Passing Remark to API
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool success = await ApiService().saveAreaTourPlan(payload);

    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Plan Saved Successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save plan."),
          backgroundColor: Colors.red,
        ),
      );
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
            Text(
              "Plan for ${DateFormat('dd MMM yyyy').format(widget.date)}",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
            ),
            Text(
              widget.userName,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
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

          Expanded(
            child: _isActivity ? _buildActivitySelector() : _buildAreaList(),
          ),

          // NEW: Remark Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                labelText: "Add Remark (Optional)",
                prefixIcon: const Icon(Icons.notes, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              maxLines: 2,
              minLines: 1,
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "SAVE PLAN",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
            border: Border.all(
              color: isActive ? _primaryColor : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaList() {
    if (_isLoadingAreas)
      return Center(child: CircularProgressIndicator(color: _primaryColor));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Select Specific Areas",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
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
              ? Center(
                  child: Text(
                    "No areas available. Please add one.",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _availableAreas.length,
                  itemBuilder: (ctx, i) {
                    final area = _availableAreas[i];
                    final isSelected = _selectedAreas.contains(area['id']);
                    final isAlreadyPlanned = area['already_planned'] == true;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? _primaryColor
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        activeColor: _primaryColor,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true)
                              _selectedAreas.add(area['id']);
                            else
                              _selectedAreas.remove(area['id']);
                          });
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                area['name'],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isAlreadyPlanned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "Planned Elsewhere",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.medical_services_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${area['dr_count']} Doctors Tagged",
                                style: const TextStyle(color: Colors.grey),
                              ),
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
          Text(
            "Select Activity Type",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text("Choose Activity..."),
                value: _selectedActivity,
                items: _activities
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedActivity = val),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
