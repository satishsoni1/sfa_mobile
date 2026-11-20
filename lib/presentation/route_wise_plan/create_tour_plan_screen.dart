import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/services/api_service.dart';

class CreateRouteTourPlanScreen extends StatefulWidget {
  final DateTime date;
  final int? userId;
  final String userName;
  final dynamic existingData;
  final bool isCampaignTpEligible;

  const CreateRouteTourPlanScreen({
    required this.date,
    this.userId,
    required this.userName,
    this.existingData,
    this.isCampaignTpEligible = true,
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

  bool _isLoadingCampaignCheck = true;
  List<Map<String, dynamic>> _availableCampaigns = [];
  int? _selectedCampaignDropdownId;
  Set<int> _activeCampaignIds = {};
  Map<int, Set<int>> _campaignSelectedDoctorIds = {}; 
  Map<int, List<Map<String, dynamic>>> _campaignEligibleDoctors = {}; 
  Map<int, int?> _campaignMaxDoctors = {}; 
  Map<int, String> _campaignDoctorIdentification = {}; 
  Set<int> _loadingDoctorCampaignIds = {};

  bool _isDayLocked = false;
  bool _isDayUnlocked = false;
  bool _isEditable = true;
  String? _unlockReason;

  List<String> _activities = [
    'Cycle Meeting',
    'Training',
    'Admin Work',
    'Transit / Traveling',
    'Conference',
    'Head Office Meeting',
    'Meeting',
    'Closing',
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
    _loadCampaignAndLockStatus();
    _loadNfwActivities();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadNfwActivities() async {
    try {
      final items = await ApiService().getOnlyNfwActivities();
      if (items.isNotEmpty && mounted) {
        setState(() {
          _activities = items;
          if (_selectedActivity != null && !_activities.contains(_selectedActivity)) {
            _activities.add(_selectedActivity!);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading NFW activities: $e");
    }
  }

  // --- NEW: Fetch Subordinates Directly ---
  Future<void> _loadSubordinates() async {
    try {
      final subs = await ApiService().getSubordinates(month: widget.date.month, year: widget.date.year);
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
          String rawName = (a['name'] ?? '').toString();
          String displayName = rawName;
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
            "raw_name": rawName,
            "dr_count": a['dr_count'] ?? 0,
            "planned_by_sub": plannedBySub,
          };
        }).toList();

        // Restore previously selected areas
        if (widget.existingData != null && !_isActivity && widget.existingData['areas'] != null) {
          final rawAreas = widget.existingData['areas'];
          final List existingList = rawAreas is List ? rawAreas : [rawAreas];

          for (var existing in existingList) {
            if (existing == null) continue;
            String existingStr = existing.toString().trim();
            if (existingStr.isEmpty) continue;

            // 1. Direct ID match
            var matchedArea = _availableAreas.firstWhere(
              (area) => area['id'].toString() == existingStr,
              orElse: () => {},
            );

            // 2. Exact or normalized name match
            if (matchedArea.isEmpty) {
              String norm(String s) {
                return s
                    .toLowerCase()
                    .replaceAll(RegExp(r'\([^)]*\)'), '') // remove (HQ), (OS), etc.
                    .replaceAll(RegExp(r'[\s\-_–—>]+'), ''); // normalize separators and spaces
              }

              String targetNorm = norm(existingStr);
              if (targetNorm.isNotEmpty) {
                matchedArea = _availableAreas.firstWhere(
                  (area) {
                    String aNameNorm = norm(area['name']?.toString() ?? '');
                    String aRawNorm = norm(area['raw_name']?.toString() ?? '');
                    return aNameNorm == targetNorm ||
                        aRawNorm == targetNorm ||
                        aNameNorm.contains(targetNorm) ||
                        targetNorm.contains(aNameNorm) ||
                        aRawNorm.contains(targetNorm) ||
                        targetNorm.contains(aRawNorm);
                  },
                  orElse: () => {},
                );
              }
            }

            if (matchedArea.isNotEmpty && matchedArea['id'] != null) {
              _selectedAreas.add(matchedArea['id'].toString());
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
          _loadCampaignAndLockStatus(); 
        },
      ),
    );
  }

  Future<void> _loadCampaignAndLockStatus() async {
    setState(() => _isLoadingCampaignCheck = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
    int? targetEmpId = _selectedWorkingWithId != null
        ? int.tryParse(_selectedWorkingWithId!)
        : widget.userId;

    try {
      final lockData = await ApiService().getDayLockStatus(dateStr, employeeId: targetEmpId);
      if (lockData.isNotEmpty) {
        _isDayUnlocked = lockData['is_day_unlocked'] == true;
        bool isMonthLocked = lockData['is_month_locked'] == true;
        _isEditable = lockData['is_editable'] ?? (!isMonthLocked || _isDayUnlocked);
        _isDayLocked = isMonthLocked && !_isDayUnlocked;
        if (lockData['active_unlock'] != null && lockData['active_unlock'] is Map) {
          _unlockReason = lockData['active_unlock']['reason'];
        }
      }

      if (widget.isCampaignTpEligible) {
        final campaigns = await ApiService().getAvailableCampaigns(
          date: dateStr,
          employeeId: targetEmpId,
        );
        _availableCampaigns = campaigns;
      } else {
        _availableCampaigns = [];
      }

      Map<String, dynamic>? dayDetails;
      if (widget.existingData != null) {
        dayDetails = await ApiService().getTourDayDetails(dateStr, employeeId: targetEmpId);
        if (dayDetails != null && dayDetails['areas'] is List) {
          for (var aId in (dayDetails['areas'] as List)) {
            if (aId != null) {
              _selectedAreas.add(aId.toString());
            }
          }
          if (mounted) setState(() {});
        }
      }

      bool hasExistingCampaign = widget.isCampaignTpEligible && widget.existingData != null &&
          (widget.existingData['has_campaign'] == true ||
              widget.existingData['has_campaign'] == 1 ||
              (widget.existingData['campaigns'] is List && (widget.existingData['campaigns'] as List).isNotEmpty));

      if (hasExistingCampaign || (widget.isCampaignTpEligible && dayDetails != null && dayDetails['campaigns'] != null)) {
        dynamic rawCampaigns = dayDetails?['campaigns'] ?? widget.existingData?['campaigns'];

        if (rawCampaigns is List && rawCampaigns.isNotEmpty) {
          for (final c in rawCampaigns) {
            if (c is Map) {
              int? campId = int.tryParse(c['campaign_id']?.toString() ?? c['id']?.toString() ?? '');
              if (campId != null) {
                _activeCampaignIds.add(campId);
                _selectedCampaignDropdownId = campId;

                final String cName = c['campaign_name']?.toString() ?? 'Campaign #$campId';
                final existingCampIndex = _availableCampaigns.indexWhere((ac) => ac['id'] == campId);
                if (existingCampIndex == -1) {
                  _availableCampaigns.add({
                    'id': campId,
                    'campaign_name': cName,
                  });
                } else if (_availableCampaigns[existingCampIndex]['campaign_name'] == null) {
                  _availableCampaigns[existingCampIndex]['campaign_name'] = cName;
                }

                if (c['doctors'] is List) {
                  final docsList = (c['doctors'] as List);
                  _campaignSelectedDoctorIds[campId] = docsList
                      .map<int>((d) {
                        if (d is Map) {
                          return int.tryParse(d['doctor_id']?.toString() ?? d['id']?.toString() ?? '') ?? 0;
                        }
                        return int.tryParse(d.toString()) ?? 0;
                      })
                      .where((id) => id > 0)
                      .toSet();

                  final existingDocs = _campaignEligibleDoctors[campId] ?? [];
                  for (final d in docsList) {
                    if (d is Map) {
                      int docId = int.tryParse(d['doctor_id']?.toString() ?? d['id']?.toString() ?? '') ?? 0;
                      if (docId > 0 && !existingDocs.any((ed) => ed['doctor_id'] == docId)) {
                        existingDocs.add({
                          'doctor_id': docId,
                          'doctor_name': d['doctor_name'] ?? 'Doctor #$docId',
                        });
                      }
                    }
                  }
                  _campaignEligibleDoctors[campId] = existingDocs;
                }
              }
            }
          }
        } else if (dayDetails != null && dayDetails['campaign'] != null) {
          int campId = dayDetails['campaign']['id'];
          _activeCampaignIds.add(campId);
          _selectedCampaignDropdownId = campId;
          if (dayDetails['doctors'] is List) {
            _campaignSelectedDoctorIds[campId] = (dayDetails['doctors'] as List)
                .map<int>((d) => int.tryParse(d['doctor_id'].toString()) ?? 0)
                .where((id) => id > 0)
                .toSet();
          }
        }
      }

      if (widget.isCampaignTpEligible) {
        for (final camp in _availableCampaigns) {
          final int cId = camp['id'];
          _fetchDoctorsForCampaign(cId, targetEmpId: targetEmpId, force: true);
        }
      }
    } catch (e) {
      debugPrint("Error loading campaign & lock status: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCampaignCheck = false);
    }
  }

  Future<void> _fetchDoctorsForCampaign(int campaignId, {int? targetEmpId, bool force = false}) async {
    if (!force &&
        _campaignEligibleDoctors.containsKey(campaignId) &&
        _campaignEligibleDoctors[campaignId]!.isNotEmpty) {
      return;
    }

    setState(() => _loadingDoctorCampaignIds.add(campaignId));
    try {
      final docData = await ApiService().getCampaignEligibleDoctors(
        campaignId: campaignId,
        employeeId: targetEmpId ??
            (_selectedWorkingWithId != null ? int.tryParse(_selectedWorkingWithId!) : widget.userId),
      );
      if (mounted) {
        setState(() {
          final rawList = docData['doctors'];
          if (rawList is List) {
            final fullList = List<Map<String, dynamic>>.from(rawList);
            final existing = _campaignEligibleDoctors[campaignId] ?? [];
            for (final ex in existing) {
              if (!fullList.any((d) => d['doctor_id'] == ex['doctor_id'])) {
                fullList.add(ex);
              }
            }
            _campaignEligibleDoctors[campaignId] = fullList;
          } else if (!_campaignEligibleDoctors.containsKey(campaignId)) {
            _campaignEligibleDoctors[campaignId] = [];
          }
          _campaignDoctorIdentification[campaignId] =
              docData['doctor_identification']?.toString() ?? 'BOTH';

          final camp = _availableCampaigns.firstWhere((c) => c['id'] == campaignId, orElse: () => {});
          final dynamic apiLimit = docData['max_doctors_per_day'] ?? camp['max_doctors_per_day'];
          if (apiLimit != null && int.tryParse(apiLimit.toString()) != null && int.parse(apiLimit.toString()) > 0) {
            _campaignMaxDoctors[campaignId] = int.parse(apiLimit.toString());
          } else {
            _campaignMaxDoctors[campaignId] = null; // Unlimited doctor selection
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching campaign doctors: $e");
    } finally {
      if (mounted) setState(() => _loadingDoctorCampaignIds.remove(campaignId));
    }
  }

  void _showDoctorPicker(int campaignId) {
    final camp = _availableCampaigns.firstWhere((c) => c['id'] == campaignId, orElse: () => {});
    final doctors = _campaignEligibleDoctors[campaignId] ?? [];
    final selectedIds = _campaignSelectedDoctorIds[campaignId] ?? {};
    final maxLimit = _campaignMaxDoctors[campaignId];
    final docIdent = _campaignDoctorIdentification[campaignId] ?? 'BOTH';

    if (doctors.isEmpty && !_loadingDoctorCampaignIds.contains(campaignId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No eligible doctors found for this campaign."), backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CampaignDoctorSearchSheet(
        campaignName: camp['campaign_name'] ?? 'Campaign Doctors',
        doctors: doctors,
        selectedDoctorIds: selectedIds,
        maxDoctors: maxLimit,
        doctorIdentification: docIdent,
        primaryColor: _primaryColor,
        onSelectionChanged: (newSelections) {
          setState(() {
            _campaignSelectedDoctorIds[campaignId] = newSelections;
          });
        },
      ),
    );
  }

  Future<void> _onSelectCampaignAndOpenDoctors(int campaignId) async {
    // If doctors are currently being fetched in background, wait
    if (_loadingDoctorCampaignIds.contains(campaignId)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text("Loading doctors..."),
                ],
              ),
            ),
          ),
        ),
      );
      while (_loadingDoctorCampaignIds.contains(campaignId)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (mounted) Navigator.pop(context);
    } else if (!_campaignEligibleDoctors.containsKey(campaignId) ||
        _campaignEligibleDoctors[campaignId]!.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text("Loading doctors..."),
                ],
              ),
            ),
          ),
        ),
      );
      await _fetchDoctorsForCampaign(campaignId);
      if (mounted) Navigator.pop(context);
    }

    if (mounted) {
      _showDoctorPicker(campaignId);
    }
  }

