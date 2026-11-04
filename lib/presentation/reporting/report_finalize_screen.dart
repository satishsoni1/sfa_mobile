import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/visit_report.dart';
import '../../providers/report_provider.dart';
import 'widgets/campaign_fields_card.dart';

class ReportFinalizeScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorSpeciality;
  final bool isPlanned;
  final DateTime visitDateTime;
  final VisitReport? existingReport;
  final List<ProductEntry> products;
  final List<String> workedWithIds;
  final List<Map<String, dynamic>> workedWithDetails;
  final String? initialBusinessValue;
  final String? initialRemark;
  final String? initialOtherRemark;

  const ReportFinalizeScreen({
    required this.doctorId,
    required this.doctorName,
    this.doctorSpeciality = '',
    this.isPlanned = false,
    required this.visitDateTime,
    this.existingReport,
    required this.products,
    required this.workedWithIds,
    required this.workedWithDetails,
    this.initialBusinessValue,
    this.initialRemark,
    this.initialOtherRemark,
    super.key,
  });

  @override
  State<ReportFinalizeScreen> createState() => _ReportFinalizeScreenState();
}

class _ReportFinalizeScreenState extends State<ReportFinalizeScreen> {
  final TextEditingController _businessValueController = TextEditingController();
  final TextEditingController _otherRemarkController = TextEditingController();
  final FocusNode _businessValueFocusNode = FocusNode();

  String? _selectedRemark;
  bool _isSubmitting = false;

