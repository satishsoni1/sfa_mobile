import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';


class SobixoVerificationSheet extends StatefulWidget {
  final int brandId;
  final String brandName;
  final List<Map<String, dynamic>> selectedDoctors;
  final int? initialDoctorId;
  final int initialDoctorIndex;
  final void Function(List<Map<String, dynamic>> updatedDetails)? onLocalUpdate;

  const SobixoVerificationSheet({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.selectedDoctors,
    this.initialDoctorId,
    this.initialDoctorIndex = 0,
    this.onLocalUpdate,
  });

  @override
  State<SobixoVerificationSheet> createState() => _SobixoVerificationSheetState();
}

class _DoctorVerificationEntry {
  final int doctorId;
  final String originalFirstName;
  final String originalSurname;
  final String originalMobile;
  final String originalEmail;
  final String? previousFirstName;
  final String? previousSurname;
  final String? previousMobile;
  final String? previousEmail;
  final String? previousFullName;
  final String specialty;
  final String area;
  final bool isPathfinder;

  late final TextEditingController firstNameCtrl;
  late final TextEditingController surnameCtrl;
  late final TextEditingController mobileCtrl;
  late final TextEditingController emailCtrl;

  _DoctorVerificationEntry({
    required this.doctorId,
    required this.originalFirstName,
    required this.originalSurname,
    required this.originalMobile,
    required this.originalEmail,
    this.previousFirstName,
    this.previousSurname,
    this.previousMobile,
    this.previousEmail,
    this.previousFullName,
    required this.specialty,
    required this.area,
    required this.isPathfinder,
  }) {
    firstNameCtrl = TextEditingController(text: originalFirstName);
    surnameCtrl = TextEditingController(text: originalSurname);
    mobileCtrl = TextEditingController(text: originalMobile);
    emailCtrl = TextEditingController(text: originalEmail);
  }

  void dispose() {
    firstNameCtrl.dispose();
    surnameCtrl.dispose();
    mobileCtrl.dispose();
    emailCtrl.dispose();
  }

  String get fullName {
    final fn = firstNameCtrl.text.trim();
    final sn = surnameCtrl.text.trim();
    if (fn.isNotEmpty || sn.isNotEmpty) {
      return '$fn $sn'.trim();
    }
    final ofn = originalFirstName.trim();
    final osn = originalSurname.trim();
    if (ofn.isNotEmpty || osn.isNotEmpty) {
      return '$ofn $osn'.trim();
    }
    return '';
  }

  String? get firstNameError {
    final t = firstNameCtrl.text.trim();
    if (t.isEmpty) return "First Name is mandatory.";
    if (t.length > 100) return "First Name cannot exceed 100 characters.";
    return null;
  }

  String? get surnameError {
    final t = surnameCtrl.text.trim();
    if (t.isEmpty) return "Surname is mandatory.";
    if (t.length > 100) return "Surname cannot exceed 100 characters.";
    return null;
  }

  String? get mobileError {
    final t = mobileCtrl.text.trim();
    if (t.isEmpty) return "Mobile Number is mandatory.";
    final regex = RegExp(r'^[6-9]\d{9}$');
    if (!regex.hasMatch(t)) {
      return "Must be a valid 10-digit number starting with 6, 7, 8, or 9.";
    }
    return null;
  }

  String? get emailError {
    final t = emailCtrl.text.trim();
    if (t.isEmpty) return null; // Optional
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(t)) {
      return "Please enter a valid email format (e.g. doctor@domain.com).";
    }
    return null;
  }

  bool get isValid =>
      firstNameError == null &&
      surnameError == null &&
      mobileError == null &&
      emailError == null;
}

class _SobixoVerificationSheetState extends State<SobixoVerificationSheet> {
  static const Color _primary = Color(0xFF4A148C);
  static const Color _primaryLight = Color(0xFFEDE7F6);
  static const Color _slateDark = Color(0xFF1E293B);
  static const Color _slateGrey = Color(0xFF64748B);

  late final List<_DoctorVerificationEntry> _entries;
  bool _isSubmitting = false;
  bool _hasScrolledToTarget = false;

