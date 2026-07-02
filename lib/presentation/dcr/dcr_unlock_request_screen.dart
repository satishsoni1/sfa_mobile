import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zforce/core/constants/app_colors.dart';
import 'package:zforce/data/services/api_service.dart';
import 'package:zforce/providers/auth_provider.dart';

class DcrUnlockRequestScreen extends StatefulWidget {
  const DcrUnlockRequestScreen({super.key});

  @override
  State<DcrUnlockRequestScreen> createState() => _DcrUnlockRequestScreenState();
}

class _DcrUnlockRequestScreenState extends State<DcrUnlockRequestScreen> {
  // ── Toggle: 'TAB' or 'WEB' ────────────────────────────────────────────────
  String _requestType = 'TAB';

  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  // Status loading
  bool _isLoadingStatus = true;
  Map<String, dynamic>? _tabStatus;  // data.tab
  Map<String, dynamic>? _webStatus;  // data.web

  // Submission
  bool _isSubmitting = false;
  DateTime? _fromDate;

  // to_date is always fromDate + 1 day (sent silently in API, not shown)
  DateTime? get _toDate =>
      _fromDate != null ? _fromDate!.add(const Duration(days: 1)) : null;

  // ── Derived helpers ────────────────────────────────────────────────────────
  bool get _isTabLocked    => _tabStatus?['locked'] == true;
  bool get _isTabRequested => _tabStatus?['requested'] == true;
  bool get _isWebEnabled   => _webStatus?['enabled'] == true;
  bool get _isWebRequested => _webStatus?['requested'] == true;

  /// Returns true when the current toggle type is already unlocked/enabled
  /// — in that case the submit button should be faded & disabled.
  bool get _isAlreadyActive =>
      (_requestType == 'TAB' && !_isTabLocked) ||
      (_requestType == 'WEB' && _isWebEnabled);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ── API: fetch status ──────────────────────────────────────────────────────
  Future<void> _loadStatus() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() => _isLoadingStatus = false);
      return;
    }
    setState(() => _isLoadingStatus = true);
    try {
      final result = await _api.fetchDcrStatus(employeeId: user.employeeId);
      final data = result['data'];
      if (!mounted) return;
      setState(() {
        _tabStatus = data is Map ? Map<String, dynamic>.from(data['tab'] ?? {}) : null;
        _webStatus = data is Map ? Map<String, dynamic>.from(data['web'] ?? {}) : null;
        _isLoadingStatus = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  // ── Date Picker ────────────────────────────────────────────────────────────
  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_requestType == 'WEB' && _fromDate == null) {
      _showSnack('Please select The Date for Web DCR unlock.', isError: true);
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      _showSnack('User not found. Please log in again.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _api.requestDcrUnlock(
        requestType: _requestType,
        employeeId: user.employeeId,
        reason: _reasonController.text.trim(),
        fromDate: _fromDate != null
            ? DateFormat('yyyy-MM-dd').format(_fromDate!)
            : null,
        toDate: _toDate != null
            ? DateFormat('yyyy-MM-dd').format(_toDate!)
            : null,
      );

      final message = result['message']?.toString() ?? 'Request submitted.';
      final success = result['success'] == true;

      if (!mounted) return;
      _showSnack(message, isError: !success);

      if (success) {
        _reasonController.clear();
        _fromDate = null;
        // Refresh status to reflect new pending request
        await _loadStatus();
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F9),
      appBar: AppBar(
        title: Text(
          'DCR Unlock Request',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Status',
            onPressed: _isLoadingStatus ? null : _loadStatus,
          ),
        ],
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status Banner ─────────────────────────────────────────
                    _buildStatusBanner(),
                    const SizedBox(height: 20),

                    // ── Request Type Toggle ───────────────────────────────────
                    _sectionLabel('Request Type'),
                    const SizedBox(height: 8),
                    _buildTypeToggle(),
                    const SizedBox(height: 24),

                    // ── Web: The Date only (to_date sent silently) ───────────
                    if (_requestType == 'WEB') ...[
                      _sectionLabel('Date*'),
                      const SizedBox(height: 8),
                      _buildDateField(
                        label: _fromDate == null
                            ? 'Select The Date'
                            : DateFormat('dd MMM yyyy').format(_fromDate!),
                        icon: Icons.calendar_today_outlined,
                        onTap: _isAlreadyActive ? null : _pickFromDate,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Reason ────────────────────────────────────────────────
                    _sectionLabel('Reason*'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 5,
                      maxLength: 500,
                      enabled: !_isAlreadyActive,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter your reason for unlocking DCR...',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: _isAlreadyActive
                            ? Colors.grey.shade100
                            : Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                        ),
                        counterStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Reason is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // ── Submit Button ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_isSubmitting || _isAlreadyActive) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _isAlreadyActive ? 0 : 2,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'SUBMIT REQUEST',
                                style: GoogleFonts.poppins(
                                  color: Colors.white
                                      .withOpacity(_isAlreadyActive ? 0.55 : 1),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Status Banner ──────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    if (_requestType == 'TAB') {
      return _buildTabStatusBanner();
    } else {
      return _buildWebStatusBanner();
    }
  }

  Widget _buildTabStatusBanner() {
    // locked = false  →  already unlocked
    if (!_isTabLocked) {
      return _StatusCard(
        icon: Icons.lock_open,
        color: Colors.green,
        title: 'Tab DCR is Already Unlocked',
        subtitle: 'Your Tab DCR is currently active. No request needed.',
      );
    }

    // locked = true & requested = true  →  pending
    if (_isTabRequested) {
      final requestedAt = _tabStatus?['request']?['requested_at'] as String?;
      final formatted = _formatDateTime(requestedAt);
      return _StatusCard(
        icon: Icons.hourglass_top_rounded,
        color: Colors.orange,
        title: 'Request Pending',
        subtitle:
            "Your last request, made on $formatted, is still pending approval on the manager's side.",
      );
    }

    // locked = true & not requested  →  no banner, user can request
    return const SizedBox.shrink();
  }

  Widget _buildWebStatusBanner() {
    // enabled = true  →  already enabled
    if (_isWebEnabled) {
      return _StatusCard(
        icon: Icons.language,
        color: Colors.green,
        title: 'Web DCR is Already Enabled',
        subtitle: 'Your Web DCR is currently active. No request needed.',
      );
    }

    // enabled = false & requested = true  →  pending
    if (_isWebRequested) {
      final requestedAt = _webStatus?['request']?['requested_at'] as String?;
      final formatted = _formatDateTime(requestedAt);
      return _StatusCard(
        icon: Icons.hourglass_top_rounded,
        color: Colors.orange,
        title: 'Request Pending',
        subtitle:
            "Your last request, made on $formatted, is still pending approval on the manager's side.",
      );
    }

    // enabled = false & not requested  →  no banner
    return const SizedBox.shrink();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  // ── Sub-Widgets ────────────────────────────────────────────────────────────
  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _toggleOption('TAB', Icons.tablet_android_outlined),
          _toggleOption('WEB', Icons.language_outlined),
        ],
      ),
    );
  }

  Widget _toggleOption(String type, IconData icon) {
    final isSelected = _requestType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _requestType = type;
          _fromDate = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                type == 'TAB' ? 'Tab DCR' : 'Web DCR',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled ? Colors.grey.shade200 : Colors.grey.shade300,
          ),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isDisabled
                    ? Colors.grey.shade400
                    : AppColors.primary),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color:
                      isDisabled ? Colors.grey.shade500 : Colors.black87,
                )),
            const Spacer(),
            if (!isDisabled)
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.black87,
        ),
      );
}

// ── Reusable Status Card ───────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
