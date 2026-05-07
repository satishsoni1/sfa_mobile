import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/models/new_doctor.dart';
import '../../data/models/speciality_target.dart';
import '../../data/services/api_service.dart';

class AddEditNewDoctorScreen extends StatefulWidget {
  final NewDoctor? doctor;
  final List<NewDoctor> existingDoctors;
  final List<SpecialityTarget> mslTargets;
  final List<SpecialityTarget> kblTargets;
  final List<SpecialityTarget> core3Targets;
  final Map<String, int> overallTargets;

  const AddEditNewDoctorScreen({
    super.key,
    this.doctor,
    this.existingDoctors = const [],
    this.mslTargets = const [],
    this.kblTargets = const [],
    this.core3Targets = const [],
    this.overallTargets = const {},
  });

  @override
  State<AddEditNewDoctorScreen> createState() => _AddEditNewDoctorScreenState();
}

class _AddEditNewDoctorScreenState extends State<AddEditNewDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  static const _purple = Color(0xFF4A148C);
  final _picker = ImagePicker();

  // ── Basic Info ──────────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  String _doctorProfile = 'T';
  String? _ageGroup;

  // ── Professional ────────────────────────────────────────────────────────────
  final _specQualCtrl = TextEditingController();
  String? _specPracticeType;
  final _patientsPerDayCtrl = TextEditingController();
  final Set<String> _daysAvailable = {};
  String? _selectedRouteName;
  List<String> _routes = [];
  bool _isLoadingRoutes = true;
  bool _isLoadingOptions = true;
  List<String> _specQualificationOptions = [];
  List<String> _practiceTypeOptions = [];

  // ── Contact & Address ───────────────────────────────────────────────────────
  final _mobileCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _townCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  // ── Classification ──────────────────────────────────────────────────────────
  final _businessPotentialCtrl = TextEditingController();
  bool _isKbl = false;
  bool _isFrd = false;
  bool _isRemaining = true; // default
  // 'kbl' | 'frd' | 'remaining'
  String _classification = 'remaining';
  String? _visitCategory; // CORE_3, FRD_2, KBL, REMAINING

  // ── Personalization ─────────────────────────────────────────────────────────
  final _regNoCtrl = TextEditingController();
  String? _dateOfBirth;
  String? _marriageAnniversary;
  final _clinicOpeningDayCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();
  String? _prescriptionMode; // 'Online' / 'Offline'

  // ── Digital Presence ─────────────────────────────────────────────────────────
  final _linkedinCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  // ── Documents ────────────────────────────────────────────────────────────────
  XFile? _prescriptionPadFile;
  XFile? _visitingCardFile;
  XFile? _signBoardFile;
  String? _prescriptionPadImageUrl;
  String? _visitingCardImageUrl;
  String? _signBoardImageUrl;

  // ── Psychographic ────────────────────────────────────────────────────────────
  String? _clinicalMindset;
  bool _earlyAdopter = false;
  bool _brandLoyalty = false;
  String? _brandPricePreference;
  String? _digitalAdoption;

  bool _isSaving = false;

  // ── Options ─────────────────────────────────────────────────────────────────
  static const _profileOptions = ['H', 'T', 'HT'];
  static const _profileLabels = {
    'H': 'Hospital',
    'T': 'Trade / Clinic',
    'HT': 'Hospital + Trade',
  };
  static const _ageGroups = ['<=35', '36-54', '>=55'];
  static const _fallbackPracticeTypes = [
    'General Physician', 'Cardiologist', 'Dermatologist', 'Gynaecologist',
    'Orthopaedic', 'Neurologist', 'Ophthalmologist', 'ENT', 'Paediatrician',
    'Pulmonologist', 'Diabetologist', 'Gastroenterologist', 'Oncologist',
    'Urologist', 'Psychiatrist', 'Nephrologist', 'Rheumatologist',
    'Endocrinologist', 'Other',
  ];
  static const _fallbackSpecQualifications = [
    'MBBS', 'MD', 'MS', 'DNB', 'DM', 'MCh', 'Diploma', 'Other',
  ];
  static const _dayOptions = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _dayLabels = {
    'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
    'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday', 'Sun': 'Sunday',
  };
  static const _mindsetOptions = [
    'Evidence Based', 'Experience Based', 'Guideline Driven',
  ];
  static const _pricePreferences = ['Economic', 'Premium', 'Does Not Matter'];
  static const _digitalOptions = ['High', 'Low'];

  // Only the two FRD sub-categories (KBL/REMAINING are auto-set)
  static const _frdCategories = [
    {'value': 'CORE_3', 'label': '3-Visit Core FRD', 'sub': '3× / month'},
    {'value': 'FRD_2',  'label': '2-Visit FRD',      'sub': '2× / month'},
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    if (d != null) {
      _firstNameCtrl.text = d.firstName;
      _surnameCtrl.text = d.surname;
      _doctorProfile = d.doctorProfile;
      _ageGroup = d.ageGroup;
      _specQualCtrl.text = d.specialtyQualification;
      _specPracticeType =
          d.specialtyPracticeType.isNotEmpty ? d.specialtyPracticeType : null;
      _patientsPerDayCtrl.text = d.patientsPerDay?.toString() ?? '';
      _daysAvailable.addAll(d.daysAvailable);
      _selectedRouteName = d.routeName;
      _mobileCtrl.text = d.mobile;
      _whatsappCtrl.text = d.whatsapp;
      _emailCtrl.text = d.email;
      _addressCtrl.text = d.address;
      _townCtrl.text = d.town;
      _cityCtrl.text = d.city;
      _pinCtrl.text = d.pin;
      _businessPotentialCtrl.text = d.businessPotential?.toString() ?? '';
      _isKbl = d.isKbl;
      _isFrd = d.isFrd;
      _isRemaining = d.isRemaining;
      _visitCategory = d.visitCategory;
      // Derive classification from visitCategory / flags
      if (d.isKbl || d.visitCategory == 'KBL') {
        _classification = 'kbl';
      } else if (d.isFrd || d.visitCategory == 'CORE_3' || d.visitCategory == 'FRD_2') {
        _classification = 'frd';
      } else {
        _classification = 'remaining';
      }
      _regNoCtrl.text = d.doctorRegNo ?? '';
      _dateOfBirth = d.dateOfBirth;
      _marriageAnniversary = d.marriageAnniversary;
      _clinicOpeningDayCtrl.text = d.clinicOpeningDay ?? '';
      _interestsCtrl.text = d.interests ?? '';
      _prescriptionMode = d.prescriptionMode;
      _linkedinCtrl.text = d.linkedin ?? '';
      _instagramCtrl.text = d.instagram ?? '';
      _websiteCtrl.text = d.website ?? '';
      _youtubeCtrl.text = d.youtube ?? '';
      _prescriptionPadImageUrl = d.prescriptionPadImage;
      _visitingCardImageUrl = d.visitingCardImage;
      _signBoardImageUrl = d.signBoardImage;
      _clinicalMindset = d.clinicalMindset;
      _earlyAdopter = d.earlyAdopter;
      _brandLoyalty = d.brandLoyalty;
      _brandPricePreference = d.brandPricePreference;
      _digitalAdoption = d.digitalAdoption;
    } else {
      // New doctor defaults to REMAINING
      _classification = 'remaining';
      _visitCategory = 'REMAINING';
      _isRemaining = true;
    }
    _loadRoutes();
    _loadMasterOptions();
  }

  // ── Set classification (mutual exclusive) ──────────────────────────────────

  void _setClassification(String val) {
    setState(() {
      _classification = val;
      _isKbl = val == 'kbl';
      _isFrd = val == 'frd';
      _isRemaining = val == 'remaining';
      if (val == 'kbl') {
        _visitCategory = 'KBL';
      } else if (val == 'remaining') {
        _visitCategory = 'REMAINING';
      } else {
        // FRD — keep existing CORE_3/FRD_2, otherwise clear
        if (_visitCategory != 'CORE_3' && _visitCategory != 'FRD_2') {
          _visitCategory = null;
        }
      }
    });
  }

  Future<void> _loadMasterOptions() async {
    setState(() => _isLoadingOptions = true);
    try {
      final options = await ApiService().getNewDoctorMasterOptions();
      final qualifications = options['specialty_qualifications'] ?? [];
      final practiceTypes = options['practice_types'] ?? [];
      if (mounted) {
        setState(() {
          _specQualificationOptions = qualifications.isNotEmpty
              ? qualifications
              : List<String>.from(_fallbackSpecQualifications);
          _practiceTypeOptions = practiceTypes.isNotEmpty
              ? practiceTypes
              : List<String>.from(_fallbackPracticeTypes);
          final currentQualification = _specQualCtrl.text.trim();
          if (currentQualification.isNotEmpty &&
              !_specQualificationOptions.contains(currentQualification)) {
            _specQualificationOptions.add(currentQualification);
          }
          if (_specPracticeType != null &&
              !_practiceTypeOptions.contains(_specPracticeType)) {
            _practiceTypeOptions.add(_specPracticeType!);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _specQualificationOptions = List<String>.from(_fallbackSpecQualifications);
          _practiceTypeOptions = List<String>.from(_fallbackPracticeTypes);
          final currentQualification = _specQualCtrl.text.trim();
          if (currentQualification.isNotEmpty &&
              !_specQualificationOptions.contains(currentQualification)) {
            _specQualificationOptions.add(currentQualification);
          }
          if (_specPracticeType != null &&
              !_practiceTypeOptions.contains(_specPracticeType)) {
            _practiceTypeOptions.add(_specPracticeType!);
          }
        });
      }
    }
    if (mounted) setState(() => _isLoadingOptions = false);
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoadingRoutes = true);
    try {
      final result = await ApiService().getTaRoutes();
      final routesList =
          (result['routes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final seen = <String>{};
      final towns = <String>[];
      for (final r in routesList) {
        final town = r['to_town_code']?.toString() ?? '';
        if (town.isNotEmpty && seen.add(town)) towns.add(town);
      }
      towns.sort();
      if (mounted) setState(() => _routes = towns);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingRoutes = false);
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _surnameCtrl, _specQualCtrl, _patientsPerDayCtrl,
      _mobileCtrl, _whatsappCtrl, _emailCtrl, _addressCtrl, _townCtrl,
      _cityCtrl, _pinCtrl, _businessPotentialCtrl, _regNoCtrl,
      _clinicOpeningDayCtrl, _interestsCtrl,
      _linkedinCtrl, _instagramCtrl, _websiteCtrl, _youtubeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Quota helpers ─────────────────────────────────────────────────────────

  List<NewDoctor> get _otherDoctors {
    final currentId = widget.doctor?.id;
    if (currentId == null) return widget.existingDoctors;
    return widget.existingDoctors.where((d) => d.id != currentId).toList();
  }

  int _countCategory(String category) =>
      _otherDoctors.where((d) => d.visitCategory == category).length;

  String _categoryLabel(String category) {
    switch (category) {
      case 'CORE_3':    return '3-Visit Core FRD';
      case 'FRD_2':     return '2-Visit FRD';
      case 'KBL':       return 'KBL';
      case 'REMAINING': return 'Remaining';
      default:          return category;
    }
  }

  SpecialityTarget? _findGroup(List<SpecialityTarget> list) {
    final sp = _specPracticeType;
    if (sp == null || sp.isEmpty) return null;
    for (final g in list) {
      if (g.contains(sp)) return g;
    }
    return null;
  }

  String? _restrictionMessage({String? category}) {
    final sp = _specPracticeType;
    if (sp == null || sp.isEmpty) return null;

    // Full MSL list limit — count all docs in the same MSL group
    final mslGroup = _findGroup(widget.mslTargets);
    if (mslGroup != null && mslGroup.quota > 0) {
      final count = _otherDoctors
          .where((d) => mslGroup.contains(d.specialtyPracticeType))
          .length;
      if (count + 1 > mslGroup.quota) {
        return '${mslGroup.category} complete list limit reached (${mslGroup.quota}/${mslGroup.quota}).';
      }
    }

    if (category == null || category.isEmpty) return null;

    // Overall category limit
    final overallKey = switch (category) {
      'CORE_3' => 'core_3',
      'FRD_2'  => 'frd_2',
      'KBL'    => 'kbl',
      _        => '',
    };
    final overallLimit = overallKey.isEmpty ? 0 : (widget.overallTargets[overallKey] ?? 0);
    if (overallLimit > 0 && _countCategory(category) + 1 > overallLimit) {
      return '${_categoryLabel(category)} overall limit reached ($overallLimit/$overallLimit).';
    }

    // KBL speciality-group limit
    if (category == 'KBL') {
      final kblGroup = _findGroup(widget.kblTargets);
      if (kblGroup != null && kblGroup.quota > 0) {
        final count = _otherDoctors
            .where((d) => kblGroup.contains(d.specialtyPracticeType) && d.visitCategory == 'KBL')
            .length;
        if (count + 1 > kblGroup.quota) {
          return 'KBL limit reached for ${kblGroup.category} (${kblGroup.quota}/${kblGroup.quota}).';
        }
      }
    }

    // 3-Visit Core FRD speciality-group limit
    if (category == 'CORE_3') {
      final core3Group = _findGroup(widget.core3Targets);
      if (core3Group != null && core3Group.quota > 0) {
        final count = _otherDoctors
            .where((d) => core3Group.contains(d.specialtyPracticeType) && d.visitCategory == 'CORE_3')
            .length;
        if (count + 1 > core3Group.quota) {
          return '3V Core limit reached for ${core3Group.category} (${core3Group.quota}/${core3Group.quota}).';
        }
      }
    }

    return null;
  }

  // ── Photo picker ─────────────────────────────────────────────────────────────

  // index: 0=prescriptionPad, 1=visitingCard, 2=signBoard
  Future<void> _pickImage(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1200);
    if (file == null || !mounted) return;
    setState(() {
      if (index == 0) _prescriptionPadFile = file;
      else if (index == 1) _visitingCardFile = file;
      else _signBoardFile = file;
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // FRD requires a sub-category
    if (_classification == 'frd' &&
        (_visitCategory == null ||
            (_visitCategory != 'CORE_3' && _visitCategory != 'FRD_2'))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a visit type (3-Visit Core FRD or 2-Visit FRD)'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final restriction = _restrictionMessage(category: _visitCategory);
    if (restriction != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(restriction), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final doc = NewDoctor(
        id: widget.doctor?.id,
        firstName: _firstNameCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        doctorProfile: _doctorProfile,
        ageGroup: _ageGroup,
        specialtyQualification: _specQualCtrl.text.trim(),
        specialtyPracticeType: _specPracticeType ?? '',
        patientsPerDay: int.tryParse(_patientsPerDayCtrl.text.trim()),
        daysAvailable: _daysAvailable.toList(),
        routeId: null,
        routeName: _selectedRouteName,
        mobile: _mobileCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        town: _townCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        pin: _pinCtrl.text.trim(),
        businessPotential:
            double.tryParse(_businessPotentialCtrl.text.trim()),
        isKbl: _isKbl,
        isFrd: _isFrd,
        isRemaining: _isRemaining,
        visitCategory: _visitCategory,
        doctorRegNo:
            _regNoCtrl.text.trim().isEmpty ? null : _regNoCtrl.text.trim(),
        dateOfBirth: _dateOfBirth,
        marriageAnniversary: _marriageAnniversary,
        clinicOpeningDay: _clinicOpeningDayCtrl.text.trim().isEmpty
            ? null : _clinicOpeningDayCtrl.text.trim(),
        interests: _interestsCtrl.text.trim().isEmpty
            ? null : _interestsCtrl.text.trim(),
        prescriptionMode: _prescriptionMode,
        linkedin: _linkedinCtrl.text.trim().isEmpty
            ? null : _linkedinCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim().isEmpty
            ? null : _instagramCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty
            ? null : _websiteCtrl.text.trim(),
        youtube: _youtubeCtrl.text.trim().isEmpty
            ? null : _youtubeCtrl.text.trim(),
        clinicalMindset: _clinicalMindset,
        earlyAdopter: _earlyAdopter,
        brandLoyalty: _brandLoyalty,
        brandPricePreference: _brandPricePreference,
        digitalAdoption: _digitalAdoption,
      );

      final payload = doc.toJson();

      // Attach photos as base64
      Future<void> attachPhoto(XFile? f, String key) async {
        if (f == null) return;
        final bytes = await f.readAsBytes();
        payload['${key}_b64'] = base64Encode(bytes);
        payload['${key}_ext'] = f.path.split('.').last.toLowerCase();
      }
      await attachPhoto(_prescriptionPadFile, 'prescription_pad_image');
      await attachPhoto(_visitingCardFile, 'visiting_card_image');
      await attachPhoto(_signBoardFile, 'sign_board_image');

      final api = ApiService();
      if (widget.doctor == null) {
        await api.addNewDoctor(payload);
      } else {
        await api.updateNewDoctor(doc.id!, payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.doctor == null
              ? 'Doctor added successfully!'
              : 'Doctor updated successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Date Picker helper ─────────────────────────────────────────────────────

  Future<void> _pickDate(BuildContext context, String? current,
      void Function(String) onPicked) async {
    final initial = current != null
        ? (DateTime.tryParse(current) ?? DateTime(1990))
        : DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _purple)),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doctor != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Doctor' : 'Add New Doctor',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Basic Info ──────────────────────────────────────────────────
            _sectionCard('Basic Information', Icons.person_outline, _purple, [
              _buildRow([
                _textField(_firstNameCtrl, 'First Name *', validator: _required),
                _textField(_surnameCtrl, 'Surname *', validator: _required),
              ]),
              const SizedBox(height: 14),
              _label('Doctor Profile *'),
              const SizedBox(height: 8),
              _segmentedButtons(
                options: _profileOptions,
                selected: _doctorProfile,
                labelOf: (o) => _profileLabels[o] ?? o,
                onSelect: (v) => setState(() => _doctorProfile = v),
              ),
              const SizedBox(height: 14),
              _dropdownField(
                label: 'Age Group',
                value: _ageGroup,
                items: _ageGroups,
                onChanged: (v) => setState(() => _ageGroup = v),
              ),
            ]),

            // ── Professional ────────────────────────────────────────────────
            _sectionCard('Professional Details', Icons.work_outline,
                Colors.blue, [
              _isLoadingOptions
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ))
                  : _dropdownField(
                      label: 'Specialty (Qualification) *',
                      value: _specQualCtrl.text.trim().isEmpty
                          ? null : _specQualCtrl.text.trim(),
                      items: _specQualificationOptions,
                      onChanged: (v) =>
                          setState(() => _specQualCtrl.text = v ?? ''),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
              const SizedBox(height: 14),
              _isLoadingOptions
                  ? const SizedBox.shrink()
                  : _dropdownField(
                      label: 'Specialty (Type of Practice) *',
                      value: _specPracticeType,
                      items: _practiceTypeOptions,
                      onChanged: (v) => setState(() => _specPracticeType = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
              const SizedBox(height: 14),
              _isLoadingRoutes
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ))
                  : _buildRouteDropdown(),
              const SizedBox(height: 14),
              _textField(_patientsPerDayCtrl, 'Patients per Day (avg OPD)',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              _label('Days Available'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: _dayOptions.map((day) {
                  final selected = _daysAvailable.contains(day);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) _daysAvailable.remove(day);
                      else _daysAvailable.add(day);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: selected ? _purple : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? _purple : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(day,
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12,
                              color: selected ? Colors.white : Colors.grey.shade700)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_daysAvailable.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _daysAvailable.map((d) => _dayLabels[d] ?? d).join(', '),
                  style: TextStyle(fontSize: 12, color: _purple,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ]),

            // ── Contact & Address ───────────────────────────────────────────
            _sectionCard('Contact & Address', Icons.contact_phone_outlined,
                Colors.teal, [
              _textField(_mobileCtrl, 'Personal Mobile Number *',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 10) return 'Enter valid number';
                    return null;
                  }),
              const SizedBox(height: 14),
              _textField(_whatsappCtrl, 'WhatsApp Number',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _textField(_emailCtrl, 'Email ID',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _textField(_addressCtrl, 'Clinic / Hospital Address', maxLines: 2),
              const SizedBox(height: 14),
              _buildRow([
                _textField(_townCtrl, 'Town'),
                _textField(_cityCtrl, 'City'),
              ]),
              const SizedBox(height: 14),
              _textField(_pinCtrl, 'PIN Code',
                  keyboardType: TextInputType.number, maxLength: 6),
            ]),

            // ── Classification ──────────────────────────────────────────────
            _sectionCard('Classification', Icons.star_outline, Colors.orange, [
              _textField(
                _businessPotentialCtrl,
                'Business Potential / Month (₹ Lacs)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixText: '₹ ',
              ),
              const SizedBox(height: 16),
              _label('Doctor Classification *'),
              const SizedBox(height: 8),
              _buildClassificationSelector(),
              const SizedBox(height: 14),
              _buildVisitCategorySection(),
            ]),

            // ── Personalization ─────────────────────────────────────────────
            _sectionCard('Personalization', Icons.person_pin_outlined,
                Colors.indigo, [
              _textField(_regNoCtrl, 'Doctor Registration Number'),
              const SizedBox(height: 14),
              _dateTile('Date of Birth', _dateOfBirth, Icons.cake_outlined,
                  () => _pickDate(context, _dateOfBirth,
                      (v) => setState(() => _dateOfBirth = v))),
              const SizedBox(height: 10),
              _dateTile('Marriage Anniversary', _marriageAnniversary,
                  Icons.favorite_border,
                  () => _pickDate(context, _marriageAnniversary,
                      (v) => setState(() => _marriageAnniversary = v))),
              const SizedBox(height: 14),
              _textField(_clinicOpeningDayCtrl, 'Clinic Opening Day',
                  hint: 'e.g. Monday, 1st of month…'),
              const SizedBox(height: 14),
              _textField(_interestsCtrl, 'Interests / Hobbies', maxLines: 2),
              const SizedBox(height: 14),
              _label('Prescription Mode'),
              const SizedBox(height: 8),
              _buildPrescriptionModeSelector(),
            ]),

            // ── Digital Presence ────────────────────────────────────────────
            _sectionCard('Digital & Social Presence',
                Icons.language_outlined, Colors.cyan.shade700, [
              _textField(_linkedinCtrl, 'LinkedIn',
                  hint: 'https://linkedin.com/in/…',
                  prefixIcon: Icons.work_outlined),
              const SizedBox(height: 14),
              _textField(_instagramCtrl, 'Instagram',
                  hint: '@handle',
                  prefixIcon: Icons.camera_alt_outlined),
              const SizedBox(height: 14),
              _textField(_websiteCtrl, 'Website',
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                  prefixIcon: Icons.public_outlined),
              const SizedBox(height: 14),
              _textField(_youtubeCtrl, 'YouTube',
                  hint: 'Channel URL or name',
                  prefixIcon: Icons.play_circle_outline),
            ]),

            // ── Documents ───────────────────────────────────────────────────
            _sectionCard('Documents', Icons.description_outlined,
                Colors.brown.shade600, [
              _label('Prescription Pad'),
              const SizedBox(height: 10),
              _buildPhotoTile(
                label: 'Prescription Pad',
                icon: Icons.receipt_long_outlined,
                file: _prescriptionPadFile,
                imageUrl: _prescriptionPadImageUrl,
                index: 0,
              ),
              const SizedBox(height: 14),
              _label('Visiting Card'),
              const SizedBox(height: 10),
              _buildPhotoTile(
                label: 'Visiting Card',
                icon: Icons.contact_page_outlined,
                file: _visitingCardFile,
                imageUrl: _visitingCardImageUrl,
                index: 1,
              ),
              const SizedBox(height: 14),
              _label('Dr. Sign Board Photo'),
              const SizedBox(height: 10),
              _buildPhotoTile(
                label: 'Sign Board Photo',
                icon: Icons.storefront_outlined,
                file: _signBoardFile,
                imageUrl: _signBoardImageUrl,
                index: 2,
              ),
            ]),

            // ── Psychographic (hidden) ──────────────────────────────────────
            if (false) _sectionCard('Psychographic Details',
                Icons.psychology_outlined, Colors.deepPurple, [
              _dropdownField(
                label: 'Clinical Mindset / Decision Making Style',
                value: _clinicalMindset,
                items: _mindsetOptions,
                onChanged: (v) => setState(() => _clinicalMindset = v),
              ),
              const SizedBox(height: 14),
              _yesNoToggle('Early Adopter', _earlyAdopter,
                  (v) => setState(() => _earlyAdopter = v)),
              const SizedBox(height: 10),
              _yesNoToggle('Brand Loyalty', _brandLoyalty,
                  (v) => setState(() => _brandLoyalty = v)),
              const SizedBox(height: 14),
              _dropdownField(
                label: 'Brand Price Preference',
                value: _brandPricePreference,
                items: _pricePreferences,
                onChanged: (v) => setState(() => _brandPricePreference = v),
              ),
              const SizedBox(height: 14),
              _dropdownField(
                label: 'Digital Adoption',
                value: _digitalAdoption,
                items: _digitalOptions,
                onChanged: (v) => setState(() => _digitalAdoption = v),
              ),
            ]),
          ],
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isSaving || _isLoadingOptions) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    isEdit ? 'UPDATE DOCTOR' : 'SAVE DOCTOR',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Route Dropdown ─────────────────────────────────────────────────────────

  Widget _buildRouteDropdown() {
    if (_routes.isEmpty) {
      return TextFormField(
        initialValue: _selectedRouteName,
        decoration: InputDecoration(
          labelText: 'Route *',
          prefixIcon: const Icon(Icons.alt_route, color: _purple, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _purple),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: _required,
        onChanged: (v) => setState(() => _selectedRouteName = v),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: (_selectedRouteName != null &&
              _routes.contains(_selectedRouteName))
          ? _selectedRouteName
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Route *',
        prefixIcon: const Icon(Icons.alt_route, color: _purple, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _purple),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: _routes
          .map((town) => DropdownMenuItem<String>(
                value: town,
                child: Text(town, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      onChanged: (val) => setState(() => _selectedRouteName = val),
    );
  }

  // ── Classification Selector (KBL / FRD / Remaining) ────────────────────────

  Widget _buildClassificationSelector() {
    final options = [
      {
        'value': 'kbl',
        'label': 'KBL',
        'sub': 'Key Business\nLeader',
        'color': Colors.deepOrange,
      },
      {
        'value': 'frd',
        'label': 'FRD',
        'sub': 'First Response\nDoctor',
        'color': Colors.indigo,
      },
      {
        'value': 'remaining',
        'label': 'Remaining',
        'sub': 'Other /\nDefault',
        'color': Colors.teal,
      },
    ];

    return Row(
      children: options.asMap().entries.map((entry) {
        final i = entry.key;
        final opt = entry.value;
        final val = opt['value'] as String;
        final isSelected = _classification == val;
        final color = opt['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => _setClassification(val),
            child: Container(
              margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text(opt['label'] as String,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(opt['sub'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey.shade500,
                          fontSize: 9,
                          height: 1.3)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Visit Category (only for FRD; locked for KBL / Remaining) ─────────────

  Widget _buildVisitCategorySection() {
    if (_classification == 'kbl' || _classification == 'remaining') {
      final isKbl = _classification == 'kbl';
      final autoLabel = isKbl ? 'KBL' : 'Remaining';
      final autoColor = isKbl ? Colors.deepOrange : Colors.teal;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: autoColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: autoColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: autoColor),
            const SizedBox(width: 8),
            Text('Visit Category auto-set: ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: autoColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(autoLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // FRD — show CORE_3 and FRD_2 chips
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Visit Type *'),
        const SizedBox(height: 8),
        Row(
          children: _frdCategories.map((cat) {
            final val = cat['value']!;
            final label = cat['label']!;
            final sub = cat['sub']!;
            final isSelected = _visitCategory == val;
            final restriction = _restrictionMessage(category: val);
            final isDisabled = !isSelected && restriction != null;
            final color = val == 'CORE_3' ? _purple : Colors.blue.shade700;
            return Expanded(
              child: GestureDetector(
                onTap: isDisabled
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(restriction ?? 'Category restricted'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    : () => setState(() => _visitCategory = val),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : isDisabled
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? color
                            : isDisabled
                                ? Colors.grey.shade400
                                : Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isDisabled
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                      Text(isDisabled ? 'Restricted' : sub,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white70
                                  : isDisabled
                                      ? Colors.red.shade300
                                      : Colors.grey.shade400,
                              fontSize: 9),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_visitCategory == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Select a visit type',
                style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
          ),
      ],
    );
  }

  // ── Prescription Mode Selector ─────────────────────────────────────────────

  Widget _buildPrescriptionModeSelector() {
    final options = [
      {'value': 'Online',  'label': 'Online',  'icon': Icons.cloud_outlined},
      {'value': 'Offline', 'label': 'Offline', 'icon': Icons.edit_note_outlined},
    ];
    return Row(
      children: options.map((opt) {
        final val = opt['value'] as String;
        final isSelected = _prescriptionMode == val;
        final color = val == 'Online' ? Colors.blue.shade700 : Colors.grey.shade700;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() =>
                _prescriptionMode = isSelected ? null : val),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(opt['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(opt['label'] as String,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Photo Tile ─────────────────────────────────────────────────────────────

  Widget _buildPhotoTile({
    required String label,
    required IconData icon,
    required XFile? file,
    required String? imageUrl,
    required int index,
  }) {
    final hasImage = file != null || (imageUrl != null && imageUrl.isNotEmpty);
    return GestureDetector(
      onTap: () => _pickImage(index),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: hasImage ? Colors.transparent : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasImage
                  ? Colors.brown.shade300
                  : Colors.grey.shade300,
              width: 1.5),
        ),
        child: hasImage
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: file != null
                        ? Image.file(File(file.path),
                            width: double.infinity,
                            height: 110,
                            fit: BoxFit.cover)
                        : Image.network(imageUrl!,
                            width: double.infinity,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _photoPlaceholder(icon, label)),
                  ),
                  // Change photo overlay
                  Positioned(
                    right: 8, bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Change',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _photoPlaceholder(icon, label),
      ),
    );
  }

  Widget _photoPlaceholder(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32, color: Colors.grey.shade300),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 14, color: Colors.brown.shade400),
            const SizedBox(width: 5),
            Text('Add $label',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.brown.shade400,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // ── Section Card ───────────────────────────────────────────────────────────

  Widget _sectionCard(
      String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ],
      ),
    );
  }

  // ── Text Field ─────────────────────────────────────────────────────────────

  Widget _textField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: Colors.grey.shade500)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _purple),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // ── Dropdown Field ─────────────────────────────────────────────────────────

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    final safeValue = (value != null && items.contains(value)) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _purple),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: items
          .map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  // ── Segmented Buttons ──────────────────────────────────────────────────────

  Widget _segmentedButtons({
    required List<String> options,
    required String selected,
    required String Function(String) labelOf,
    required void Function(String) onSelect,
  }) {
    return Row(
      children: options.map((o) {
        final isSelected = selected == o;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(o),
            child: Container(
              margin: EdgeInsets.only(right: o != options.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isSelected ? _purple : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected ? _purple : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text(o,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(labelOf(o),
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey.shade500,
                          fontSize: 10),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Yes/No Toggle ──────────────────────────────────────────────────────────

  Widget _yesNoToggle(
      String label, bool value, void Function(bool) onChange) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ),
        GestureDetector(
          onTap: () => onChange(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            width: 86,
            height: 34,
            decoration: BoxDecoration(
              color: value ? _purple : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment:
                  value ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4)
                    ],
                  ),
                  child: Center(
                    child: Text(
                      value ? 'YES' : 'NO',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: value ? _purple : Colors.grey.shade500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Date Tile ──────────────────────────────────────────────────────────────

  Widget _dateTile(
      String label, String? value, IconData icon, VoidCallback onTap) {
    final display = value != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(value))
        : 'Tap to select';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: _purple, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(display,
                      style: TextStyle(
                          fontSize: 14,
                          color: value != null
                              ? Colors.black87
                              : Colors.grey.shade400,
                          fontWeight: value != null
                              ? FontWeight.w500
                              : FontWeight.normal)),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── Row wrapper ────────────────────────────────────────────────────────────

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600));
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}