  /*
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
  */

  void _savePlan() async {
    if (!_isEditable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This tour date is locked and cannot be modified without an active authorized unlock."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isActivity && _selectedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one area.")));
      return;
    }

    if (_isActivity && _selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an activity.")));
      return;
    }

    // --- CAMPAIGN VALIDATION (OPTIONAL FOR FIELD WORK) ---
    final bool hasCampaign = widget.isCampaignTpEligible && !_isActivity && _activeCampaignIds.isNotEmpty;

    if (hasCampaign) {
      for (int campId in _activeCampaignIds) {
        final docIds = _campaignSelectedDoctorIds[campId] ?? {};
        final camp = _availableCampaigns.firstWhere((c) => c['id'] == campId, orElse: () => {});
        final campName = camp['campaign_name'] ?? 'Campaign';

        if (docIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please select at least one doctor for $campName."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final maxLimit = _campaignMaxDoctors[campId];
        if (maxLimit != null && docIds.length > maxLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Doctor selection for $campName exceeds maximum allowed limit of $maxLimit doctors."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    final payload = <String, dynamic>{
      "plan_date": DateFormat('yyyy-MM-dd').format(widget.date),
      "type": _isActivity ? "activity" : "field",
      "has_campaign": hasCampaign,
      "remark": _remarkController.text.trim(),
      "worked_with_id": _selectedWorkingWithId,
    };

    if (!_isActivity) {
      payload["areas"] = _selectedAreas.map((id) => int.tryParse(id) ?? id).toList();
    }

    if (_isActivity) {
      payload["activity_name"] = _selectedActivity;
    }

    if (hasCampaign && _activeCampaignIds.isNotEmpty) {
      final campaignList = <Map<String, dynamic>>[];

      for (int campId in _activeCampaignIds) {
        final ids = _campaignSelectedDoctorIds[campId] ?? {};
        campaignList.add({
          "campaign_id": campId,
          "doctor_ids": ids.toList(),
        });
      }

      payload["campaigns"] = campaignList;

      if (_selectedActivity == null || _selectedActivity!.isEmpty) {
        final names = _activeCampaignIds.map((cid) {
          final c = _availableCampaigns.firstWhere((item) => item['id'] == cid, orElse: () => {});
          return c['campaign_name'] ?? 'Campaign';
        }).join(', ');
        payload["activity_name"] = names.isNotEmpty ? names : "Campaign Field Work";
      }
    } else {
      payload["campaigns"] = [];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService().saveAreaTourPlanWithResult(payload);

    if (mounted) Navigator.pop(context);

    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Plan Saved Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Failed to save plan."),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          if (_isDayUnlocked) _buildUnlockBanner(),
          if (_isDayLocked) _buildLockBanner(),
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
          
          if (!_isActivity && _isLoadingCampaignCheck)
            const LinearProgressIndicator(minHeight: 3),

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
                labelText: "Add Remark ",
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
                onPressed: _isEditable ? _savePlan : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditable ? _primaryColor : Colors.grey, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                child: Text(
                  _isEditable ? "SAVE PLAN" : "DATE LOCKED", 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5), // Light purple
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7B1FA2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFF4A148C), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Campaign Day",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A148C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            "Select Campaign:",
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple.shade900),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade200, width: 1.2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: null, 
                hint: Row(
                  children: [
                    const Icon(Icons.campaign, color: Color(0xFF4A148C), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Select Campaign",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4A148C),
                      ),
                    ),
                  ],
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4A148C)),
                items: _availableCampaigns.map((camp) {
                  final int cid = camp['id'];
                  final int docCount = (_campaignSelectedDoctorIds[cid] ?? {}).length;
                  final String campName = camp['campaign_name'] ?? 'Campaign';

                  return DropdownMenuItem<int>(
                    value: cid,
                    child: Row(
                      children: [
                        const Icon(Icons.campaign, color: Color(0xFF4A148C), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            campName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4A148C),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (docCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$docCount tagged",
                              style: TextStyle(fontSize: 10, color: Colors.purple.shade800, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (campId) {
                  if (campId == null) return;
                  setState(() {
                    _selectedCampaignDropdownId = campId;
                    _activeCampaignIds.add(campId);
                  });
                  _onSelectCampaignAndOpenDoctors(campId);
                },
              ),
            ),
          ),
          if (_activeCampaignIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._activeCampaignIds.map((campId) {
              final camp = _availableCampaigns.firstWhere((c) => c['id'] == campId, orElse: () => {});
              final selectedIds = _campaignSelectedDoctorIds[campId] ?? {};
              final maxLimit = _campaignMaxDoctors[campId];
              final doctors = _campaignEligibleDoctors[campId] ?? [];
              final isLoadingDocs = _loadingDoctorCampaignIds.contains(campId);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header Headed with Campaign Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign, color: Color(0xFF4A148C), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  camp['campaign_name'] ?? 'Campaign',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4A148C),
                                  ),
                                ),
                                if (camp['campaign_type'] != null && camp['campaign_type'].toString().trim().isNotEmpty)
                                  Text(
                                    camp['campaign_type'].toString().trim(),
                                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.purple.shade800),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: selectedIds.isNotEmpty ? Colors.green.shade700 : Colors.orange.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              maxLimit != null 
                                ? "${selectedIds.length}/$maxLimit Doctors"
                                : "No Limit",
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, color: Colors.purple, size: 18),
                            tooltip: "Remove Campaign",
                            onPressed: () {
                              setState(() {
                                _activeCampaignIds.remove(campId);
                                _campaignSelectedDoctorIds.remove(campId);
                                if (_selectedCampaignDropdownId == campId) {
                                  _selectedCampaignDropdownId = _activeCampaignIds.isNotEmpty ? _activeCampaignIds.last : null;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Select / Change Doctors button
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isLoadingDocs ? null : () => _showDoctorPicker(campId),
                                  icon: isLoadingDocs 
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.person_add_alt_1, size: 16),
                                  label: Text(
                                    selectedIds.isEmpty 
                                      ? "Select Doctors" 
                                      : "Change Doctors (${selectedIds.length})",
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A148C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Individual Good Cards for Each Selected Doctor
                          if (selectedIds.isEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    "No doctors tagged yet. Tap above to select.",
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            Text(
                              "Tagged Doctors (${selectedIds.length}):",
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 6),
                            ...selectedIds.map((docId) {
                              final doc = doctors.firstWhere(
                                (d) => d['doctor_id'] == docId,
                                orElse: () => {'doctor_name': 'Doctor #$docId', 'doctor_id': docId},
                              );
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.purple.shade100),
                                ),
                                color: const Color(0xFFFAFAFC),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFFF3E5F5),
                                        child: const Icon(Icons.medical_services_outlined, color: Color(0xFF4A148C), size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    doc['doctor_name'] ?? 'Doctor #$docId',
                                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // if (doc['doctor_category'] != null && doc['doctor_category'].toString().isNotEmpty)
                                                //   Container(
                                                //     padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                //     decoration: BoxDecoration(
                                                //       color: Colors.blue.shade50,
                                                //       borderRadius: BorderRadius.circular(4),
                                                //       border: Border.all(color: Colors.blue.shade200),
                                                //     ),
                                                //     child: Text(
                                                //       doc['doctor_category'].toString(),
                                                //       style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                                //     ),
                                                //   ),
                                              ],
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              "${doc['speciality'] ?? ''} ${doc['qualification'] != null ? '• ${doc['qualification']}' : ''}".trim(),
                                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                if (doc['area'] != null && doc['area'].toString().isNotEmpty) ...[
                                                  const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    "${doc['area']}${doc['town'] != null ? ', ${doc['town']}' : ''}",
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Text("ID: #${doc['doctor_id'] ?? docId}", style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                        tooltip: "Remove Doctor",
                                        onPressed: () {
                                          setState(() {
                                            _campaignSelectedDoctorIds[campId]?.remove(docId);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildUnlockBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade50,
      child: Row(
        children: [
          Icon(Icons.lock_open, size: 18, color: Colors.green.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _unlockReason != null && _unlockReason!.isNotEmpty 
                ? "Date Unlocked: $_unlockReason"
                : "Active authorized unlock for this tour date",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.lock, size: 18, color: Colors.red.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Tour date is locked on an approved/pending month. Modification requires manager unlock.",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade800),
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Campaign Section displayed ONLY during Field Work (Area)
        if (widget.isCampaignTpEligible && _availableCampaigns.isNotEmpty)
          _buildCampaignSection(),

        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedWorkingWithId == null ? "Select Specific Areas" : "Select Subordinate's Areas", 
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)
              ),
              // Only allow adding new areas if working in own territory
              // if (_selectedWorkingWithId == null)
              //   TextButton.icon(
              //     onPressed: _showAddAreaDialog,
              //     icon: const Icon(Icons.add_circle_outline, size: 18),
              //     label: const Text("Add Area"),
              //     style: TextButton.styleFrom(foregroundColor: _primaryColor),
              //   ),
            ],
          ),
        ),

        if (_availableAreas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text("No areas available.", style: TextStyle(color: Colors.grey.shade500))),
          )
        else
          ..._availableAreas.map((area) {
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
                    if (val == true) {
                      _selectedAreas.add(area['id']);
                    } else {
                      _selectedAreas.remove(area['id']);
                    }
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
          }),
      ],
    );
  }

  Widget _buildActivitySelector() {
    final currentActivities = List<String>.from(_activities);
    if (_selectedActivity != null && !currentActivities.contains(_selectedActivity)) {
      currentActivities.add(_selectedActivity!);
    }

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
                items: currentActivities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
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

// =========================================================================
// CUSTOM CAMPAIGN DOCTOR SEARCH BOTTOM SHEET
// =========================================================================

class _CampaignDoctorSearchSheet extends StatefulWidget {
  final String campaignName;
  final List<Map<String, dynamic>> doctors;
  final Set<int> selectedDoctorIds;
  final int? maxDoctors;
  final String doctorIdentification;
  final Function(Set<int>) onSelectionChanged;
  final Color primaryColor;

  const _CampaignDoctorSearchSheet({
    required this.campaignName,
    required this.doctors,
    required this.selectedDoctorIds,
    required this.maxDoctors,
    required this.doctorIdentification,
    required this.onSelectionChanged,
    required this.primaryColor,
  });

  @override
  State<_CampaignDoctorSearchSheet> createState() => _CampaignDoctorSearchSheetState();
}

class _CampaignDoctorSearchSheetState extends State<_CampaignDoctorSearchSheet> {
  String _searchQuery = "";
  late Set<int> _currentSelections;

  @override
  void initState() {
    super.initState();
    _currentSelections = Set<int>.from(widget.selectedDoctorIds);
  }

  List<Map<String, dynamic>> get _filteredDoctors {
    if (_searchQuery.trim().isEmpty) return widget.doctors;
    final q = _searchQuery.toLowerCase();
    return widget.doctors.where((d) {
      final name = d['doctor_name']?.toString().toLowerCase() ?? '';
      final id = d['doctor_id']?.toString().toLowerCase() ?? '';
      final spec = d['speciality']?.toString().toLowerCase() ?? '';
      final town = d['town']?.toString().toLowerCase() ?? '';
      final area = d['area']?.toString().toLowerCase() ?? '';
      return name.contains(q) || id.contains(q) || spec.contains(q) || town.contains(q) || area.contains(q);
    }).toList();
  }

  void _toggle(int doctorId) {
    setState(() {
      if (_currentSelections.contains(doctorId)) {
        _currentSelections.remove(doctorId);
      } else {
        if (widget.maxDoctors != null && _currentSelections.length >= widget.maxDoctors!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Maximum ${widget.maxDoctors} doctors allowed for this campaign."),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _currentSelections.add(doctorId);
      }
    });
    widget.onSelectionChanged(_currentSelections);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.campaign, color: Color(0xFF4A148C), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.campaignName, 
                                  style: GoogleFonts.poppins(
                                    fontSize: 15, 
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4A148C),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  widget.maxDoctors != null
                                    ? "Selected: ${_currentSelections.length} / ${widget.maxDoctors} Doctors"
                                    : "Selected: ${_currentSelections.length} Doctors (No Limit)",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Done", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (q) => setState(() => _searchQuery = q),
                  decoration: InputDecoration(
                    hintText: "Search by doctor name, speciality, area...",
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF4A148C)),
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
            child: _filteredDoctors.isEmpty
                ? Center(
                    child: Text(
                      widget.doctors.isEmpty 
                        ? "No eligible doctors found." 
                        : "No matching doctors found.",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredDoctors[index];
                      final int docId = int.tryParse(doc['doctor_id']?.toString() ?? '0') ?? 0;
                      final isSelected = _currentSelections.contains(docId);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF4A148C) : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          activeColor: const Color(0xFF4A148C),
                          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) => _toggle(docId),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  doc['doctor_name'] ?? 'Doctor #$docId',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                              // if (doc['doctor_category'] != null)
                              //   Container(
                              //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              //     decoration: BoxDecoration(
                              //       color: Colors.blue.shade50,
                              //       borderRadius: BorderRadius.circular(4),
                              //       border: Border.all(color: Colors.blue.shade200),
                              //     ),
                              //     child: Text(
                              //       doc['doctor_category'].toString(),
                              //       style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                              //     ),
                              //   ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                "${doc['speciality'] ?? ''} ${doc['qualification'] != null ? '• ${doc['qualification']}' : ''}",
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (doc['area'] != null) ...[
                                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    Text("${doc['area']}${doc['town'] != null ? ', ${doc['town']}' : ''}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                  ],
                                  Text("ID: #$docId", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}