  final List<String> remarks = [
    "Asked for immediate availability of brand",
    "Assured for prescription initiation",
    "Asked to give reminder for a brand",
    "Inquired regarding product availability",
    "Prefers competitor product",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate business value
    if (widget.initialBusinessValue != null && widget.initialBusinessValue!.trim().isNotEmpty) {
      _businessValueController.text = widget.initialBusinessValue!.trim();
    } else if (widget.existingReport != null && widget.existingReport!.businessValuePts > 0) {
      _businessValueController.text = widget.existingReport!.businessValuePts.toString();
    }

    // Pre-populate remark
    if (widget.initialRemark != null && widget.initialRemark!.isNotEmpty) {
      _selectedRemark = widget.initialRemark;
      if (widget.initialRemark == 'Other' && widget.initialOtherRemark != null) {
        _otherRemarkController.text = widget.initialOtherRemark!;
      }
    } else if (widget.existingReport != null && widget.existingReport!.remarks.isNotEmpty) {
      final savedRemark = widget.existingReport!.remarks;
      if (remarks.contains(savedRemark)) {
        _selectedRemark = savedRemark;
      } else {
        _selectedRemark = 'Other';
        _otherRemarkController.text = savedRemark;
      }
    }

    // Fetch active dynamic campaigns for this doctor & visit date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<ReportProvider>(context, listen: false);
        provider.loadCampaignsForDoctor(
          doctorId: widget.doctorId,
          visitDateTime: widget.visitDateTime,
        );
        if (widget.existingReport != null &&
            widget.existingReport!.campaignData.isNotEmpty) {
          provider.restoreCampaignData(widget.existingReport!.campaignData);
        }
      }
    });
  }

  @override
  void dispose() {
    _businessValueController.dispose();
    _otherRemarkController.dispose();
    _businessValueFocusNode.dispose();
    super.dispose();
  }

  String _formatDrName(String name) {
    final cleaned = name.replaceAll(
      RegExp(r'^(dr\.?\s*|doctor\s*)', caseSensitive: false),
      '',
    ).trim();
    return 'Dr. $cleaned';
  }

  Future<void> _submitReport() async {
    final String bvText = _businessValueController.text.trim();
    if (bvText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Doctor Business Value as per PTS")),
      );
      return;
    }

    final int ptsValue = int.tryParse(bvText) ?? 0;

    final provider = Provider.of<ReportProvider>(context, listen: false);

    // Validate dynamic campaign fields if any are active
    final campaignError = provider.validateCampaignFields();
    if (campaignError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(campaignError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedRemark == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Visit Outcome / Remark")),
      );
      return;
    }

    String finalRemark = _selectedRemark!;
    if (_selectedRemark == 'Other') {
      if (_otherRemarkController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please type your remark")),
        );
        return;
      }
      finalRemark = _otherRemarkController.text.trim();
    }

    setState(() => _isSubmitting = true);

    final report = VisitReport(
      id: widget.existingReport?.id ?? "",
      doctorId: widget.doctorId,
      doctorName: widget.doctorName,
      doctorSpeciality: widget.doctorSpeciality,
      visitTime: widget.visitDateTime,
      remarks: finalRemark,
      products: widget.products,
      workedWith: widget.workedWithIds,
      workedWithNames: widget.workedWithDetails,
      businessValuePts: ptsValue,
      isSubmitted: false,
      campaignData: provider.buildCampaignDataPayload(),
    );

    try {
      if (widget.existingReport != null) {
        await provider.updateReport(report);
      } else {
        await provider.addReport(report);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report Saved!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBusinessValueSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Business Value",
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _businessValueController,
            focusNode: _businessValueFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: "Dr. Business Value as per PTS *",
              hintText: "Enter amount",
              prefixIcon: Icon(
                Icons.currency_rupee,
                color: primaryColor,
                size: 18,
              ),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitOutcomeSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Visit Outcome",
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRemark,
            isExpanded: true,
            icon: Icon(
              Icons.arrow_drop_down_circle,
              color: primaryColor,
              size: 20,
            ),
            items: remarks
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      r,
                      style: GoogleFonts.poppins(fontSize: 12.5),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _selectedRemark = v;
              if (v != 'Other') {
                _otherRemarkController.clear();
              }
            }),
            decoration: InputDecoration(
              labelText: "Visit Outcome / Remark *",
              prefixIcon: Icon(
                Icons.assignment_outlined,
                color: primaryColor,
                size: 18,
              ),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
        if (_selectedRemark == 'Other') ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _otherRemarkController,
              style: GoogleFonts.poppins(fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Type custom remark...",
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCampaignSection(ReportProvider provider) {
    if (provider.isLoadingCampaigns) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4A148C),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Checking active campaigns...",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final activeCampaigns = provider.activeCampaigns;
    if (activeCampaigns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < activeCampaigns.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          CampaignFieldsCard(
            key: ValueKey("campaign_${activeCampaigns[i].campaignId}"),
            campaign: activeCampaigns[i],
            values: provider.campaignFormValues[activeCampaigns[i].campaignId] ?? {},
            readOnly: false,
            onFieldChanged: (fieldName, value) {
              provider.setCampaignFieldValue(
                activeCampaigns[i].campaignId,
                fieldName,
                value,
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A148C);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: Text(
            widget.existingReport != null ? "Edit Report" : "New Report",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Doctor & Visit Summary Card ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade100,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.medical_services_outlined,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDrName(widget.doctorName),
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (widget.doctorSpeciality.isNotEmpty)
                                        Text(
                                          widget.doctorSpeciality,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (widget.isPlanned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Text(
                                      "Planned",
                                      style: GoogleFonts.poppins(
                                        color: Colors.green.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            // Visit details row
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 13, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a')
                                      .format(widget.visitDateTime),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Badges row: Products count + Joint work count
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.inventory_2_outlined,
                                          size: 12, color: primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${widget.products.length} Brands Selected",
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.workedWithDetails.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.people_outline,
                                            size: 12, color: Colors.orange.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Joint Work (${widget.workedWithDetails.length})",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── RESPONSIVE BUSINESS VALUE, VISIT OUTCOME & DYNAMIC CAMPAIGN ──
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isWide = constraints.maxWidth >= 768;
                          final provider = Provider.of<ReportProvider>(context);
                          final hasCampaigns = provider.activeCampaigns.isNotEmpty;

                          if (isWide && (hasCampaigns || provider.isLoadingCampaigns)) {
                            // ── DESKTOP WEB 2-COLUMN VIEW (Beside Visit Outcome / Business Value) ──
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Core Inputs (Business Value + Visit Outcome)
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildBusinessValueSection(primaryColor),
                                      const SizedBox(height: 20),
                                      _buildVisitOutcomeSection(primaryColor),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Right Column: Dynamic Campaign Module (Beside)
                                Expanded(
                                  flex: 1,
                                  child: _buildCampaignSection(provider),
                                ),
                              ],
                            );
                          } else {
                            // ── COMPACT / MOBILE / SINGLE COLUMN VIEW ──
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildBusinessValueSection(primaryColor),
                                const SizedBox(height: 20),
                                if (hasCampaigns || provider.isLoadingCampaigns) ...[
                                  _buildCampaignSection(provider),
                                  const SizedBox(height: 20),
                                ],
                                _buildVisitOutcomeSection(primaryColor),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── BOTTOM ACTION BAR (SUBMIT / UPDATE) ─────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black.withValues(alpha: 0.06),
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            widget.existingReport != null
                                ? "UPDATE REPORT"
                                : "SUBMIT REPORT",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