  int get _targetIndex {
    if (widget.initialDoctorId != null) {
      final idx =
          _entries.indexWhere((e) => e.doctorId == widget.initialDoctorId);
      if (idx != -1) return idx;
    }
    if (widget.initialDoctorIndex >= 0 &&
        widget.initialDoctorIndex < _entries.length) {
      return widget.initialDoctorIndex;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _entries = widget.selectedDoctors.map((doc) {
      final int id = int.tryParse(doc['id']?.toString() ?? '0') ?? 0;

      final Map<String, Map<String, String>> changesMap = {};
      if (doc['has_changes'] == true && doc['changes'] is List) {
        for (final item in (doc['changes'] as List)) {
          if (item is! Map) continue;
          final field = item['field']?.toString().trim() ?? '';
          if (field.isEmpty) continue;
          final oldVal = item['old_value']?.toString().trim() ?? '';
          final newVal = item['new_value']?.toString().trim() ?? '';
          if (!changesMap.containsKey(field)) {
            changesMap[field] = {'old_value': oldVal, 'new_value': newVal};
          } else {
            changesMap[field]!['new_value'] = newVal;
          }
        }
        changesMap.removeWhere((_, v) => v['old_value'] == v['new_value']);
      }

      final String rawFn = (doc['first_name'] ?? '').toString().trim();
      final String rawSn = (doc['surname'] ?? '').toString().trim();
      final String rawDocName = (doc['doctor_name'] ?? '').toString().trim();

      String fn = changesMap['first_name']?['new_value'] ?? rawFn;
      String sn = changesMap['surname']?['new_value'] ?? rawSn;
      if (fn.isEmpty && sn.isEmpty && rawDocName.isNotEmpty) {
        final clean = rawDocName
            .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
            .trim();
        final parts = clean.split(RegExp(r'\s+'));
        if (parts.length > 1) {
          fn = parts.sublist(0, parts.length - 1).join(' ');
          sn = parts.last;
        } else {
          fn = clean;
          sn = '';
        }
      }

      final mobile = changesMap['mobile']?['new_value'] ??
          doc['mobile']?.toString() ??
          doc['phone']?.toString() ??
          '';
      final email =
          changesMap['email']?['new_value'] ?? doc['email']?.toString() ?? '';
      final specialty = doc['specialty_practice_type']?.toString() ??
          doc['specialty']?.toString() ??
          '';
      final area =
          doc['area']?.toString() ?? doc['clinic_name']?.toString() ?? '';
      final bool isPathfinder = doc['is_pathfinder'] == true;

      String? prevFullName;
      if (changesMap['doctor_name'] != null &&
          (changesMap['doctor_name']!['old_value'] ?? '').isNotEmpty) {
        prevFullName = changesMap['doctor_name']!['old_value'];
      } else if (changesMap['first_name'] != null ||
          changesMap['surname'] != null) {
        final pFn = changesMap['first_name']?['old_value'] ?? rawFn;
        final pSn = changesMap['surname']?['old_value'] ?? rawSn;
        final joined = '$pFn $pSn'.trim();
        if (joined.isNotEmpty) prevFullName = joined;
      }

      return _DoctorVerificationEntry(
        doctorId: id,
        originalFirstName: fn,
        originalSurname: sn,
        originalMobile: mobile,
        originalEmail: email,
        previousFirstName: changesMap['first_name']?['old_value'],
        previousSurname: changesMap['surname']?['old_value'],
        previousMobile: changesMap['mobile']?['old_value'],
        previousEmail: changesMap['email']?['old_value'],
        previousFullName: prevFullName,
        specialty: specialty,
        area: area,
        isPathfinder: isPathfinder,
      );
    }).toList();

    for (final e in _entries) {
      e.firstNameCtrl.addListener(_onFieldChanged);
      e.surnameCtrl.addListener(_onFieldChanged);
      e.mobileCtrl.addListener(_onFieldChanged);
      e.emailCtrl.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
    if (widget.onLocalUpdate != null) {
      final updated = _entries.map((e) {
        final fn = e.firstNameCtrl.text.trim();
        final sn = e.surnameCtrl.text.trim();
        return {
          'doctor_id': e.doctorId,
          'first_name': fn,
          'surname': sn,
          'doctor_name': '$fn $sn'.trim(),
          'mobile': e.mobileCtrl.text.trim(),
          'email': e.emailCtrl.text.trim(),
        };
      }).toList();
      widget.onLocalUpdate!(updated);
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  int get _confirmedCount => _entries.where((e) => e.isValid).length;

  bool get _isAllValid {
    if (_entries.length != 3) return false;
    return _entries.every((e) => e.isValid);
  }

  Future<void> _submitVerification() async {
    if (!_isAllValid) return;

    setState(() => _isSubmitting = true);

    try {
      final List<int> doctorIds = _entries.map((e) => e.doctorId).toList();
      final List<Map<String, dynamic>> verifiedDetails = _entries.map((e) {
        final fn = e.firstNameCtrl.text.trim();
        final sn = e.surnameCtrl.text.trim();
        final compositeName = '$fn $sn'.trim();
        return {
          'doctor_id': e.doctorId,
          'first_name': fn,
          'surname': sn,
          'doctor_name': compositeName,
          'mobile': e.mobileCtrl.text.trim(),
          'email': e.emailCtrl.text.trim(),
        };
      }).toList();

      final res = await ApiService().verifyAndSubmitSobixoDoctors(
        widget.brandId,
        doctorIds: doctorIds,
        verifiedDetails: verifiedDetails,
        submitFinal: true,
      );

      if (!mounted) return;

      final message = res['message']?.toString() ??
          "Final list of 3 doctors verified and submitted successfully for '${widget.brandName}'.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $err'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) {
        if (!_hasScrolledToTarget && _targetIndex > 0) {
          _hasScrolledToTarget = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollCtrl.hasClients) {
              final double offset = (_targetIndex * 260.0)
                  .clamp(0.0, scrollCtrl.position.maxScrollExtent);
              scrollCtrl.animateTo(
                offset,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            }
          });
        }
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F6F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag pill
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: _primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_outlined, color: _primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Doctor Verification",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _slateDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _primary.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  "SOBIXO SPECIAL 3",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Verify details. Edit only incorrect fields before final submission.",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _slateGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),

              // Progress Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Verification Progress",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _slateDark,
                          ),
                        ),
                        Text(
                          "$_confirmedCount of ${_entries.length} Verified",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isAllValid ? const Color(0xFF16A34A) : _primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _entries.isEmpty ? 0 : _confirmedCount / _entries.length,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isAllValid ? const Color(0xFF16A34A) : _primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Scrollable doctor cards
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) {
                    final bool isTarget = (i == _targetIndex);
                    return _buildDoctorCard(_entries[i], i + 1, isTarget: isTarget);
                  },
                ),
              ),

              // Bottom Submission Bar
              _buildBottomActionBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDoctorCard(_DoctorVerificationEntry entry, int index, {bool isTarget = false}) {
    final firstNameErr = entry.firstNameError;
    final surnameErr = entry.surnameError;
    final mobileErr = entry.mobileError;
    final emailErr = entry.emailError;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isValid
              ? const Color(0xFF86EFAC)
              : isTarget
                  ? _primary
                  : const Color(0xFFE2E8F0),
          width: (entry.isValid || isTarget) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _primaryLight,
                  child: Text(
                    "$index",
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          if (entry.previousFullName != null &&
                              entry.previousFullName!.isNotEmpty &&
                              entry.previousFullName != entry.fullName) ...[
                            Text(
                              entry.previousFullName!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: const Color(0xFFDC2626),
                                decorationThickness: 2.0,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                          ],
                          Text(
                            entry.fullName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _slateDark,
                            ),
                          ),
                          if (isTarget) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _primaryLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: _primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                "Editing",
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (entry.specialty.isNotEmpty || entry.area.isNotEmpty)
                        Text(
                          [entry.specialty, entry.area].where((s) => s.isNotEmpty).join(' • '),
                          style: GoogleFonts.poppins(fontSize: 11, color: _slateGrey),
                        ),
                    ],
                  ),
                ),
                if (entry.isValid) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          "Verified",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (entry.isPathfinder) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Text(
                      "Target Doctor",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      "MCL Doctor",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // 1. First Name Input (Mandatory with asterisk *)
            _buildTextField(
              label: "First Name *",
              controller: entry.firstNameCtrl,
              icon: Icons.person_outline,
              errorText: firstNameErr,
              previousValue: entry.previousFirstName,
              maxLength: 100,
              hintText: "Enter first name (e.g. Aniket)",
            ),

            const SizedBox(height: 12),

            // 2. Surname Input (Mandatory with asterisk *)
            _buildTextField(
              label: "Surname *",
              controller: entry.surnameCtrl,
              icon: Icons.badge_outlined,
              errorText: surnameErr,
              previousValue: entry.previousSurname,
              maxLength: 100,
              hintText: "Enter surname (e.g. Mandrekar)",
            ),

            const SizedBox(height: 12),

            // 3. Mobile Number Input (Mandatory: 10 digits starting 6-9)
            _buildTextField(
              label: "Mobile Number *",
              controller: entry.mobileCtrl,
              icon: Icons.phone_android_outlined,
              errorText: mobileErr,
              previousValue: entry.previousMobile,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              hintText: "10-digit mobile (e.g. 9876543210)",
            ),

            const SizedBox(height: 12),

            // 4. Email ID Input (Optional)
            _buildTextField(
              label: "Email ID (Optional)",
              controller: entry.emailCtrl,
              icon: Icons.alternate_email_outlined,
              errorText: emailErr,
              previousValue: entry.previousEmail,
              keyboardType: TextInputType.emailAddress,
              hintText: "doctor@example.com",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? errorText,
    String? previousValue,
    String? hintText,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final bool hasError = errorText != null;
    final bool showPrev = previousValue != null &&
        previousValue.isNotEmpty &&
        previousValue != controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: hasError ? const Color(0xFFDC2626) : const Color(0xFF475569),
              ),
            ),
            if (showPrev)
              Text(
                previousValue,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: const Color(0xFFDC2626),
                  decorationThickness: 2.0,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: hasError ? const Color(0xFFDC2626) : _primary.withValues(alpha: 0.6),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: hasError ? const Color(0xFFFEF2F2) : const Color(0xFFFAFAFA),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFDC2626) : _primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    final int confirmedCount = _confirmedCount;
    final bool ready = _isAllValid;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: ready && !_isSubmitting ? _submitVerification : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: ready ? 2 : 0,
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isSubmitting
                  ? "Submitting..."
                  : ready
                      ? "Submit 3 Doctors for Approval"
                      : _entries.length < 3
                          ? "Select 3 Doctors to Submit (${_entries.length}/3)"
                          : "Please correct invalid fields ($confirmedCount/3 Valid)",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
