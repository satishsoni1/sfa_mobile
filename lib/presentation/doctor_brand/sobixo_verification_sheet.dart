import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/api_service.dart';


class SobixoVerificationSheet extends StatefulWidget {
  final int brandId;
  final String brandName;
  final List<Map<String, dynamic>> selectedDoctors;

  const SobixoVerificationSheet({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.selectedDoctors,
  });

  @override
  State<SobixoVerificationSheet> createState() => _SobixoVerificationSheetState();
}

class _DoctorVerificationEntry {
  final int doctorId;
  final String originalName;
  final String originalMobile;
  final String originalEmail;
  final String specialty;
  final String area;
  final bool isPathfinder;

  late final TextEditingController nameCtrl;
  late final TextEditingController mobileCtrl;
  late final TextEditingController emailCtrl;
  bool isConfirmed = false;

  _DoctorVerificationEntry({
    required this.doctorId,
    required this.originalName,
    required this.originalMobile,
    required this.originalEmail,
    required this.specialty,
    required this.area,
    required this.isPathfinder,
  }) {
    nameCtrl = TextEditingController(text: originalName);
    mobileCtrl = TextEditingController(text: originalMobile);
    emailCtrl = TextEditingController(text: originalEmail);
  }

  void dispose() {
    nameCtrl.dispose();
    mobileCtrl.dispose();
    emailCtrl.dispose();
  }

  String? get nameError {
    final t = nameCtrl.text.trim();
    if (t.isEmpty) return "Doctor's Name is mandatory.";
    if (t.length < 2) return "Name must be at least 2 characters.";
    if (t.length > 200) return "Name cannot exceed 200 characters.";
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

  bool get isValid => nameError == null && mobileError == null && emailError == null && isConfirmed;
}

class _SobixoVerificationSheetState extends State<SobixoVerificationSheet> {
  static const Color _primary = Color(0xFF4A148C);
  static const Color _primaryLight = Color(0xFFEDE7F6);
  static const Color _slateDark = Color(0xFF1E293B);
  static const Color _slateGrey = Color(0xFF64748B);

  late final List<_DoctorVerificationEntry> _entries;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.selectedDoctors.map((doc) {
      final int id = int.tryParse(doc['id']?.toString() ?? '0') ?? 0;
      final name = doc['doctor_name']?.toString() ?? '';
      final mobile = doc['mobile']?.toString() ?? doc['phone']?.toString() ?? '';
      final email = doc['email']?.toString() ?? '';
      final specialty = doc['specialty_practice_type']?.toString() ?? doc['specialty']?.toString() ?? '';
      final area = doc['area']?.toString() ?? doc['clinic_name']?.toString() ?? '';
      final bool isPathfinder = doc['is_pathfinder'] == true;

      return _DoctorVerificationEntry(
        doctorId: id,
        originalName: name,
        originalMobile: mobile,
        originalEmail: email,
        specialty: specialty,
        area: area,
        isPathfinder: isPathfinder,
      );
    }).toList();

    for (final e in _entries) {
      e.nameCtrl.addListener(() => setState(() {}));
      e.mobileCtrl.addListener(() => setState(() {}));
      e.emailCtrl.addListener(() => setState(() {}));
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
        return {
          'doctor_id': e.doctorId,
          'doctor_name': e.nameCtrl.text.trim(),
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
                      decoration: BoxDecoration(
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
                    return _buildDoctorCard(_entries[i], i + 1);
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

  Widget _buildDoctorCard(_DoctorVerificationEntry entry, int index) {
    final nameErr = entry.nameError;
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
              : const Color(0xFFE2E8F0),
          width: entry.isValid ? 1.5 : 1,
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
                      Text(
                        entry.originalName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _slateDark,
                        ),
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

            // 1. Doctor's Name Input (Mandatory)
            _buildTextField(
              label: "Doctor's Name / Spelling *",
              controller: entry.nameCtrl,
              icon: Icons.person_outline,
              errorText: nameErr,
              maxLength: 200,
              hintText: "Enter full name (e.g. Dr. Rajesh Sharma)",
            ),

            const SizedBox(height: 12),

            // 2. Mobile Number Input (Mandatory: 10 digits starting 6-9)
            _buildTextField(
              label: "Mobile Number *",
              controller: entry.mobileCtrl,
              icon: Icons.phone_android_outlined,
              errorText: mobileErr,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              hintText: "10-digit mobile (e.g. 9876543210)",
            ),

            const SizedBox(height: 12),

            // 3. Email ID Input (Optional)
            _buildTextField(
              label: "Email ID (Optional)",
              controller: entry.emailCtrl,
              icon: Icons.alternate_email_outlined,
              errorText: emailErr,
              keyboardType: TextInputType.emailAddress,
              hintText: "doctor@example.com",
            ),

            const SizedBox(height: 14),

            // 4. Confirmation Checkbox
            InkWell(
              onTap: () {
                setState(() => entry.isConfirmed = !entry.isConfirmed);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: entry.isConfirmed
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: entry.isConfirmed
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: entry.isConfirmed,
                        activeColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() => entry.isConfirmed = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "I confirm that Dr. ${entry.nameCtrl.text.trim().isEmpty ? 'this doctor' : entry.nameCtrl.text.trim()}'s details are verified & accurate.",
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: entry.isConfirmed
                              ? const Color(0xFF14532D)
                              : _slateDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    String? hintText,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final bool hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: hasError ? const Color(0xFFDC2626) : const Color(0xFF475569),
          ),
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
                      : "Confirm All 3 Doctors to Submit ($confirmedCount/3)",
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
